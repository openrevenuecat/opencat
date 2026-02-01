# Apple App Store Connect Integration — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make OpenCat fetch product catalog from Apple's App Store Connect API so the SDK gets product metadata from our server (like RevenueCat), instead of relying on StoreKit being available.

**Architecture:** Server stores App Store Connect API credentials per app, syncs product catalog (names, prices, periods, trials) from Apple, and serves them to the SDK via a new `/v1/offerings` endpoint. SDK calls server first, tries StoreKit second for enrichment.

**Tech Stack:** Rust/Axum server, SQLite, jsonwebtoken (ES256), reqwest, Swift/StoreKit 2 SDK, Next.js/React dashboard.

---

### Task 1: Database Migration — Add Product Display Metadata

**Files:**
- Create: `crates/server/migrations/002_product_metadata.sql`

**Step 1: Write the migration**

```sql
-- Add display metadata columns to products table
ALTER TABLE products ADD COLUMN display_name TEXT;
ALTER TABLE products ADD COLUMN description TEXT;
ALTER TABLE products ADD COLUMN price_micros INTEGER;
ALTER TABLE products ADD COLUMN currency TEXT;
ALTER TABLE products ADD COLUMN subscription_period TEXT;
ALTER TABLE products ADD COLUMN trial_period TEXT;
ALTER TABLE products ADD COLUMN last_synced_at TEXT;
```

**Step 2: Verify migration runs**

Run: `cd crates/server && cargo run -- serve`
Expected: Server starts without errors, products table has new columns.

**Step 3: Update Product model**

Modify: `crates/server/src/models/product.rs`

```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Product {
    pub id: String,
    pub app_id: String,
    pub store_product_id: String,
    pub product_type: String,
    pub display_name: Option<String>,
    pub description: Option<String>,
    pub price_micros: Option<i64>,
    pub currency: Option<String>,
    pub subscription_period: Option<String>,
    pub trial_period: Option<String>,
    pub last_synced_at: Option<String>,
    pub created_at: String,
}

#[derive(Debug, Deserialize)]
pub struct CreateProduct {
    pub store_product_id: String,
    pub product_type: String,
    pub entitlement_ids: Vec<String>,
}
```

**Step 4: Run tests**

Run: `cd crates/server && cargo test`
Expected: All existing tests pass (they use `SELECT *` which will pick up new nullable columns).

**Step 5: Commit**

```bash
git add crates/server/migrations/002_product_metadata.sql crates/server/src/models/product.rs
git commit -m "feat: add product display metadata columns to database"
```

---

### Task 2: Credentials API — Save & Retrieve Store Credentials

**Files:**
- Modify: `crates/server/src/api/apps.rs`
- Modify: `crates/server/src/api/mod.rs`
- Modify: `crates/server/src/models/app.rs`

**Step 1: Add credentials input model**

Modify: `crates/server/src/models/app.rs` — add after `CreateApp`:

```rust
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
```

**Step 2: Add PUT /v1/apps/{app_id}/credentials endpoint**

Add to `crates/server/src/api/apps.rs`:

```rust
use crate::models::app::{App, CreateApp, UpdateStoreCredentials, StoreCredentials};
use axum::extract::Path;

pub async fn update_credentials(
    State(state): State<AppState>,
    Path(app_id): Path<String>,
    Json(input): Json<UpdateStoreCredentials>,
) -> Result<StatusCode, (StatusCode, String)> {
    let creds = StoreCredentials {
        apple: input.apple,
    };
    let json = serde_json::to_string(&creds)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    sqlx::query("UPDATE apps SET store_credentials_encrypted = ?, updated_at = ? WHERE id = ?")
        .bind(&json)
        .bind(chrono::Utc::now().to_rfc3339())
        .bind(&app_id)
        .execute(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(StatusCode::OK)
}

pub async fn get_credentials(
    State(state): State<AppState>,
    Path(app_id): Path<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let app = sqlx::query_as::<_, App>("SELECT * FROM apps WHERE id = ?")
        .bind(&app_id)
        .fetch_optional(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or((StatusCode::NOT_FOUND, "App not found".to_string()))?;

    // Return credentials with private key masked
    if let Some(creds_json) = &app.store_credentials_encrypted {
        let mut creds: serde_json::Value = serde_json::from_str(creds_json)
            .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
        // Mask private key for security
        if let Some(apple) = creds.get_mut("apple") {
            if apple.get("private_key").is_some() {
                apple["private_key"] = serde_json::json!("***configured***");
            }
        }
        Ok(Json(creds))
    } else {
        Ok(Json(serde_json::json!({})))
    }
}
```

