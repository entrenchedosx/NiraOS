pub mod agent;
pub mod config;
pub mod grpc;
pub mod inference;
pub mod models;
pub mod security;

use config::AiDaemonConfig;
use config::DaemonMode;
use grpc::proto::ai_service_server::AiServiceServer;
use inference::InferenceEngine;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};
use sysinfo::System;
use tokio::sync::{Mutex, RwLock};
use tonic::transport::Server;

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ModelState {
    Unloaded,
    Loading,
    Ready,
    Unloading,
}

impl ModelState {
    pub fn as_str(&self) -> &'static str {
        match self {
            ModelState::Unloaded => "unloaded",
            ModelState::Loading => "loading",
            ModelState::Ready => "ready",
            ModelState::Unloading => "unloading",
        }
    }
}

pub struct DaemonState {
    pub mode: RwLock<DaemonMode>,
    pub model_state: RwLock<ModelState>,
    pub inactivity_timeout: RwLock<Duration>,
    pub model_path: RwLock<PathBuf>,
    pub model_config: inference::ModelConfig,
    pub engine: Mutex<Option<Box<dyn InferenceEngine>>>,
    pub last_activity: Mutex<Instant>,
    pub engine_created: AtomicBool,
}

impl DaemonState {
    pub fn new(model_config: inference::ModelConfig) -> Self {
        DaemonState {
            mode: RwLock::new(DaemonMode::OnDemand),
            model_state: RwLock::new(ModelState::Unloaded),
            inactivity_timeout: RwLock::new(Duration::from_secs(300)),
            model_path: RwLock::new(PathBuf::from("/var/lib/niraos/models/default.gguf")),
            model_config,
            engine: Mutex::new(None),
            last_activity: Mutex::new(Instant::now()),
            engine_created: AtomicBool::new(false),
        }
    }

    pub async fn ensure_model_loaded(&self) -> anyhow::Result<()> {
        {
            let mut engine = self.engine.lock().await;
            if engine.is_none() {
                *self.model_state.write().await = ModelState::Loading;
                let path = self.model_path.read().await.clone();
                let backend = inference::llama_cpp::LlamaCppBackend::new(path, self.model_config)?;
                *engine = Some(Box::new(backend));
                self.engine_created.store(true, Ordering::Release);
            }

            if let Some(eng) = engine.as_ref() {
                let status = eng.get_hardware_status().await?;
                if status.active_model == "none" || status.active_model == "unloaded" {
                    if let Some(e) = engine.as_mut() {
                        let path = self.model_path.read().await.clone();
                        e.load_model(&path, self.model_config).await?;
                    }
                }
            }
        }
        *self.last_activity.lock().await = Instant::now();
        *self.model_state.write().await = ModelState::Ready;
        Ok(())
    }

    pub async fn unload_model(&self) -> anyhow::Result<()> {
        *self.model_state.write().await = ModelState::Unloading;
        let mut engine = self.engine.lock().await;
        if let Some(e) = engine.as_mut() {
            e.unload_model().await?;
        }
        *engine = None;
        self.engine_created.store(false, Ordering::Release);
        *self.model_state.write().await = ModelState::Unloaded;
        println!("[AI Daemon] Model unloaded due to inactivity");
        Ok(())
    }
}

fn load_daemon_config() -> AiDaemonConfig {
    let config_path = PathBuf::from("/etc/niraos/ai.toml");
    if config_path.exists() {
        match std::fs::read_to_string(&config_path) {
            Ok(content) => match toml::from_str(&content) {
                Ok(cfg) => {
                    println!("[AI Daemon] Loaded config from {:?}", config_path);
                    return cfg;
                }
                Err(e) => {
                    eprintln!("[AI Daemon] Failed to parse config: {}. Using defaults.", e);
                }
            },
            Err(e) => {
                eprintln!("[AI Daemon] Failed to read config: {}. Using defaults.", e);
            }
        }
    } else {
        println!("[AI Daemon] No config at {:?}, using defaults", config_path);
    }
    AiDaemonConfig::default()
}

