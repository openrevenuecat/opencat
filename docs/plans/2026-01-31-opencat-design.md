# OpenCat — Open-Source In-App Purchase Infrastructure

> Self-hosted RevenueCat alternative. Own your subscription data.

## Positioning

"Stripe Atlas for mobile subscriptions, but you own everything."

**Target users:**
- Indie devs tired of RevenueCat fees
- Companies with compliance/data residency requirements
- Developers who want control

---

## 1. System Architecture

OpenCat is a three-layer system:

### Layer 1 — Client SDKs (Swift, Kotlin, Flutter)

Lightweight libraries that handle purchasing, receipt caching, and entitlement checks. Two operating modes:

- **Standalone mode** — SDK validates receipts directly with Apple/Google, stores state locally on-device. No server needed.
- **Server mode** — SDK forwards receipts to the OpenCat server, which handles validation, stores canonical state, and syncs entitlements back.

### Layer 2 — OpenCat Server (Rust)

A single self-hosted binary that provides:
- Receipt validation against Apple/Google APIs
- Subscriber and entitlement state management
- Server-to-server notification ingestion
- REST API for querying subscriber data
- CLI tooling for management

### Layer 3 — Storage (PostgreSQL or SQLite)

SQLite for quick local dev and small deployments. PostgreSQL for production.

### Layer 4 — Dashboard (React/Next.js)

Separate frontend application. Ships as its own Docker image alongside the server. Talks to the OpenCat REST API.

```
┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│  iOS SDK    │   │ Android SDK │   │ Flutter SDK │
└──────┬──────┘   └──────┬──────┘   └──────┬──────┘
       │                 │                  │
       └────────┬────────┴──────────────────┘
                │  (standalone or server mode)
         ┌──────▼──────┐
         │ OpenCat API  │ ← Apple/Google S2S notifications
         │   (Rust)     │
         └──────┬──────┘
         ┌──────▼──────┐
         │  Postgres /  │
         │   SQLite     │
         └─────────────┘
                │
         ┌──────▼──────┐
         │  Dashboard   │
         │  (Next.js)   │
         └─────────────┘
```

---

## 2. Data Model

### `app`
A registered application. Developers can manage multiple apps from one OpenCat instance.
- `id`, `name`, `platform` (ios/android), `bundle_id`, `store_credentials` (encrypted)

### `product`
A purchasable item mapped to a store product ID.
- `id`, `app_id`, `store_product_id`, `type` (subscription/consumable/non-consumable), `entitlement_ids`

### `entitlement`
A named access grant (e.g., "pro", "premium_features").
- `id`, `app_id`, `name`, `description`

Entitlements are decoupled from products — one product can grant multiple entitlements, and multiple products can grant the same entitlement. This lets developers restructure pricing without changing access logic.

### `subscriber`
A user identified by a developer-provided `app_user_id`.
- `id`, `app_id`, `app_user_id`, `created_at`

`app_user_id` is developer-controlled. OpenCat does not manage auth.

### `transaction`
An individual purchase or renewal event.
- `id`, `subscriber_id`, `product_id`, `store` (apple/google), `store_transaction_id`, `purchase_date`, `expiration_date`, `status` (active/expired/refunded/grace_period/billing_retry), `raw_receipt` (stored for audit)

### `event`
An immutable append-only log of everything that happens. Powers the dashboard, webhooks, and audit trail.
- `id`, `subscriber_id`, `type`, `payload`, `created_at`

---

## 3. Store Integration

### Apple App Store

- **App Store Server API v2** (not the deprecated `verifyReceipt`)
- Authentication via JWT signed with App Store Connect API key
- Receipts are JWS-signed transactions — OpenCat verifies signatures using Apple's public keys
- **Server Notifications V2** pushed to `/v1/notifications/apple` — notifications contain the full signed transaction payload inline (no follow-up API call needed)
- Key endpoint: `GET /inApps/v1/subscriptions/{transactionId}` for subscription status

### Google Play

