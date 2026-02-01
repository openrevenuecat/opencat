pub mod apple;
pub mod apple_connect;
pub mod google;
pub mod types;

use types::{TransactionEvent, VerifiedTransaction};

#[async_trait::async_trait]
pub trait StoreAdapter: Send + Sync {
    async fn verify_purchase(&self, receipt_data: &str) -> anyhow::Result<VerifiedTransaction>;
    async fn get_subscription_status(&self, store_transaction_id: &str) -> anyhow::Result<VerifiedTransaction>;
    async fn process_notification(&self, payload: &[u8]) -> anyhow::Result<Vec<TransactionEvent>>;
}