**Step 3: Register routes**

Modify: `crates/server/src/api/mod.rs` — add route:

```rust
.route("/v1/apps/{app_id}/credentials", put(apps::update_credentials).get(apps::get_credentials))
```

Add `put` to the `use axum::routing::{get, post}` import → `use axum::routing::{get, post, put}`.

**Step 4: Run tests**

Run: `cd crates/server && cargo test`
Expected: All tests pass, new endpoints compile.

**Step 5: Commit**

```bash
git add crates/server/src/api/apps.rs crates/server/src/api/mod.rs crates/server/src/models/app.rs
git commit -m "feat: add store credentials API endpoints"
```

---

### Task 3: App Store Connect API Client

**Files:**
- Create: `crates/server/src/store/apple_connect.rs`
- Modify: `crates/server/src/store/mod.rs`

**Step 1: Create the Apple Connect API client**

Create: `crates/server/src/store/apple_connect.rs`

This module calls `api.appstoreconnect.apple.com` to fetch the product catalog. The App Store Connect API uses the same ES256 JWT auth as the App Store Server API but with `audience: "appstoreconnect-v1"` (which the existing `apple.rs` already uses).

```rust
use reqwest::Client;
use crate::models::app::AppleCredentials;

pub struct AppleConnectClient {
    client: Client,
    credentials: AppleCredentials,
    bundle_id: String,
}

/// Represents a subscription from App Store Connect API
#[derive(Debug, Clone, serde::Deserialize)]
pub struct AppleSubscription {
    pub product_id: String,
    pub name: String,
    pub subscription_period: String,  // e.g. "P1M", "P1Y"
}

/// Represents subscription pricing from App Store Connect API
#[derive(Debug, Clone, serde::Deserialize)]
pub struct ApplePrice {
    pub price_micros: i64,   // price in micros (cents * 10000)
    pub currency: String,     // e.g. "USD"
}

/// Represents an introductory offer
#[derive(Debug, Clone)]
pub struct AppleIntroOffer {
    pub period: String,        // e.g. "P1W"
    pub payment_mode: String,  // "freeTrial", "payAsYouGo", "payUpFront"
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
            "exp": now + 1200,  // 20 min max for Connect API
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

    /// Fetch all subscriptions and in-app purchases for this app from App Store Connect.
    pub async fn sync_products(&self) -> anyhow::Result<Vec<SyncedProduct>> {
        let jwt = self.generate_jwt()?;
        let mut products = Vec::new();

        // Step 1: Find the app by bundle ID
        let app_id = self.find_app_id(&jwt).await?;

        // Step 2: Fetch subscription groups
        let subscription_products = self.fetch_subscriptions(&jwt, &app_id).await?;
        products.extend(subscription_products);

        // Step 3: Fetch non-subscription IAPs
        let iap_products = self.fetch_in_app_purchases(&jwt, &app_id).await?;
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

        // Get subscription groups
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

        let groups = groups_resp["data"].as_array().unwrap_or(&vec![]);

        for group in groups {
            let group_id = group["id"].as_str().unwrap_or_default();

            // Get subscriptions in this group
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

            let subs = subs_resp["data"].as_array().unwrap_or(&vec![]);

            for sub in subs {
                let sub_id = sub["id"].as_str().unwrap_or_default();
                let attrs = &sub["attributes"];
                let product_id = attrs["productId"].as_str().unwrap_or_default();
                let name = attrs["name"].as_str().unwrap_or(product_id);

                // Get subscription localizations for display name/description
                let (display_name, description) = self.fetch_subscription_localization(jwt, sub_id).await
                    .unwrap_or((name.to_string(), None));

                // Get subscription price
                let (price_micros, currency) = self.fetch_subscription_price(jwt, sub_id).await
                    .unwrap_or((0, "USD".to_string()));

                // Get subscription period from group info
                let period = self.fetch_subscription_period(jwt, sub_id).await.ok();

                // Get introductory offer (trial)
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
        let localizations = resp["data"].as_array().unwrap_or(&vec![]);

        // Prefer en-US, fall back to first
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
        let prices = resp["data"].as_array().unwrap_or(&vec![]);

        // Get the first price point (territory-specific pricing)
        // For simplicity, get the base price. The `subscriptionPricePoint` relationship has the actual amount.
        if let Some(price) = prices.first() {
            let price_point_url = price["relationships"]["subscriptionPricePoint"]["links"]["related"]
                .as_str()
                .ok_or_else(|| anyhow::anyhow!("No price point link"))?;

            let pp_resp: serde_json::Value = self.client.get(price_point_url).bearer_auth(jwt).send().await?.json().await?;
            let amount_str = pp_resp["data"]["attributes"]["customerPrice"].as_str().unwrap_or("0");
            let amount: f64 = amount_str.parse().unwrap_or(0.0);
            let price_micros = (amount * 1_000_000.0) as i64;

            // Get territory for currency
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

        // subscriptionPeriod is in attributes: ONE_MONTH, ONE_YEAR, etc.
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
        let offers = resp["data"].as_array().unwrap_or(&vec![]);

        if let Some(offer) = offers.first() {
            let attrs = &offer["attributes"];
            let duration = attrs["duration"].as_str().unwrap_or("P1W");
            let mode = attrs["offerMode"].as_str().unwrap_or("freeTrial");

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
                payment_mode: mode.to_string(),
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
        let iaps = resp["data"].as_array().unwrap_or(&vec![]);
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
```

