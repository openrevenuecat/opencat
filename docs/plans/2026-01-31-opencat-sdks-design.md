# OpenCat SDKs Design

> Client SDKs for iOS (Swift), Android (Kotlin), and Flutter (Dart).

## Architecture

All three SDKs share the same layered architecture:

```
┌─────────────────────────────┐
│       Public API Layer      │  ← Developer-facing: configure, purchase, isEntitled
├─────────────────────────────┤
│      Entitlement Engine     │  ← Resolves "does user have access to X?"
├─────────────────────────────┤
│       Purchase Manager      │  ← Wraps StoreKit 2 / Play Billing / in_app_purchase
├─────────────────────────────┤
│      Backend Connector      │  ← Talks to OpenCat server (or nil in standalone)
├─────────────────────────────┤
│        Local Cache          │  ← Encrypted on-device storage for CustomerInfo
└─────────────────────────────┘
```

All three SDKs are fully independent. No cross-dependencies. Flutter SDK is pure Dart (no platform channels to native SDKs).

## Two Explicit Modes

```swift
// Standalone — no server, on-device only
OpenCat.configureStandalone(appUserId: "user_123")

// Server mode — full features
OpenCat.configureWithServer(serverUrl: "https://...", apiKey: "ocat_...", appUserId: "user_123")
```

Separate entry points prevent misconfiguration. The two modes have fundamentally different architectures:

- **Standalone**: SDK validates receipts directly with Apple/Google, stores state on-device only. No cross-device sync, no dashboard data.
- **Server mode**: SDK sends receipts to OpenCat server, server is source of truth. Cache used for offline access.

After configuration, the rest of the API is identical regardless of mode.

## Data Models

```
CustomerInfo
  ├── appUserId: String
  ├── activeEntitlements: Map<String, EntitlementInfo>
  ├── allTransactions: List<TransactionInfo>
  └── firstSeenAt: DateTime

EntitlementInfo
  ├── id: String
  ├── isActive: Bool
  ├── expirationDate: DateTime?
  ├── productId: String
  ├── store: apple | google
  ├── willRenew: Bool
  └── purchaseDate: DateTime

TransactionInfo
  ├── transactionId: String
  ├── productId: String
  ├── purchaseDate: DateTime
  ├── expirationDate: DateTime?
  └── status: active | expired | refunded | grace_period | billing_retry
```

---

## Swift SDK (iOS)

**Package:** Swift Package Manager (SPM). No CocoaPods/Carthage.

**Minimum target:** iOS 15+ (StoreKit 2 requirement)

**Store interaction:** StoreKit 2 directly. No StoreKit 1 fallback.

**Public API:**

```swift
OpenCat.configureStandalone(appUserId: "user_123")
OpenCat.configureWithServer(serverUrl: "https://...", apiKey: "ocat_...", appUserId: "user_123")

let offerings = try await OpenCat.getOfferings()
let transaction = try await OpenCat.purchase("monthly_pro")
let customerInfo = try await OpenCat.restorePurchases()

let isPro = OpenCat.isEntitled("pro")
let customerInfo = try await OpenCat.getCustomerInfo()

OpenCat.onCustomerInfoUpdate { customerInfo in }
```

**Implementation details:**

- All public methods are `async/await`
- `Transaction.updates` listener for renewals/revocations
- `isEntitled()` is synchronous — reads from cache
- Cache in Keychain (encrypted, survives reinstall)
- Standalone uses `Transaction.currentEntitlements`
- Server mode posts `Transaction.jwsRepresentation`

**Project structure:**

```
sdks/swift/
├── Package.swift
├── Sources/OpenCat/
│   ├── OpenCat.swift
│   ├── Configuration.swift
│   ├── CustomerInfo.swift
│   ├── EntitlementEngine.swift
│   ├── PurchaseManager.swift
│   ├── BackendConnector.swift
│   └── LocalCache.swift
└── Tests/OpenCatTests/
```

---

## Kotlin SDK (Android)

**Package:** Maven Central. Gradle dependency.

**Minimum target:** Android API 24 (Android 7.0)

**Store interaction:** Google Play Billing Library 7.

**Public API:**

```kotlin
OpenCat.configureStandalone(context, appUserId = "user_123")
OpenCat.configureWithServer(context, serverUrl = "https://...", apiKey = "ocat_...", appUserId = "user_123")

val offerings = OpenCat.getOfferings()
val transaction = OpenCat.purchase(activity, "monthly_pro")
val customerInfo = OpenCat.restorePurchases()

val isPro = OpenCat.isEntitled("pro")
val customerInfo = OpenCat.getCustomerInfo()

OpenCat.onCustomerInfoUpdate { customerInfo -> }
```

