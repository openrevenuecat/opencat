pub mod api;
pub mod cli;
pub mod config;
pub mod db;
pub mod models;
pub mod store;
pub mod webhooks;

use crate::config::AppConfig;

pub async fn run() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "opencat_server=debug,tower_http=debug".parse().unwrap()),
        )
        .init();

    let config = AppConfig::load()?;
    let pool = db::connect(&config.database.url).await?;

    let app = api::router(api::AppState { pool });

    let addr = format!("{}:{}", config.server.host, config.server.port);
    tracing::info!("OpenCat server listening on {}", addr);

    let listener = tokio::net::TcpListener::bind(&addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}
