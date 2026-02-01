use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct App {
    pub id: String,
    pub name: String,
    pub platform: String,
    pub bundle_id: String,
    pub store_credentials_encrypted: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Deserialize)]
pub struct CreateApp {
    pub name: String,
    pub platform: String,
    pub bundle_id: String,
}

#[derive(Debug, Deserialize)]
pub struct UpdateStoreCredentials {
    pub apple: Option<AppleCredentials>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppleCredentials {
    pub issuer_id: String,
    pub key_id: String,
    pub private_key: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StoreCredentials {
    pub apple: Option<AppleCredentials>,
}
