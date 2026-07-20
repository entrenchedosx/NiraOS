use rusqlite::Connection;
use std::path::Path;

pub const DB_PATH: &str = "/var/lib/niraos/permissions/permissions.db";

pub fn init_db() -> anyhow::Result<Connection> {
    let path = Path::new(DB_PATH);
    let parent = path
        .parent()
        .ok_or_else(|| anyhow::anyhow!("permission database has no parent directory"))?;
    std::fs::create_dir_all(parent)?;
    let conn = Connection::open(path)?;

    conn.execute_batch(
        "PRAGMA journal_mode=WAL;
        PRAGMA foreign_keys=ON;
        CREATE TABLE IF NOT EXISTS permissions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            capability TEXT NOT NULL,
            resource_scope TEXT NOT NULL,
            decision TEXT NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            expires_at TEXT,
            UNIQUE(capability, resource_scope)
        );
        CREATE TABLE IF NOT EXISTS audit_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action_type TEXT NOT NULL,
            application TEXT NOT NULL,
            resource TEXT NOT NULL,
            permission_result TEXT NOT NULL,
            user_confirmation INTEGER DEFAULT 0,
            timestamp TEXT DEFAULT CURRENT_TIMESTAMP
        );",
    )?;

    println!("SQLite Permissions DB initialized at {}.", path.display());
    Ok(conn)
}
