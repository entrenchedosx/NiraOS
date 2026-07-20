use std::time::Duration;
use tokio::time;

pub mod common {
    tonic::include_proto!("niraos.common.v1");
}
tonic::include_proto!("niraos.ai.v1");

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    println!("Starting NiraOS AI Lifecycle Manager...");

    let channel = sys_utils::uds::connect_uds("ai")
        .await
        .map_err(|e| anyhow::anyhow!("Failed to connect to AI daemon: {}", e))?;
    let mut client = ai_service_client::AiServiceClient::new(channel);

    // Periodic health check and lifecycle management
    loop {
        time::sleep(Duration::from_secs(30)).await;

        let mut status_chan = match sys_utils::uds::connect_uds("ai").await {
            Ok(c) => {
                let mut c2 = ai_service_client::AiServiceClient::new(c.clone());
                match c2
                    .get_status(tonic::Request::new(StatusRequest {}))
                    .await
                {
                    Ok(resp) => {
                        let status = resp.into_inner();
                        println!(
                            "[AI Manager] Mode: {}, State: {}, Model: {}",
                            status.mode,
                            status.state,
                            status.active_model
                        );

                        // In AutoUnload mode, if the panel has been closed and
                        // model is loaded but idle, the daemon handles it via
                        // its own inactivity watchdog. We just log here.
                        if status.mode == "auto-unload" && status.state == "ready" {
                            // Daemon handles auto-unload via its own timer
                        }

                        // In OnDemand mode, if model is loaded but not in use,
                        // daemon will auto-unload; we just monitor.
                        if status.mode == "ondemand" && status.state == "unloaded" {
                            // Normal — model is unloaded as expected
                        }
                    }
                    Err(e) => {
                        eprintln!("[AI Manager] Failed to get AI status: {}", e);
                    }
                }
                c
            }
            Err(e) => {
                eprintln!("[AI Manager] Cannot connect to AI daemon: {}", e);
                // Try to reconnect on next cycle
                continue;
            }
        };

        // In AlwaysEnabled mode, ensure the model stays loaded
        let mut status_client = ai_service_client::AiServiceClient::new(status_chan);
        if let Ok(resp) = status_client
            .get_status(tonic::Request::new(StatusRequest {}))
            .await
        {
            let status = resp.into_inner();
            if status.mode == "always" && status.state == "unloaded" {
                eprintln!("[AI Manager] Model is unloaded in AlwaysEnabled mode — triggering reload");
                // Trigger a generation to force reload (daemon loads on demand)
                let _ = status_client
                    .set_mode(tonic::Request::new(SetModeRequest {
                        mode: "always".into(),
                    }))
                    .await;
            }
        }
    }
}
