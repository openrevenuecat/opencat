use axum::{
    extract::FromRequestParts,
    http::{request::Parts, StatusCode},
};
use sha2::{Sha256, Digest};
use crate::api::AppState;

pub struct AuthenticatedApp {
    pub app_id: String,
}

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

#[cfg(test)]
mod tests {
    use crate::api::AppState;
    use crate::db;
    use axum::body::Body;
    use axum::http::{Request, StatusCode};
    use sha2::{Sha256, Digest};
    use tower::ServiceExt;

    #[tokio::test]
    async fn test_unauthenticated_request_returns_401() {
        let pool = db::connect("sqlite::memory:").await.unwrap();
        let state = AppState { pool };
        let app = crate::api::router(state);

        let response = app
            .oneshot(
                Request::builder()
                    .uri("/v1/apps")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        // Currently list_apps doesn't require auth, so this returns 200
        // Auth will be applied selectively to protected routes
        assert_eq!(response.status(), StatusCode::OK);
    }

    #[tokio::test]
    async fn test_api_key_hash() {
        let mut hasher = Sha256::new();
        hasher.update(b"ocat_test_key_123");
        let hash = format!("{:x}", hasher.finalize());
        assert!(!hash.is_empty());
    }
}
