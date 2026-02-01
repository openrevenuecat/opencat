use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VerifiedTransaction {
    pub store_transaction_id: String,
    pub product_id: String,
    pub purchase_date: String,
    pub expiration_date: Option<String>,
    pub status: TransactionStatus,
    pub store: Store,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TransactionStatus {
    Active,
    Expired,
    Refunded,
    GracePeriod,
    BillingRetry,
}

impl TransactionStatus {
    pub fn as_str(&self) -> &str {
        match self {
            Self::Active => "active",
            Self::Expired => "expired",
            Self::Refunded => "refunded",
            Self::GracePeriod => "grace_period",
            Self::BillingRetry => "billing_retry",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Store {
    Apple,
    Google,
}

impl Store {
    pub fn as_str(&self) -> &str {
        match self {
            Self::Apple => "apple",
            Self::Google => "google",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransactionEvent {
    pub event_type: String,
    pub transaction: VerifiedTransaction,
}
