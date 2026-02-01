use reqwest::Client;
use crate::models::app::AppleCredentials;

pub struct AppleConnectClient {
    client: Client,
    credentials: AppleCredentials,
    bundle_id: String,
}

/// Combined product info ready for our database
#[derive(Debug, Clone)]
pub struct SyncedProduct {
    pub store_product_id: String,
    pub display_name: String,
    pub description: Option<String>,
    pub price_micros: i64,
    pub currency: String,
    pub subscription_period: Option<String>,
    pub trial_period: Option<String>,
    pub product_type: String,
}

#[derive(Debug, Clone)]
struct AppleIntroOffer {
    period: String,
}

impl AppleConnectClient {
    pub fn new(credentials: AppleCredentials, bundle_id: String) -> Self {
        Self {
            client: Client::new(),
            credentials,
            bundle_id,
        }
    }

    fn generate_jwt(&self) -> anyhow::Result<String> {
        use jsonwebtoken::{encode, EncodingKey, Header, Algorithm};

        let now = chrono::Utc::now().timestamp();
        let claims = serde_json::json!({
            "iss": self.credentials.issuer_id,
            "iat": now,
            "exp": now + 1200,
            "aud": "appstoreconnect-v1",
        });

        let mut header = Header::new(Algorithm::ES256);
        header.kid = Some(self.credentials.key_id.clone());

        let token = encode(
            &header,
            &claims,
            &EncodingKey::from_ec_pem(self.credentials.private_key.as_bytes())?,
        )?;

        Ok(token)
    }

    pub async fn sync_products(&self) -> anyhow::Result<Vec<SyncedProduct>> {
        let jwt = self.generate_jwt()?;
        let mut products = Vec::new();

        let app_id = self.find_app_id(&jwt).await?;
        tracing::info!("Found Apple app ID: {} for bundle: {}", app_id, self.bundle_id);

        let subscription_products = self.fetch_subscriptions(&jwt, &app_id).await?;
        tracing::info!("Fetched {} subscriptions", subscription_products.len());
        products.extend(subscription_products);

        let iap_products = self.fetch_in_app_purchases(&jwt, &app_id).await?;
        tracing::info!("Fetched {} IAPs", iap_products.len());
        products.extend(iap_products);

        Ok(products)
    }

    async fn find_app_id(&self, jwt: &str) -> anyhow::Result<String> {
        let url = format!(
            "https://api.appstoreconnect.apple.com/v1/apps?filter[bundleId]={}",
            self.bundle_id
        );
        let resp: serde_json::Value = self.client
            .get(&url)
            .bearer_auth(jwt)
            .send()
            .await?
            .json()
            .await?;

        resp["data"][0]["id"]
            .as_str()
            .map(|s| s.to_string())
            .ok_or_else(|| anyhow::anyhow!("App not found in App Store Connect for bundle_id: {}", self.bundle_id))
    }

    async fn fetch_subscriptions(&self, jwt: &str, app_id: &str) -> anyhow::Result<Vec<SyncedProduct>> {
        let mut products = Vec::new();

        let groups_url = format!(
            "https://api.appstoreconnect.apple.com/v1/apps/{}/subscriptionGroups",
            app_id
        );
        let groups_resp: serde_json::Value = self.client
            .get(&groups_url)
            .bearer_auth(jwt)
            .send()
            .await?
            .json()
            .await?;

        tracing::info!("Subscription groups response: {}", serde_json::to_string(&groups_resp).unwrap_or_default());

        let empty = vec![];
        let groups = groups_resp["data"].as_array().unwrap_or(&empty);
        tracing::info!("Found {} subscription groups", groups.len());

        for group in groups {
            let group_id = group["id"].as_str().unwrap_or_default();

            let subs_url = format!(
                "https://api.appstoreconnect.apple.com/v1/subscriptionGroups/{}/subscriptions",
                group_id
            );
            let subs_resp: serde_json::Value = self.client
                .get(&subs_url)
                .bearer_auth(jwt)
                .send()
                .await?
                .json()
                .await?;

            let empty_subs = vec![];
            let subs = subs_resp["data"].as_array().unwrap_or(&empty_subs);

            for sub in subs {
                let sub_id = sub["id"].as_str().unwrap_or_default();
                let attrs = &sub["attributes"];
                let product_id = attrs["productId"].as_str().unwrap_or_default();
                let name = attrs["name"].as_str().unwrap_or(product_id);

                let (display_name, description) = self.fetch_subscription_localization(jwt, sub_id).await
                    .unwrap_or((name.to_string(), None));

                let (price_micros, currency) = self.fetch_subscription_price(jwt, sub_id).await
                    .unwrap_or((0, "USD".to_string()));

                let period = self.fetch_subscription_period(jwt, sub_id).await.ok();

                let trial = self.fetch_introductory_offer(jwt, sub_id).await.ok().flatten();

                products.push(SyncedProduct {
                    store_product_id: product_id.to_string(),
                    display_name,
                    description,
                    price_micros,
                    currency,
                    subscription_period: period,
                    trial_period: trial.map(|t| t.period),
                    product_type: "subscription".to_string(),
                });
            }
        }

        Ok(products)
    }

