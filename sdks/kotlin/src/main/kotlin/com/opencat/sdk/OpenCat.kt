package com.opencat.sdk

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.Instant

object OpenCat {

    private var configuration: Configuration? = null
    private var purchaseManager: PurchaseManager? = null
    private var backendConnector: BackendConnector? = null
    private var localCache: LocalCache? = null
    private var customerInfoListeners = mutableListOf<(CustomerInfo) -> Unit>()

    private val mutex = Mutex()

    fun configureStandalone(context: Context, appUserId: String) {
        val config = Configuration.StandaloneConfiguration(context, appUserId)
        setup(config)
    }

    fun configureWithServer(context: Context, serverUrl: String, apiKey: String, appUserId: String) {
        val config = Configuration.ServerConfiguration(context, serverUrl, apiKey, appUserId)
        setup(config)
        backendConnector = BackendConnector(serverUrl, apiKey)
    }

    private fun setup(config: Configuration) {
        configuration = config
        purchaseManager = PurchaseManager(config.context)
        localCache = LocalCache(config.context)
        backendConnector = null
        customerInfoListeners.clear()
    }

    suspend fun purchase(activity: Activity, productId: String): CustomerInfo = mutex.withLock {
        val config = requireConfigured()
        val pm = purchaseManager!!
        val cache = localCache!!

        // Query product details (try subscription first, then in-app)
        var detailsList = pm.queryProductDetails(listOf(productId), BillingClient.ProductType.SUBS)
        if (detailsList.isEmpty()) {
            detailsList = pm.queryProductDetails(listOf(productId), BillingClient.ProductType.INAPP)
        }

        val productDetails = detailsList.firstOrNull()
            ?: throw OpenCatException.PurchaseFailed("Product not found: $productId")

        val purchase = pm.purchase(activity, productDetails)

        // Auto-acknowledge to prevent 3-day auto-refund
        if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED && !purchase.isAcknowledged) {
            pm.acknowledgePurchase(purchase.purchaseToken)
        }

        val customerInfo = when (config) {
            is Configuration.ServerConfiguration -> {
                backendConnector!!.postReceipt(config.appUserId, productId, purchase.purchaseToken)
            }
            is Configuration.StandaloneConfiguration -> {
                buildCustomerInfoFromPurchases(config.appUserId)
            }
        }