**Implementation details:**

- All public methods are `suspend` functions (Kotlin coroutines)
- `purchase()` requires `Activity` parameter (Play Billing requirement)
- `isEntitled()` is synchronous — reads from cache
- Cache in `EncryptedSharedPreferences`
- Auto-acknowledges purchases after verification (prevents 3-day auto-refund)
- Standalone uses `BillingClient.queryPurchasesAsync()`
- Server mode posts purchase tokens
- `BillingClient` auto-reconnects on disconnect

**Project structure:**

```
sdks/kotlin/
├── build.gradle.kts
├── settings.gradle.kts
├── opencat/
│   ├── build.gradle.kts
│   └── src/main/kotlin/dev/opencat/sdk/
│       ├── OpenCat.kt
│       ├── Configuration.kt
│       ├── CustomerInfo.kt
│       ├── EntitlementEngine.kt
│       ├── PurchaseManager.kt
│       ├── BackendConnector.kt
│       └── LocalCache.kt
└── opencat/src/test/kotlin/dev/opencat/sdk/
```

---

## Flutter SDK (Dart)

**Package:** pub.dev. Pure Dart — no platform channels.

**Minimum target:** Flutter 3.10+, Dart 3.0+

**Store interaction:** `in_app_purchase` official Flutter plugin.

**Public API:**

```dart
OpenCat.configureStandalone(appUserId: 'user_123');
OpenCat.configureWithServer(serverUrl: 'https://...', apiKey: 'ocat_...', appUserId: 'user_123');

final offerings = await OpenCat.getOfferings();
final transaction = await OpenCat.purchase('monthly_pro');
final customerInfo = await OpenCat.restorePurchases();

final isPro = OpenCat.isEntitled('pro');
final customerInfo = await OpenCat.getCustomerInfo();

OpenCat.customerInfoStream.listen((customerInfo) { });
```

**Implementation details:**

- Async methods return `Future<T>`
- Real-time updates as `Stream<CustomerInfo>`
- `isEntitled()` is synchronous — reads from cache
- Cache via `flutter_secure_storage`
- `in_app_purchase` handles platform differences
- Standalone uses `InAppPurchase.instance.restorePurchases()`
- Server mode posts platform-specific receipt data
- Offerings cached between launches with staleness check

**Project structure:**

```
sdks/flutter/
├── pubspec.yaml
├── lib/
│   ├── opencat.dart
│   └── src/
│       ├── configuration.dart
│       ├── customer_info.dart
│       ├── entitlement_engine.dart
│       ├── purchase_manager.dart
│       ├── backend_connector.dart
│       └── local_cache.dart
├── test/
└── example/
```

---

## Shared Behavior

**Offline:**
- `isEntitled()` always works offline — reads from cache
- `getCustomerInfo()` returns cached data if offline, fetches fresh if online
- `purchase()` works offline (stores handle this) — receipt syncs to server on reconnect
- Offerings cached between launches with 24-hour staleness window
- Entitlements respect actual `expiration_date` — no arbitrary offline timeout

**Error types (all SDKs):**
- `PurchaseCancelled` — user dismissed purchase dialog
- `PurchaseFailed` — store rejected purchase
- `NetworkError` — couldn't reach OpenCat server (server mode)
- `StoreError` — underlying store SDK error
- `NotConfigured` — SDK methods called before `configure()`

Errors are typed, not string-based. Each platform uses idiomatic error patterns.

**Logging:**
- Off by default
- `OpenCat.setLogLevel(.debug)` to enable
- Logs purchase flow, cache hits/misses, server communication
- Never logs receipt data or API keys

**Thread safety:**
- Public API safe to call from any thread/coroutine/isolate
- Swift: actors. Kotlin: Mutex. Dart: zones.

---

## Decision Summary

| Aspect | Decision |
|--------|----------|
| Independence | All three SDKs fully independent |
| Flutter approach | Pure Dart via `in_app_purchase` plugin |
| Configuration | Explicit separate entry points per mode |
| Swift store | StoreKit 2 only, iOS 15+ |
| Kotlin store | Play Billing Library 7, API 24+ |
| Flutter store | `in_app_purchase` official plugin |
| Swift distribution | SPM |
| Kotlin distribution | Maven Central |
| Flutter distribution | pub.dev |
| Async model | Swift async/await, Kotlin coroutines, Dart Futures/Streams |
| Cache | Keychain (iOS), EncryptedSharedPreferences (Android), flutter_secure_storage (Flutter) |
