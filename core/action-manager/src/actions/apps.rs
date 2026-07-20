/// Launch a desktop application by its .desktop file ID (e.g. "foot",
/// "firefox", "org.gnome.Nautilus").
///
/// Uses `gtk-launch` which resolves the ID against the XDG data
/// directories and handles environment setup, DBus activation, and
/// single-instance desktop files automatically.
///
/// The child process is reaped asynchronously via tokio::spawn so that
/// zombie processes never accumulate in the action-manager's process
/// table.
pub async fn launch_application(app_id: &str) -> anyhow::Result<()> {
    let id = app_id.trim();
    if id.is_empty() {
        anyhow::bail!("application ID must not be empty");
    }
    if id.contains('/') || id.contains('\\') {
        anyhow::bail!("invalid application ID: must not contain path separators");
    }

    let mut child = tokio::process::Command::new("gtk-launch")
        .arg(id)
        .stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .spawn()
        .map_err(|e| anyhow::anyhow!("failed to launch '{}': {}", id, e))?;

    let pid = child.id().unwrap_or(0);
    println!("[ActionManager] launched '{}' (PID {})", id, pid);

    // Spawn a background task that waits for the child to exit and
    // reaps its exit status.  Without this wait(), the child becomes
    // a zombie when it terminates.
    // If the daemon restarts before the application closes, the
    // Child struct is dropped without killing the process (kill_on_drop
    // defaults to false).  The orphan is reparented to init / systemd
    // which reaps it when it eventually exits.
    tokio::spawn(async move {
        match child.wait().await {
            Ok(s) => println!("[ActionManager] child {} exited with {}", pid, s),
            Err(e) => eprintln!("[ActionManager] failed to wait on child {}: {}", pid, e),
        }
    });

    Ok(())
}
