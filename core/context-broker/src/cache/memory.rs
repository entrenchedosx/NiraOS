use std::collections::HashMap;
use std::sync::Mutex;
use std::time::Instant;

pub struct MemoryCache {
    store: Mutex<HashMap<String, (String, Instant)>>,
}

impl MemoryCache {
    pub fn new() -> Self {
        Self { store: Mutex::new(HashMap::new()) }
    }
    pub fn set(&self, key: impl Into<String>, value: impl Into<String>) {
        self.store
            .lock()
            .expect("context cache lock poisoned")
            .insert(key.into(), (value.into(), Instant::now()));
    }

    pub fn get(&self, key: &str, max_age: std::time::Duration) -> Option<String> {
        let mut store = self.store.lock().expect("context cache lock poisoned");
        let (value, created_at) = store.get(key)?.clone();
        if created_at.elapsed() > max_age {
            store.remove(key);
            return None;
        }
        Some(value)
    }

    pub fn invalidate(&self, key: &str) {
        self.store
            .lock()
            .expect("context cache lock poisoned")
            .remove(key);
    }
}
