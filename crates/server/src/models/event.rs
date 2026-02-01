use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Event {
    pub id: String,
    pub subscriber_id: String,
    pub event_type: String,
    pub payload: String,
    pub created_at: String,
}
