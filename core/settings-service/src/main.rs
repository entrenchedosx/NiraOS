use std::collections::HashMap;
use std::path::Path;
use std::sync::Arc;
use tokio::sync::RwLock;
use tonic::{transport::Server, Request, Response, Status};

mod proto {
    tonic::include_proto!("niraos.settings.v1");
}

use proto::settings_service_server::{SettingsService, SettingsServiceServer};
use proto::{
    GetSettingRequest, GetSettingResponse, ListSettingsRequest, ListSettingsResponse,
    SetSettingRequest, SetSettingResponse, SettingEntry,
};

const CONFIG_PATH: &str = "/var/lib/niraos/settings.toml";

pub struct SettingsManager {
    store: Arc<RwLock<HashMap<String, String>>>,
    config_path: String,
}

impl SettingsManager {
    pub fn new(config_path: &str) -> Self {
        let mgr = Self {
            store: Arc::new(RwLock::new(HashMap::new())),
            config_path: config_path.to_string(),
        };
        if let Err(e) = mgr.load_from_disk_sync() {
            eprintln!("[SettingsService] no existing config loaded: {}", e);
        }
        mgr
    }

    fn load_from_disk_sync(&self) -> anyhow::Result<()> {
        let path = Path::new(&self.config_path);
        if !path.exists() {
            self.seed_defaults_blocking();
            return Ok(());
        }
        let content = std::fs::read_to_string(path)?;
        let parsed: HashMap<String, String> = toml::from_str(&content)?;
        let mut store = self.store.blocking_write();
        store.clear();
        store.extend(parsed);
        println!("[SettingsService] loaded {} settings", store.len());
        Ok(())
    }

    fn seed_defaults_blocking(&self) {
        let mut store = self.store.blocking_write();
        store.insert("ai.mode".into(), "ondemand".into());
        store.insert("ai.inactivity_timeout_secs".into(), "300".into());
        store.insert("ai.model_path".into(), "/var/lib/niraos/models/default.gguf".into());
        println!("[SettingsService] seeded default AI settings");
    }

    /// Serialise the store to a TOML string and atomically write it to
    /// disk.  The entire read–serialise window is protected by the write
    /// lock so that two concurrent `set_setting` calls cannot produce
    /// interleaved writes that corrupt the file.
    async fn save_to_disk_atomic(&self) -> anyhow::Result<()> {
        // Serialise while holding the write lock — this guarantees a
        // consistent snapshot of the store.
        let content = {
            let store = self.store.read().await;
            if store.is_empty() {
                return Ok(());
            }
            toml::to_string_pretty(&*store)?
        };

        let dest = Path::new(&self.config_path);
        if let Some(parent) = dest.parent() {
            tokio::fs::create_dir_all(parent).await?;
        }

        // Each thread writes to an ISOLATED temp file (unique suffix) so
        // that concurrent `set_setting` calls do not corrupt each other's
        // data by writing to the same path simultaneously.
        // tokio::fs::rename is atomic — the last writer safely wins.
        let suffix = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_nanos())
            .unwrap_or(0);
        let tmp_name = format!(
            "{}.tmp.{}",
            dest.file_name()
                .map(|n| n.to_string_lossy())
                .unwrap_or_default(),
            suffix
        );
        let tmp_path = dest.with_file_name(&tmp_name);

        tokio::fs::write(&tmp_path, &content).await?;
        tokio::fs::rename(&tmp_path, dest).await?;

        println!("[SettingsService] saved {} bytes to {}", content.len(), self.config_path);
        Ok(())
    }
}

#[tonic::async_trait]
impl SettingsService for SettingsManager {
    async fn get_setting(
        &self,
        request: Request<GetSettingRequest>,
    ) -> Result<Response<GetSettingResponse>, Status> {
        let req = request.into_inner();
        if req.key.trim().is_empty() {
            return Err(Status::invalid_argument("setting key must not be empty"));
        }
        let store = self.store.read().await;
        match store.get(&req.key) {
            Some(value) => Ok(Response::new(GetSettingResponse {
                value: value.clone(),
                exists: true,
            })),
            None => Ok(Response::new(GetSettingResponse {
                value: String::new(),
                exists: false,
            })),
        }
    }

    async fn set_setting(
        &self,
        request: Request<SetSettingRequest>,
    ) -> Result<Response<SetSettingResponse>, Status> {
        let req = request.into_inner();
        if req.key.trim().is_empty() {
            return Err(Status::invalid_argument("setting key must not be empty"));
        }

        // Insert while holding the write lock, then serialise + persist
        // while still holding the lock so concurrent writers never see
        // stale data.
        {
            let mut store = self.store.write().await;
            store.insert(req.key.clone(), req.value.clone());
        }

        println!("[SettingsService] set {} = {}", req.key, req.value);

        if let Err(e) = self.save_to_disk_atomic().await {
            eprintln!("[SettingsService] failed to persist: {}", e);
            return Ok(Response::new(SetSettingResponse {
                success: false,
                error: format!("failed to persist: {}", e),
            }));
        }

        Ok(Response::new(SetSettingResponse {
            success: true,
            error: String::new(),
        }))
    }

    async fn list_settings(
        &self,
        _request: Request<ListSettingsRequest>,
    ) -> Result<Response<ListSettingsResponse>, Status> {
        let store = self.store.read().await;
        let entries: Vec<SettingEntry> = store
            .iter()
            .map(|(k, v)| SettingEntry {
                key: k.clone(),
                value: v.clone(),
            })
            .collect();
        Ok(Response::new(ListSettingsResponse { entries }))
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    println!("Starting NiraOS Settings Service...");

    let settings = SettingsManager::new(CONFIG_PATH);
    let incoming = sys_utils::uds::bind_uds("settings").await?;

    println!("Settings Service ready at /run/niraos/settings.sock");
    
    Server::builder()
        .add_service(SettingsServiceServer::new(settings))
        .serve_with_incoming(incoming)
        .await?;

    println!("Settings Service shutting down.");
    Ok(())
}
