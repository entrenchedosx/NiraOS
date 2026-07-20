use serde::Deserialize;
use std::collections::HashMap;
use std::fs;
use std::path::Path;

#[derive(Debug, Deserialize)]
pub struct PromptTemplate {
    pub name: Option<String>,
    pub role: Option<String>,
    pub system_prompt: String,
}

#[derive(Debug, Deserialize)]
pub struct PromptsConfig {
    #[serde(flatten)]
    pub profiles: HashMap<String, PromptTemplate>,
}

pub fn load_prompts() -> anyhow::Result<PromptsConfig> {
    // Priority: User -> System -> Default
    let paths = vec![
        shellexpand::tilde("~/.config/niraos/prompts.toml").to_string(),
        "/etc/niraos/prompts.toml".to_string(),
        "/usr/share/niraos/prompts.toml".to_string(),
    ];

    for path in paths {
        if Path::new(&path).exists() {
            let content = fs::read_to_string(&path)?;
            let config: PromptsConfig = toml::from_str(&content)?;
            println!("Loaded prompts from {}", path);
            return Ok(config);
        }
    }

    // Hard fallback if all else fails
    Ok(PromptsConfig {
        profiles: {
            let mut m = HashMap::new();
            m.insert("assistant".into(), PromptTemplate {
                name: Some("NiraAI".into()),
                role: Some("AI OS Assistant".into()),
                system_prompt: "You are NiraAI, the core intelligence layer of NiraOS. You are an operating system assistant built deeply into the system. You have no connection to Qwen, Alibaba, or any other external corporation. You rely on capability requests to read files.".into(),
            });
            m
        },
    })
}
