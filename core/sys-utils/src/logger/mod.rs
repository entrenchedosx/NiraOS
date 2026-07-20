pub fn init_logging(component: &str) {
    let subscriber = tracing_subscriber::fmt()
        .with_env_filter(format!("{}=debug,info", component))
        .finish();

    let _ = tracing::subscriber::set_global_default(subscriber);
    tracing::info!("[{}] Logging initialized", component);
}
