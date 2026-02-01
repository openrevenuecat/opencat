use clap::Parser;
use opencat_server::cli::{Cli, Commands};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Serve => opencat_server::run().await,
        Commands::Migrate => {
            let config = opencat_server::config::AppConfig::load()?;
            let pool = opencat_server::db::connect(&config.database.url).await?;
            drop(pool);
            println!("Migrations applied successfully.");
            Ok(())
        }
        Commands::Apps { command } => opencat_server::cli::handle_apps(command).await,
        Commands::Subscribers { command } => opencat_server::cli::handle_subscribers(command).await,
        Commands::Events { command } => opencat_server::cli::handle_events(command).await,
    }
}
