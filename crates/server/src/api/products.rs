use axum::{extract::{Path, State}, http::StatusCode, Json};
use crate::api::AppState;
use crate::models::product::{CreateProduct, Product};

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

pub async fn list_products(
    State(state): State<AppState>,
    Path(app_id): Path<String>,
) -> Result<Json<Vec<Product>>, (StatusCode, String)> {
    let products = sqlx::query_as::<_, Product>(
        "SELECT * FROM products WHERE app_id = ? ORDER BY created_at DESC"
    )
    .bind(&app_id)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(products))
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

    async fn create_test_entitlement(state: &AppState, app_id: &str) -> String {
        let app = crate::api::router(state.clone());
        let resp = app
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
        let body = axum::body::to_bytes(resp.into_body(), usize::MAX).await.unwrap();
        let v: Value = serde_json::from_slice(&body).unwrap();
        v["id"].as_str().unwrap().to_string()
    }

    #[tokio::test]
    async fn test_create_and_list_products() {
        let state = test_state().await;
        let app_id = create_test_app(&state).await;
        let ent_id = create_test_entitlement(&state, &app_id).await;
        let app = crate::api::router(state);

        let response = app.clone()
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri(&format!("/v1/apps/{app_id}/products"))
                    .header("content-type", "application/json")
                    .body(Body::from(format!(
                        r#"{{"store_product_id":"com.test.pro","product_type":"subscription","entitlement_ids":["{ent_id}"]}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::CREATED);

        let response = app
            .oneshot(
                Request::builder()
                    .uri(&format!("/v1/apps/{app_id}/products"))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::OK);
    }
}