**Step 2: Export from store module**

Modify: `crates/server/src/store/mod.rs` — add:

```rust
pub mod apple_connect;
```

**Step 3: Run tests**

Run: `cd crates/server && cargo test`
Expected: Compiles and tests pass.

**Step 4: Commit**

```bash
git add crates/server/src/store/apple_connect.rs crates/server/src/store/mod.rs
git commit -m "feat: add App Store Connect API client for product catalog sync"
```

---

### Task 4: Sync Products Endpoint & Offerings API

**Files:**
- Create: `crates/server/src/api/offerings.rs`
- Modify: `crates/server/src/api/apps.rs`
- Modify: `crates/server/src/api/mod.rs`

**Step 1: Create offerings endpoint**

Create: `crates/server/src/api/offerings.rs`

```rust
use axum::{extract::{Path, State}, http::StatusCode, Json};
use serde::Serialize;
use crate::api::AppState;

#[derive(Debug, Serialize)]
pub struct OfferingProduct {
    pub store_product_id: String,
    pub product_type: String,
    pub display_name: String,
    pub description: Option<String>,
    pub price_micros: i64,
    pub currency: String,
    pub subscription_period: Option<String>,
    pub trial_period: Option<String>,
    pub entitlements: Vec<String>,
}

#[derive(Debug, Serialize)]
pub struct OfferingsResponse {
    pub offerings: Vec<OfferingProduct>,
}

pub async fn get_offerings(
    State(state): State<AppState>,
    Path(app_id): Path<String>,
) -> Result<Json<OfferingsResponse>, (StatusCode, String)> {
    // Fetch products with their entitlements
    let products = sqlx::query_as::<_, crate::models::product::Product>(
        "SELECT * FROM products WHERE app_id = ? ORDER BY created_at"
    )
    .bind(&app_id)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    let mut offerings = Vec::new();

    for product in products {
        // Get entitlement names for this product
        let entitlements: Vec<String> = sqlx::query_scalar(
            "SELECT e.name FROM entitlements e \
             JOIN product_entitlements pe ON pe.entitlement_id = e.id \
             WHERE pe.product_id = ?"
        )
        .bind(&product.id)
        .fetch_all(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

        offerings.push(OfferingProduct {
            store_product_id: product.store_product_id,
            product_type: product.product_type,
            display_name: product.display_name.unwrap_or_default(),
            description: product.description,
            price_micros: product.price_micros.unwrap_or(0),
            currency: product.currency.unwrap_or_else(|| "USD".to_string()),
            subscription_period: product.subscription_period,
            trial_period: product.trial_period,
            entitlements,
        });
    }

    Ok(Json(OfferingsResponse { offerings }))
}
```

