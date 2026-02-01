use axum::{extract::{Path, State}, http::StatusCode, Json};
use serde::Serialize;
use crate::api::AppState;

#[derive(Debug, Serialize)]
pub struct OfferingProduct {
    pub store_product_id: String,
    pub product_type: String,
    pub display_name: String,
    pub description: Option<String>,
    pub price_micros: i64,
    pub currency: String,
    pub subscription_period: Option<String>,
    pub trial_period: Option<String>,
    pub entitlements: Vec<String>,
}

#[derive(Debug, Serialize)]
pub struct OfferingsResponse {
    pub offerings: Vec<OfferingProduct>,
}

pub async fn get_offerings(
    State(state): State<AppState>,
    Path(app_id): Path<String>,
) -> Result<Json<OfferingsResponse>, (StatusCode, String)> {
    let products = sqlx::query_as::<_, crate::models::product::Product>(
        "SELECT * FROM products WHERE app_id = ? ORDER BY created_at"
    )
    .bind(&app_id)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    let mut offerings = Vec::new();

    for product in products {
        let entitlements: Vec<String> = sqlx::query_scalar(
            "SELECT e.name FROM entitlements e \
             JOIN product_entitlements pe ON pe.entitlement_id = e.id \
             WHERE pe.product_id = ?"
        )
        .bind(&product.id)
        .fetch_all(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

        offerings.push(OfferingProduct {
            store_product_id: product.store_product_id,
            product_type: product.product_type,
            display_name: product.display_name.unwrap_or_default(),
            description: product.description,
            price_micros: product.price_micros.unwrap_or(0),
            currency: product.currency.unwrap_or_else(|| "USD".to_string()),
            subscription_period: product.subscription_period,
            trial_period: product.trial_period,
            entitlements,
        });
    }

    Ok(Json(OfferingsResponse { offerings }))
}
