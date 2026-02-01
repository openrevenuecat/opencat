# OpenCat — AI Agent Setup Prompt

> Paste this into Claude Code, Cursor, Copilot, or any AI coding agent to set up the full OpenCat platform.

---

## Prompt

```
You are setting up OpenCat — an open-source subscription management platform (alternative to RevenueCat).

## What is OpenCat?
A self-hosted platform that lets iOS/Android developers manage in-app subscriptions without vendor lock-in. It consists of:
1. A Rust API server (receipt validation, entitlements, product catalog)
2. A Next.js admin dashboard
3. Native SDKs (Swift, Kotlin, Flutter)

## Repositories
- https://github.com/openrevenuecat/opencat — Server + Dashboard monorepo
- https://github.com/openrevenuecat/opencat-ios — Swift/iOS SDK
- https://github.com/openrevenuecat/opencat-android — Kotlin/Android SDK (needs implementation)
- https://github.com/openrevenuecat/opencat-flutter — Flutter SDK (needs implementation)

## What is the OpenCat server?

The OpenCat server is a self-hosted REST API that sits between your app and Apple/Google. It handles:
- **Receipt validation** — verify purchases server-side (not just on-device)
- **Entitlement management** — track who has access to what
- **Product catalog** — sync pricing and metadata from App Store Connect / Google Play
- **Webhooks** — notify your backend when subscriptions change
- **Customer records** — unified view of a user's purchases across platforms

You run it on your own infrastructure. Your mobile app talks to it via the SDK, and your backend can query it for entitlement checks.

```
┌─────────┐     SDK      ┌──────────────┐     API      ┌─────────────┐
│ iOS App │─────────────→│ OpenCat      │←────────────│ Your Backend│
│ Android │  (purchases,  │ Server       │  (check      │ (Node, Py,  │
│ Flutter │   offerings)  │ (Rust+SQLite)│   subs,      │  Go, etc)   │
└─────────┘              └──────┬───────┘   webhooks)  └─────────────┘
                                │
                    ┌───────────┴───────────┐
                    │ Apple App Store       │
                    │ Google Play Console   │
                    └───────────────────────┘
```

## Step 1: Run the OpenCat server

### Option A: Docker (recommended)
```bash
git clone https://github.com/openrevenuecat/opencat.git
cd opencat
docker compose up
```
Server: http://localhost:3000 | Dashboard: http://localhost:3001

### Option B: From source
```bash
git clone https://github.com/openrevenuecat/opencat.git
cd opencat

# Server (requires Rust)
cd crates/server
cp ../../.env.example .env
cargo run
# → http://localhost:3000

# Dashboard (requires Node.js)
cd ../../dashboard
npm install
npm run dev
# → http://localhost:3001
```

## Step 2: Register your app

```bash
# Create an app
curl -X POST http://localhost:3000/v1/apps \
  -H "Content-Type: application/json" \
  -d '{"name": "My App", "bundle_id": "com.example.myapp", "platform": "ios"}'

# Create an entitlement
curl -X POST http://localhost:3000/v1/entitlements \
  -H "Content-Type: application/json" \
  -d '{"app_id": "<APP_ID>", "name": "pro", "description": "Premium access"}'

# Register products
curl -X POST http://localhost:3000/v1/products \
  -H "Content-Type: application/json" \
  -d '{"app_id": "<APP_ID>", "store_product_id": "com.example.premium.monthly", "product_type": "subscription", "entitlement_ids": ["<ENTITLEMENT_ID>"]}'
```

## Step 3: Integrate the SDK

### Swift (iOS)
Add via SPM: `https://github.com/openrevenuecat/opencat-ios.git`

```swift
import OpenCat

// On app launch
OpenCat.configureWithServer(
    serverUrl: "https://your-server.com",
    apiKey: "your-api-key",
    appUserId: userId,
    appId: "<APP_ID>"
)

// Fetch offerings
let offerings = try await OpenCat.getOfferings()

// Purchase
let tx = try await OpenCat.purchase("com.example.premium.monthly")

// Check entitlements
if OpenCat.isEntitled("pro") { /* premium */ }
```

### Kotlin (Android) — see sdks/kotlin/SPEC.md
### Flutter — see sdks/flutter/SPEC.md

