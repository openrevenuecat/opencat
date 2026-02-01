use axum::{extract::{Path, State}, http::StatusCode, Json};
use crate::api::AppState;
use crate::models::app::{App, CreateApp, UpdateStoreCredentials, StoreCredentials};
use crate::store::apple_connect::AppleConnectClient;

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

pub async fn update_credentials(
    State(state): State<AppState>,
    Path(app_id): Path<String>,
    Json(input): Json<UpdateStoreCredentials>,
) -> Result<StatusCode, (StatusCode, String)> {
    let creds = StoreCredentials {
        apple: input.apple,
    };
    let json = serde_json::to_string(&creds)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    sqlx::query("UPDATE apps SET store_credentials_encrypted = ?, updated_at = ? WHERE id = ?")
        .bind(&json)
        .bind(chrono::Utc::now().to_rfc3339())
        .bind(&app_id)
        .execute(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(StatusCode::OK)
}

pub async fn sync_products(
    State(state): State<AppState>,
    Path(app_id): Path<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let app = sqlx::query_as::<_, App>("SELECT * FROM apps WHERE id = ?")
        .bind(&app_id)
        .fetch_optional(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or((StatusCode::NOT_FOUND, "App not found".to_string()))?;

    let creds_json = app.store_credentials_encrypted
        .ok_or((StatusCode::BAD_REQUEST, "No store credentials configured".to_string()))?;

    let creds: StoreCredentials = serde_json::from_str(&creds_json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    let apple_creds = creds.apple
        .ok_or((StatusCode::BAD_REQUEST, "No Apple credentials configured".to_string()))?;

    let client = AppleConnectClient::new(apple_creds, app.bundle_id);
    let synced = client.sync_products().await
        .map_err(|e| (StatusCode::BAD_GATEWAY, format!("Apple API error: {}", e)))?;

    let now = chrono::Utc::now().to_rfc3339();
    let mut synced_count = 0;

    for product in &synced {
        let existing = sqlx::query_scalar::<_, String>(
            "SELECT id FROM products WHERE app_id = ? AND store_product_id = ?"
        )
        .bind(&app_id)
        .bind(&product.store_product_id)
        .fetch_optional(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

        if let Some(product_id) = existing {
            sqlx::query(
                "UPDATE products SET display_name = ?, description = ?, price_micros = ?, \
                 currency = ?, subscription_period = ?, trial_period = ?, last_synced_at = ? \
                 WHERE id = ?"
            )
            .bind(&product.display_name)
            .bind(&product.description)
            .bind(product.price_micros)
            .bind(&product.currency)
            .bind(&product.subscription_period)
            .bind(&product.trial_period)
            .bind(&now)
            .bind(&product_id)
            .execute(&state.pool)
            .await
            .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
        } else {
            let id = uuid::Uuid::new_v4().to_string();
            sqlx::query(
                "INSERT INTO products (id, app_id, store_product_id, product_type, display_name, \
                 description, price_micros, currency, subscription_period, trial_period, \
                 last_synced_at, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
            )
            .bind(&id)
            .bind(&app_id)
            .bind(&product.store_product_id)
            .bind(&product.product_type)
            .bind(&product.display_name)
            .bind(&product.description)
            .bind(product.price_micros)
            .bind(&product.currency)
            .bind(&product.subscription_period)
            .bind(&product.trial_period)
            .bind(&now)
            .bind(&now)
            .execute(&state.pool)
            .await
            .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
        }
        synced_count += 1;
    }

    Ok(Json(serde_json::json!({
        "synced": synced_count,
        "products": synced.iter().map(|p| &p.store_product_id).collect::<Vec<_>>()
    })))
}

pub async fn get_credentials(
    State(state): State<AppState>,
    Path(app_id): Path<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let app = sqlx::query_as::<_, App>("SELECT * FROM apps WHERE id = ?")
        .bind(&app_id)
        .fetch_optional(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or((StatusCode::NOT_FOUND, "App not found".to_string()))?;

    if let Some(creds_json) = &app.store_credentials_encrypted {
        let mut creds: serde_json::Value = serde_json::from_str(creds_json)
            .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
        if let Some(apple) = creds.get_mut("apple") {
            if apple.get("private_key").is_some() {
                apple["private_key"] = serde_json::json!("***configured***");
            }
        }
        Ok(Json(creds))
    } else {
        Ok(Json(serde_json::json!({})))
    }
}

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
