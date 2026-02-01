use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "opencat", about = "OpenCat — Open-Source In-App Purchase Infrastructure")]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Start the OpenCat server
    Serve,
    /// Run database migrations
    Migrate,
    /// Manage apps
    Apps {
        #[command(subcommand)]
        command: AppsCommands,
    },
    /// Look up a subscriber
    Subscribers {
        #[command(subcommand)]
        command: SubscribersCommands,
    },
    /// Stream events
    Events {
        #[command(subcommand)]
        command: EventsCommands,
    },
}

#[derive(Subcommand)]
pub enum AppsCommands {
    /// List all apps
    List,
}

#[derive(Subcommand)]
pub enum SubscribersCommands {
    /// Get subscriber info
    Get { app_user_id: String },
}

#[derive(Subcommand)]
pub enum EventsCommands {
    /// Tail events in real time
    Tail,
}

pub async fn handle_apps(command: AppsCommands) -> anyhow::Result<()> {
    let config = crate::config::AppConfig::load()?;
    let pool = crate::db::connect(&config.database.url).await?;

    match command {
        AppsCommands::List => {
            let apps = sqlx::query_as::<_, crate::models::app::App>(
                "SELECT * FROM apps ORDER BY created_at DESC"
            )
            .fetch_all(&pool)
            .await?;

            for app in apps {
                println!("{}\t{}\t{}\t{}", app.id, app.name, app.platform, app.bundle_id);
            }
        }
    }

    Ok(())
}

pub async fn handle_subscribers(command: SubscribersCommands) -> anyhow::Result<()> {
    let config = crate::config::AppConfig::load()?;
    let pool = crate::db::connect(&config.database.url).await?;

    match command {
        SubscribersCommands::Get { app_user_id } => {
            let subscriber = sqlx::query_as::<_, crate::models::subscriber::Subscriber>(
                "SELECT * FROM subscribers WHERE app_user_id = ?"
            )
            .bind(&app_user_id)
            .fetch_optional(&pool)
            .await?;

            match subscriber {
                Some(s) => println!("{}\t{}\t{}", s.id, s.app_user_id, s.created_at),
                None => println!("Subscriber not found"),
            }
        }
    }

    Ok(())
}

pub async fn handle_events(command: EventsCommands) -> anyhow::Result<()> {
    let config = crate::config::AppConfig::load()?;
    let pool = crate::db::connect(&config.database.url).await?;

    match command {
        EventsCommands::Tail => {
            let mut cursor = String::new();
            loop {
                let events = if cursor.is_empty() {
                    sqlx::query_as::<_, crate::models::event::Event>(
                        "SELECT * FROM events ORDER BY created_at DESC LIMIT 10"
                    )
                    .fetch_all(&pool)
                    .await?
                } else {
                    sqlx::query_as::<_, crate::models::event::Event>(
                        "SELECT * FROM events WHERE created_at > ? ORDER BY created_at ASC LIMIT 50"
                    )
                    .bind(&cursor)
                    .fetch_all(&pool)
                    .await?
                };

                for event in &events {
                    println!("{}\t{}\t{}", event.created_at, event.event_type, event.id);
                }

                if let Some(last) = events.last() {
                    cursor = last.created_at.clone();
                }

                tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
            }
        }
    }
}
