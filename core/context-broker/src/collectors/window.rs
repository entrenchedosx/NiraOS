pub async fn query_active_window() -> anyhow::Result<String> {
    Err(anyhow::anyhow!(
        "active-window context is unavailable until the compositor exports authenticated metadata"
    ))
}
