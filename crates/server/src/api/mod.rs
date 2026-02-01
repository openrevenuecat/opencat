pub mod apps;
pub mod auth;
pub mod entitlements;
pub mod events;
pub mod health;
pub mod notifications;
pub mod offerings;
pub mod products;
pub mod receipts;
pub mod subscribers;
pub mod webhooks;

use axum::Router;
use axum::routing::{get, post, put};
use tower_http::cors::{CorsLayer, Any};
use crate::db::DbPool;

#[derive(Clone)]
pub struct AppState {
    pub pool: DbPool,
}

pub fn router(state: AppState) -> Router {
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    Router::new()
        .route("/health", get(health::health_check))
        .route("/v1/apps", post(apps::create_app).get(apps::list_apps))
        .route("/v1/apps/{app_id}/credentials", put(apps::update_credentials).get(apps::get_credentials))
        .route("/v1/apps/{app_id}/offerings", get(offerings::get_offerings))
        .route("/v1/apps/{app_id}/sync-products", post(apps::sync_products))
        .route("/v1/apps/{app_id}/entitlements", post(entitlements::create_entitlement).get(entitlements::list_entitlements))
        .route("/v1/apps/{app_id}/products", post(products::create_product).get(products::list_products))
        .route("/v1/subscribers/{app_user_id}", get(subscribers::get_subscriber))
        .route("/v1/receipts", post(receipts::submit_receipt))
        .route("/v1/notifications/apple", post(notifications::apple_notification))
        .route("/v1/notifications/google", post(notifications::google_notification))
        .route("/v1/webhooks", post(webhooks::create_webhook).get(webhooks::list_webhooks))
        .route("/v1/events", get(events::list_events))
        .layer(cors)
        .with_state(state)
}
