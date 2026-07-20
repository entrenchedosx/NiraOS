//! Unix Domain Socket helpers for the NiraOS gRPC daemons.
//!
//! Provides a `UnixStream` wrapper that implements tonic's `Connected` trait
//! (required by `serve_with_incoming`), plus `bind_uds` / `connect_uds`
//! convenience functions.
//!
//! All types in this module are `#[cfg(unix)]` only.

use std::io;
use std::path::Path;
use std::pin::Pin;
use std::task::{Context, Poll};

use tokio::io::{AsyncRead, AsyncWrite, ReadBuf};
use tokio_stream::wrappers::UnixListenerStream;

// ── Connected UnixStream wrapper ───────────────────────────────────────

/// Wraps `tokio::net::UnixStream` and implements tonic's `Connected` trait
/// so it can be used with `tonic::transport::Server::serve_with_incoming`.
pub struct UnixStream(pub tokio::net::UnixStream);

impl AsyncRead for UnixStream {
    fn poll_read(
        self: Pin<&mut Self>,
        cx: &mut Context<'_>,
        buf: &mut ReadBuf<'_>,
    ) -> Poll<io::Result<()>> {
        Pin::new(&mut self.get_mut().0).poll_read(cx, buf)
    }
}

impl AsyncWrite for UnixStream {
    fn poll_write(
        self: Pin<&mut Self>,
        cx: &mut Context<'_>,
        buf: &[u8],
    ) -> Poll<io::Result<usize>> {
        Pin::new(&mut self.get_mut().0).poll_write(cx, buf)
    }

    fn poll_flush(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<io::Result<()>> {
        Pin::new(&mut self.get_mut().0).poll_flush(cx)
    }

    fn poll_shutdown(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<io::Result<()>> {
        Pin::new(&mut self.get_mut().0).poll_shutdown(cx)
    }
}

impl tonic::transport::server::Connected for UnixStream {
    type ConnectInfo = ();
    fn connect_info(&self) -> Self::ConnectInfo {}
}

// ── Helpers ────────────────────────────────────────────────────────────

const SOCKET_DIR: &str = "/run/niraos";

/// Returns the full socket path for a daemon name.
///
/// Validates that `name` is a simple alphanumeric identifier to prevent
/// path traversal through the socket name.
pub fn socket_path(name: &str) -> String {
    assert!(
        !name.is_empty()
            && name.chars().all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-'),
        "invalid socket name: {name}"
    );
    format!("{}/{}.sock", SOCKET_DIR, name)
}

/// Create a `UnixListenerStream` for a daemon socket.
///
/// Removes any stale socket file from a previous crash and binds the listener.
///
/// `/run/niraos` is a shared, root-owned directory provisioned by
/// systemd-tmpfiles. Individual daemons must not create or chmod it: most run
/// without root privileges and own only their socket file.
pub async fn bind_uds(name: &str) -> io::Result<UnixListenerStream> {
    let path = socket_path(name);

    validate_socket_dir(Path::new(SOCKET_DIR)).await?;

    // Remove stale socket from a previous crash.
    match tokio::fs::remove_file(&path).await {
        Ok(()) => {}
        Err(error) if error.kind() == io::ErrorKind::NotFound => {}
        Err(error) => return Err(error),
    }

    let listener = tokio::net::UnixListener::bind(&path)?;

    // Verify that the bound socket is not a symlink (defense-in-depth
    // against TOCTOU races between remove_file and bind).
    let bound_meta = std::fs::symlink_metadata(&path)?;
    if bound_meta.file_type().is_symlink() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("socket at {} is a symlink", path),
        ));
    }

    // Owner and the dedicated nira-ipc group may connect.  The service units
    // set Group=nira-ipc, while the desktop user is a member of that group.
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = bound_meta.permissions();
        perms.set_mode(0o660);
        std::fs::set_permissions(&path, perms)?;
    }

    println!("[UDS] bound {} at {}", name, path);
    Ok(UnixListenerStream::new(listener))
}

async fn validate_socket_dir(socket_dir: &Path) -> io::Result<()> {
    let metadata = tokio::fs::metadata(socket_dir).await.map_err(|error| {
        io::Error::new(
            error.kind(),
            format!(
                "systemd-tmpfiles did not provision {}: {error}",
                socket_dir.display()
            ),
        )
    })?;
    if !metadata.is_dir() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("{} is not a directory", socket_dir.display()),
        ));
    }
    Ok(())
}

pub async fn connect_uds(name: &str) -> io::Result<tonic::transport::Channel> {
    let path = socket_path(name);

    let channel = tonic::transport::Endpoint::try_from("http://localhost")
        .map_err(|e| io::Error::new(io::ErrorKind::Other, e))?
        .connect_with_connector(tower::service_fn(move |_: tonic::transport::Uri| {
            let p = path.clone();
            async move {
                let stream = tokio::net::UnixStream::connect(p).await?;
                Ok::<_, io::Error>(UnixStream(stream))
            }
        }))
        .await
        .map_err(|e| io::Error::new(io::ErrorKind::ConnectionRefused, e))?;

    Ok(channel)
}

#[cfg(test)]
mod tests {
    use super::validate_socket_dir;
    use std::os::unix::fs::PermissionsExt;

    fn test_path(suffix: &str) -> std::path::PathBuf {
        std::env::temp_dir().join(format!(
            "nira-uds-{}-{}-{suffix}",
            std::process::id(),
            std::thread::current().name().unwrap_or("test")
        ))
    }

    #[tokio::test]
    async fn validation_does_not_change_shared_directory_mode() {
        let path = test_path("mode");
        std::fs::create_dir(&path).unwrap();
        std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o750)).unwrap();

        validate_socket_dir(&path).await.unwrap();

        let mode = std::fs::metadata(&path).unwrap().permissions().mode() & 0o777;
        assert_eq!(mode, 0o750);
        std::fs::remove_dir(&path).unwrap();
    }

    #[tokio::test]
    async fn validation_rejects_a_non_directory_path() {
        let path = test_path("file");
        std::fs::write(&path, b"not a directory").unwrap();

        let error = validate_socket_dir(&path).await.unwrap_err();

        assert_eq!(error.kind(), std::io::ErrorKind::InvalidInput);
        std::fs::remove_file(&path).unwrap();
    }
}
