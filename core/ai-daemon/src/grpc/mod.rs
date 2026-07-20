use std::sync::Arc;
use std::time::Duration;
use tokio_stream::wrappers::ReceiverStream;
use tokio_stream::StreamExt;
use tonic::{Request, Response, Status};

use crate::config::DaemonMode;
use crate::inference::GenerationParams;
use crate::DaemonState;

pub mod proto {
    tonic::include_proto!("niraos.ai.v1");
}

pub mod common {
    tonic::include_proto!("niraos.common.v1");
}

pub mod context {
    tonic::include_proto!("niraos.context.v1");
}

pub mod actions {
    tonic::include_proto!("niraos.actions.v1");
}

pub mod permissions {
    tonic::include_proto!("niraos.permissions.v1");
}

pub struct AiGrpcServer {
    pub state: Arc<DaemonState>,
}

#[tonic::async_trait]
impl proto::ai_service_server::AiService for AiGrpcServer {
    type StreamGenerateStream = ReceiverStream<Result<proto::AiResponse, Status>>;

    async fn generate(
        &self,
        request: Request<proto::GenerateRequest>,
    ) -> Result<Response<proto::AiResponse>, Status> {
        let req = request.into_inner();
        validate_request(&req)?;

        self.ensure_model_for_request().await?;

        let context_id = req.context_id.clone();
        if let Some(action_result) = intercept_quick_action(&req.prompt).await {
            return Ok(Response::new(proto::AiResponse {
                text: action_result,
                is_finished: true,
                tokens_used: 0,
                error: None,
            }));
        }

        let full_prompt = if context_id == "active" {
            enrich_prompt_with_context(&req.prompt).await
        } else {
            req.prompt.clone()
        };

        let mut token_stream = {
            let engine = self.state.engine.lock().await;
            let eng = engine
                .as_ref()
                .ok_or_else(|| Status::internal("AI engine not available"))?;
            eng.generate_stream(GenerationParams {
                prompt: full_prompt,
                temperature: req.temperature,
                max_tokens: req.max_tokens as usize,
            })
            .await
            .map_err(|e| Status::internal(e.to_string()))?
        };

        let mut full_text = String::new();
        let mut tokens_used = 0;
        while let Some(result) = token_stream.next().await {
            match result {
                Ok(token) => {
                    if !token.is_finished {
                        full_text.push_str(&token.text);
                        tokens_used += 1;
                    }
                }
                Err(e) => {
                    return Err(Status::internal(format!("generation error: {}", e)));
                }
            }
        }

        let (text, error) = dispatch_tool_if_needed(&full_text).await;

        *self.state.last_activity.lock().await = std::time::Instant::now();

        Ok(Response::new(proto::AiResponse {
            text,
            is_finished: true,
            tokens_used,
            error: error.map(|e| common::Error {
                code: 500,
                message: e,
                details: "".into(),
            }),
        }))
    }

