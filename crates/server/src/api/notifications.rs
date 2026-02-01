use axum::{extract::State, http::StatusCode, Json};
use serde::Deserialize;
use crate::api::AppState;

pub async fn apple_notification(
    State(state): State<AppState>,
    body: axum::body::Bytes,
) -> Result<StatusCode, (StatusCode, String)> {
    // Parse the notification to extract event data
    let payload: serde_json::Value = serde_json::from_slice(&body)
        .map_err(|e| (StatusCode::BAD_REQUEST, e.to_string()))?;

    // Store raw event
    let event_id = uuid::Uuid::new_v4().to_string();
    let now = chrono::Utc::now().to_rfc3339();

    // We need a subscriber_id to store the event. In a full implementation,
    // we'd decode the JWS to find the transaction, look up the subscriber,
    // then store the event. For now, store with a placeholder if we can't resolve.
    sqlx::query(
        "INSERT INTO events (id, subscriber_id, event_type, payload, created_at)
         SELECT ?, s.id, 'APPLE_NOTIFICATION', ?, ?
         FROM subscribers s LIMIT 1"
    )
    .bind(&event_id)
    .bind(serde_json::to_string(&payload).unwrap_or_default())
    .bind(&now)
    .execute(&state.pool)
    .await
    .ok(); // Best-effort event storage

    Ok(StatusCode::OK)
}

#[derive(Deserialize)]
pub struct PubSubMessage {
    pub message: PubSubData,
}

#[derive(Deserialize)]
pub struct PubSubData {
    pub data: String,
}

pub async fn google_notification(
    State(state): State<AppState>,
    Json(pubsub_message): Json<PubSubMessage>,
) -> Result<StatusCode, (StatusCode, String)> {
    use base64::Engine;
    let data = base64::engine::general_purpose::STANDARD.decode(&pubsub_message.message.data)
        .map_err(|e| (StatusCode::BAD_REQUEST, e.to_string()))?;

    let payload: serde_json::Value = serde_json::from_slice(&data)
        .map_err(|e| (StatusCode::BAD_REQUEST, e.to_string()))?;

    let event_id = uuid::Uuid::new_v4().to_string();
    let now = chrono::Utc::now().to_rfc3339();

    sqlx::query(
        "INSERT INTO events (id, subscriber_id, event_type, payload, created_at)
         SELECT ?, s.id, 'GOOGLE_NOTIFICATION', ?, ?
         FROM subscribers s LIMIT 1"
    )
    .bind(&event_id)
    .bind(serde_json::to_string(&payload).unwrap_or_default())
    .bind(&now)
    .execute(&state.pool)
    .await
    .ok();

    Ok(StatusCode::OK)
}
