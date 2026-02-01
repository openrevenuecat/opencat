use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Transaction {
    pub id: String,
    pub subscriber_id: String,
    pub product_id: String,
    pub store: String,
    pub store_transaction_id: String,
    pub purchase_date: String,
    pub expiration_date: Option<String>,
    pub status: String,
    pub raw_receipt: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}
