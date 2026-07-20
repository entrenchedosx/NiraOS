use std::io::Write;
use std::path::Path;
use std::sync::Arc;
use tokio::sync::Mutex;

pub struct DownloadProgress {
    pub bytes_downloaded: u64,
    pub total_bytes: Option<u64>,
    pub is_complete: bool,
}

pub struct Downloader {
    client: reqwest::Client,
    progress: Arc<Mutex<DownloadProgress>>,
}

impl Downloader {
    pub fn new() -> Self {
        let client = reqwest::Client::builder()
            .user_agent("NiraOS/0.1.0")
            .tcp_keepalive(Some(std::time::Duration::from_secs(30)))
            .build()
            .expect("failed to build HTTP client");
        Self {
            client,
            progress: Arc::new(Mutex::new(DownloadProgress {
                bytes_downloaded: 0,
                total_bytes: None,
                is_complete: false,
            })),
        }
    }

    pub fn progress(&self) -> Arc<Mutex<DownloadProgress>> {
        self.progress.clone()
    }

    pub async fn download(&self, url: &str, dest: &Path) -> anyhow::Result<()> {
        if dest.exists() {
            let metadata = std::fs::metadata(dest)?;
            if metadata.len() > 0 {
                println!(
                    "[Downloader] file already exists at {}, skipping",
                    dest.display()
                );
                return Ok(());
            }
        }

        if let Some(parent) = dest.parent() {
            std::fs::create_dir_all(parent)?;
        }

        println!("[Downloader] downloading {} -> {}", url, dest.display());

        let response = self
            .client
            .get(url)
            .timeout(std::time::Duration::from_secs(3600))
            .send()
            .await
            .map_err(|e| anyhow::anyhow!("HTTP request failed: {}", e))?;

        if !response.status().is_success() {
            anyhow::bail!("HTTP {}: {}", response.status(), url);
        }

        let total = response.content_length();
        {
            let mut prog = self.progress.lock().await;
            prog.total_bytes = total;
            prog.bytes_downloaded = 0;
        }

        if let Some(size) = total {
            println!("[Downloader] size: {} MB", size / 1024 / 1024);
        }

        let mut file = std::fs::File::create(dest)
            .map_err(|e| anyhow::anyhow!("failed to create {}: {}", dest.display(), e))?;

        let mut stream = response.bytes_stream();
        use futures_util::StreamExt;
        while let Some(chunk_result) = stream.next().await {
            let chunk =
                chunk_result.map_err(|e| anyhow::anyhow!("download stream error: {}", e))?;
            file.write_all(&chunk)
                .map_err(|e| anyhow::anyhow!("write error for {}: {}", dest.display(), e))?;

            let mut prog = self.progress.lock().await;
            prog.bytes_downloaded += chunk.len() as u64;
        }

        file.flush()?;
        drop(file);

        {
            let mut prog = self.progress.lock().await;
            prog.is_complete = true;
        }

        let actual_size = std::fs::metadata(dest)?.len();
        println!(
            "[Downloader] complete: {} ({} bytes)",
            dest.display(),
            actual_size
        );
        Ok(())
    }
}

impl Default for Downloader {
    fn default() -> Self {
        Self::new()
    }
}