**Step 2: Create sync-products endpoint**

Add to `crates/server/src/api/apps.rs`:

```rust
use crate::models::app::StoreCredentials;
use crate::store::apple_connect::AppleConnectClient;

pub async fn sync_products(
    State(state): State<AppState>,
    Path(app_id): Path<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    // Get app with credentials
    let app = sqlx::query_as::<_, App>("SELECT * FROM apps WHERE id = ?")
        .bind(&app_id)
        .fetch_optional(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or((StatusCode::NOT_FOUND, "App not found".to_string()))?;

    let creds_json = app.store_credentials_encrypted
        .ok_or((StatusCode::BAD_REQUEST, "No store credentials configured".to_string()))?;

    let creds: StoreCredentials = serde_json::from_str(&creds_json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    let apple_creds = creds.apple
        .ok_or((StatusCode::BAD_REQUEST, "No Apple credentials configured".to_string()))?;

    // Sync from Apple
    let client = AppleConnectClient::new(apple_creds, app.bundle_id);
    let synced = client.sync_products().await
        .map_err(|e| (StatusCode::BAD_GATEWAY, format!("Apple API error: {}", e)))?;

    let now = chrono::Utc::now().to_rfc3339();
    let mut synced_count = 0;

    for product in &synced {
        // Upsert: update existing products or create new ones
        let existing = sqlx::query_scalar::<_, String>(
            "SELECT id FROM products WHERE app_id = ? AND store_product_id = ?"
        )
        .bind(&app_id)
        .bind(&product.store_product_id)
        .fetch_optional(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

        if let Some(product_id) = existing {
            sqlx::query(
                "UPDATE products SET display_name = ?, description = ?, price_micros = ?, \
                 currency = ?, subscription_period = ?, trial_period = ?, last_synced_at = ? \
                 WHERE id = ?"
            )
            .bind(&product.display_name)
            .bind(&product.description)
            .bind(product.price_micros)
            .bind(&product.currency)
            .bind(&product.subscription_period)
            .bind(&product.trial_period)
            .bind(&now)
            .bind(&product_id)
            .execute(&state.pool)
            .await
            .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
        } else {
            let id = uuid::Uuid::new_v4().to_string();
            sqlx::query(
                "INSERT INTO products (id, app_id, store_product_id, product_type, display_name, \
                 description, price_micros, currency, subscription_period, trial_period, \
                 last_synced_at, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
            )
            .bind(&id)
            .bind(&app_id)
            .bind(&product.store_product_id)
            .bind(&product.product_type)
            .bind(&product.display_name)
            .bind(&product.description)
            .bind(product.price_micros)
            .bind(&product.currency)
            .bind(&product.subscription_period)
            .bind(&product.trial_period)
            .bind(&now)
            .bind(&now)
            .execute(&state.pool)
            .await
            .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
        }
        synced_count += 1;
    }

    Ok(Json(serde_json::json!({
        "synced": synced_count,
        "products": synced.iter().map(|p| &p.store_product_id).collect::<Vec<_>>()
    })))
}
```

**Step 3: Register new routes**

Modify: `crates/server/src/api/mod.rs` — add:

```rust
pub mod offerings;
```

Add routes:

```rust
.route("/v1/apps/{app_id}/offerings", get(offerings::get_offerings))
.route("/v1/apps/{app_id}/sync-products", post(apps::sync_products))
```

**Step 4: Run tests**

Run: `cd crates/server && cargo test`
Expected: All tests pass.

**Step 5: Commit**

```bash
git add crates/server/src/api/offerings.rs crates/server/src/api/apps.rs crates/server/src/api/mod.rs
git commit -m "feat: add offerings API and product sync endpoint"
```

---

### Task 5: SDK — New ProductOffering Type & Server-Based getOfferings

**Files:**
- Modify: `ios-app/RushDay/Core/Services/OpenCat/OpenCat.swift`
- Modify: `ios-app/RushDay/Core/Services/OpenCat/BackendConnector.swift`

**Step 1: Add ProductOffering model and server fetch to BackendConnector**

Add to `BackendConnector.swift` — new model and method:

