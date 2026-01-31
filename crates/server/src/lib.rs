pub async fn run() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "opencat_server=debug,tower_http=debug".parse().unwrap()),
        )
        .init();

    tracing::info!("OpenCat server starting");
    Ok(())
}
