use std::path::Path;
use tokio::fs::{self, File};
use tokio::io::{AsyncReadExt, AsyncWriteExt};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    println!("Starting NiraOS Model Manager...");
    // The AI daemon consumes a single stable path.  Downloads are staged and
    // validated before an atomic rename so a power loss cannot expose a
    // partial model as usable.
    let model_url = "https://huggingface.co/microsoft/Phi-4-mini-instruct-gguf/resolve/main/Phi-4-mini-instruct-q4_k_m.gguf";
    let model_dir = "/var/lib/niraos/models";
    let model_path = format!("{}/default.gguf", model_dir);
    let partial_path = format!("{}.part", model_path);

    // Ensure directory exists
    if let Err(e) = fs::create_dir_all(model_dir).await {
        println!("Warning: Could not create model directory: {}", e);
    }

    if !Path::new(&model_path).exists() {
        println!("Default model not found. Downloading from: {}", model_url);

        let client = reqwest::Client::builder()
            .connect_timeout(std::time::Duration::from_secs(15))
            .timeout(std::time::Duration::from_secs(2 * 60 * 60))
            .build()?;
        let mut response = client.get(model_url).send().await?.error_for_status()?;
        if let Some(length) = response.content_length() {
            if length == 0 || length > 16 * 1024 * 1024 * 1024 {
                anyhow::bail!("model download reported an invalid size: {} bytes", length);
            }
        }

        let _ = fs::remove_file(&partial_path).await;
        let mut file = File::create(&partial_path).await?;
        let mut downloaded: u64 = 0;
        while let Some(chunk) = response.chunk().await? {
            file.write_all(&chunk).await?;
            downloaded += chunk.len() as u64;
            if downloaded % (50 * 1024 * 1024) == 0 {
                println!("Downloaded {} MB...", downloaded / 1024 / 1024);
            }
        }
        file.sync_all().await?;
        drop(file);

        let mut downloaded_file = File::open(&partial_path).await?;
        let mut magic = [0u8; 4];
        downloaded_file.read_exact(&mut magic).await?;
        if &magic != b"GGUF" {
            let _ = fs::remove_file(&partial_path).await;
            anyhow::bail!("downloaded model is not a GGUF file");
        }
        fs::rename(&partial_path, &model_path).await?;
        println!("Model download complete: {} bytes.", downloaded);
    } else {
        let mut existing = File::open(&model_path).await?;
        let mut magic = [0u8; 4];
        existing.read_exact(&mut magic).await?;
        if &magic != b"GGUF" {
            anyhow::bail!("existing model is not a valid GGUF file: {}", model_path);
        }
        println!("Default model already exists at {}", model_path);
    }

    println!("Model Manager ready. Waiting for connections...");
    tokio::signal::ctrl_c().await?;
    println!("Model Manager shutting down.");
    Ok(())
}
