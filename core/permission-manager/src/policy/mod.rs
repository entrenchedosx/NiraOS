pub mod capability;
use rusqlite::Connection;
use rusqlite::OptionalExtension;
use std::sync::{Arc, Mutex};

pub struct PolicyEngine {
    db: Arc<Mutex<Connection>>,
}

impl PolicyEngine {
    pub fn new(db: Arc<Mutex<Connection>>) -> Self {
        Self { db }
    }

    /// Evaluate a capability request.
    ///
    /// The entire SQLite interaction (query + audit-log insert) is
    /// offloaded to `tokio::task::spawn_blocking` so that the Tokio
    /// worker thread is never blocked by synchronous database I/O.
    pub async fn evaluate_capability(
        &self,
        capability: &str,
        resource: &str,
    ) -> anyhow::Result<String> {
        let cap = capability.to_owned();
        let res = resource.to_owned();
        let db = Arc::clone(&self.db);

        tokio::task::spawn_blocking(move || Self::evaluate_sync(&db, &cap, &res))
            .await
            .map_err(|e| anyhow::anyhow!("blocking task panicked: {}", e))?
    }

    /// Synchronous evaluation — runs on a blocking thread, never on a
    /// Tokio worker.
    fn evaluate_sync(
        db: &Arc<Mutex<Connection>>,
        capability: &str,
        resource: &str,
    ) -> anyhow::Result<String> {
        if capability.trim().is_empty() || resource.trim().is_empty() {
            return Err(anyhow::anyhow!("capability and resource must not be empty"));
        }

        let conn = db
            .lock()
            .map_err(|_| anyhow::anyhow!("permission database lock poisoned"))?;
        let stored_decision = conn
            .query_row(
                "SELECT decision FROM permissions
                 WHERE capability = ?1
                   AND resource_scope = ?2
                   AND (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP)",
                rusqlite::params![capability, resource],
                |row| row.get::<_, String>(0),
            )
            .optional()?;

        // No capability is implicitly trusted.  An explicit, unexpired grant
        // must already exist in the database; the future approval broker is
        // responsible for creating that grant after user confirmation.
        let decision = match stored_decision.as_deref() {
            Some("allowed") => "allowed".to_string(),
            Some("denied") | None => "denied".to_string(),
            Some(other) => {
                return Err(anyhow::anyhow!(
                    "invalid permission decision '{}' for capability '{}'",
                    other,
                    capability
                ));
            }
        };

        conn.execute(
            "INSERT INTO audit_log (action_type, application, resource, permission_result)
             VALUES (?1, ?2, ?3, ?4)",
            rusqlite::params![capability, "nira-action", resource, decision],
        )?;

        Ok(decision)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_engine() -> (PolicyEngine, Arc<Mutex<Connection>>) {
        let connection = Connection::open_in_memory().expect("open in-memory database");
        connection
            .execute_batch(
                "CREATE TABLE permissions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    capability TEXT NOT NULL,
                    resource_scope TEXT NOT NULL,
                    decision TEXT NOT NULL,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    expires_at TEXT,
                    UNIQUE(capability, resource_scope)
                );
                CREATE TABLE audit_log (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    action_type TEXT NOT NULL,
                    application TEXT NOT NULL,
                    resource TEXT NOT NULL,
                    permission_result TEXT NOT NULL,
                    user_confirmation INTEGER DEFAULT 0,
                    timestamp TEXT DEFAULT CURRENT_TIMESTAMP
                );",
            )
            .expect("create test schema");
        let db = Arc::new(Mutex::new(connection));
        (PolicyEngine::new(Arc::clone(&db)), db)
    }

    #[tokio::test]
    async fn missing_grant_is_denied_and_audited() {
        let (engine, db) = test_engine();

        let decision = engine
            .evaluate_capability("filesystem.move", "/home/nira/report.txt")
            .await
            .expect("evaluate missing grant");

        assert_eq!(decision, "denied");
        let audit_count: i64 = db
            .lock()
            .expect("lock database")
            .query_row("SELECT COUNT(*) FROM audit_log", [], |row| row.get(0))
            .expect("count audit rows");
        assert_eq!(audit_count, 1);
    }

    #[tokio::test]
    async fn only_explicit_unexpired_allow_is_accepted() {
        let (engine, db) = test_engine();
        {
            let connection = db.lock().expect("lock database");
            connection
                .execute(
                    "INSERT INTO permissions (capability, resource_scope, decision)
                     VALUES (?1, ?2, 'allowed')",
                    rusqlite::params!["filesystem.move", "/home/nira/report.txt"],
                )
                .expect("insert explicit grant");
            connection
                .execute(
                    "INSERT INTO permissions
                        (capability, resource_scope, decision, expires_at)
                     VALUES (?1, ?2, 'allowed', '2000-01-01 00:00:00')",
                    rusqlite::params!["filesystem.move", "/home/nira/expired.txt"],
                )
                .expect("insert expired grant");
        }

        assert_eq!(
            engine
                .evaluate_capability("filesystem.move", "/home/nira/report.txt")
                .await
                .expect("evaluate explicit grant"),
            "allowed"
        );
        assert_eq!(
            engine
                .evaluate_capability("filesystem.move", "/home/nira/expired.txt")
                .await
                .expect("evaluate expired grant"),
            "denied"
        );
    }

    #[tokio::test]
    async fn invalid_stored_decision_fails_closed() {
        let (engine, db) = test_engine();
        db.lock()
            .expect("lock database")
            .execute(
                "INSERT INTO permissions (capability, resource_scope, decision)
                 VALUES (?1, ?2, 'maybe')",
                rusqlite::params!["filesystem.move", "/home/nira/report.txt"],
            )
            .expect("insert invalid decision");

        let error = engine
            .evaluate_capability("filesystem.move", "/home/nira/report.txt")
            .await
            .expect_err("invalid decision must fail closed");
        assert!(error.to_string().contains("invalid permission decision"));
    }
}