    async fn fetch_subscription_localization(&self, jwt: &str, sub_id: &str) -> anyhow::Result<(String, Option<String>)> {
        let url = format!(
            "https://api.appstoreconnect.apple.com/v1/subscriptions/{}/subscriptionLocalizations",
            sub_id
        );
        let resp: serde_json::Value = self.client.get(&url).bearer_auth(jwt).send().await?.json().await?;
        let empty = vec![];
        let localizations = resp["data"].as_array().unwrap_or(&empty);

        let loc = localizations.iter()
            .find(|l| l["attributes"]["locale"].as_str() == Some("en-US"))
            .or_else(|| localizations.first());

        if let Some(loc) = loc {
            let name = loc["attributes"]["name"].as_str().unwrap_or_default().to_string();
            let desc = loc["attributes"]["description"].as_str().map(|s| s.to_string());
            Ok((name, desc))
        } else {
            anyhow::bail!("No localizations found")
        }
    }

    async fn fetch_subscription_price(&self, jwt: &str, sub_id: &str) -> anyhow::Result<(i64, String)> {
        let url = format!(
            "https://api.appstoreconnect.apple.com/v1/subscriptions/{}/prices",
            sub_id
        );
        let resp: serde_json::Value = self.client.get(&url).bearer_auth(jwt).send().await?.json().await?;
        let empty = vec![];
        let prices = resp["data"].as_array().unwrap_or(&empty);

        if let Some(price) = prices.first() {
            let price_point_url = price["relationships"]["subscriptionPricePoint"]["links"]["related"]
                .as_str()
                .ok_or_else(|| anyhow::anyhow!("No price point link"))?;

            let pp_resp: serde_json::Value = self.client.get(price_point_url).bearer_auth(jwt).send().await?.json().await?;
            let amount_str = pp_resp["data"]["attributes"]["customerPrice"].as_str().unwrap_or("0");
            let amount: f64 = amount_str.parse().unwrap_or(0.0);
            let price_micros = (amount * 1_000_000.0) as i64;

            let territory_url = pp_resp["data"]["relationships"]["territory"]["links"]["related"]
                .as_str()
                .unwrap_or("");
            let currency = if !territory_url.is_empty() {
                let t_resp: serde_json::Value = self.client.get(territory_url).bearer_auth(jwt).send().await?.json().await?;
                t_resp["data"]["attributes"]["currency"].as_str().unwrap_or("USD").to_string()
            } else {
                "USD".to_string()
            };

            Ok((price_micros, currency))
        } else {
            anyhow::bail!("No prices found")
        }
    }

    async fn fetch_subscription_period(&self, jwt: &str, sub_id: &str) -> anyhow::Result<String> {
        let url = format!(
            "https://api.appstoreconnect.apple.com/v1/subscriptions/{}",
            sub_id
        );
        let resp: serde_json::Value = self.client.get(&url).bearer_auth(jwt).send().await?.json().await?;

        let period = resp["data"]["attributes"]["subscriptionPeriod"]
            .as_str()
            .unwrap_or("ONE_MONTH");

        let iso = match period {
            "ONE_WEEK" => "P1W",
            "ONE_MONTH" => "P1M",
            "TWO_MONTHS" => "P2M",
            "THREE_MONTHS" => "P3M",
            "SIX_MONTHS" => "P6M",
            "ONE_YEAR" => "P1Y",
            other => other,
        };

        Ok(iso.to_string())
    }

    async fn fetch_introductory_offer(&self, jwt: &str, sub_id: &str) -> anyhow::Result<Option<AppleIntroOffer>> {
        let url = format!(
            "https://api.appstoreconnect.apple.com/v1/subscriptions/{}/introductoryOffers",
            sub_id
        );
        let resp: serde_json::Value = self.client.get(&url).bearer_auth(jwt).send().await?.json().await?;
        let empty = vec![];
        let offers = resp["data"].as_array().unwrap_or(&empty);

        if let Some(offer) = offers.first() {
            let attrs = &offer["attributes"];
            let duration = attrs["duration"].as_str().unwrap_or("P1W");

            let iso_period = match duration {
                "THREE_DAYS" => "P3D",
                "ONE_WEEK" => "P1W",
                "TWO_WEEKS" => "P2W",
                "ONE_MONTH" => "P1M",
                "TWO_MONTHS" => "P2M",
                "THREE_MONTHS" => "P3M",
                "SIX_MONTHS" => "P6M",
                "ONE_YEAR" => "P1Y",
                other => other,
            };

            Ok(Some(AppleIntroOffer {
                period: iso_period.to_string(),
            }))
        } else {
            Ok(None)
        }
    }

    async fn fetch_in_app_purchases(&self, jwt: &str, app_id: &str) -> anyhow::Result<Vec<SyncedProduct>> {
        let url = format!(
            "https://api.appstoreconnect.apple.com/v2/apps/{}/inAppPurchasesV2",
            app_id
        );
        let resp: serde_json::Value = self.client.get(&url).bearer_auth(jwt).send().await?.json().await?;
        let empty = vec![];
        let iaps = resp["data"].as_array().unwrap_or(&empty);
        let mut products = Vec::new();

        for iap in iaps {
            let attrs = &iap["attributes"];
            let product_id = attrs["productId"].as_str().unwrap_or_default();
            let name = attrs["name"].as_str().unwrap_or(product_id);
            let iap_type = attrs["inAppPurchaseType"].as_str().unwrap_or("CONSUMABLE");

            let product_type = match iap_type {
                "CONSUMABLE" => "consumable",
                "NON_CONSUMABLE" => "non_consumable",
                _ => "consumable",
            };

            products.push(SyncedProduct {
                store_product_id: product_id.to_string(),
                display_name: name.to_string(),
                description: None,
                price_micros: 0,
                currency: "USD".to_string(),
                subscription_period: None,
                trial_period: None,
                product_type: product_type.to_string(),
            });
        }

        Ok(products)
    }
}