    async fn stream_generate(
        &self,
        request: Request<proto::GenerateRequest>,
    ) -> Result<Response<Self::StreamGenerateStream>, Status> {
        let req = request.into_inner();
        validate_request(&req)?;

        // Fast path: quick actions never touch the model and must return
        // immediately so the UI does not wait on a cold model load.
        if let Some(action_result) = intercept_quick_action(&req.prompt).await {
            let (tx, rx) = tokio::sync::mpsc::channel(32);
            tokio::spawn(async move {
                let _ = tx
                    .send(Ok(proto::AiResponse {
                        text: action_result,
                        is_finished: true,
                        tokens_used: 0,
                        error: None,
                    }))
                    .await;
            });
            return Ok(Response::new(ReceiverStream::new(rx)));
        }

        // ManualPreload refuses to perform an on-demand load; fail fast with a
        // structured status before the stream is opened so the client gets a
        // clean trailers-only response instead of a timed-out stream.
        let mode = *self.state.mode.read().await;
        if mode == DaemonMode::ManualPreload {
            let ms = *self.state.model_state.read().await;
            if ms != crate::ModelState::Ready {
                return Err(Status::failed_precondition(
                    "AI model is not loaded. Use Settings \u{2192} AI to enable a mode that loads the model.",
                ));
            }
        }

        // Context enrichment is network-bounded (a local UDS round trip to the
        // context broker) and cheap, so resolve it before opening the stream.
        let full_prompt = if req.context_id == "active" {
            enrich_prompt_with_context(&req.prompt).await
        } else {
            req.prompt.clone()
        };

        // Open the response stream immediately.  Model loading happens *inside*
        // the spawned task so the HTTP/2 response headers are already flushed
        // by the time the (potentially multi-second) cold load begins.  This is
        // the root-cause fix for the RST_STREAM / "Stream removed" errors: the
        // previous implementation awaited ensure_model_for_request() before
        // returning, so a 2.4 GiB GGUF cold load exceeded the client's 120 s
        // deadline and the client cancelled the not-yet-started stream.
        let (tx, rx) = tokio::sync::mpsc::channel::<Result<proto::AiResponse, Status>>(64);
        let state = self.state.clone();

        tokio::spawn(async move {
            // On-demand model load, inside the stream.
            if let Err(e) = state.ensure_model_loaded().await {
                let _ = tx
                    .send(Err(Status::internal(format!(
                        "failed to load AI model: {}",
                        e
                    ))))
                    .await;
                return;
            }

            let mut token_stream = {
                let engine = state.engine.lock().await;
                let Some(eng) = engine.as_ref() else {
                    let _ = tx
                        .send(Err(Status::internal("AI engine not available")))
                        .await;
                    return;
                };
                match eng
                    .generate_stream(GenerationParams {
                        prompt: full_prompt,
                        temperature: req.temperature,
                        max_tokens: req.max_tokens as usize,
                    })
                    .await
                {
                    Ok(s) => s,
                    Err(e) => {
                        let _ = tx.send(Err(Status::internal(e.to_string()))).await;
                        return;
                    }
                }
            };

            let mut tokens_used = 0;
            loop {
                match token_stream.next().await {
                    Some(Ok(token)) => {
                        if !token.is_finished {
                            tokens_used += 1;
                        }
                        let is_finished = token.is_finished;
                        if tx
                            .send(Ok(proto::AiResponse {
                                text: token.text,
                                is_finished,
                                tokens_used,
                                error: None,
                            }))
                            .await
                            .is_err()
                        {
                            break;
                        }
                        if is_finished {
                            break;
                        }
                    }
                    Some(Err(e)) => {
                        let _ = tx
                            .send(Err(Status::internal(format!(
                                "generation error: {}",
                                e
                            ))))
                            .await;
                        break;
                    }
                    None => break,
                }
            }
            *state.last_activity.lock().await = std::time::Instant::now();
        });

        Ok(Response::new(ReceiverStream::new(rx)))
    }

    async fn get_status(
        &self,
        _request: Request<proto::StatusRequest>,
    ) -> Result<Response<proto::AiStatus>, Status> {
        let mode = *self.state.mode.read().await;
        let ms = *self.state.model_state.read().await;

        // Avoid blocking the (frequent) status poll on the engine mutex while a
        // model load is in progress: a long load would otherwise freeze every
        // status update in the shell.  try_lock lets us fall back to the cached
        // model_state / "loading" indicator when the engine is busy.
        let (active_model, is_loading, vram_usage_mb) = match self.state.engine.try_lock() {
            Ok(engine) => match engine.as_ref() {
                Some(e) => {
                    let status = e
                        .get_hardware_status()
                        .await
                        .map_err(|e| Status::internal(e.to_string()))?;
                    (status.active_model, status.is_loading, status.vram_usage_mb)
                }
                None => ("unloaded".into(), false, 0.0),
            },
            Err(_) => {
                // Engine mutex is contended (a load is in progress). Report the
                // cached state so the UI reflects "loading" instead of hanging.
                let loading = ms == crate::ModelState::Loading;
                let model = if loading { "loading".into() } else { ms.as_str().into() };
                (model, loading, 0.0)
            }
        };

        Ok(Response::new(proto::AiStatus {
            active_model,
            is_loading,
            vram_usage_mb,
            mode: mode.as_str().into(),
            state: ms.as_str().into(),
        }))
    }

