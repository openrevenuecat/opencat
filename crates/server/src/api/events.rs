use axum::{extract::{Query, State}, http::StatusCode, Json};
use serde::Deserialize;
use crate::api::AppState;
use crate::models::event::Event;

#[derive(Deserialize)]
pub struct EventsQuery {
    pub since: Option<String>,
    pub limit: Option<i64>,
}

pub async fn list_events(
    State(state): State<AppState>,
    Query(query): Query<EventsQuery>,
) -> Result<Json<Vec<Event>>, (StatusCode, String)> {
    let limit = query.limit.unwrap_or(50).min(100);

    let events = if let Some(since) = &query.since {
        sqlx::query_as::<_, Event>(
            "SELECT * FROM events WHERE created_at > ? ORDER BY created_at ASC LIMIT ?"
        )
        .bind(since)
        .bind(limit)
        .fetch_all(&state.pool)
        .await
    } else {
        sqlx::query_as::<_, Event>(
            "SELECT * FROM events ORDER BY created_at DESC LIMIT ?"
        )
        .bind(limit)
        .fetch_all(&state.pool)
        .await
    }
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(events))
}
