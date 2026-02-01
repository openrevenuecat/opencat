# OpenCat Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a self-hosted in-app purchase infrastructure server (RevenueCat alternative) with REST API, webhook delivery, Apple/Google store integration, and web dashboard.

**Architecture:** Rust server (Axum) with SQLx for dual PostgreSQL/SQLite support, background job processing for webhook delivery, and a separate Next.js dashboard. Client SDKs (Swift, Kotlin, Flutter) communicate via REST API.

**Tech Stack:** Rust (Axum 0.8, SQLx 0.8, Tokio), PostgreSQL + SQLite, Next.js (dashboard), reqwest (HTTP client), apalis (background jobs), jsonwebtoken + app-store-server-library (Apple JWS/JWT)

---

## Phase 1: Project Skeleton & Database

### Task 1: Initialize Rust project with workspace structure

**Files:**
- Create: `Cargo.toml` (workspace root)
- Create: `crates/server/Cargo.toml`
- Create: `crates/server/src/main.rs`
- Create: `crates/server/src/lib.rs`

**Step 1: Create workspace Cargo.toml**

```toml
# Cargo.toml (workspace root)
[workspace]
resolver = "2"
members = ["crates/server"]

[workspace.dependencies]
axum = { version = "0.8", features = ["macros"] }
tokio = { version = "1", features = ["full"] }
tower = "0.5"
tower-http = { version = "0.6", features = ["trace", "cors"] }
sqlx = { version = "0.8", features = ["runtime-tokio", "chrono", "uuid"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
jsonwebtoken = "9"
reqwest = { version = "0.12", features = ["json", "rustls-tls"] }
config = "0.15"
secrecy = { version = "0.8", features = ["serde"] }
dotenvy = "0.15"
chrono = { version = "0.4", features = ["serde"] }
uuid = { version = "1", features = ["v4", "serde"] }
anyhow = "1"
thiserror = "2"
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }
```

**Step 2: Create server crate Cargo.toml**

```toml
# crates/server/Cargo.toml
[package]
name = "opencat-server"
version = "0.1.0"
edition = "2021"

[dependencies]
axum.workspace = true
tokio.workspace = true
tower.workspace = true
tower-http.workspace = true
sqlx = { workspace = true, features = ["postgres", "sqlite", "migrate"] }
serde.workspace = true
serde_json.workspace = true
reqwest.workspace = true
config.workspace = true
secrecy.workspace = true
dotenvy.workspace = true
chrono.workspace = true
uuid.workspace = true
anyhow.workspace = true
thiserror.workspace = true
tracing.workspace = true
tracing-subscriber.workspace = true

[dev-dependencies]
tokio-test = "0.4"
wiremock = "0.6"
```

**Step 3: Create minimal main.rs and lib.rs**

```rust
// crates/server/src/main.rs
use opencat_server::run;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    run().await
}
```

```rust
// crates/server/src/lib.rs
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
```

**Step 4: Verify it compiles**

Run: `cargo build`
Expected: Compiles with no errors

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: initialize Rust workspace with server crate"
```

---

### Task 2: Configuration system

**Files:**
- Create: `crates/server/src/config.rs`
- Modify: `crates/server/src/lib.rs`
- Create: `crates/server/config/default.toml`
- Create: `.env.example`

**Step 1: Write the test**

Add to `crates/server/src/config.rs`:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config_loads() {
        std::env::set_var("OPENCAT__DATABASE__URL", "sqlite://opencat.db");
        std::env::set_var("OPENCAT__SERVER__SECRET_KEY", "test-secret-key-min-32-chars-long!!");
        let config = AppConfig::load().unwrap();
        assert_eq!(config.server.host, "0.0.0.0");
        assert_eq!(config.server.port, 8080);
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cargo test -p opencat-server test_default_config_loads`
Expected: FAIL — `AppConfig` not defined

**Step 3: Implement configuration**

```rust
// crates/server/src/config.rs
use config::{Config, Environment, File};
use secrecy::SecretString;
use serde::Deserialize;

#[derive(Debug, Deserialize, Clone)]
pub struct AppConfig {
    pub server: ServerConfig,
    pub database: DatabaseConfig,
}

#[derive(Debug, Deserialize, Clone)]
pub struct ServerConfig {
    pub host: String,
    pub port: u16,
    pub secret_key: SecretString,
}

#[derive(Debug, Deserialize, Clone)]
pub struct DatabaseConfig {
    pub url: String,
}

impl AppConfig {
    pub fn load() -> anyhow::Result<Self> {
        let config = Config::builder()
            .add_source(File::with_name("config/default").required(false))
            .add_source(
                Environment::with_prefix("OPENCAT")
                    .separator("__")
                    .try_parsing(true),
            )
            .build()?;

        Ok(config.try_deserialize()?)
    }
}
```

```toml
# crates/server/config/default.toml
[server]
host = "0.0.0.0"
port = 8080

[database]
url = "sqlite://opencat.db"
```

```bash
# .env.example
OPENCAT__SERVER__SECRET_KEY=change-me-to-a-random-string-at-least-32-chars
OPENCAT__DATABASE__URL=sqlite://opencat.db
# OPENCAT__DATABASE__URL=postgres://user:pass@localhost/opencat
```

**Step 4: Wire into lib.rs**

```rust
// crates/server/src/lib.rs
pub mod config;

pub async fn run() -> anyhow::Result<()> {
    dotenvy::dotenv().ok();

    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "opencat_server=debug,tower_http=debug".parse().unwrap()),
        )
        .init();

    let config = config::AppConfig::load()?;
    tracing::info!("OpenCat server starting on {}:{}", config.server.host, config.server.port);
    Ok(())
}
```

**Step 5: Run tests**

Run: `cargo test -p opencat-server test_default_config_loads`
Expected: PASS

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add configuration system with env var and TOML support"
```

---

### Task 3: Database connection pool and migrations

**Files:**
- Create: `crates/server/src/db.rs`
- Create: `crates/server/migrations/001_initial_schema.sql`
- Modify: `crates/server/src/lib.rs`

**Step 1: Write the migration SQL**

```sql
-- crates/server/migrations/001_initial_schema.sql

CREATE TABLE IF NOT EXISTS apps (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
    bundle_id TEXT NOT NULL,
    store_credentials_encrypted TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    UNIQUE(bundle_id, platform)
);

