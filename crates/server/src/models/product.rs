use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Product {
    pub id: String,
    pub app_id: String,
    pub store_product_id: String,
    pub product_type: String,
    pub display_name: Option<String>,
    pub description: Option<String>,
    pub price_micros: Option<i64>,
    pub currency: Option<String>,
    pub subscription_period: Option<String>,
    pub trial_period: Option<String>,
    pub last_synced_at: Option<String>,
    pub created_at: String,
}

#[derive(Debug, Deserialize)]
pub struct CreateProduct {
    pub store_product_id: String,
    pub product_type: String,
    pub entitlement_ids: Vec<String>,
}
