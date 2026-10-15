use std::collections::HashMap;
use std::sync::{Arc, Mutex};

/// Handle-keyed registry. Every method releases the lock before returning.
/// A poisoned lock is reported as `Err`, never as `None` (which means "unknown handle").
pub struct Registry<T> {
    inner: Mutex<HashMap<String, Arc<T>>>,
}

impl<T> Registry<T> {
    pub fn new() -> Self {
        Registry { inner: Mutex::new(HashMap::new()) }
    }

    pub fn insert(&self, key: String, value: T) -> Result<(), String> {
        let mut map = self.inner.lock()
            .map_err(|e| format!("client registry poisoned: {}", e))?;
        map.insert(key, Arc::new(value));
        Ok(())
    }

    pub fn acquire(&self, key: &str) -> Result<Option<Arc<T>>, String> {
        let map = self.inner.lock()
            .map_err(|e| format!("client registry poisoned: {}", e))?;
        Ok(map.get(key).cloned())
    }

    pub fn remove(&self, key: &str) -> Result<Option<Arc<T>>, String> {
        let mut map = self.inner.lock()
            .map_err(|e| format!("client registry poisoned: {}", e))?;
        Ok(map.remove(key))
    }
}
