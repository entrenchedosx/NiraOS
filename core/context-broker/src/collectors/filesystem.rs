use std::fs;
use std::path::Path;

pub async fn read_file_safely(path: &str) -> anyhow::Result<String> {
    let requested = Path::new(path);
    if !requested.is_absolute() {
        return Err(anyhow::anyhow!("absolute paths are required"));
    }

    let allowed_root = Path::new("/home/nira").canonicalize()?;
    let canonical = requested.canonicalize()?;
    if !canonical.starts_with(&allowed_root) || !canonical.is_file() {
        return Err(anyhow::anyhow!("file context is restricted to regular files under /home/nira"));
    }

    let metadata = fs::metadata(&canonical)?;
    if metadata.len() > 500_000 {
        return Err(anyhow::anyhow!("file exceeds the 500 KB context limit"));
    }
    let content = fs::read_to_string(canonical)?;
    Ok(content)
}