```swift
/// Product offering returned by the OpenCat server.
struct ProductOffering: Codable {
    let storeProductId: String
    let productType: String
    let displayName: String
    let description: String?
    let priceMicros: Int64
    let currency: String
    let subscriptionPeriod: String?
    let trialPeriod: String?
    let entitlements: [String]

    /// StoreKit Product, attached after fetching from StoreKit (nil if StoreKit unavailable)
    var storeProduct: Product?

    enum CodingKeys: String, CodingKey {
        case storeProductId, productType, displayName, description
        case priceMicros, currency, subscriptionPeriod, trialPeriod, entitlements
    }

    /// Price as Decimal (from micros)
    var price: Decimal {
        Decimal(priceMicros) / 1_000_000
    }

    /// Formatted price string
    var displayPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: price as NSDecimalNumber) ?? "$\(price)"
    }
}

struct OfferingsResponse: Codable {
    let offerings: [ProductOffering]
}
```

Add method to `BackendConnector`:

```swift
/// Fetch product offerings from the OpenCat server.
func getOfferings(appId: String) async throws -> [ProductOffering] {
    let url = serverUrl.appendingPathComponent("/v1/apps/\(appId)/offerings")

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await session.data(for: request)
    try validateResponse(response)

    let decoded = try JSONDecoder.openCat.decode(OfferingsResponse.self, from: data)
    return decoded.offerings
}
```

**Step 2: Update OpenCat.getOfferings to use server**

Modify: `OpenCat.swift` — replace the `getOfferings` method:

```swift
/// Fetch available product offerings.
/// In server mode: fetches from OpenCat server, enriches with StoreKit Products when available.
/// In standalone mode: fetches directly from StoreKit (requires StoreKit environment).
public static func getOfferings(productIds: [String] = []) async throws -> [ProductOffering] {
    let instance = shared
    try instance.ensureConfigured()

    guard let mode = instance.getMode() else { throw OpenCatError.notConfigured }

    switch mode {
    case .server:
        guard let connector = instance.backendConnector else { throw OpenCatError.notConfigured }

        // Fetch offerings from server
        // Use apiKey as app_id for now (the server knows the app from the key)
        var offerings = try await connector.getOfferings(appId: "default")

        // Try to enrich with StoreKit products (for purchasing)
        let storeProductIds = offerings.map { $0.storeProductId }
        if let storeProducts = try? await instance.purchaseManager.getProducts(productIds: storeProductIds) {
            let productMap = Dictionary(uniqueKeysWithValues: storeProducts.map { ($0.id, $0) })
            for i in offerings.indices {
                offerings[i].storeProduct = productMap[offerings[i].storeProductId]
            }
        }

        return offerings

    case .standalone:
        // Standalone: use StoreKit directly (original behavior)
        let products = try await instance.purchaseManager.getProducts(productIds: productIds)
        return products.map { product in
            var offering = ProductOffering(
                storeProductId: product.id,
                productType: product.subscription != nil ? "subscription" : "non_consumable",
                displayName: product.displayName,
                description: product.description,
                priceMicros: Int64(truncating: (product.price * 1_000_000) as NSDecimalNumber),
                currency: "USD",
                subscriptionPeriod: nil,
                trialPeriod: nil,
                entitlements: []
            )
            offering.storeProduct = product
            return offering
        }
    }
}
```

**Step 3: Update OpenCat.purchase to accept product ID string**

The `purchase` method already takes a `String` productId — no change needed.

**Step 4: Build**

Run: `xcodebuild -project ios-app/RushDay.xcodeproj -scheme RushDay -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.1' build 2>&1 | tail -5`
Expected: Compiler errors in OpenCatService.swift and SubscriptionPackage.swift (they still reference `Product` and old API). We fix those in Task 6.

**Step 5: Commit (SDK core only)**

```bash
git add ios-app/RushDay/Core/Services/OpenCat/OpenCat.swift ios-app/RushDay/Core/Services/OpenCat/BackendConnector.swift
git commit -m "feat: SDK fetches offerings from server instead of StoreKit directly"
```

---

### Task 6: Update SubscriptionPackage & OpenCatService for ProductOffering

**Files:**
- Modify: `ios-app/RushDay/Core/Services/OpenCat/SubscriptionPackage.swift`
- Modify: `ios-app/RushDay/Core/Services/OpenCat/OpenCatService.swift`