    async fn set_mode(
        &self,
        request: Request<proto::SetModeRequest>,
    ) -> Result<Response<proto::SetModeResponse>, Status> {
        let req = request.into_inner();
        let new_mode = match req.mode.as_str() {
            "ondemand" => DaemonMode::OnDemand,
            "always" => DaemonMode::AlwaysEnabled,
            "preload" => DaemonMode::ManualPreload,
            "auto-unload" => DaemonMode::AutoUnload,
            other => {
                return Ok(Response::new(proto::SetModeResponse {
                    success: false,
                    error: format!("unknown mode: {}", other),
                }));
            }
        };

        *self.state.mode.write().await = new_mode;

        if new_mode == DaemonMode::AlwaysEnabled || new_mode == DaemonMode::ManualPreload {
            if let Err(e) = self.state.ensure_model_loaded().await {
                return Ok(Response::new(proto::SetModeResponse {
                    success: false,
                    error: format!("failed to load model: {}", e),
                }));
            }
        } else if new_mode == DaemonMode::OnDemand || new_mode == DaemonMode::AutoUnload {
            if self.state.engine_created.load(std::sync::atomic::Ordering::Acquire) {
                let ms = *self.state.model_state.read().await;
                if ms == crate::ModelState::Ready {
                    // Keep model loaded for now; inactivity timer will unload
                }
            }
        }

        println!("[AI Daemon] Mode changed to: {:?}", new_mode);
        Ok(Response::new(proto::SetModeResponse {
            success: true,
            error: String::new(),
        }))
    }

    async fn set_inactivity_timeout(
        &self,
        request: Request<proto::SetInactivityTimeoutRequest>,
    ) -> Result<Response<proto::SetInactivityTimeoutResponse>, Status> {
        let req = request.into_inner();
        if req.timeout_secs < 30 {
            return Ok(Response::new(proto::SetInactivityTimeoutResponse {
                success: false,
                error: "timeout must be at least 30 seconds".into(),
            }));
        }
        *self.state.inactivity_timeout.write().await = Duration::from_secs(req.timeout_secs as u64);
        println!(
            "[AI Daemon] Inactivity timeout changed to {}s",
            req.timeout_secs
        );
        Ok(Response::new(proto::SetInactivityTimeoutResponse {
            success: true,
            error: String::new(),
        }))
    }
}

impl AiGrpcServer {
    async fn ensure_model_for_request(&self) -> Result<(), Status> {
        let mode = *self.state.mode.read().await;
        if mode == DaemonMode::ManualPreload {
            let ms = *self.state.model_state.read().await;
            if ms != crate::ModelState::Ready {
                return Err(Status::failed_precondition(
                    "AI model is not loaded. Use Settings → AI to enable a mode that loads the model.",
                ));
            }
        }
        self.state
            .ensure_model_loaded()
            .await
            .map_err(|e| Status::internal(format!("failed to load AI model: {}", e)))
    }
}

async fn enrich_prompt_with_context(prompt: &str) -> String {
    let mut full_prompt = prompt.to_string();
    let ch = match sys_utils::uds::connect_uds("context").await {
        Ok(c) => Ok(c),
        Err(_) => match tonic::transport::Endpoint::new("http://[::1]:50054") {
            Ok(e) => e
                .connect_timeout(std::time::Duration::from_millis(500))
                .connect()
                .await
                .map_err(|_| ()),
            Err(_) => Err(()),
        },
    };
    if let Ok(ch) = ch {
        let mut ctx_client = context::context_service_client::ContextServiceClient::new(ch);
        if let Ok(resp) = ctx_client
            .get_context(tonic::Request::new(context::ContextRequest {
                app_id: "nira-ai".into(),
            }))
            .await
        {
            let ctx = resp.into_inner();
            let tool_schema = "To perform an action, output EXACTLY this JSON: {\"type\": \"tool_request\", \"tool\": \"action_id\", \"arguments\": {\"key\": \"value\"}, \"reason\": \"Why you are doing this\"}";
            full_prompt = format!(
                "<|system|> System Context:\nActive Process: {}\nStatus: {}\n{}\n<|user|> {}\n<|assistant|>",
                ctx.active_window_title, ctx.selected_text, tool_schema, prompt
            );
        }
    }
    full_prompt
}

