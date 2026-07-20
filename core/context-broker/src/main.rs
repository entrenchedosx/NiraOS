pub mod collectors;

use serde::Deserialize;
use std::path::Path;
use tokio::fs;
use tonic::{transport::Server, Request, Response, Status};
use tokio_stream::wrappers::ReceiverStream;

pub mod proto {
    pub mod common {
        tonic::include_proto!("niraos.common.v1");
    }
    tonic::include_proto!("niraos.context.v1");
}

use proto::context_service_server::{ContextService, ContextServiceServer};
use proto::{ContextRequest, ContextResponse, ContextFilter, ContextUpdate};

#[derive(Deserialize)]
#[allow(dead_code)]
struct ActiveWindow {
    #[serde(default)]
    app_id: String,
    #[serde(default)]
    title: String,
    #[serde(default)]
    seat: String,
}

/// Path to the JSON file written by the compositor's ContextExporter.
/// Located under the first user's XDG_RUNTIME_DIR.  We try a few paths
/// since the broker may run before the compositor starts.
const COMPOSITOR_STATUS_PATHS: &[&str] = &[
    "/run/user/1000/nira-active-window.json",
    "/tmp/nira-active-window.json",
];

#[derive(Default)]
pub struct ContextServer {}

impl ContextServer {
    async fn read_active_window() -> Option<ActiveWindow> {
        for path_str in COMPOSITOR_STATUS_PATHS {
            let path = Path::new(path_str);
            if !path.exists() {
                continue;
            }
            match fs::read_to_string(path).await {
                Ok(content) => {
                    if let Ok(window) = serde_json::from_str::<ActiveWindow>(&content) {
                        return Some(window);
                    }
                }
                Err(e) => {
                    eprintln!("[ContextBroker] failed to read {}: {}", path_str, e);
                }
            }
        }
        None
    }
}

#[tonic::async_trait]
impl ContextService for ContextServer {
    async fn get_context(
        &self,
        request: Request<ContextRequest>,
    ) -> Result<Response<ContextResponse>, Status> {
        let req = request.into_inner();
        if req.app_id.trim().is_empty() {
            return Err(Status::invalid_argument("app_id is required"));
        }

        // Read the real active window from the compositor.
        let (active_title, app_id) = match Self::read_active_window().await {
            Some(w) => (w.title, w.app_id),
            None => {
                // Compositor not yet ready — return a best-effort placeholder.
                ("NiraOS Compositor (starting)".to_string(), String::new())
            }
        };

        // Build a compact process summary for the system context.
        let process_summary = collectors::process::collect_top_processes();
        let hardware_ctx = collectors::hardware::collect_hardware_context();

        let selected_text = format!("{}\n{}", process_summary, hardware_ctx);

        Ok(Response::new(ContextResponse {
            active_window_title: format!(
                "{} (app: {}) | Querying app: {}",
                active_title,
                if app_id.is_empty() { "unknown" } else { &app_id },
                req.app_id
            ),
            selected_text,
            current_file_path: String::new(),
            error: None,
        }))
    }

    type SubscribeContextStream = ReceiverStream<Result<ContextUpdate, Status>>;

    async fn subscribe_context(
        &self,
        _request: Request<ContextFilter>,
    ) -> Result<Response<Self::SubscribeContextStream>, Status> {
        Err(Status::unimplemented(
            "context subscriptions require compositor metadata support",
        ))
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    println!("Starting NiraOS Context Broker v0.1.0...");

    let incoming = sys_utils::uds::bind_uds("context").await?;
    let server = ContextServer::default();

    println!("Context Broker ready at /run/niraos/context.sock");
    
    Server::builder()
        .add_service(ContextServiceServer::new(server))
        .serve_with_incoming(incoming)
        .await?;

    println!("Context Broker shutting down.");
    Ok(())
}
