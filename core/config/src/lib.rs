use serde::Deserialize;
use std::fs;

#[derive(Deserialize, Default)]
pub struct NiraConfig {
    #[serde(default = "default_model_path")]
    pub ai_model_path: String,
    #[serde(default = "default_vram")]
    pub max_vram_mb: usize,
}

fn default_model_path() -> String {
    "/var/lib/niraos/models/default.gguf".to_string()
}

fn default_vram() -> usize {
    8192
}

pub fn load_config() -> NiraConfig {
    let config_path = "/etc/niraos/nira.toml";
    if let Ok(content) = fs::read_to_string(config_path) {
        toml::from_str(&content).unwrap_or_else(|_| NiraConfig::default())
    } else {
        NiraConfig::default()
    }
}
