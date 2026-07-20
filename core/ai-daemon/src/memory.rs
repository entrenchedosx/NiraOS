use std::collections::VecDeque;
use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize, Clone)]
pub struct MemoryEntry {
    pub role: String,
    pub content: String,
}

pub struct MemoryProvider {
    // Keep strictly in RAM for privacy
    short_term_buffer: VecDeque<MemoryEntry>,
    max_tokens: usize,
}

impl MemoryProvider {
    pub fn new(max_tokens: usize) -> Self {
        Self {
            short_term_buffer: VecDeque::new(),
            max_tokens,
        }
    }

    pub fn push(&mut self, entry: MemoryEntry) {
        // Enforce token limit roughly by character count (1 token ≈ 4 chars)
        self.short_term_buffer.push_back(entry);
        
        // Very rudimentary eviction strategy
        while self.estimate_tokens() > self.max_tokens && !self.short_term_buffer.is_empty() {
            self.short_term_buffer.pop_front();
        }
    }

    pub fn get_context(&self) -> Vec<MemoryEntry> {
        self.short_term_buffer.iter().cloned().collect()
    }

    pub fn clear(&mut self) {
        self.short_term_buffer.clear();
    }
    
    fn estimate_tokens(&self) -> usize {
        self.short_term_buffer.iter().map(|e| e.content.len() / 4).sum()
    }
}
