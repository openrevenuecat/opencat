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

    async fn create_test_product(state: &AppState, app_id: &str) -> String {
        let app = crate::api::router(state.clone());
        let resp = app
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri(&format!("/v1/apps/{app_id}/products"))
                    .header("content-type", "application/json")
                    .body(Body::from(r#"{"store_product_id":"com.test.pro","product_type":"subscription","entitlement_ids":[]}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        let body = axum::body::to_bytes(resp.into_body(), usize::MAX).await.unwrap();
        let v: Value = serde_json::from_slice(&body).unwrap();
        v["id"].as_str().unwrap().to_string()
    }

    #[tokio::test]
    async fn test_submit_receipt_and_get_subscriber() {
        let state = test_state().await;
        let app_id = create_test_app(&state).await;
        let product_id = create_test_product(&state, &app_id).await;

        let app = crate::api::router(state);

        // Submit receipt
        let response = app.clone()
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/v1/receipts")
                    .header("content-type", "application/json")
                    .body(Body::from(format!(
                        r#"{{"app_id":"{app_id}","app_user_id":"user123","store":"apple","receipt_data":"fake","product_id":"{product_id}"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::CREATED);

        // Get subscriber
        let response = app
            .oneshot(
                Request::builder()
                    .uri("/v1/subscribers/user123")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::OK);
    }
}