        cache.saveCustomerInfo(customerInfo)
        notifyListeners(customerInfo)
        customerInfo
    }

    suspend fun getOfferings(): List<ProductDetails> {
        requireConfigured()
        val pm = purchaseManager!!
        pm.ensureConnected()
        // Return empty list; caller should query specific product IDs via queryProductDetails
        // This is a placeholder -- real implementation would fetch offering config from server or local config
        return emptyList()
    }

    suspend fun restorePurchases(): CustomerInfo = mutex.withLock {
        val config = requireConfigured()
        val pm = purchaseManager!!
        val cache = localCache!!

        val customerInfo = when (config) {
            is Configuration.ServerConfiguration -> {
                val subPurchases = pm.queryPurchases(BillingClient.ProductType.SUBS)
                val inAppPurchases = pm.queryPurchases(BillingClient.ProductType.INAPP)
                val allPurchases = subPurchases + inAppPurchases

                // Acknowledge any unacknowledged purchases
                for (purchase in allPurchases) {
                    if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED && !purchase.isAcknowledged) {
                        pm.acknowledgePurchase(purchase.purchaseToken)
                    }
                }

                val purchaseTokens = allPurchases.map { p ->
                    mapOf(
                        "purchase_token" to p.purchaseToken,
                        "product_id" to (p.products.firstOrNull() ?: ""),
                    )
                }
                backendConnector!!.restorePurchases(config.appUserId, purchaseTokens)
            }
            is Configuration.StandaloneConfiguration -> {
                buildCustomerInfoFromPurchases(config.appUserId)
            }
        }

        cache.saveCustomerInfo(customerInfo)
        notifyListeners(customerInfo)
        customerInfo
    }

    fun isEntitled(entitlementId: String): Boolean {
        val cache = localCache ?: return false
        val customerInfo = cache.loadCustomerInfo() ?: return false
        return EntitlementEngine.isEntitled(customerInfo, entitlementId)
    }

    suspend fun getCustomerInfo(): CustomerInfo = mutex.withLock {
        val config = requireConfigured()
        val cache = localCache!!

        val customerInfo = when (config) {
            is Configuration.ServerConfiguration -> {
                try {
                    val fresh = backendConnector!!.getCustomerInfo(config.appUserId)
                    cache.saveCustomerInfo(fresh)
                    fresh
                } catch (_: OpenCatException.NetworkError) {
                    cache.loadCustomerInfo()
                        ?: throw OpenCatException.NetworkError("No cached data and network unavailable")
                }
            }
            is Configuration.StandaloneConfiguration -> {
                cache.loadCustomerInfo() ?: CustomerInfo(appUserId = config.appUserId)
            }
        }

        customerInfo
    }

    fun onCustomerInfoUpdate(listener: (CustomerInfo) -> Unit) {
        customerInfoListeners.add(listener)
    }

    private fun notifyListeners(customerInfo: CustomerInfo) {
        for (listener in customerInfoListeners) {
            listener(customerInfo)
        }
    }

    private fun requireConfigured(): Configuration {
        return configuration ?: throw OpenCatException.NotConfigured()
    }

    private suspend fun buildCustomerInfoFromPurchases(appUserId: String): CustomerInfo {
        val pm = purchaseManager!!
        val subPurchases = pm.queryPurchases(BillingClient.ProductType.SUBS)
        val inAppPurchases = pm.queryPurchases(BillingClient.ProductType.INAPP)
        val allPurchases = subPurchases + inAppPurchases

        // Acknowledge unacknowledged purchases
        for (purchase in allPurchases) {
            if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED && !purchase.isAcknowledged) {
                pm.acknowledgePurchase(purchase.purchaseToken)
            }
        }

        val transactions = allPurchases.map { purchase ->
            val productId = purchase.products.firstOrNull() ?: ""
            TransactionInfo(
                transactionId = purchase.orderId ?: purchase.purchaseToken,
                productId = productId,
                purchaseDate = Instant.ofEpochMilli(purchase.purchaseTime).toString(),
                expirationDate = null,
                status = when (purchase.purchaseState) {
                    Purchase.PurchaseState.PURCHASED -> TransactionStatus.ACTIVE
                    else -> TransactionStatus.EXPIRED
                },
            )
        }

        val entitlements = mutableMapOf<String, EntitlementInfo>()
        for (transaction in transactions) {
            if (transaction.status == TransactionStatus.ACTIVE) {
                entitlements[transaction.productId] = EntitlementInfo(
                    id = transaction.productId,
                    isActive = true,
                    expirationDate = transaction.expirationDate,
                    productId = transaction.productId,
                    store = "google",
                    willRenew = false,
                    purchaseDate = transaction.purchaseDate,
                )
            }
        }

        return CustomerInfo(
            appUserId = appUserId,
            activeEntitlements = entitlements,
            allTransactions = transactions,
            firstSeenAt = Instant.now().toString(),
        )
    }
}

sealed class OpenCatException(message: String, cause: Throwable? = null) : Exception(message, cause) {
    class PurchaseCancelled : OpenCatException("Purchase was cancelled by the user")
    class PurchaseFailed(message: String) : OpenCatException(message)
    class NetworkError(message: String, cause: Throwable? = null) : OpenCatException(message, cause)
    class StoreError(val code: Int, val debugMessage: String) : OpenCatException("Store error $code: $debugMessage")
    class NotConfigured : OpenCatException("OpenCat SDK is not configured. Call configureStandalone() or configureWithServer() first.")
}
