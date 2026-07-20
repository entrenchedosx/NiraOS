use std::fs::{self, OpenOptions};
use std::io;
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};

const WALLPAPER_STORE: &str = "/var/lib/niraos/desktop/wallpaper.png";

/// Replace the desktop wallpaper.
///
/// Copies the image at `path` into a well-known location that the
/// compositor monitors, then updates the permissions so the user's
/// session process can read it.
pub async fn change_wallpaper(path: &str) -> anyhow::Result<()> {
    let src = Path::new(path);
    if !src.exists() {
        anyhow::bail!("wallpaper file does not exist: {}", path);
    }
    if !src.is_file() {
        anyhow::bail!("wallpaper path is not a regular file: {}", path);
    }

    // Validate that it looks like an image (reject directories, pipes, etc.)
    let meta = std::fs::metadata(src)?;
    if meta.len() == 0 {
        anyhow::bail!("wallpaper file is empty: {}", path);
    }
    // Reject files larger than 50 MB (reasonable ceiling for a wallpaper).
    if meta.len() > 50 * 1024 * 1024 {
        anyhow::bail!("wallpaper file exceeds 50 MB limit");
    }
    // Basic content-type check: reject ELF, scripts, etc.
    let ext = src
        .extension()
        .and_then(|e| e.to_str())
        .map(|e| e.to_lowercase())
        .unwrap_or_default();
    if !matches!(
        ext.as_str(),
        "png" | "jpg" | "jpeg" | "bmp" | "svg" | "webp"
    ) {
        anyhow::bail!(
            "unsupported wallpaper format: .{} (expected png/jpg/bmp/svg/webp)",
            ext
        );
    }

    let dest = Path::new(WALLPAPER_STORE);
    let store_dir = dest
        .parent()
        .ok_or_else(|| anyhow::anyhow!("wallpaper destination has no parent"))?;
    if !store_dir.is_dir() {
        anyhow::bail!(
            "wallpaper state directory is unavailable: {}",
            store_dir.display()
        );
    }

    // Stage and fsync the image in the destination directory before the
    // atomic rename.  The compositor therefore never observes a partial file.
    let nonce = SystemTime::now().duration_since(UNIX_EPOCH)?.as_nanos();
    let temp_path = store_dir.join(format!(".wallpaper-{}-{nonce}.tmp", std::process::id()));
    let copy_result = (|| -> anyhow::Result<()> {
        let mut input = fs::File::open(src)?;
        let mut output = OpenOptions::new()
            .create_new(true)
            .write(true)
            .open(&temp_path)?;
        io::copy(&mut input, &mut output)?;
        output.sync_all()?;
        set_unix_perms(&temp_path, 0o644)?;
        fs::rename(&temp_path, dest)?;
        Ok(())
    })();
    if copy_result.is_err() {
        let _ = fs::remove_file(&temp_path);
    }
    copy_result
        .map_err(|e| anyhow::anyhow!("failed to install wallpaper at {}: {}", dest.display(), e))?;

    println!(
        "[ActionManager] wallpaper changed: {} -> {} ({} bytes)",
        path,
        dest.display(),
        meta.len()
    );

    Ok(())
}

#[cfg(target_os = "linux")]
fn set_unix_perms(path: &Path, mode: u32) -> anyhow::Result<()> {
    use std::os::unix::fs::PermissionsExt;
    let mut perms = std::fs::metadata(path)?.permissions();
    perms.set_mode(mode);
    std::fs::set_permissions(path, perms)?;
    Ok(())
}

#[cfg(not(target_os = "linux"))]
fn set_unix_perms(_path: &Path, _mode: u32) -> anyhow::Result<()> {
    Ok(())
}