async fn inactivity_watchdog(state: Arc<DaemonState>) {
    loop {
        tokio::time::sleep(Duration::from_secs(15)).await;

        if !state.engine_created.load(Ordering::Acquire) {
            continue;
        }

        let mode = *state.mode.read().await;
        let should_auto_unload = matches!(mode, DaemonMode::OnDemand | DaemonMode::AutoUnload);
        if !should_auto_unload {
            continue;
        }

        let timeout = *state.inactivity_timeout.read().await;
        let last = *state.last_activity.lock().await;
        if Instant::now().duration_since(last) >= timeout {
            let ms = *state.model_state.read().await;
            if ms == ModelState::Ready {
                println!("[AI Daemon] Inactivity timeout reached ({:?}), unloading model", timeout);
                let _ = state.unload_model().await;
            }
        }
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("Starting NiraOS AI Daemon...");

    let daemon_cfg = load_daemon_config();

    let mut sys = System::new_all();
    sys.refresh_all();
    let total_ram_mb = sys.total_memory() / 1024 / 1024;
    println!("Hardware Detection: {} MB RAM available.", total_ram_mb);

    let (context_length, batch_size) = if total_ram_mb > 16000 {
        println!("High-end PC detected. Enabling large context.");
        (8192, 512)
    } else if total_ram_mb > 8000 {
        println!("Normal PC detected. Standard context settings.");
        (4096, 256)
    } else {
        println!("Low RAM detected. Reducing context and batch size to avoid freezing.");
        (2048, 128)
    };

    let model_config = inference::ModelConfig {
        context_length,
        batch_size,
    };

    let state = Arc::new(DaemonState::new(model_config));

    {
        *state.mode.write().await = daemon_cfg.mode;
        *state.inactivity_timeout.write().await = Duration::from_secs(daemon_cfg.inactivity_timeout_secs);
        *state.model_path.write().await = PathBuf::from(&daemon_cfg.model_path);
    }

    println!(
        "[AI Daemon] Mode: {:?}, model: {:?}, timeout: {}s",
        daemon_cfg.mode,
        daemon_cfg.model_path,
        daemon_cfg.inactivity_timeout_secs,
    );

    // Auto-preload the model whenever the GGUF file is present on disk,
    // regardless of mode.  The mode only governs *unloading* (inactivity
    // watchdog); loading eagerly on startup means:
    //   - the shell's status poll immediately reports a real model name
    //     instead of "none" (fixes the "Model: NONE" symptom),
    //   - the first user prompt does not block for a multi-second cold load,
    //     which is what previously exceeded the client deadline and triggered
    //     RST_STREAM / "Stream removed".
    // If the file is missing we log a clear, actionable error and continue so
    // the daemon can still serve quick actions and report a precise status.
    let model_file = PathBuf::from(&daemon_cfg.model_path);
    if model_file.is_file() {
        println!(
            "[AI Daemon] Model file present at {}, preloading on startup",
            model_file.display()
        );
        if let Err(e) = state.ensure_model_loaded().await {
            eprintln!(
                "[AI Daemon] Failed to preload model from {}: {}",
                model_file.display(),
                e
            );
        }
    } else if daemon_cfg.mode == DaemonMode::AlwaysEnabled
        || daemon_cfg.mode == DaemonMode::ManualPreload
    {
        // Preserve the original explicit-preload semantics for modes that
        // promise a loaded model; this surfaces a clear error when the
        // operator selected "always" but no model is installed.
        eprintln!(
            "[AI Daemon] Mode {:?} expects a loaded model but none exists at {}",
            daemon_cfg.mode,
            model_file.display()
        );
        if let Err(e) = state.ensure_model_loaded().await {
            eprintln!("[AI Daemon] Pre-load failed: {}", e);
        }
    } else {
        println!(
            "[AI Daemon] No model file at {}; on-demand load will be attempted on first request",
            model_file.display()
        );
    }

    let watchdog_state = state.clone();
    tokio::spawn(async move {
        inactivity_watchdog(watchdog_state).await;
    });

    let incoming = sys_utils::uds::bind_uds("ai").await?;
    let grpc_server = grpc::AiGrpcServer {
        state: state.clone(),
    };

    println!("AI Daemon ready at /run/niraos/ai.sock");

    // HTTP/2 keepalive: send PING frames every 30 s and reset the connection
    // if a PING is not acknowledged within 20 s.  This keeps long-running
    // streams alive during cold model loads (which can take tens of seconds)
    // and detects dead clients promptly so the worker thread can stop
    // generating tokens for a disconnected peer.
    Server::builder()
        .http2_keepalive_interval(Some(Duration::from_secs(30)))
        .http2_keepalive_timeout(Some(Duration::from_secs(20)))
        .add_service(AiServiceServer::new(grpc_server))
        .serve_with_incoming(incoming)
        .await?;

    println!("AI Daemon shutting down.");
    Ok(())
}