**Step 1: Rewrite SubscriptionPackage to wrap ProductOffering**

Replace entire `SubscriptionPackage.swift`:

```swift
import Foundation
import StoreKit

// MARK: - Subscription Package

/// A wrapper around `ProductOffering` (from server) that provides the display interface
/// needed by Paywall screens.
struct SubscriptionPackage: Identifiable {
    let offering: ProductOffering
    let packageType: SubscriptionPackageType

    var id: String { offering.storeProductId }
    var identifier: String { offering.storeProductId }

    // MARK: - Store Product Interface

    var storeProduct: StoreProductInfo { StoreProductInfo(offering: offering) }

    // MARK: - Free Trial

    var hasFreeTrial: Bool {
        offering.trialPeriod != nil
    }

    var freeTrialDays: Int {
        guard let period = offering.trialPeriod else { return 0 }
        return isoDurationToDays(period)
    }

    // MARK: - Display Helpers

    var displayTitle: String {
        switch packageType {
        case .annual: return "Annual"
        case .monthly: return "Monthly"
        case .weekly: return "Weekly"
        case .lifetime: return "Lifetime"
        case .unknown: return offering.displayName
        }
    }

    var pricePerMonth: String {
        switch packageType {
        case .annual:
            let monthlyPrice = offering.price / 12
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = offering.currency
            return formatter.string(from: monthlyPrice as NSDecimalNumber) ?? offering.displayPrice
        default:
            return offering.displayPrice
        }
    }

    /// The StoreKit Product for purchasing (nil if StoreKit unavailable)
    var storeKitProduct: Product? { offering.storeProduct }
}

// MARK: - Package Type

enum SubscriptionPackageType: String {
    case annual = "ANNUAL"
    case monthly = "MONTHLY"
    case weekly = "WEEKLY"
    case lifetime = "LIFETIME"
    case unknown = "UNKNOWN"

    var stringValue: String {
        switch self {
        case .annual: return "annual"
        case .monthly: return "monthly"
        case .weekly: return "weekly"
        case .lifetime: return "lifetime"
        case .unknown: return "unknown"
        }
    }

    /// Infer package type from ISO 8601 subscription period.
    static func from(period: String?) -> SubscriptionPackageType {
        guard let period = period else { return .lifetime }
        switch period {
        case "P1Y": return .annual
        case "P1M": return .monthly
        case "P1W": return .weekly
        default:
            if period.contains("Y") { return .annual }
            if period.contains("M") { return .monthly }
            if period.contains("W") { return .weekly }
            return .unknown
        }
    }

    /// Infer package type from a StoreKit Product (fallback for standalone mode).
    static func from(product: Product) -> SubscriptionPackageType {
        guard let subscription = product.subscription else { return .lifetime }
        let period = subscription.subscriptionPeriod
        switch period.unit {
        case .year: return .annual
        case .month:
            if period.value >= 12 { return .annual }
            return .monthly
        case .week: return .weekly
        case .day:
            if period.value >= 28 { return .monthly }
            if period.value >= 7 { return .weekly }
            return .unknown
        @unknown default: return .unknown
        }
    }
}

// MARK: - Store Product Info

/// Provides a unified product info interface regardless of whether data comes from server or StoreKit.
struct StoreProductInfo {
    let offering: ProductOffering

    var price: Decimal { offering.price }
    var localizedTitle: String { offering.displayName }
    var localizedPriceString: String { offering.displayPrice }
    var productIdentifier: String { offering.storeProductId }
    var currencyCode: String? { offering.currency }
    var introductoryDiscount: IntroductoryDiscount? {
        guard offering.trialPeriod != nil else { return nil }
        return IntroductoryDiscount(trialPeriod: offering.trialPeriod!)
    }
}

// MARK: - Introductory Discount

struct IntroductoryDiscount {
    let trialPeriod: String

    var subscriptionPeriod: SubscriptionPeriodInfo {
        SubscriptionPeriodInfo(isoPeriod: trialPeriod)
    }
}

struct SubscriptionPeriodInfo {
    let isoPeriod: String

    var unit: PeriodUnit {
        if isoPeriod.contains("Y") { return .year }
        if isoPeriod.contains("M") { return .month }
        if isoPeriod.contains("W") { return .week }
        return .day
    }

    var value: Int {
        isoDurationToValue(isoPeriod)
    }

    enum PeriodUnit {
        case day, week, month, year
    }
}

// MARK: - ISO 8601 Duration Helpers

private func isoDurationToDays(_ period: String) -> Int {
    let value = isoDurationToValue(period)
    if period.contains("D") { return value }
    if period.contains("W") { return value * 7 }
    if period.contains("M") { return value * 30 }
    if period.contains("Y") { return value * 365 }
    return 0
}

private func isoDurationToValue(_ period: String) -> Int {
    // Parse "P1W", "P3D", "P1M", "P1Y" etc.
    let digits = period.filter { $0.isNumber }
    return Int(digits) ?? 0
}
```

