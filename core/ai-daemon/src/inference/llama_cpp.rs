use std::io::Read;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex as StdMutex};

use super::{BoxStream, GenerationParams, HardwareStatus, InferenceEngine, ModelConfig, Token};
use anyhow::{bail, Context};
use encoding_rs::UTF_8;
use llama_cpp_2::context::params::LlamaContextParams;
use llama_cpp_2::llama_backend::LlamaBackend;
use llama_cpp_2::llama_batch::LlamaBatch;
use llama_cpp_2::model::AddBos;
use llama_cpp_2::model::LlamaModel;
use llama_cpp_2::sampling::LlamaSampler;
use tokio::sync::{mpsc, oneshot};
use tokio_stream::wrappers::ReceiverStream;

// ── Actor command protocol ──────────────────────────────────────────────
// The worker thread owns the !Send LlamaModel / LlamaContext types.
// Every interaction goes through message passing so the Tokio runtime is
// never blocked by CPU-bound matrix operations.

enum WorkerCommand {
    LoadModel {
        path: PathBuf,
        context_length: usize,
        batch_size: usize,
        reply: oneshot::Sender<anyhow::Result<()>>,
    },
    UnloadModel {
        reply: oneshot::Sender<anyhow::Result<()>>,
    },
    Generate {
        prompt: String,
        params: GenerationParams,
        context_length: usize,
        batch_size: usize,
        token_tx: mpsc::Sender<anyhow::Result<Token>>,
    },
    Shutdown,
}

// ── Public backend ──────────────────────────────────────────────────────

pub struct LlamaCppBackend {
    cmd_tx: mpsc::UnboundedSender<WorkerCommand>,
    model_name: Arc<StdMutex<Option<String>>>,
    is_loaded: Arc<AtomicBool>,
    is_loading: Arc<AtomicBool>,
    context_length: Arc<AtomicUsize>,
    batch_size: Arc<AtomicUsize>,
    _join_handle: Option<std::thread::JoinHandle<()>>,
}

impl LlamaCppBackend {
    pub fn new(default_model_path: PathBuf, default_config: ModelConfig) -> anyhow::Result<Self> {
        println!("Nira AI Backend: inference actor ready (model initialization deferred)");
        let (cmd_tx, cmd_rx) = mpsc::unbounded_channel::<WorkerCommand>();
        let model_name: Arc<StdMutex<Option<String>>> = Arc::new(StdMutex::new(None));
        let is_loaded = Arc::new(AtomicBool::new(false));
        let is_loading = Arc::new(AtomicBool::new(false));
        let context_length: Arc<AtomicUsize> =
            Arc::new(AtomicUsize::new(default_config.context_length));
        let batch_size: Arc<AtomicUsize> = Arc::new(AtomicUsize::new(default_config.batch_size));

        let mn = Arc::clone(&model_name);
        let il = Arc::clone(&is_loaded);
        let loading = Arc::clone(&is_loading);
        let cl = Arc::clone(&context_length);
        let bs = Arc::clone(&batch_size);

        let join_handle = std::thread::Builder::new()
            .name("nira-inference".into())
            .spawn(move || {
                worker_thread(
                    cmd_rx,
                    mn,
                    il,
                    loading,
                    cl,
                    bs,
                    default_model_path,
                    default_config,
                )
            })?;

        Ok(Self {
            cmd_tx,
            model_name,
            is_loaded,
            is_loading,
            context_length,
            batch_size,
            _join_handle: Some(join_handle),
        })
    }
}

impl Drop for LlamaCppBackend {
    fn drop(&mut self) {
        let _ = self.cmd_tx.send(WorkerCommand::Shutdown);
    }
}

// ── InferenceEngine trait impl (never blocks the async runtime) ─────────

#[async_trait::async_trait]
impl InferenceEngine for LlamaCppBackend {
    async fn load_model(&mut self, path: &Path, config: ModelConfig) -> anyhow::Result<()> {
        let (tx, rx) = oneshot::channel();
        self.cmd_tx
            .send(WorkerCommand::LoadModel {
                path: path.to_path_buf(),
                context_length: config.context_length,
                batch_size: config.batch_size,
                reply: tx,
            })
            .map_err(|_| anyhow::anyhow!("inference worker channel closed"))?;
        rx.await
            .map_err(|_| anyhow::anyhow!("inference worker reply cancelled"))?
    }

