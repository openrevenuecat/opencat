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