## Step 4: Connect Apple App Store (optional)

In the dashboard (Settings page):
1. Select your app
2. Enter App Store Connect credentials (Issuer ID, Key ID, .p8 private key)
3. Click "Sync Products" to pull product metadata from Apple

## Architecture

```
crates/server/
  src/
    main.rs          — Entry point, Axum router
    lib.rs           — App state, router setup
    db.rs            — SQLite connection pool
    config.rs        — Environment config
    cli.rs           — CLI argument parsing
    api/             — REST endpoints (apps, products, entitlements, offerings, receipts)
    models/          — Data structs (App, Product, Entitlement, CustomerInfo)
    store/           — Platform connectors (apple_connect.rs)
  migrations/        — SQLite migrations (001_initial, 002_product_metadata)
  config/            — TOML config files

dashboard/
  src/app/           — Next.js pages (apps, products, entitlements, settings)
  src/lib/api.ts     — API client
  src/components/    — Shared UI components

sdks/
  swift/             — iOS SDK (published as opencat-ios)
  kotlin/            — Android SDK (SPEC.md ready, needs implementation)
  flutter/           — Flutter SDK (SPEC.md ready, needs implementation)
```

## Step 5: Backend integration (your server)

Your backend communicates with the OpenCat server to verify purchases, check entitlements, and manage customers. All endpoints are REST/JSON.

### Base URL
```
https://your-opencat-server.com/v1
```

### Verify a purchase (after SDK sends receipt)
```
POST /v1/receipts
{
  "app_id": "<APP_ID>",
  "app_user_id": "user_123",
  "receipt_data": "<base64 receipt or purchase token>",
  "platform": "ios"  // or "android"
}
```

### Check if a user is subscribed
```
GET /v1/subscribers/{app_user_id}

Response:
{
  "app_user_id": "user_123",
  "entitlements": {
    "pro": { "is_active": true, "expires_at": "2026-03-01T00:00:00Z", "product_id": "com.app.premium.monthly" }
  },
  "subscriptions": { ... },
  "non_subscriptions": { ... }
}
```

### Get product offerings (for server-side paywalls or pricing pages)
```
GET /v1/apps/{app_id}/offerings

Response:
[{
  "store_product_id": "com.app.premium.monthly",
  "product_type": "subscription",
  "display_name": "Premium Monthly",
  "price_micros": 9990000,
  "currency": "USD",
  "subscription_period": "P1M",
  "entitlements": ["pro"]
}]
```

### Listen for subscription events (webhooks)
```
POST /v1/webhooks
{
  "app_id": "<APP_ID>",
  "url": "https://your-backend.com/webhook/opencat",
  "events": ["purchase", "renewal", "cancellation", "expiration"]
}
```

### Example: Python backend checking entitlements
```python
import requests

OPENCAT_URL = "https://your-opencat-server.com/v1"

def is_user_premium(user_id: str) -> bool:
    resp = requests.get(f"{OPENCAT_URL}/subscribers/{user_id}")
    data = resp.json()
    ent = data.get("entitlements", {}).get("pro", {})
    return ent.get("is_active", False)
```

### Example: Node.js backend checking entitlements
```javascript
async function isUserPremium(userId) {
  const res = await fetch(`${OPENCAT_URL}/v1/subscribers/${userId}`);
  const data = await res.json();
  return data.entitlements?.pro?.is_active ?? false;
}
```

## What needs implementation

1. **Kotlin SDK** — Port Swift SDK to Kotlin with Google Play Billing. See `sdks/kotlin/SPEC.md`.
2. **Flutter SDK** — Platform channel plugin wrapping native SDKs. See `sdks/flutter/SPEC.md`.
3. **Receipt validation** — Server-side Apple/Google receipt verification.
4. **Webhook events** — Notify external systems on subscription changes.
5. **User authentication** — API key management, admin auth for dashboard.

## Key design decisions
- SQLite for simplicity (single-file DB, no external dependencies)
- Rust/Axum for performance and safety
- StoreKit 2 (not original StoreKit) for iOS
- Google Play Billing Library 6+ for Android
- SDKs work in both server mode (recommended) and standalone mode (no server)
- ProductOffering model decouples server metadata from store-native types
```