async fn dispatch_tool_if_needed(full_text: &str) -> (String, Option<String>) {
    if !full_text.contains("\"tool_request\"") {
        return (full_text.to_string(), None);
    }

    let tool_req = match crate::agent::tools::parse_tool_request(full_text) {
        Some(r) => r,
        None => return (full_text.to_string(), None),
    };

    let ch = match sys_utils::uds::connect_uds("actions").await {
        Ok(c) => c,
        Err(_) => match tonic::transport::Endpoint::new("http://[::1]:50053")
            .map(|e| e.connect_timeout(std::time::Duration::from_millis(1000)))
            .and_then(|e| Ok(e.connect_lazy()))
        {
            Ok(c) => c,
            Err(_) => {
                return (
                    full_text.to_string(),
                    Some("failed to connect to Action Manager".into()),
                );
            }
        },
    };

    let mut action_client = actions::action_service_client::ActionServiceClient::new(ch);
    let mut params = std::collections::HashMap::new();
    for (k, v) in tool_req.arguments {
        params.insert(k, v);
    }

    match action_client
        .execute_action(tonic::Request::new(actions::ActionRequest {
            action_id: tool_req.tool,
            parameters: params,
            reason: tool_req.reason,
            risk: actions::RiskLevel::Medium as i32,
        }))
        .await
    {
        Ok(resp) => {
            let inner = resp.into_inner();
            (
                format!(
                    "Tool executed: {} (Success: {})",
                    inner.message, inner.success
                ),
                None,
            )
        }
        Err(e) => (
            full_text.to_string(),
            Some(format!("tool execution failed: {}", e)),
        ),
    }
}

fn validate_request(request: &proto::GenerateRequest) -> Result<(), Status> {
    if request.prompt.trim().is_empty() {
        return Err(Status::invalid_argument("prompt must not be empty"));
    }
    if request.prompt.len() > 32_000 {
        return Err(Status::invalid_argument(
            "prompt exceeds the 32 KiB request limit",
        ));
    }
    if request.max_tokens <= 0 || request.max_tokens > 4096 {
        return Err(Status::invalid_argument(
            "max_tokens must be between 1 and 4096",
        ));
    }
    if !request.temperature.is_finite() || !(0.0..=2.0).contains(&request.temperature) {
        return Err(Status::invalid_argument(
            "temperature must be between 0.0 and 2.0",
        ));
    }
    Ok(())
}

async fn intercept_quick_action(prompt: &str) -> Option<String> {
    let trimmed = prompt.trim().to_lowercase();

    if trimmed.contains("optimize") && trimmed.contains("pc")
        || trimmed.contains("optimize") && trimmed.contains("system")
        || trimmed == "optimize my pc"
    {
        return Some(execute_quick_action("optimize_system", "Optimize my PC").await);
    }

    None
}

async fn execute_quick_action(action_id: &str, label: &str) -> String {
    let channel = match sys_utils::uds::connect_uds("actions").await {
        Ok(c) => c,
        Err(_) => {
            return format!(
                "I could not reach the action system to perform \"{}\".",
                label
            )
        }
    };

    let mut client = actions::action_service_client::ActionServiceClient::new(channel);
    let result = client
        .execute_action(tonic::Request::new(actions::ActionRequest {
            action_id: action_id.into(),
            parameters: std::collections::HashMap::new(),
            reason: format!("User requested: {}", label),
            risk: actions::RiskLevel::Low as i32,
        }))
        .await;

    match result {
        Ok(resp) => {
            let inner = resp.into_inner();
            format!(
                "**Action: {}**\n\nI've completed that task. {}",
                label,
                if inner.success {
                    format!("The operation succeeded: {}", inner.message)
                } else {
                    format!("There was an issue: {}", inner.message)
                }
            )
        }
        Err(e) => format!(
            "**Action: {}**\n\nI tried, but couldn't reach the system: {}",
            label, e
        ),
    }
}