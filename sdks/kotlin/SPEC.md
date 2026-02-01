# OpenCat Android/Kotlin SDK Spec

## Reference
Port the Swift SDK: `sdks/swift/Sources/OpenCat/`

## Architecture
Mirror the Swift SDK 1:1:

| Swift File | Kotlin Equivalent |
|------------|-------------------|
| OpenCat.swift | OpenCat.kt (singleton, public API) |
| Configuration.swift | Configuration.kt (StandaloneConfig, ServerConfig) |
| CustomerInfo.swift | CustomerInfo.kt (data classes) |
| BackendConnector.swift | BackendConnector.kt (HTTP client + ProductOffering) |
| PurchaseManager.swift | PurchaseManager.kt (wraps Google Play Billing) |
| EntitlementEngine.swift | EntitlementEngine.kt (resolve from Play purchases) |
| LocalCache.swift | LocalCache.kt (SharedPreferences/EncryptedSharedPreferences) |

## Dependencies
- `com.android.billingclient:billing-ktx` (Google Play Billing Library 6+)
- `com.squareup.okhttp3:okhttp` or `io.ktor:ktor-client`
- `org.jetbrains.kotlinx:kotlinx-serialization-json`
- `org.jetbrains.kotlinx:kotlinx-coroutines-core`

## Public API (match Swift exactly)
```kotlin
object OpenCat {
    fun configureStandalone(context: Context, appUserId: String)
    fun configureWithServer(context: Context, serverUrl: String, apiKey: String, appUserId: String, appId: String = "")
    suspend fun getOfferings(productIds: List<String> = emptyList()): List<ProductOffering>
    suspend fun purchase(activity: Activity, productId: String): TransactionInfo
    suspend fun restorePurchases(): CustomerInfo
    fun isEntitled(entitlementId: String): Boolean
    suspend fun getCustomerInfo(): CustomerInfo
    fun onCustomerInfoUpdate(listener: (CustomerInfo) -> Unit)
    fun setLogLevel(level: LogLevel)
}
```

## ProductOffering
```kotlin
@Serializable
data class ProductOffering(
    val storeProductId: String,
    val productType: String,
    val displayName: String,
    val description: String?,
    val priceMicros: Long,
    val currency: String,
    val subscriptionPeriod: String?,
    val trialPeriod: String?,
    val entitlements: List<String>,
    @Transient var productDetails: ProductDetails? = null
) {
    val price: BigDecimal get() = BigDecimal(priceMicros).divide(BigDecimal(1_000_000))
    val displayPrice: String get() = NumberFormat.getCurrencyInstance().apply { currency = Currency.getInstance(this@ProductOffering.currency) }.format(price)
}
```

## Server endpoints used
- `POST /v1/receipts` — send purchase token
- `GET /v1/customers/{appUserId}` — get customer info
- `GET /v1/apps/{appId}/offerings` — get product offerings

## Packaging
- Publish as Maven artifact: `dev.opencat:opencat-android`
- Min SDK: 24
- Target SDK: 34
