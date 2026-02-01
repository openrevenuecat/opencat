use reqwest::Client;
use crate::db::DbPool;

pub struct WebhookDeliveryWorker {
    pool: DbPool,
    client: Client,
}

impl WebhookDeliveryWorker {
    pub fn new(pool: DbPool) -> Self {
        Self {
            pool,
            client: Client::new(),
        }
    }

    pub async fn run(&self) {
        loop {
            if let Err(e) = self.process_pending().await {
                tracing::error!("Webhook delivery error: {e}");
            }
            tokio::time::sleep(tokio::time::Duration::from_secs(1)).await;
        }
    }

    async fn process_pending(&self) -> anyhow::Result<()> {
        let now = chrono::Utc::now().to_rfc3339();

        let deliveries = sqlx::query_as::<_, (String, String, String, String, i32)>(
            "SELECT wd.id, we.url, we.secret, e.payload, wd.attempts
             FROM webhook_deliveries wd
             JOIN webhook_endpoints we ON wd.webhook_endpoint_id = we.id
             JOIN events e ON wd.event_id = e.id
             WHERE wd.status IN ('pending', 'failed')
             AND (wd.next_retry_at IS NULL OR wd.next_retry_at <= ?)
             AND we.active = 1
             LIMIT 10"
        )
        .bind(&now)
        .fetch_all(&self.pool)
        .await?;

        for (delivery_id, url, secret, payload, attempts) in deliveries {
            let result = self.client
                .post(&url)
                .header("X-Webhook-Secret", &secret)
                .header("Content-Type", "application/json")
                .body(payload)
                .timeout(std::time::Duration::from_secs(10))
                .send()
                .await;

            let now = chrono::Utc::now().to_rfc3339();

            match result {
                Ok(resp) if resp.status().is_success() => {
                    sqlx::query("UPDATE webhook_deliveries SET status = 'delivered', last_attempt_at = ?, attempts = ? WHERE id = ?")
                        .bind(&now)
                        .bind(attempts + 1)
                        .bind(&delivery_id)
                        .execute(&self.pool)
                        .await?;
                }
                Ok(resp) => {
                    let error = format!("HTTP {}", resp.status());
                    self.mark_failed(&delivery_id, &error, attempts + 1, &now).await?;
                }
                Err(e) => {
                    self.mark_failed(&delivery_id, &e.to_string(), attempts + 1, &now).await?;
                }
            }
        }

        Ok(())
    }

    async fn mark_failed(&self, delivery_id: &str, error: &str, attempts: i32, now: &str) -> anyhow::Result<()> {
        let status = if attempts >= 10 { "dead_letter" } else { "failed" };
        let next_retry = if status == "failed" {
            let delay = next_retry_delay(attempts);
            Some(chrono::Utc::now() + chrono::Duration::seconds(delay.as_secs() as i64))
        } else {
            None
        };

        sqlx::query(
            "UPDATE webhook_deliveries SET status = ?, attempts = ?, last_attempt_at = ?, last_error = ?, next_retry_at = ? WHERE id = ?"
        )
        .bind(status)
        .bind(attempts)
        .bind(now)
        .bind(error)
        .bind(next_retry.map(|t| t.to_rfc3339()))
        .bind(delivery_id)
        .execute(&self.pool)
        .await?;

        Ok(())
    }
}

fn next_retry_delay(attempts: i32) -> std::time::Duration {
    let delays = [1, 5, 30, 120, 600, 3600];
    let index = (attempts as usize).min(delays.len() - 1);
    std::time::Duration::from_secs(delays[index])
}
