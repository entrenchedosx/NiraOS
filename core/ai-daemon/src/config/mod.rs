pub mod prompts;

use serde::Deserialize;

#[derive(Debug, Clone, Copy, PartialEq, Deserialize)]
pub enum DaemonMode {
    #[serde(rename = "ondemand")]
    OnDemand,
    #[serde(rename = "always")]
    AlwaysEnabled,
    #[serde(rename = "preload")]
    ManualPreload,
    #[serde(rename = "auto-unload")]
    AutoUnload,
}

impl Default for DaemonMode {
    fn default() -> Self {
        DaemonMode::OnDemand
    }
}

impl DaemonMode {
    pub fn as_str(&self) -> &'static str {
        match self {
            DaemonMode::OnDemand => "ondemand",
            DaemonMode::AlwaysEnabled => "always",
            DaemonMode::ManualPreload => "preload",
            DaemonMode::AutoUnload => "auto-unload",
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct ResourcesConfig {
    pub mode: String,
    pub max_vram_gb: f32,
    pub max_ram_gb: f32,
    pub threads: u32,
}

#[derive(Debug, Deserialize)]
pub struct Config {
    pub resources: ResourcesConfig,
}

#[derive(Debug, Clone, Deserialize)]
pub struct AiDaemonConfig {
    #[serde(default)]
    pub mode: DaemonMode,
    #[serde(default = "default_timeout")]
    pub inactivity_timeout_secs: u64,
    #[serde(default = "default_model_path")]
    pub model_path: String,
}

fn default_timeout() -> u64 { 300 }
fn default_model_path() -> String { "/var/lib/niraos/models/default.gguf".into() }

impl Default for AiDaemonConfig {
    fn default() -> Self {
        AiDaemonConfig {
            mode: DaemonMode::OnDemand,
            inactivity_timeout_secs: 300,
            model_path: "/var/lib/niraos/models/default.gguf".into(),
        }
    }
}
