use std::fs;
use std::path::Path;

/// Check that every component in `path` is not a symlink, preventing
/// symlink-based path traversal attacks where an intermediate directory
/// could redirect outside the allowed root.
fn validate_no_symlinks(path: &Path) -> anyhow::Result<()> {
    let mut current = path.to_path_buf();
    // Walk up to the root, checking every ancestor component.
    loop {
        let meta = fs::symlink_metadata(&current)
            .map_err(|e| anyhow::anyhow!("cannot inspect path component {}: {}", current.display(), e))?;
        if meta.file_type().is_symlink() {
            anyhow::bail!("symbolic link in path component: {}", current.display());
        }
        if !current.pop() {
            break;
        }
    }
    Ok(())
}

pub async fn move_file_safely(src: &str, dest: &str) -> anyhow::Result<()> {
    let source_raw = Path::new(src);
    let destination = Path::new(dest);
    let allowed_root = Path::new("/home/nira").canonicalize()?;

    if !source_raw.is_absolute() || !destination.is_absolute() {
        return Err(anyhow::anyhow!(
            "absolute paths are required for file moves"
        ));
    }
    if destination.exists() {
        return Err(anyhow::anyhow!("destination already exists"));
    }

    // Validate every path component for symlinks before canonicalization.
    validate_no_symlinks(source_raw)?;
    validate_no_symlinks(destination)?;

    let source = source_raw.canonicalize()?;
    if !source.starts_with(&allowed_root) || !source.is_file() {
        return Err(anyhow::anyhow!(
            "source must be a regular file under /home/nira"
        ));
    }

    let destination_parent = destination
        .parent()
        .ok_or_else(|| anyhow::anyhow!("destination has no parent directory"))?
        .canonicalize()?;
    if !destination_parent.starts_with(&allowed_root) {
        return Err(anyhow::anyhow!("destination must remain under /home/nira"));
    }

    let destination = destination_parent.join(
        destination
            .file_name()
            .ok_or_else(|| anyhow::anyhow!("destination has no file name"))?,
    );
    fs::rename(&source, destination)?;
    Ok(())
}