    async fn unload_model(&mut self) -> anyhow::Result<()> {
        let (tx, rx) = oneshot::channel();
        self.cmd_tx
            .send(WorkerCommand::UnloadModel { reply: tx })
            .map_err(|_| anyhow::anyhow!("inference worker channel closed"))?;
        rx.await
            .map_err(|_| anyhow::anyhow!("inference worker reply cancelled"))?
    }

    async fn generate_stream(
        &self,
        params: GenerationParams,
    ) -> anyhow::Result<BoxStream<anyhow::Result<Token>>> {
        if params.prompt.trim().is_empty() {
            bail!("prompt must not be empty");
        }
        if params.max_tokens == 0 {
            bail!("max_tokens must be greater than zero");
        }

        let (token_tx, token_rx) = mpsc::channel::<anyhow::Result<Token>>(64);
        let ctx = self.context_length.load(Ordering::Acquire);
        let batch = self.batch_size.load(Ordering::Acquire);

        let started_loading = if !self.is_loaded.load(Ordering::Acquire) {
            self.is_loading
                .compare_exchange(false, true, Ordering::AcqRel, Ordering::Acquire)
                .is_ok()
        } else {
            false
        };

        if let Err(error) = self.cmd_tx.send(WorkerCommand::Generate {
            prompt: params.prompt.clone(),
            params,
            context_length: ctx,
            batch_size: batch,
            token_tx,
        }) {
            if started_loading {
                self.is_loading.store(false, Ordering::Release);
            }
            return Err(anyhow::anyhow!("inference worker channel closed: {error}"));
        }

        Ok(Box::pin(ReceiverStream::new(token_rx)))
    }

    async fn get_hardware_status(&self) -> anyhow::Result<HardwareStatus> {
        let active_model = self
            .model_name
            .lock()
            .map_err(|_| anyhow::anyhow!("model status lock poisoned"))?
            .clone()
            .unwrap_or_else(|| "none".into());
        Ok(HardwareStatus {
            active_model,
            is_loading: self.is_loading.load(Ordering::Acquire),
            vram_usage_mb: 0.0,
        })
    }
}

// ── Worker thread ───────────────────────────────────────────────────────
// Runs on a dedicated OS thread named "nira-inference".  Owns the
// LlamaModel and creates per-request LlamaContext instances locally.

fn worker_thread(
    mut cmd_rx: mpsc::UnboundedReceiver<WorkerCommand>,
    model_name: Arc<StdMutex<Option<String>>>,
    is_loaded: Arc<AtomicBool>,
    is_loading: Arc<AtomicBool>,
    context_length_store: Arc<AtomicUsize>,
    batch_size_store: Arc<AtomicUsize>,
    default_model_path: PathBuf,
    default_config: ModelConfig,
) {
    let mut backend: Option<LlamaBackend> = None;
    let mut model: Option<LlamaModel> = None;

    loop {
        let cmd = match cmd_rx.try_recv() {
            Ok(cmd) => cmd,
            Err(mpsc::error::TryRecvError::Empty) => {
                std::thread::sleep(std::time::Duration::from_millis(10));
                continue;
            }
            Err(mpsc::error::TryRecvError::Disconnected) => break,
        };
        match cmd {
            WorkerCommand::LoadModel {
                path,
                context_length,
                batch_size,
                reply,
            } => {
                is_loading.store(true, Ordering::Release);
                let result = validate_model_request(&path, context_length, batch_size)
                    .and_then(|()| initialize_backend(&mut backend))
                    .and_then(|backend| {
                        load_model_impl(
                            backend,
                            &path,
                            context_length,
                            batch_size,
                            &model_name,
                            &is_loaded,
                            &mut model,
                        )
                    });
                is_loading.store(false, Ordering::Release);
                if result.is_ok() {
                    context_length_store.store(context_length, Ordering::Release);
                    batch_size_store.store(batch_size, Ordering::Release);
                }
                let _ = reply.send(result);
            }

            WorkerCommand::UnloadModel { reply } => {
                model = None;
                if let Ok(mut guard) = model_name.lock() {
                    *guard = None;
                }
                context_length_store.store(default_config.context_length, Ordering::Release);
                batch_size_store.store(default_config.batch_size, Ordering::Release);
                is_loaded.store(false, Ordering::Release);
                println!("[Worker] Model unloaded from memory.");
                let _ = reply.send(Ok(()));
            }

            WorkerCommand::Generate {
                prompt,
                params,
                context_length,
                batch_size,
                token_tx,
            } => {
                if model.is_none() {
                    is_loading.store(true, Ordering::Release);
                    let load_result = validate_model_request(
                        &default_model_path,
                        default_config.context_length,
                        default_config.batch_size,
                    )
                    .and_then(|()| initialize_backend(&mut backend))
                    .and_then(|backend| {
                        load_model_impl(
                            backend,
                            &default_model_path,
                            default_config.context_length,
                            default_config.batch_size,
                            &model_name,
                            &is_loaded,
                            &mut model,
                        )
                    });
                    is_loading.store(false, Ordering::Release);
                    if let Err(error) = load_result {
                        let _ = token_tx.blocking_send(Err(error));
                        continue;
                    }
                }

                let result = match backend.as_ref() {
                    Some(backend) => generate_impl(
                        backend,
                        model.as_ref(),
                        &prompt,
                        &params,
                        context_length,
                        batch_size,
                        &model_name,
                        &token_tx,
                    ),
                    None => Err(anyhow::anyhow!("inference backend is unavailable")),
                };
                if let Err(e) = result {
                    let _ = token_tx.blocking_send(Err(e));
                }
            }

            WorkerCommand::Shutdown => {
                println!("[Worker] shutting down");
                break;
            }
        }
    }
}

