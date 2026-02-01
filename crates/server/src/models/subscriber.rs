use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Subscriber {
    pub id: String,
    pub app_id: String,
    pub app_user_id: String,
    pub created_at: String,
}
