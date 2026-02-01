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
