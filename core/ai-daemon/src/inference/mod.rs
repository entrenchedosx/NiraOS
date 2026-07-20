use std::path::Path;
use std::pin::Pin;
use tokio_stream::Stream;

pub mod llama_cpp;

pub type BoxStream<T> = Pin<Box<dyn Stream<Item = T> + Send + 'static>>;

#[derive(Clone, Copy, Debug)]
pub struct ModelConfig {
    pub context_length: usize,
    pub batch_size: usize,
}

pub struct GenerationParams {
    pub prompt: String,
    pub temperature: f32,
    pub max_tokens: usize,
}

#[derive(Debug)]
pub struct Token {
    pub text: String,
    pub is_finished: bool,
}

pub struct HardwareStatus {
    pub active_model: String,
    pub is_loading: bool,
    pub vram_usage_mb: f32,
}

#[async_trait::async_trait]
pub trait InferenceEngine: Send + Sync {
    async fn load_model(&mut self, path: &Path, config: ModelConfig) -> anyhow::Result<()>;
    async fn unload_model(&mut self) -> anyhow::Result<()>;
    async fn generate_stream(
        &self,
        params: GenerationParams,
    ) -> anyhow::Result<BoxStream<anyhow::Result<Token>>>;
    async fn get_hardware_status(&self) -> anyhow::Result<HardwareStatus>;
}