- **Purchases Subscriptions v2 API** (`subscriptionsv2.get`) with OAuth 2.0 service account auth
- **Real-Time Developer Notifications (RTDN)** via Google Cloud Pub/Sub — notifications only signal state changes, OpenCat follows up with an API call for full details
- Purchase tokens are the primary identifier

### Store Abstraction

```rust
trait StoreAdapter {
    async fn verify_purchase(&self, receipt: &RawReceipt) -> Result<VerifiedTransaction>;
    async fn get_subscription_status(&self, id: &StoreSubscriptionId) -> Result<SubscriptionStatus>;
    async fn process_notification(&self, payload: &[u8]) -> Result<Vec<TransactionEvent>>;
}
```

Each store implements this trait. The rest of the server works with unified types. Adding a new store (Stripe, Amazon, etc.) means implementing this trait.

---

## 4. SDK Architecture

### Core API (all platforms)

```
OpenCat.configure(apiKey?, serverUrl?, appUserId)
OpenCat.getOfferings() → List<Offering>
OpenCat.purchase(productId) → Transaction
OpenCat.restorePurchases() → CustomerInfo
OpenCat.getCustomerInfo() → CustomerInfo
OpenCat.isEntitled("pro") → Bool
```

### Standalone Mode (no server)

- SDK validates receipts directly with Apple/Google
- Entitlement state stored on-device (encrypted local storage)
- No cross-device sync, no dashboard
- Zero infrastructure needed

### Server Mode (with OpenCat backend)

- SDK sends purchase tokens to OpenCat server for validation
- Server is source of truth for entitlement state
- SDK caches `CustomerInfo` locally for offline access
- Cross-device sync via `app_user_id`

### Improvements Over RevenueCat

1. **Offerings cached between launches** — RevenueCat doesn't persist offerings across app restarts. OpenCat does, with a staleness check on next fetch.
2. **Longer offline tolerance** — RevenueCat marks entitlements inactive after 3 days offline. OpenCat respects the actual `expiration_date` from the last known transaction.
3. **No `syncPurchases` vs `restorePurchases` confusion** — One method: `restorePurchases()`. Handles both anonymous and identified users.
4. **Explicit purchase acknowledgment** — On Android, auto-acknowledges after successful validation, preventing the 3-day refund window issue.

### Flutter SDK

Wraps the native Swift/Kotlin SDKs via platform channels — not a reimplementation.

---

## 5. Server REST API

```
POST   /v1/apps                                    # Register an app
POST   /v1/apps/{app_id}/products                  # Define products & entitlement mappings
POST   /v1/apps/{app_id}/entitlements               # Define entitlements

POST   /v1/receipts                                 # Submit a receipt/token for validation
GET    /v1/subscribers/{app_user_id}                # Get subscriber info + active entitlements
GET    /v1/subscribers/{app_user_id}/transactions   # Transaction history

POST   /v1/webhooks                                 # Register a webhook endpoint
GET    /v1/events                                   # Poll events (alternative to webhooks)

# Store notification ingestion (called by Apple/Google, not by developers)
POST   /v1/notifications/apple                      # App Store Server Notifications V2
POST   /v1/notifications/google                     # Google RTDN (Pub/Sub push)
```

**Authentication:** API key in `Authorization: Bearer <key>` header. Keys scoped per-app with read/write permissions.

---

## 6. Webhook System

RevenueCat has known reliability issues where purchases succeed but webhooks never fire. OpenCat addresses this:

- Events written to the `event` table first (durable)
- Separate delivery worker reads undelivered events and POSTs to registered webhook URLs
- **Exponential backoff retry**: 1s, 5s, 30s, 2min, 10min, 1hr — up to 24 hours
- **Delivery receipts**: webhook must respond 2xx within 10s or it's retried
- **Dead letter queue**: after 24hr of failures, events land in a DLQ visible in the dashboard
- **Event polling fallback**: `GET /v1/events?since={cursor}` for developers who prefer pull over push

### Event Types

