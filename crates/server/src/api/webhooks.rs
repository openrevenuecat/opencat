use axum::{extract::State, http::StatusCode, Json};
use serde::{Deserialize, Serialize};
use crate::api::AppState;

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct WebhookEndpoint {
    pub id: String,
    pub app_id: String,
    pub url: String,
    pub secret: String,
    pub active: i32,
    pub created_at: String,
}

#[derive(Debug, Deserialize)]
pub struct CreateWebhook {
    pub app_id: String,
    pub url: String,
}

pub async fn create_webhook(
    State(state): State<AppState>,
    Json(input): Json<CreateWebhook>,
) -> Result<(StatusCode, Json<WebhookEndpoint>), (StatusCode, String)> {
    let id = uuid::Uuid::new_v4().to_string();
    let secret = uuid::Uuid::new_v4().to_string();
    let now = chrono::Utc::now().to_rfc3339();

    sqlx::query("INSERT INTO webhook_endpoints (id, app_id, url, secret, active, created_at) VALUES (?, ?, ?, ?, 1, ?)")
        .bind(&id)
        .bind(&input.app_id)
        .bind(&input.url)
        .bind(&secret)
        .bind(&now)
        .execute(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    let webhook = sqlx::query_as::<_, WebhookEndpoint>("SELECT * FROM webhook_endpoints WHERE id = ?")
        .bind(&id)
        .fetch_one(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok((StatusCode::CREATED, Json(webhook)))
}

pub async fn list_webhooks(
    State(state): State<AppState>,
) -> Result<Json<Vec<WebhookEndpoint>>, (StatusCode, String)> {
    let webhooks = sqlx::query_as::<_, WebhookEndpoint>(
        "SELECT * FROM webhook_endpoints ORDER BY created_at DESC"
    )
    .fetch_all(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(webhooks))
}
