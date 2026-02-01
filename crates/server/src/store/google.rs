use super::{StoreAdapter, types::*};
use reqwest::Client;
use serde::Deserialize;

pub struct GooglePlayAdapter {
    client: Client,
    service_account_key: String,
    package_name: String,
}

#[derive(Deserialize)]
struct ServiceAccountKey {
    client_email: String,
    private_key: String,
    token_uri: String,
}

#[derive(Deserialize)]
struct TokenResponse {
    access_token: String,
}

impl GooglePlayAdapter {
    pub fn new(service_account_key: String, package_name: String) -> Self {
        Self {
            client: Client::new(),
            service_account_key,
            package_name,
        }
    }

    async fn get_access_token(&self) -> anyhow::Result<String> {
        let key: ServiceAccountKey = serde_json::from_str(&self.service_account_key)?;

        let now = chrono::Utc::now().timestamp();
        let claims = serde_json::json!({
            "iss": key.client_email,
            "scope": "https://www.googleapis.com/auth/androidpublisher",
            "aud": key.token_uri,
            "iat": now,
            "exp": now + 3600,
        });

        let header = jsonwebtoken::Header::new(jsonwebtoken::Algorithm::RS256);
        let jwt = jsonwebtoken::encode(
            &header,
            &claims,
            &jsonwebtoken::EncodingKey::from_rsa_pem(key.private_key.as_bytes())?,
        )?;

        let resp: TokenResponse = self.client
            .post(&key.token_uri)
            .form(&[
                ("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer"),
                ("assertion", &jwt),
            ])
            .send()
            .await?
            .json()
            .await?;

        Ok(resp.access_token)
    }
}

#[async_trait::async_trait]
impl StoreAdapter for GooglePlayAdapter {
    async fn verify_purchase(&self, purchase_token: &str) -> anyhow::Result<VerifiedTransaction> {
        let token = self.get_access_token().await?;
        let url = format!(
            "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{}/purchases/subscriptionsv2/tokens/{}",
            self.package_name, purchase_token
        );

        let response = self.client
            .get(&url)
            .bearer_auth(&token)
            .send()
            .await?;

        if !response.status().is_success() {
            anyhow::bail!("Google API error: {}", response.status());
        }

        let body: serde_json::Value = response.json().await?;

        let status = match body["subscriptionState"].as_str().unwrap_or("") {
            "SUBSCRIPTION_STATE_ACTIVE" => TransactionStatus::Active,
            "SUBSCRIPTION_STATE_EXPIRED" => TransactionStatus::Expired,
            "SUBSCRIPTION_STATE_GRACE_PERIOD" => TransactionStatus::GracePeriod,
            "SUBSCRIPTION_STATE_ON_HOLD" => TransactionStatus::BillingRetry,
            _ => TransactionStatus::Active,
        };

        Ok(VerifiedTransaction {
            store_transaction_id: purchase_token.to_string(),
            product_id: body["lineItems"][0]["productId"].as_str().unwrap_or_default().to_string(),
            purchase_date: body["startTime"].as_str().unwrap_or_default().to_string(),
            expiration_date: body["lineItems"][0]["expiryTime"].as_str().map(String::from),
            status,
            store: Store::Google,
        })
    }

    async fn get_subscription_status(&self, purchase_token: &str) -> anyhow::Result<VerifiedTransaction> {
        self.verify_purchase(purchase_token).await
    }

    async fn process_notification(&self, payload: &[u8]) -> anyhow::Result<Vec<TransactionEvent>> {
        let body: serde_json::Value = serde_json::from_slice(payload)?;

        let notification_type = body["subscriptionNotification"]["notificationType"]
            .as_i64()
            .unwrap_or(0);

        let purchase_token = body["subscriptionNotification"]["purchaseToken"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("Missing purchaseToken"))?;

        let event_type = match notification_type {
            1 => "SUBSCRIPTION_RECOVERED",
            2 => "RENEWAL",
            3 => "CANCELLATION",
            4 => "INITIAL_PURCHASE",
            5 => "ACCOUNT_HOLD",
            6 => "GRACE_PERIOD",
            7 => "RESTARTED",
            12 => "REFUND",
            13 => "EXPIRATION",
            _ => "UNKNOWN",
        };

        let transaction = self.verify_purchase(purchase_token).await?;

        Ok(vec![TransactionEvent {
            event_type: event_type.to_string(),
            transaction,
        }])
    }
}