```
INITIAL_PURCHASE
RENEWAL
CANCELLATION
EXPIRATION
REFUND
BILLING_ISSUE_DETECTED
BILLING_ISSUE_RESOLVED
PRODUCT_CHANGE
```

Each event includes: `event_id`, `type`, `subscriber`, `product`, `transaction`, `store`, `timestamp`.

---

## 7. Dashboard

Separate React/Next.js application. Talks to the same REST API developers use. Ships as its own Docker image.

**Why separate from the server:**
- Business teams need to customize it without touching Rust
- Faster iteration cycle (frontend deploys independently)
- Can be themed/white-labeled
- Community can contribute UI improvements without knowing Rust

### Pages

- **Dashboard home** — MRR, active subscribers, trial conversions, churn rate, refund rate. Date range picker. All charts configurable (show/hide metrics).
- **Subscribers** — Search, filter by status/product/entitlement/store. Bulk CSV export. Click into subscriber detail: entitlements, transactions, events, raw receipt data.
- **Revenue** — Revenue by product, by store, by period. Cohort retention charts. Refund breakdown.
- **Events** — Real-time feed with filters. Click to inspect full payload.
- **Webhooks** — Endpoint management, delivery logs, DLQ with retry buttons.
- **Products & Entitlements** — Visual mapping of which products grant which entitlements.
- **Settings** — API keys, store credentials, team members (basic RBAC: admin/viewer).

### Customizability

- Every dashboard section is a toggleable module — hide what you don't need
- Configurable default date ranges, currency display, timezone
- Theming via CSS variables (brand colors, logo)
- All dashboard data available via the REST API — teams can build their own if they outgrow the default

---

## 8. Deployment & Developer Experience

### Quick Start (< 5 minutes)

```bash
# Option 1: Docker (recommended)
docker compose up

# Option 2: Single binary + SQLite
curl -fsSL https://opencat.dev/install.sh | sh
opencat serve
```

Both start the server + dashboard. SQLite by default. First visit opens a setup wizard: create admin account, register first app, paste store credentials.

### Production

```yaml
# docker-compose.yml
services:
  opencat:
    image: opencat/server:latest
    environment:
      DATABASE_URL: postgres://...
      OPENCAT_SECRET_KEY: ...
    ports:
      - "8080:8080"

  dashboard:
    image: opencat/dashboard:latest
    environment:
      OPENCAT_API_URL: http://opencat:8080
    ports:
      - "3000:3000"
```

Configuration via environment variables. Twelve-factor app principles.

### CLI

The `opencat` binary doubles as a CLI:
- `opencat serve` — start the server
- `opencat migrate` — run database migrations
- `opencat apps list` — manage apps
- `opencat subscribers get <user_id>` — quick subscriber lookup
- `opencat events tail` — stream events in terminal

### SDK Integration (iOS Example)

```swift
OpenCat.configure(
    serverUrl: "https://your-server.com",  // omit for standalone mode
    apiKey: "ocat_...",
    appUserId: currentUser.id
)

if OpenCat.isEntitled("pro") {
    // unlock feature
}

let transaction = try await OpenCat.purchase("monthly_pro")
```

---

## 9. Decision Summary

| Aspect | Decision |
|--------|----------|
| Platforms | Apple App Store + Google Play |
| SDKs | Swift, Kotlin, Flutter |
| SDK modes | Standalone (no server) + Server mode |
| Server | Rust, single binary |
| Database | PostgreSQL + SQLite fallback |
| Apple integration | App Store Server API v2 + Notifications V2 |
| Google integration | Subscriptions v2 API + RTDN via Pub/Sub |
| Dashboard | Separate React/Next.js app, modular & customizable |
| Webhooks | Durable delivery with retry + DLQ + polling fallback |
| Deployment | Docker Compose or single binary |

---

## 10. Explicitly Out of Scope for v1

- A/B testing for paywalls
- Paywall builder / template system
- Revenue forecasting
- User segmentation
- Stripe / web purchases
- Amazon / Huawei app stores
- Family sharing support
- Promotional entitlements