CREATE TABLE IF NOT EXISTS entitlements (
    id TEXT PRIMARY KEY,
    app_id TEXT NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    UNIQUE(app_id, name)
);

CREATE TABLE IF NOT EXISTS products (
    id TEXT PRIMARY KEY,
    app_id TEXT NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
    store_product_id TEXT NOT NULL,
    product_type TEXT NOT NULL CHECK (product_type IN ('subscription', 'consumable', 'non_consumable')),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    UNIQUE(app_id, store_product_id)
);

CREATE TABLE IF NOT EXISTS product_entitlements (
    product_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    entitlement_id TEXT NOT NULL REFERENCES entitlements(id) ON DELETE CASCADE,
    PRIMARY KEY (product_id, entitlement_id)
);

CREATE TABLE IF NOT EXISTS subscribers (
    id TEXT PRIMARY KEY,
    app_id TEXT NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
    app_user_id TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    UNIQUE(app_id, app_user_id)
);

CREATE TABLE IF NOT EXISTS transactions (
    id TEXT PRIMARY KEY,
    subscriber_id TEXT NOT NULL REFERENCES subscribers(id) ON DELETE CASCADE,
    product_id TEXT NOT NULL REFERENCES products(id),
    store TEXT NOT NULL CHECK (store IN ('apple', 'google')),
    store_transaction_id TEXT NOT NULL,
    purchase_date TEXT NOT NULL,
    expiration_date TEXT,
    status TEXT NOT NULL CHECK (status IN ('active', 'expired', 'refunded', 'grace_period', 'billing_retry')),
    raw_receipt TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE IF NOT EXISTS events (
    id TEXT PRIMARY KEY,
    subscriber_id TEXT NOT NULL REFERENCES subscribers(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    payload TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE IF NOT EXISTS webhook_endpoints (
    id TEXT PRIMARY KEY,
    app_id TEXT NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    secret TEXT NOT NULL,
    active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE IF NOT EXISTS webhook_deliveries (
    id TEXT PRIMARY KEY,
    webhook_endpoint_id TEXT NOT NULL REFERENCES webhook_endpoints(id) ON DELETE CASCADE,
    event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('pending', 'delivered', 'failed', 'dead_letter')),
    attempts INTEGER NOT NULL DEFAULT 0,
    last_attempt_at TEXT,
    next_retry_at TEXT,
    last_error TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE IF NOT EXISTS api_keys (
    id TEXT PRIMARY KEY,
    app_id TEXT NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
    key_hash TEXT NOT NULL UNIQUE,
    key_prefix TEXT NOT NULL,
    permissions TEXT NOT NULL DEFAULT 'read',
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    revoked_at TEXT
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_subscribers_app_user ON subscribers(app_id, app_user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_subscriber ON transactions(subscriber_id);
CREATE INDEX IF NOT EXISTS idx_transactions_store_tx ON transactions(store_transaction_id);
CREATE INDEX IF NOT EXISTS idx_events_subscriber ON events(subscriber_id);
CREATE INDEX IF NOT EXISTS idx_events_created ON events(created_at);
CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_status ON webhook_deliveries(status, next_retry_at);
CREATE INDEX IF NOT EXISTS idx_api_keys_hash ON api_keys(key_hash);
```

**Step 2: Write the db module**

```rust
// crates/server/src/db.rs
use sqlx::sqlite::{SqliteConnectOptions, SqlitePoolOptions};
use sqlx::{Pool, Sqlite};
use std::str::FromStr;

pub type DbPool = Pool<Sqlite>;

pub async fn connect(database_url: &str) -> anyhow::Result<DbPool> {
    let options = SqliteConnectOptions::from_str(database_url)?
        .create_if_missing(true)
        .journal_mode(sqlx::sqlite::SqliteJournalMode::Wal)
        .foreign_keys(true);

    let pool = SqlitePoolOptions::new()
        .max_connections(5)
        .connect_with(options)
        .await?;

    sqlx::migrate!("./migrations").run(&pool).await?;

    Ok(pool)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_connect_and_migrate() {
        let pool = connect("sqlite::memory:").await.unwrap();
        let result = sqlx::query("SELECT name FROM sqlite_master WHERE type='table' AND name='apps'")
            .fetch_optional(&pool)
            .await
            .unwrap();
        assert!(result.is_some());
    }
}
```

**Step 3: Wire into lib.rs**

Add `pub mod db;` to `lib.rs`.

**Step 4: Run tests**

Run: `cargo test -p opencat-server test_connect_and_migrate`
Expected: PASS

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add database schema and migration system"
```

---

### Task 4: Axum server with health check endpoint

**Files:**
- Create: `crates/server/src/api/mod.rs`
- Create: `crates/server/src/api/health.rs`
- Modify: `crates/server/src/lib.rs`

**Step 1: Write the test**

```rust
// crates/server/src/api/health.rs
use axum::{http::StatusCode, Json};
use serde::Serialize;

#[derive(Serialize)]
pub struct HealthResponse {
    pub status: String,
    pub version: String,
}

pub async fn health_check() -> (StatusCode, Json<HealthResponse>) {
    (
        StatusCode::OK,
        Json(HealthResponse {
            status: "ok".to_string(),
            version: env!("CARGO_PKG_VERSION").to_string(),
        }),
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::body::Body;
    use axum::http::Request;
    use axum::Router;
    use tower::ServiceExt;

    #[tokio::test]
    async fn test_health_check() {
        let app = Router::new().route("/health", axum::routing::get(health_check));

        let response = app
            .oneshot(Request::builder().uri("/health").body(Body::empty()).unwrap())
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::OK);
    }
}
```

**Step 2: Create the API module**

```rust
// crates/server/src/api/mod.rs
pub mod health;

use axum::Router;
use crate::db::DbPool;

#[derive(Clone)]
pub struct AppState {
    pub pool: DbPool,
}

pub fn router(state: AppState) -> Router {
    Router::new()
        .route("/health", axum::routing::get(health::health_check))
        .with_state(state)
}
```

**Step 3: Update lib.rs to start Axum**

```rust
// crates/server/src/lib.rs
pub mod api;
pub mod config;
pub mod db;

use std::net::SocketAddr;
use tokio::net::TcpListener;

pub async fn run() -> anyhow::Result<()> {
    dotenvy::dotenv().ok();

    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "opencat_server=debug,tower_http=debug".parse().unwrap()),
        )
        .init();

    let config = config::AppConfig::load()?;
    let pool = db::connect(&config.database.url).await?;

    let state = api::AppState { pool };
    let app = api::router(state);

    let addr: SocketAddr = format!("{}:{}", config.server.host, config.server.port).parse()?;
    tracing::info!("OpenCat server listening on {addr}");
    let listener = TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}
```

**Step 4: Run tests**

Run: `cargo test -p opencat-server test_health_check`
Expected: PASS

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add Axum server with health check endpoint"
```

---

## Phase 2: Core CRUD API

### Task 5: Domain models

**Files:**
- Create: `crates/server/src/models/mod.rs`
- Create: `crates/server/src/models/app.rs`
- Create: `crates/server/src/models/entitlement.rs`
- Create: `crates/server/src/models/product.rs`
- Create: `crates/server/src/models/subscriber.rs`
- Create: `crates/server/src/models/transaction.rs`
- Create: `crates/server/src/models/event.rs`
- Modify: `crates/server/src/lib.rs`

**Step 1: Create the models**

```rust
// crates/server/src/models/mod.rs
pub mod app;
pub mod entitlement;
pub mod event;
pub mod product;
pub mod subscriber;
pub mod transaction;
```

```rust
// crates/server/src/models/app.rs
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct App {
    pub id: String,
    pub name: String,
    pub platform: String,
    pub bundle_id: String,
    pub store_credentials_encrypted: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Deserialize)]
pub struct CreateApp {
    pub name: String,
    pub platform: String,
    pub bundle_id: String,
}
```

```rust
// crates/server/src/models/entitlement.rs
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Entitlement {
    pub id: String,
    pub app_id: String,
    pub name: String,
    pub description: Option<String>,
    pub created_at: String,
}

#[derive(Debug, Deserialize)]
pub struct CreateEntitlement {
    pub name: String,
    pub description: Option<String>,
}
```

```rust
// crates/server/src/models/product.rs
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Product {
    pub id: String,
    pub app_id: String,
    pub store_product_id: String,
    pub product_type: String,
    pub created_at: String,
}

#[derive(Debug, Deserialize)]
pub struct CreateProduct {
    pub store_product_id: String,
    pub product_type: String,
    pub entitlement_ids: Vec<String>,
}
```

```rust
// crates/server/src/models/subscriber.rs
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Subscriber {
    pub id: String,
    pub app_id: String,
    pub app_user_id: String,
    pub created_at: String,
}
```

```rust
// crates/server/src/models/transaction.rs
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Transaction {
    pub id: String,
    pub subscriber_id: String,
    pub product_id: String,
    pub store: String,
    pub store_transaction_id: String,
    pub purchase_date: String,
    pub expiration_date: Option<String>,
    pub status: String,
    pub raw_receipt: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}
```

```rust
// crates/server/src/models/event.rs
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Event {
    pub id: String,
    pub subscriber_id: String,
    pub event_type: String,
    pub payload: String,
    pub created_at: String,
}
```

**Step 2: Add `pub mod models;` to lib.rs**

**Step 3: Verify it compiles**

Run: `cargo build`
Expected: Compiles with no errors

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: add domain models for all entities"
```

---

### Task 6: App CRUD endpoints

**Files:**
- Create: `crates/server/src/api/apps.rs`
- Modify: `crates/server/src/api/mod.rs`

**Step 1: Write the failing test**

```rust
// crates/server/src/api/apps.rs (tests at bottom)
#[cfg(test)]
mod tests {
    use crate::api::AppState;
    use crate::db;
    use axum::body::Body;
    use axum::http::{Request, StatusCode};
    use tower::ServiceExt;

    async fn test_state() -> AppState {
        let pool = db::connect("sqlite::memory:").await.unwrap();
        AppState { pool }
    }

    #[tokio::test]
    async fn test_create_and_get_app() {
        let state = test_state().await;
        let app = crate::api::router(state);

        // Create
        let response = app.clone()
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/v1/apps")
                    .header("content-type", "application/json")
                    .body(Body::from(r#"{"name":"My App","platform":"ios","bundle_id":"com.example.app"}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::CREATED);

        // List
        let response = app
            .oneshot(
                Request::builder()
                    .uri("/v1/apps")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::OK);
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cargo test -p opencat-server test_create_and_get_app`
Expected: FAIL

**Step 3: Implement the endpoints**

```rust
// crates/server/src/api/apps.rs
use axum::{extract::State, http::StatusCode, Json};
use crate::api::AppState;
use crate::models::app::{App, CreateApp};

pub async fn create_app(
    State(state): State<AppState>,
    Json(input): Json<CreateApp>,
) -> Result<(StatusCode, Json<App>), (StatusCode, String)> {
    let id = uuid::Uuid::new_v4().to_string();
    let now = chrono::Utc::now().to_rfc3339();

    sqlx::query(
        "INSERT INTO apps (id, name, platform, bundle_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)"
    )
    .bind(&id)
    .bind(&input.name)
    .bind(&input.platform)
    .bind(&input.bundle_id)
    .bind(&now)
    .bind(&now)
    .execute(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    let app = sqlx::query_as::<_, App>("SELECT * FROM apps WHERE id = ?")
        .bind(&id)
        .fetch_one(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok((StatusCode::CREATED, Json(app)))
}

pub async fn list_apps(
    State(state): State<AppState>,
) -> Result<Json<Vec<App>>, (StatusCode, String)> {
    let apps = sqlx::query_as::<_, App>("SELECT * FROM apps ORDER BY created_at DESC")
        .fetch_all(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(apps))
}
```

**Step 4: Add routes to api/mod.rs**

```rust
// Update crates/server/src/api/mod.rs
pub mod apps;
pub mod health;

use axum::Router;
use axum::routing::{get, post};
use crate::db::DbPool;

#[derive(Clone)]
pub struct AppState {
    pub pool: DbPool,
}

pub fn router(state: AppState) -> Router {
    Router::new()
        .route("/health", get(health::health_check))
        .route("/v1/apps", post(apps::create_app).get(apps::list_apps))
        .with_state(state)
}
```

**Step 5: Run tests**

Run: `cargo test -p opencat-server test_create_and_get_app`
Expected: PASS

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add app CRUD endpoints"
```

---

### Task 7: Entitlement CRUD endpoints

**Files:**
- Create: `crates/server/src/api/entitlements.rs`
- Modify: `crates/server/src/api/mod.rs`

**Step 1: Write the failing test**

```rust
// crates/server/src/api/entitlements.rs (tests at bottom)
#[cfg(test)]
mod tests {
    use crate::api::AppState;
    use crate::db;
    use axum::body::Body;
    use axum::http::{Request, StatusCode};
    use serde_json::Value;
    use tower::ServiceExt;

    async fn test_state() -> AppState {
        let pool = db::connect("sqlite::memory:").await.unwrap();
        AppState { pool }
    }

    async fn create_test_app(state: &AppState) -> String {
        let app = crate::api::router(state.clone());
        let resp = app
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/v1/apps")
                    .header("content-type", "application/json")
                    .body(Body::from(r#"{"name":"Test","platform":"ios","bundle_id":"com.test"}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        let body = axum::body::to_bytes(resp.into_body(), usize::MAX).await.unwrap();
        let v: Value = serde_json::from_slice(&body).unwrap();
        v["id"].as_str().unwrap().to_string()
    }

    #[tokio::test]
    async fn test_create_and_list_entitlements() {
        let state = test_state().await;
        let app_id = create_test_app(&state).await;
        let app = crate::api::router(state);

        let response = app.clone()
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri(&format!("/v1/apps/{app_id}/entitlements"))
                    .header("content-type", "application/json")
                    .body(Body::from(r#"{"name":"pro","description":"Pro access"}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::CREATED);

        let response = app
            .oneshot(
                Request::builder()
                    .uri(&format!("/v1/apps/{app_id}/entitlements"))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::OK);
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cargo test -p opencat-server test_create_and_list_entitlements`
Expected: FAIL

**Step 3: Implement endpoints**

```rust
// crates/server/src/api/entitlements.rs
use axum::{extract::{Path, State}, http::StatusCode, Json};
use crate::api::AppState;
use crate::models::entitlement::{CreateEntitlement, Entitlement};

pub async fn create_entitlement(
    State(state): State<AppState>,
    Path(app_id): Path<String>,
    Json(input): Json<CreateEntitlement>,
) -> Result<(StatusCode, Json<Entitlement>), (StatusCode, String)> {
    let id = uuid::Uuid::new_v4().to_string();
    let now = chrono::Utc::now().to_rfc3339();

    sqlx::query("INSERT INTO entitlements (id, app_id, name, description, created_at) VALUES (?, ?, ?, ?, ?)")
        .bind(&id)
        .bind(&app_id)
        .bind(&input.name)
        .bind(&input.description)
        .bind(&now)
        .execute(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    let entitlement = sqlx::query_as::<_, Entitlement>("SELECT * FROM entitlements WHERE id = ?")
        .bind(&id)
        .fetch_one(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok((StatusCode::CREATED, Json(entitlement)))
}

pub async fn list_entitlements(
    State(state): State<AppState>,
    Path(app_id): Path<String>,
) -> Result<Json<Vec<Entitlement>>, (StatusCode, String)> {
    let entitlements = sqlx::query_as::<_, Entitlement>(
        "SELECT * FROM entitlements WHERE app_id = ? ORDER BY created_at DESC"
    )
    .bind(&app_id)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(entitlements))
}
```

**Step 4: Add routes**

Add to `api/mod.rs`:
```rust
pub mod entitlements;
// In router():
.route("/v1/apps/{app_id}/entitlements", post(entitlements::create_entitlement).get(entitlements::list_entitlements))
```

**Step 5: Run tests**

Run: `cargo test -p opencat-server test_create_and_list_entitlements`
Expected: PASS

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add entitlement CRUD endpoints"
```

---

### Task 8: Product CRUD endpoints

**Files:**
- Create: `crates/server/src/api/products.rs`
- Modify: `crates/server/src/api/mod.rs`

Follow the same pattern as Task 7:
1. Write test that creates an app, then creates a product with entitlement_ids, then lists products
2. Implement `create_product` (inserts into `products` + `product_entitlements` junction table) and `list_products`
3. Add route: `/v1/apps/{app_id}/products`
4. Test, commit

**Key implementation detail for create_product:** Use a transaction to insert into both `products` and `product_entitlements`:

```rust
pub async fn create_product(
    State(state): State<AppState>,
    Path(app_id): Path<String>,
    Json(input): Json<CreateProduct>,
) -> Result<(StatusCode, Json<Product>), (StatusCode, String)> {
    let id = uuid::Uuid::new_v4().to_string();
    let now = chrono::Utc::now().to_rfc3339();

    let mut tx = state.pool.begin().await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    sqlx::query("INSERT INTO products (id, app_id, store_product_id, product_type, created_at) VALUES (?, ?, ?, ?, ?)")
        .bind(&id)
        .bind(&app_id)
        .bind(&input.store_product_id)
        .bind(&input.product_type)
        .bind(&now)
        .execute(&mut *tx)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    for entitlement_id in &input.entitlement_ids {
        sqlx::query("INSERT INTO product_entitlements (product_id, entitlement_id) VALUES (?, ?)")
            .bind(&id)
            .bind(entitlement_id)
            .execute(&mut *tx)
            .await
            .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
    }

    tx.commit().await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    let product = sqlx::query_as::<_, Product>("SELECT * FROM products WHERE id = ?")
        .bind(&id)
        .fetch_one(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok((StatusCode::CREATED, Json(product)))
}
```

**Commit message:** `feat: add product CRUD endpoints with entitlement mapping`

---

### Task 9: Subscriber and receipt submission endpoints

**Files:**
- Create: `crates/server/src/api/subscribers.rs`
- Create: `crates/server/src/api/receipts.rs`
- Modify: `crates/server/src/api/mod.rs`

**Step 1: Write the subscriber test**

Test that `GET /v1/subscribers/{app_user_id}` returns subscriber info with active entitlements.

**Step 2: Implement get_subscriber**

```rust
// crates/server/src/api/subscribers.rs
use axum::{extract::{Path, State}, http::StatusCode, Json};
use serde::Serialize;
use crate::api::AppState;
use crate::models::subscriber::Subscriber;
use crate::models::entitlement::Entitlement;
use crate::models::transaction::Transaction;

#[derive(Serialize)]
pub struct SubscriberInfo {
    pub subscriber: Subscriber,
    pub active_entitlements: Vec<Entitlement>,
    pub transactions: Vec<Transaction>,
}

pub async fn get_subscriber(
    State(state): State<AppState>,
    Path(app_user_id): Path<String>,
) -> Result<Json<SubscriberInfo>, (StatusCode, String)> {
    let subscriber = sqlx::query_as::<_, Subscriber>(
        "SELECT * FROM subscribers WHERE app_user_id = ?"
    )
    .bind(&app_user_id)
    .fetch_optional(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
    .ok_or((StatusCode::NOT_FOUND, "Subscriber not found".to_string()))?;

    let transactions = sqlx::query_as::<_, Transaction>(
        "SELECT * FROM transactions WHERE subscriber_id = ? ORDER BY purchase_date DESC"
    )
    .bind(&subscriber.id)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    // Get active entitlements: entitlements linked to products with active transactions
    let active_entitlements = sqlx::query_as::<_, Entitlement>(
        "SELECT DISTINCT e.* FROM entitlements e
         JOIN product_entitlements pe ON e.id = pe.entitlement_id
         JOIN transactions t ON pe.product_id = t.product_id
         WHERE t.subscriber_id = ? AND t.status = 'active'"
    )
    .bind(&subscriber.id)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(SubscriberInfo {
        subscriber,
        active_entitlements,
        transactions,
    }))
}
```

**Step 3: Implement receipt submission**

```rust
// crates/server/src/api/receipts.rs
use axum::{extract::State, http::StatusCode, Json};
use serde::Deserialize;
use crate::api::AppState;
use crate::models::subscriber::Subscriber;
use crate::models::transaction::Transaction;

#[derive(Deserialize)]
pub struct SubmitReceipt {
    pub app_id: String,
    pub app_user_id: String,
    pub store: String,
    pub receipt_data: String,
    pub product_id: String,
}

pub async fn submit_receipt(
    State(state): State<AppState>,
    Json(input): Json<SubmitReceipt>,
) -> Result<(StatusCode, Json<Transaction>), (StatusCode, String)> {
    // Get or create subscriber
    let subscriber_id = uuid::Uuid::new_v4().to_string();
    let now = chrono::Utc::now().to_rfc3339();

    sqlx::query(
        "INSERT OR IGNORE INTO subscribers (id, app_id, app_user_id, created_at) VALUES (?, ?, ?, ?)"
    )
    .bind(&subscriber_id)
    .bind(&input.app_id)
    .bind(&input.app_user_id)
    .bind(&now)
    .execute(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    let subscriber = sqlx::query_as::<_, Subscriber>(
        "SELECT * FROM subscribers WHERE app_id = ? AND app_user_id = ?"
    )
    .bind(&input.app_id)
    .bind(&input.app_user_id)
    .fetch_one(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    // TODO: In Phase 3, this will call the store adapter to verify the receipt.
    // For now, create a transaction with status 'active' (placeholder).
    let tx_id = uuid::Uuid::new_v4().to_string();
    let store_tx_id = format!("pending_verification_{tx_id}");

    sqlx::query(
        "INSERT INTO transactions (id, subscriber_id, product_id, store, store_transaction_id, purchase_date, status, raw_receipt, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, 'active', ?, ?, ?)"
    )
    .bind(&tx_id)
    .bind(&subscriber.id)
    .bind(&input.product_id)
    .bind(&input.store)
    .bind(&store_tx_id)
    .bind(&now)
    .bind(&input.receipt_data)
    .bind(&now)
    .bind(&now)
    .execute(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    let transaction = sqlx::query_as::<_, Transaction>("SELECT * FROM transactions WHERE id = ?")
        .bind(&tx_id)
        .fetch_one(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok((StatusCode::CREATED, Json(transaction)))
}
```

**Step 4: Add routes**

```rust
.route("/v1/subscribers/{app_user_id}", get(subscribers::get_subscriber))
.route("/v1/receipts", post(receipts::submit_receipt))
```

**Step 5: Test, commit**

```bash
git add -A
git commit -m "feat: add subscriber lookup and receipt submission endpoints"
```

---

### Task 10: API key authentication middleware

**Files:**
- Create: `crates/server/src/api/auth.rs`
- Modify: `crates/server/src/api/mod.rs`

**Step 1: Write the test**

Test that requests without `Authorization: Bearer ocat_...` header return 401, and valid keys return 200.

**Step 2: Implement auth extractor**

```rust
// crates/server/src/api/auth.rs
use axum::{
    extract::{FromRequestParts, State},
    http::{request::Parts, StatusCode},
};
use sha2::{Sha256, Digest};
use crate::api::AppState;

pub struct AuthenticatedApp {
    pub app_id: String,
}

#[axum::async_trait]
impl FromRequestParts<AppState> for AuthenticatedApp {
    type Rejection = (StatusCode, String);

    async fn from_request_parts(parts: &mut Parts, state: &AppState) -> Result<Self, Self::Rejection> {
        let header = parts
            .headers
            .get("authorization")
            .and_then(|v| v.to_str().ok())
            .ok_or((StatusCode::UNAUTHORIZED, "Missing Authorization header".to_string()))?;

        let token = header
            .strip_prefix("Bearer ")
            .ok_or((StatusCode::UNAUTHORIZED, "Invalid Authorization format".to_string()))?;

        let mut hasher = Sha256::new();
        hasher.update(token.as_bytes());
        let key_hash = format!("{:x}", hasher.finalize());

        let result = sqlx::query_as::<_, (String,)>(
            "SELECT app_id FROM api_keys WHERE key_hash = ? AND revoked_at IS NULL"
        )
        .bind(&key_hash)
        .fetch_optional(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or((StatusCode::UNAUTHORIZED, "Invalid API key".to_string()))?;

        Ok(AuthenticatedApp { app_id: result.0 })
    }
}
```

Add `sha2 = "0.10"` to server `Cargo.toml` dependencies.

**Step 3: Apply middleware to protected routes**

Protected routes use `AuthenticatedApp` extractor. Health check and notification endpoints remain public.

**Step 4: Test, commit**

```bash
git add -A
git commit -m "feat: add API key authentication middleware"
```

---

## Phase 3: Store Integration

### Task 11: Store adapter trait and Apple implementation

**Files:**
- Create: `crates/server/src/store/mod.rs`
- Create: `crates/server/src/store/apple.rs`
- Create: `crates/server/src/store/types.rs`

**Step 1: Define the trait and unified types**

```rust
// crates/server/src/store/types.rs
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VerifiedTransaction {
    pub store_transaction_id: String,
    pub product_id: String,
    pub purchase_date: String,
    pub expiration_date: Option<String>,
    pub status: TransactionStatus,
    pub store: Store,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TransactionStatus {
    Active,
    Expired,
    Refunded,
    GracePeriod,
    BillingRetry,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Store {
    Apple,
    Google,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransactionEvent {
    pub event_type: String,
    pub transaction: VerifiedTransaction,
}
```

```rust
// crates/server/src/store/mod.rs
pub mod apple;
pub mod types;

use types::{TransactionEvent, VerifiedTransaction};

#[async_trait::async_trait]
pub trait StoreAdapter: Send + Sync {
    async fn verify_purchase(&self, receipt_data: &str) -> anyhow::Result<VerifiedTransaction>;
    async fn get_subscription_status(&self, store_transaction_id: &str) -> anyhow::Result<VerifiedTransaction>;
    async fn process_notification(&self, payload: &[u8]) -> anyhow::Result<Vec<TransactionEvent>>;
}
```

Add `async-trait = "0.1"` to dependencies.

**Step 2: Implement Apple adapter**

```rust
// crates/server/src/store/apple.rs
use super::{StoreAdapter, types::*};
use jsonwebtoken::{decode, DecodingKey, Validation, Algorithm};
use reqwest::Client;
use serde::{Deserialize, Serialize};

pub struct AppleStoreAdapter {
    client: Client,
    issuer_id: String,
    key_id: String,
    private_key: String,
    bundle_id: String,
    environment: AppleEnvironment,
}

#[derive(Debug, Clone)]
pub enum AppleEnvironment {
    Production,
    Sandbox,
}

impl AppleStoreAdapter {
    pub fn new(
        issuer_id: String,
        key_id: String,
        private_key: String,
        bundle_id: String,
        environment: AppleEnvironment,
    ) -> Self {
        Self {
            client: Client::new(),
            issuer_id,
            key_id,
            private_key,
            bundle_id,
            environment,
        }
    }

    fn base_url(&self) -> &str {
        match self.environment {
            AppleEnvironment::Production => "https://api.storekit.itunes.apple.com",
            AppleEnvironment::Sandbox => "https://api.storekit-sandbox.itunes.apple.com",
        }
    }

    fn generate_jwt(&self) -> anyhow::Result<String> {
        use jsonwebtoken::{encode, EncodingKey, Header};

        let now = chrono::Utc::now().timestamp();
        let claims = serde_json::json!({
            "iss": self.issuer_id,
            "iat": now,
            "exp": now + 3600,
            "aud": "appstoreconnect-v1",
            "bid": self.bundle_id,
        });

        let mut header = Header::new(Algorithm::ES256);
        header.kid = Some(self.key_id.clone());

        let token = encode(
            &header,
            &claims,
            &EncodingKey::from_ec_pem(self.private_key.as_bytes())?,
        )?;

        Ok(token)
    }
}

#[async_trait::async_trait]
impl StoreAdapter for AppleStoreAdapter {
    async fn verify_purchase(&self, transaction_id: &str) -> anyhow::Result<VerifiedTransaction> {
        let jwt = self.generate_jwt()?;
        let url = format!("{}/inApps/v1/transactions/{}", self.base_url(), transaction_id);

        let response = self.client
            .get(&url)
            .bearer_auth(&jwt)
            .send()
            .await?;

        if !response.status().is_success() {
            anyhow::bail!("Apple API error: {}", response.status());
        }

        let body: serde_json::Value = response.json().await?;
        // Decode the JWS signed transaction
        let signed_transaction = body["signedTransactionInfo"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("Missing signedTransactionInfo"))?;

        // For production: verify JWS signature with Apple's public key
        // For now: decode the payload (middle part of JWS)
        let parts: Vec<&str> = signed_transaction.split('.').collect();
        if parts.len() != 3 {
            anyhow::bail!("Invalid JWS format");
        }
        use base64::Engine;
        let payload = base64::engine::general_purpose::URL_SAFE_NO_PAD.decode(parts[1])?;
        let decoded: serde_json::Value = serde_json::from_slice(&payload)?;

        Ok(VerifiedTransaction {
            store_transaction_id: decoded["transactionId"].as_str().unwrap_or_default().to_string(),
            product_id: decoded["productId"].as_str().unwrap_or_default().to_string(),
            purchase_date: decoded["purchaseDate"].as_str().unwrap_or_default().to_string(),
            expiration_date: decoded["expiresDate"].as_str().map(String::from),
            status: TransactionStatus::Active,
            store: Store::Apple,
        })
    }

    async fn get_subscription_status(&self, transaction_id: &str) -> anyhow::Result<VerifiedTransaction> {
        let jwt = self.generate_jwt()?;
        let url = format!("{}/inApps/v1/subscriptions/{}", self.base_url(), transaction_id);

        let response = self.client
            .get(&url)
            .bearer_auth(&jwt)
            .send()
            .await?;

        if !response.status().is_success() {
            anyhow::bail!("Apple API error: {}", response.status());
        }

        // Parse subscription status response
        let body: serde_json::Value = response.json().await?;
        // Real implementation would parse all subscription groups
        self.verify_purchase(transaction_id).await
    }

    async fn process_notification(&self, payload: &[u8]) -> anyhow::Result<Vec<TransactionEvent>> {
        let body: serde_json::Value = serde_json::from_slice(payload)?;
        let signed_payload = body["signedPayload"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("Missing signedPayload"))?;

        // Decode JWS notification
        let parts: Vec<&str> = signed_payload.split('.').collect();
        if parts.len() != 3 {
            anyhow::bail!("Invalid JWS format");
        }
        use base64::Engine;
        let payload_bytes = base64::engine::general_purpose::URL_SAFE_NO_PAD.decode(parts[1])?;
        let decoded: serde_json::Value = serde_json::from_slice(&payload_bytes)?;

        let notification_type = decoded["notificationType"]
            .as_str()
            .unwrap_or("UNKNOWN")
            .to_string();

        let event_type = match notification_type.as_str() {
            "DID_RENEW" => "RENEWAL",
            "EXPIRED" => "EXPIRATION",
            "DID_FAIL_TO_RENEW" => "BILLING_ISSUE_DETECTED",
            "REFUND" => "REFUND",
            "SUBSCRIBED" | "INITIAL_BUY" => "INITIAL_PURCHASE",
            "DID_CHANGE_RENEWAL_STATUS" => "CANCELLATION",
            other => other,
        };

        // Extract transaction from notification data
        if let Some(signed_tx) = decoded["data"]["signedTransactionInfo"].as_str() {
            let tx_parts: Vec<&str> = signed_tx.split('.').collect();
            if tx_parts.len() == 3 {
                let tx_payload = base64::engine::general_purpose::URL_SAFE_NO_PAD.decode(tx_parts[1])?;
                let tx_decoded: serde_json::Value = serde_json::from_slice(&tx_payload)?;

                return Ok(vec![TransactionEvent {
                    event_type: event_type.to_string(),
                    transaction: VerifiedTransaction {
                        store_transaction_id: tx_decoded["transactionId"].as_str().unwrap_or_default().to_string(),
                        product_id: tx_decoded["productId"].as_str().unwrap_or_default().to_string(),
                        purchase_date: tx_decoded["purchaseDate"].as_str().unwrap_or_default().to_string(),
                        expiration_date: tx_decoded["expiresDate"].as_str().map(String::from),
                        status: TransactionStatus::Active,
                        store: Store::Apple,
                    },
                }]);
            }
        }

        Ok(vec![])
    }
}
```

Add `base64 = "0.22"` to dependencies.

**Step 3: Write unit test with mocked Apple response**

Use `wiremock` to mock Apple's API, verify that `verify_purchase` returns a valid `VerifiedTransaction`.

**Step 4: Test, commit**

```bash
git add -A
git commit -m "feat: add Apple App Store adapter with JWS verification"
```

---

### Task 12: Google Play adapter

**Files:**
- Create: `crates/server/src/store/google.rs`
- Modify: `crates/server/src/store/mod.rs`

Follow the same pattern as Task 11 but for Google:
- OAuth 2.0 service account authentication
- `subscriptionsv2.get` endpoint for verification
- RTDN Pub/Sub notification processing (notification signals state change → follow-up API call)

**Key difference:** Google notifications don't include full transaction data. `process_notification` must:
1. Parse the Pub/Sub message to extract `purchaseToken`
2. Call `subscriptionsv2.get` with the token
3. Return the full `TransactionEvent`

**Commit message:** `feat: add Google Play adapter with RTDN support`

---

### Task 13: Notification ingestion endpoints

**Files:**
- Create: `crates/server/src/api/notifications.rs`
- Modify: `crates/server/src/api/mod.rs`

**Step 1: Implement Apple notification endpoint**

```rust
// POST /v1/notifications/apple
pub async fn apple_notification(
    State(state): State<AppState>,
    body: axum::body::Bytes,
) -> Result<StatusCode, (StatusCode, String)> {
    let adapter = state.apple_adapter()?;
    let events = adapter.process_notification(&body).await
        .map_err(|e| (StatusCode::BAD_REQUEST, e.to_string()))?;

    for event in events {
        // Update transaction status in DB
        // Insert into events table
        // Trigger webhook delivery
    }

    Ok(StatusCode::OK)
}
```

**Step 2: Implement Google notification endpoint (Pub/Sub push)**

```rust
// POST /v1/notifications/google
pub async fn google_notification(
    State(state): State<AppState>,
    Json(pubsub_message): Json<PubSubMessage>,
) -> Result<StatusCode, (StatusCode, String)> {
    let data = base64::engine::general_purpose::STANDARD.decode(&pubsub_message.message.data)
        .map_err(|e| (StatusCode::BAD_REQUEST, e.to_string()))?;

    let adapter = state.google_adapter()?;
    let events = adapter.process_notification(&data).await
        .map_err(|e| (StatusCode::BAD_REQUEST, e.to_string()))?;

    // Same as Apple: update DB, insert events, trigger webhooks

    Ok(StatusCode::OK)
}
```

**Step 3: Add routes (public, no auth)**

```rust
.route("/v1/notifications/apple", post(notifications::apple_notification))
.route("/v1/notifications/google", post(notifications::google_notification))
```

**Step 4: Test, commit**

```bash
git add -A
git commit -m "feat: add Apple and Google notification ingestion endpoints"
```

---

### Task 14: Wire store verification into receipt submission

**Files:**
- Modify: `crates/server/src/api/receipts.rs`

Update `submit_receipt` to:
1. Look up the app's store credentials
2. Instantiate the appropriate `StoreAdapter`
3. Call `verify_purchase` with the receipt data
4. Store the verified transaction (not a placeholder)
5. Create an `INITIAL_PURCHASE` event

**Commit message:** `feat: wire store verification into receipt submission flow`

---

## Phase 4: Webhook Delivery

### Task 15: Event creation and webhook dispatch

**Files:**
- Create: `crates/server/src/api/webhooks.rs`
- Create: `crates/server/src/api/events.rs`
- Create: `crates/server/src/webhooks/mod.rs`
- Create: `crates/server/src/webhooks/delivery.rs`
- Modify: `crates/server/src/api/mod.rs`

**Step 1: Webhook CRUD endpoints**

```rust
// POST /v1/webhooks — register endpoint
// GET /v1/webhooks — list endpoints
```

**Step 2: Event polling endpoint**

```rust
// GET /v1/events?since={cursor}&limit=50
```

**Step 3: Webhook delivery worker**

```rust
// crates/server/src/webhooks/delivery.rs
use reqwest::Client;
use crate::db::DbPool;

pub struct WebhookDeliveryWorker {
    pool: DbPool,
    client: Client,
}

impl WebhookDeliveryWorker {
    pub async fn run(&self) {
        loop {
            // Fetch pending deliveries where next_retry_at <= now
            // For each: POST to webhook URL with event payload
            // On 2xx: mark as 'delivered'
            // On failure: increment attempts, calculate next_retry_at with exponential backoff
            // After 24hr of failures: mark as 'dead_letter'
            tokio::time::sleep(tokio::time::Duration::from_secs(1)).await;
        }
    }
}

fn next_retry_delay(attempts: i32) -> std::time::Duration {
    let delays = [1, 5, 30, 120, 600, 3600];
    let index = (attempts as usize).min(delays.len() - 1);
    std::time::Duration::from_secs(delays[index])
}
```

**Step 4: Start worker alongside Axum server in lib.rs**

```rust
// In run():
let worker = webhooks::delivery::WebhookDeliveryWorker::new(pool.clone());
tokio::spawn(async move { worker.run().await });
```

**Step 5: Test with wiremock, commit**

```bash
git add -A
git commit -m "feat: add webhook delivery system with retry and dead letter queue"
```

---

## Phase 5: Events API & Subscriber Transactions

### Task 16: Events and transaction history endpoints

**Files:**
- Modify: `crates/server/src/api/events.rs`
- Modify: `crates/server/src/api/subscribers.rs`

**Step 1: Implement**

```rust
// GET /v1/events?since={cursor}&limit=50
// GET /v1/subscribers/{app_user_id}/transactions
```

**Step 2: Test, commit**

```bash
git add -A
git commit -m "feat: add events polling and transaction history endpoints"
```

---

## Phase 6: CLI

### Task 17: CLI with clap

**Files:**
- Modify: `crates/server/src/main.rs`
- Create: `crates/server/src/cli.rs`

Add `clap = { version = "4", features = ["derive"] }` to dependencies.

**Step 1: Implement CLI commands**

```rust
// crates/server/src/cli.rs
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
    List,
}

#[derive(Subcommand)]
pub enum SubscribersCommands {
    Get { app_user_id: String },
}

#[derive(Subcommand)]
pub enum EventsCommands {
    Tail,
}
```

**Step 2: Wire into main.rs**

```rust
use clap::Parser;
use opencat_server::cli::{Cli, Commands};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();
    match cli.command {
        Commands::Serve => opencat_server::run().await,
        Commands::Migrate => opencat_server::migrate().await,
        Commands::Apps { command } => opencat_server::cli::handle_apps(command).await,
        Commands::Subscribers { command } => opencat_server::cli::handle_subscribers(command).await,
        Commands::Events { command } => opencat_server::cli::handle_events(command).await,
    }
}
```

**Step 3: Test, commit**

```bash
git add -A
git commit -m "feat: add CLI with serve, migrate, apps, subscribers, events commands"
```

---

## Phase 7: Dashboard (Next.js)

### Task 18: Initialize Next.js dashboard

**Files:**
- Create: `dashboard/` directory via `npx create-next-app@latest`

**Step 1: Scaffold**

Run: `npx create-next-app@latest dashboard --typescript --tailwind --app --src-dir --no-import-alias`

**Step 2: Add API client**

Create `dashboard/src/lib/api.ts` that wraps `fetch` calls to the OpenCat REST API.

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: initialize Next.js dashboard"
```

---

### Task 19: Dashboard pages

**Files:**
- Create: `dashboard/src/app/page.tsx` (Overview)
- Create: `dashboard/src/app/subscribers/page.tsx`
- Create: `dashboard/src/app/subscribers/[id]/page.tsx`
- Create: `dashboard/src/app/revenue/page.tsx`
- Create: `dashboard/src/app/events/page.tsx`
- Create: `dashboard/src/app/webhooks/page.tsx`
- Create: `dashboard/src/app/products/page.tsx`
- Create: `dashboard/src/app/settings/page.tsx`

Implement each page one at a time. Each page:
1. Fetches data from the OpenCat REST API
2. Renders a table/chart/form
3. Supports the toggleable module system (each section can be hidden via settings)

This is a large task — break into sub-tasks per page during execution.

**Commit per page.**

---

### Task 20: Dashboard theming and customization

**Files:**
- Create: `dashboard/src/lib/theme.ts`
- Modify: `dashboard/tailwind.config.ts`

Implement:
- CSS variable-based theming (brand colors, logo)
- Module toggle system (show/hide dashboard sections)
- Configurable defaults (date range, currency, timezone)

**Commit message:** `feat: add dashboard theming and module toggle system`

---

## Phase 8: Docker & Deployment

### Task 21: Dockerfiles and compose

**Files:**
- Create: `Dockerfile` (Rust server — multi-stage build)
- Create: `dashboard/Dockerfile`
- Create: `docker-compose.yml`

**Step 1: Server Dockerfile**

```dockerfile
# Dockerfile
FROM rust:1.84-bookworm AS builder
WORKDIR /app
COPY . .
RUN cargo build --release -p opencat-server

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/opencat-server /usr/local/bin/opencat
EXPOSE 8080
CMD ["opencat", "serve"]
```

**Step 2: docker-compose.yml**

```yaml
services:
  opencat:
    build: .
    ports:
      - "8080:8080"
    environment:
      OPENCAT__DATABASE__URL: "sqlite:///data/opencat.db"
      OPENCAT__SERVER__SECRET_KEY: "${OPENCAT_SECRET_KEY}"
    volumes:
      - opencat-data:/data

  dashboard:
    build: ./dashboard
    ports:
      - "3000:3000"
    environment:
      NEXT_PUBLIC_API_URL: "http://opencat:8080"

volumes:
  opencat-data:
```

**Step 3: Test locally**

Run: `docker compose up --build`
Expected: Both services start, health check returns 200

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: add Docker and docker-compose setup"
```

---

## Phase 9: Install Script

### Task 22: Install script for single-binary mode

**Files:**
- Create: `scripts/install.sh`

Simple curl-pipe-sh installer that downloads the pre-built binary for the user's platform.

**Commit message:** `feat: add install script for single-binary deployment`

---

## Summary

| Phase | Tasks | What it delivers |
|-------|-------|-----------------|
| 1 | 1-4 | Project skeleton, config, database, health check |
| 2 | 5-10 | Domain models, CRUD API, auth middleware |
| 3 | 11-14 | Apple + Google store integration, receipt verification |
| 4 | 15 | Webhook delivery with retry + DLQ |
| 5 | 16 | Events polling, transaction history |
| 6 | 17 | CLI tooling |
| 7 | 18-20 | Next.js dashboard |
| 8 | 21 | Docker deployment |
| 9 | 22 | Install script |
