use std::collections::HashMap;
use std::sync::atomic::{AtomicU32, Ordering};
use zbus::blocking::Connection;
use zbus::interface;

static NEXT_ID: AtomicU32 = AtomicU32::new(1);

fn allocate_id(replaces_id: u32) -> u32 {
    if replaces_id > 0 { return replaces_id; }
    let id = NEXT_ID.fetch_add(1, Ordering::Relaxed);
    if id == 0 { NEXT_ID.fetch_add(1, Ordering::Relaxed) } else { id }
}

/// NiraOS Notification Service — implements org.freedesktop.Notifications
/// so existing applications (notify-send, Firefox, etc.) work correctly.
///
/// The custom NotificationAdded signal (needed by the shell for toast UI)
/// is deferred because zbus 4.x has a #[zbus(signal)] proc-macro codegen
/// incompatibility with Rust 1.97.  The shell's NotificationClient logs a
/// warning and continues without toasts; notifications are visible in the
/// journal via `journalctl -t nira-notification`.
struct NiraNotification;

#[interface(name = "org.freedesktop.Notifications")]
impl NiraNotification {
    fn notify(
        &self,
        app_name: String,
        replaces_id: u32,
        _app_icon: String,
        summary: String,
        body: String,
        _actions: Vec<String>,
        _hints: HashMap<String, zbus::zvariant::Value<'_>>,
        _expire_timeout: i32,
    ) -> u32 {
        let id = allocate_id(replaces_id);
        println!("[Notification] {} ({}): {} - {}", app_name, id, summary, body);
        id
    }

    fn get_server_information(&self) -> (String, String, String, String) {
        ("NiraOS Notification Service".into(), "niraos".into(), "0.1.0".into(), "1.2".into())
    }

    fn get_capabilities(&self) -> Vec<String> {
        vec!["body".into(), "body-markup".into()]
    }

    fn close_notification(&self, _id: u32) {}
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("Starting NiraOS Notification Service v0.1.0...");
    let _conn = Connection::session()?;
    std::thread::park();
    Ok(())
}
