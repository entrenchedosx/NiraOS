use std::path::Path;
use std::time::SystemTime;

#[derive(Debug, Clone)]
pub struct ModelMetadata {
    pub name: String,
    pub path: String,
    pub size_bytes: u64,
    pub is_loaded: bool,
    pub modified_at: Option<u64>,
}

impl ModelMetadata {
    pub fn new(name: &str, path: &str) -> Self {
        let size = std::fs::metadata(path).ok().map(|m| m.len()).unwrap_or(0);
        let modified = std::fs::metadata(path)
            .ok()
            .and_then(|m| m.modified().ok())
            .and_then(|t| t.duration_since(SystemTime::UNIX_EPOCH).ok())
            .map(|d| d.as_secs());
        Self {
            name: name.to_string(),
            path: path.to_string(),
            size_bytes: size,
            is_loaded: false,
            modified_at: modified,
        }
    }

    pub fn from_path(path: &Path) -> anyhow::Result<Self> {
        if !path.exists() {
            anyhow::bail!("model path does not exist: {}", path.display());
        }
        let metadata = std::fs::metadata(path)?;
        let name = path
            .file_name()
            .map(|n| n.to_string_lossy().into_owned())
            .unwrap_or_else(|| path.to_string_lossy().into_owned());
        let modified = metadata
            .modified()
            .ok()
            .and_then(|t| t.duration_since(SystemTime::UNIX_EPOCH).ok())
            .map(|d| d.as_secs());
        Ok(Self {
            name,
            path: path.to_string_lossy().into_owned(),
            size_bytes: metadata.len(),
            is_loaded: false,
            modified_at: modified,
        })
    }

    pub fn refresh_size(&mut self) {
        self.size_bytes = std::fs::metadata(&self.path)
            .ok()
            .map(|m| m.len())
            .unwrap_or(0);
    }

    pub fn size_mb(&self) -> f64 {
        self.size_bytes as f64 / (1024.0 * 1024.0)
    }

    pub fn size_gb(&self) -> f64 {
        self.size_bytes as f64 / (1024.0 * 1024.0 * 1024.0)
    }
}
