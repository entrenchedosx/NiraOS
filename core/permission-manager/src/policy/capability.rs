use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Capability {
    pub capability_type: String, // e.g. "filesystem.read"
    pub scope: String,           // e.g. "/home/user/projects"
    pub duration: String,        // e.g. "session"
    pub granted: bool,
}