fn initialize_backend(backend: &mut Option<LlamaBackend>) -> anyhow::Result<&LlamaBackend> {
    if backend.is_none() {
        println!("[Worker] initializing llama-cpp-2 backend");
        *backend = Some(LlamaBackend::init()?);
    }
    backend
        .as_ref()
        .context("llama backend initialization did not produce a backend")
}

fn validate_model_request(
    path: &Path,
    context_length: usize,
    batch_size: usize,
) -> anyhow::Result<()> {
    if !path.is_file() {
        bail!("model path is not a regular file: {}", path.display());
    }
    if context_length == 0 || batch_size == 0 {
        bail!("model context length and batch size must be non-zero");
    }

    let metadata = std::fs::metadata(path)?;
    if metadata.len() < 24 {
        bail!("model is too small to contain a GGUF header");
    }
    let mut header = [0_u8; 8];
    std::fs::File::open(path)?.read_exact(&mut header)?;
    if &header[..4] != b"GGUF" {
        bail!("model does not have a GGUF header: {}", path.display());
    }
    let version = u32::from_le_bytes(header[4..8].try_into()?);
    if !(1..=3).contains(&version) {
        bail!("unsupported GGUF version {version}");
    }
    Ok(())
}

// ── Model loading (runs on worker thread) ───────────────────────────────

fn load_model_impl(
    backend: &LlamaBackend,
    path: &Path,
    context_length: usize,
    batch_size: usize,
    model_name_store: &StdMutex<Option<String>>,
    is_loaded: &AtomicBool,
    model: &mut Option<LlamaModel>,
) -> anyhow::Result<()> {
    println!("[Worker] Loading AI model from {:?}...", path);
    let params = llama_cpp_2::model::params::LlamaModelParams::default();
    let loaded = LlamaModel::load_from_file(backend, path, &params)
        .map_err(|e| anyhow::anyhow!("Failed to load model: {}", e))?;

    let name = path
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_default();

    *model = Some(loaded);
    if let Ok(mut guard) = model_name_store.lock() {
        *guard = Some(name);
    }
    is_loaded.store(true, Ordering::Release);
    println!(
        "[Worker] Model successfully loaded (ctx={}, batch={})",
        context_length, batch_size
    );
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};
    use tokio_stream::StreamExt;

    #[tokio::test]
    async fn startup_and_status_do_not_initialize_a_model() {
        let missing_model = std::env::temp_dir().join(format!(
            "nira-missing-model-{}-{}.gguf",
            std::process::id(),
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .expect("system clock")
                .as_nanos()
        ));
        let backend = LlamaCppBackend::new(
            missing_model,
            ModelConfig {
                context_length: 1024,
                batch_size: 64,
            },
        )
        .expect("create lazy backend");

        let status = backend.get_hardware_status().await.expect("read status");
        assert_eq!(status.active_model, "none");
        assert!(!status.is_loading);
    }

    #[tokio::test]
    async fn missing_default_model_is_reported_through_the_stream() {
        let missing_model = std::env::temp_dir().join(format!(
            "nira-missing-model-{}-stream.gguf",
            std::process::id()
        ));
        let backend = LlamaCppBackend::new(
            missing_model,
            ModelConfig {
                context_length: 1024,
                batch_size: 64,
            },
        )
        .expect("create lazy backend");
        let mut stream = backend
            .generate_stream(GenerationParams {
                prompt: "health check".to_string(),
                temperature: 0.0,
                max_tokens: 1,
            })
            .await
            .expect("queue generation");

        let result = tokio::time::timeout(std::time::Duration::from_secs(2), stream.next())
            .await
            .expect("worker response timeout")
            .expect("worker closed stream without a response");
        assert!(result
            .expect_err("missing model must be an error")
            .to_string()
            .contains("model path is not a regular file"));
    }
}