**Step 2: Update OpenCatService.swift**

Replace the `getOfferings` method:

```swift
func getOfferings() async throws -> [SubscriptionPackage] {
    guard isConfigured else { throw SubscriptionError.notConfigured }

    do {
        let offerings = try await OpenCat.getOfferings(productIds: Self.productIds)

        return offerings
            .map { offering in
                SubscriptionPackage(
                    offering: offering,
                    packageType: SubscriptionPackageType.from(period: offering.subscriptionPeriod)
                )
            }
            .sorted { lhs, rhs in
                packageOrder(lhs.packageType) < packageOrder(rhs.packageType)
            }
    } catch let error as OpenCatError {
        throw mapOpenCatError(error)
    }
}
```

Replace the `purchase` method:

```swift
func purchase(package: SubscriptionPackage) async throws -> SubscriptionStatus {
    guard isConfigured else { throw SubscriptionError.notConfigured }

    do {
        let transaction = try await OpenCat.purchase(package.offering.storeProductId)

        let status = SubscriptionStatus(
            isActive: transaction.status == .active,
            expirationDate: transaction.expirationDate,
            productId: transaction.productId,
            packageType: package.packageType
        )

        statusContinuation?.yield(status)
        return status
    } catch let error as OpenCatError {
        throw mapOpenCatError(error)
    }
}
```

**Step 3: Build**

Run: `xcodebuild -project ios-app/RushDay.xcodeproj -scheme RushDay -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.1' build 2>&1 | tail -5`
Expected: **BUILD SUCCEEDED**

**Step 4: Commit**

```bash
git add ios-app/RushDay/Core/Services/OpenCat/SubscriptionPackage.swift ios-app/RushDay/Core/Services/OpenCat/OpenCatService.swift
git commit -m "feat: SubscriptionPackage wraps ProductOffering from server"
```

---

### Task 7: SDK — Pass App ID to getOfferings

**Files:**
- Modify: `ios-app/RushDay/Core/Services/OpenCat/OpenCat.swift`
- Modify: `ios-app/RushDay/Core/Services/OpenCat/Configuration.swift`
- Modify: `ios-app/RushDay/Core/Services/OpenCat/OpenCatService.swift`

The SDK needs to know the app_id to call `/v1/apps/{app_id}/offerings`. The simplest approach: add `appId` to `ServerConfiguration`.

**Step 1: Add appId to ServerConfiguration**

Modify `Configuration.swift`:

```swift
public struct ServerConfiguration {
    public let serverUrl: URL
    public let apiKey: String
    public let appUserId: String
    public let appId: String

    public init(serverUrl: String, apiKey: String, appUserId: String, appId: String = "") {
        guard let url = URL(string: serverUrl) else {
            fatalError("OpenCat: Invalid server URL: \(serverUrl)")
        }
        self.serverUrl = url
        self.apiKey = apiKey
        self.appUserId = appUserId
        self.appId = appId
    }
}
```

**Step 2: Update OpenCat.configureWithServer**

Modify `OpenCat.swift` — add appId parameter:

```swift
public static func configureWithServer(serverUrl: String, apiKey: String, appUserId: String, appId: String = "") {
    let config = ServerConfiguration(serverUrl: serverUrl, apiKey: apiKey, appUserId: appUserId, appId: appId)
    // ... rest unchanged
}
```

**Step 3: Use appId in getOfferings**

In `OpenCat.swift` `getOfferings` method, replace `"default"`:

```swift
case .server(let config):
    guard let connector = instance.backendConnector else { throw OpenCatError.notConfigured }
    var offerings = try await connector.getOfferings(appId: config.appId)
    // ...
```

**Step 4: Pass appId in OpenCatService and RushDayApp**

In `OpenCatService.swift`, add `appId` config:

```swift
private static let appId = "" // Set after registering app with OpenCat server
```

And pass it in `configure()` and `login()` calls. In `RushDayApp.swift`, add the appId to the configure call.

Note: For now the appId can be empty — the integration test script from earlier creates the app and returns its ID. We'll wire this up during testing.

**Step 5: Build and commit**

Run: `xcodebuild -project ios-app/RushDay.xcodeproj -scheme RushDay -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.1' build 2>&1 | tail -5`

```bash
git add ios-app/RushDay/Core/Services/OpenCat/
git commit -m "feat: pass app ID to server for offerings lookup"
```

---

### Task 8: Dashboard — Credentials Form & Product Sync

**Files:**
- Modify: `dashboard/src/lib/api.ts`
- Modify: `dashboard/src/app/products/page.tsx`
- Create or modify: `dashboard/src/app/settings/page.tsx`

**Step 1: Add new API methods**

Add to `dashboard/src/lib/api.ts`:

```typescript
export interface ProductWithMetadata extends Product {
  display_name: string | null;
  description: string | null;
  price_micros: number | null;
  currency: string | null;
  subscription_period: string | null;
  trial_period: string | null;
  last_synced_at: string | null;
}

// Add to api object:
  updateCredentials: (appId: string, data: { apple?: { issuer_id: string; key_id: string; private_key: string } }) =>
    request<void>(`/v1/apps/${appId}/credentials`, { method: "PUT", body: JSON.stringify(data) }),

  getCredentials: (appId: string) =>
    request<Record<string, unknown>>(`/v1/apps/${appId}/credentials`),

  syncProducts: (appId: string) =>
    request<{ synced: number; products: string[] }>(`/v1/apps/${appId}/sync-products`, { method: "POST" }),

  listProductsWithMetadata: (appId: string) =>
    request<ProductWithMetadata[]>(`/v1/apps/${appId}/products`),
```

**Step 2: Create settings page with credentials form**

Create/modify `dashboard/src/app/settings/page.tsx` with a form that:
- Lets user select an app from dropdown
- Shows fields for Apple Issuer ID, Key ID, Private Key (.p8 contents paste)
- Has a "Save Credentials" button that calls `PUT /v1/apps/{app_id}/credentials`
- Has a "Sync Products from Apple" button that calls `POST /v1/apps/{app_id}/sync-products`
- Shows sync results (number of products synced)

**Step 3: Update products page**

Modify `dashboard/src/app/products/page.tsx` to show the new metadata columns:
- Display Name, Price (formatted from micros), Period, Trial, Last Synced
- Add a "Sync" button

**Step 4: Test manually**

Start dashboard: `cd dashboard && npm run dev`
Navigate to Settings, select app, enter credentials, sync.

**Step 5: Commit**

```bash
git add dashboard/src/
git commit -m "feat: dashboard credentials form and product sync UI"
```

---

### Task 9: Integration Test — End to End

**Files:**
- Modify: `scripts/integration-test.sh`

**Step 1: Update integration test**

Update `scripts/integration-test.sh` to:
1. Start server
2. Create app
3. Save mock credentials (won't actually call Apple in test, but tests the endpoint)
4. Create products with display metadata manually (since we can't call Apple without real creds)
5. Call `GET /v1/apps/{app_id}/offerings` and verify it returns products with metadata
6. Build iOS app and verify it compiles

**Step 2: Run test**

Run: `./scripts/integration-test.sh`
Expected: All steps pass, offerings endpoint returns products.

**Step 3: Commit**

```bash
git add scripts/integration-test.sh
git commit -m "test: update integration test for offerings API"
```

---

## Execution Order

Tasks 1-4 are server-side (sequential).
Tasks 5-7 are SDK-side (sequential, depend on Task 4).
Task 8 is dashboard (can parallel with 5-7).
Task 9 is integration (depends on all above).

```
1 → 2 → 3 → 4 → 5 → 6 → 7 → 9
                  ↘ 8 ↗
```
