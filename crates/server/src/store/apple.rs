use super::{StoreAdapter, types::*};
use reqwest::Client;

pub struct AppleStoreAdapter {
    client: Client,
    issuer_id: String,
    key_id: String,
    private_key: String,
    bundle_id: String,
    environment: AppleEnvironment,
}

#[derive(Debug, Clone)]
pub enum AppleEnvironment {
    Production,
    Sandbox,
}

impl AppleStoreAdapter {
    pub fn new(
        issuer_id: String,
        key_id: String,
        private_key: String,
        bundle_id: String,
        environment: AppleEnvironment,
    ) -> Self {
        Self {
            client: Client::new(),
            issuer_id,
            key_id,
            private_key,
            bundle_id,
            environment,
        }
    }

    fn base_url(&self) -> &str {
        match self.environment {
            AppleEnvironment::Production => "https://api.storekit.itunes.apple.com",
            AppleEnvironment::Sandbox => "https://api.storekit-sandbox.itunes.apple.com",
        }
    }

    fn generate_jwt(&self) -> anyhow::Result<String> {
        use jsonwebtoken::{encode, EncodingKey, Header, Algorithm};

        let now = chrono::Utc::now().timestamp();
        let claims = serde_json::json!({
            "iss": self.issuer_id,
            "iat": now,
            "exp": now + 3600,
            "aud": "appstoreconnect-v1",
            "bid": self.bundle_id,
        });

        let mut header = Header::new(Algorithm::ES256);
        header.kid = Some(self.key_id.clone());

        let token = encode(
            &header,
            &claims,
            &EncodingKey::from_ec_pem(self.private_key.as_bytes())?,
        )?;

        Ok(token)
    }
}

#[async_trait::async_trait]
impl StoreAdapter for AppleStoreAdapter {
    async fn verify_purchase(&self, transaction_id: &str) -> anyhow::Result<VerifiedTransaction> {
        let jwt = self.generate_jwt()?;
        let url = format!("{}/inApps/v1/transactions/{}", self.base_url(), transaction_id);

        let response = self.client
            .get(&url)
            .bearer_auth(&jwt)
            .send()
            .await?;

        if !response.status().is_success() {
            anyhow::bail!("Apple API error: {}", response.status());
        }

        let body: serde_json::Value = response.json().await?;
        let signed_transaction = body["signedTransactionInfo"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("Missing signedTransactionInfo"))?;

        let parts: Vec<&str> = signed_transaction.split('.').collect();
        if parts.len() != 3 {
            anyhow::bail!("Invalid JWS format");
        }
        use base64::Engine;
        let payload = base64::engine::general_purpose::URL_SAFE_NO_PAD.decode(parts[1])?;
        let decoded: serde_json::Value = serde_json::from_slice(&payload)?;

        Ok(VerifiedTransaction {
            store_transaction_id: decoded["transactionId"].as_str().unwrap_or_default().to_string(),
            product_id: decoded["productId"].as_str().unwrap_or_default().to_string(),
            purchase_date: decoded["purchaseDate"].as_str().unwrap_or_default().to_string(),
            expiration_date: decoded["expiresDate"].as_str().map(String::from),
            status: TransactionStatus::Active,
            store: Store::Apple,
        })
    }

    async fn get_subscription_status(&self, transaction_id: &str) -> anyhow::Result<VerifiedTransaction> {
        self.verify_purchase(transaction_id).await
    }

    async fn process_notification(&self, payload: &[u8]) -> anyhow::Result<Vec<TransactionEvent>> {
        let body: serde_json::Value = serde_json::from_slice(payload)?;
        let signed_payload = body["signedPayload"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("Missing signedPayload"))?;

        let parts: Vec<&str> = signed_payload.split('.').collect();
        if parts.len() != 3 {
            anyhow::bail!("Invalid JWS format");
        }
        use base64::Engine;
        let payload_bytes = base64::engine::general_purpose::URL_SAFE_NO_PAD.decode(parts[1])?;
        let decoded: serde_json::Value = serde_json::from_slice(&payload_bytes)?;

        let notification_type = decoded["notificationType"]
            .as_str()
            .unwrap_or("UNKNOWN")
            .to_string();

        let event_type = match notification_type.as_str() {
            "DID_RENEW" => "RENEWAL",
            "EXPIRED" => "EXPIRATION",
            "DID_FAIL_TO_RENEW" => "BILLING_ISSUE_DETECTED",
            "REFUND" => "REFUND",
            "SUBSCRIBED" | "INITIAL_BUY" => "INITIAL_PURCHASE",
            "DID_CHANGE_RENEWAL_STATUS" => "CANCELLATION",
            other => other,
        };

        if let Some(signed_tx) = decoded["data"]["signedTransactionInfo"].as_str() {
            let tx_parts: Vec<&str> = signed_tx.split('.').collect();
            if tx_parts.len() == 3 {
                let tx_payload = base64::engine::general_purpose::URL_SAFE_NO_PAD.decode(tx_parts[1])?;
                let tx_decoded: serde_json::Value = serde_json::from_slice(&tx_payload)?;

                return Ok(vec![TransactionEvent {
                    event_type: event_type.to_string(),
                    transaction: VerifiedTransaction {
                        store_transaction_id: tx_decoded["transactionId"].as_str().unwrap_or_default().to_string(),
                        product_id: tx_decoded["productId"].as_str().unwrap_or_default().to_string(),
                        purchase_date: tx_decoded["purchaseDate"].as_str().unwrap_or_default().to_string(),
                        expiration_date: tx_decoded["expiresDate"].as_str().map(String::from),
                        status: TransactionStatus::Active,
                        store: Store::Apple,
                    },
                }]);
            }
        }

        Ok(vec![])
    }
}