// ── Token generation (runs on worker thread, CPU-bound) ─────────────────

fn generate_impl(
    backend: &LlamaBackend,
    model: Option<&LlamaModel>,
    prompt: &str,
    params: &GenerationParams,
    context_length: usize,
    batch_size: usize,
    model_name_store: &StdMutex<Option<String>>,
    token_tx: &mpsc::Sender<anyhow::Result<Token>>,
) -> anyhow::Result<()> {
    let model = model.context("no AI model is loaded")?;

    // Tokenize the prompt.
    let prompt_tokens = model
        .str_to_token(prompt, AddBos::Always)
        .map_err(|e| anyhow::anyhow!("failed to tokenize prompt: {e}"))?;

    let available_context = context_length;
    if prompt_tokens.len() >= available_context {
        bail!(
            "prompt requires {} tokens but configured context supports fewer than {}",
            prompt_tokens.len(),
            available_context
        );
    }

    let max_tokens = params
        .max_tokens
        .min(available_context.saturating_sub(prompt_tokens.len()));

    let eval_batch_size = batch_size.max(1).min(context_length);

    // Create context, batch, and sampler on this thread.  Prompt evaluation
    // is chunked so the configured batch limit actually bounds memory use.
    let ctx_params = LlamaContextParams::default()
        .with_n_ctx(std::num::NonZeroU32::new(context_length as u32))
        .with_n_batch(eval_batch_size as u32)
        .with_n_ubatch(eval_batch_size as u32);
    let mut context = model
        .new_context(backend, ctx_params)
        .map_err(|e| anyhow::anyhow!("failed to create inference context: {e}"))?;

    let mut batch = LlamaBatch::new(eval_batch_size, 1);
    let mut prompt_position = 0usize;
    for chunk in prompt_tokens.chunks(eval_batch_size) {
        batch.clear();
        for token in chunk {
            let produce_logits = prompt_position + 1 == prompt_tokens.len();
            batch
                .add(*token, prompt_position as i32, &[0], produce_logits)
                .map_err(|e| anyhow::anyhow!("failed to prepare inference batch: {e}"))?;
            prompt_position += 1;
        }
        context
            .decode(&mut batch)
            .map_err(|e| anyhow::anyhow!("failed to evaluate prompt: {e}"))?;
    }

    let temperature = params.temperature.clamp(0.0, 2.0);
    let mut sampler = LlamaSampler::chain_simple([
        LlamaSampler::temp(temperature),
        LlamaSampler::dist(0xA37E_2026),
    ]);
    let mut utf8_decoder = UTF_8.new_decoder();
    let mut position = prompt_tokens.len();

    let model_name = model_name_store
        .lock()
        .ok()
        .and_then(|g| g.clone())
        .unwrap_or_else(|| "unknown".into());

    println!(
        "[Worker] generating up to {} tokens with '{}' (temp={})",
        max_tokens, model_name, temperature
    );

    for i in 0..max_tokens {
        let token = sampler.sample(&context, -1);
        if model.is_eog_token(token) {
            break;
        }

        let text = model
            .token_to_piece(token, &mut utf8_decoder, false, None)
            .map_err(|e| anyhow::anyhow!("failed to decode token: {e}"))?;

        if !text.is_empty() {
            // Send the token to the async side immediately.
            // If the receiver has been dropped (client disconnected),
            // we abort generation to avoid wasted work.
            if token_tx
                .try_send(Ok(Token {
                    text,
                    is_finished: false,
                }))
                .is_err()
            {
                println!("[Worker] client disconnected after {} tokens", i);
                return Ok(());
            }
        }

        sampler.accept(token);
        batch.clear();
        batch
            .add(token, position as i32, &[0], true)
            .map_err(|e| anyhow::anyhow!("failed to advance batch: {e}"))?;
        context
            .decode(&mut batch)
            .map_err(|e| anyhow::anyhow!("failed to decode token: {e}"))?;
        position += 1;
    }

    // Signal completion.
    let _ = token_tx.blocking_send(Ok(Token {
        text: String::new(),
        is_finished: true,
    }));

    println!(
        "[Worker] generation complete ({} tokens)",
        position - prompt_tokens.len()
    );
    Ok(())
}
