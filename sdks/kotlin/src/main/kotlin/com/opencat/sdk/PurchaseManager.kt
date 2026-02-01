package com.opencat.sdk

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

internal class PurchaseManager(context: Context) {

    private val mutex = Mutex()
    private var pendingPurchaseCallback: ((Result<Purchase>) -> Unit)? = null

    private val purchasesUpdatedListener = PurchasesUpdatedListener { billingResult, purchases ->
        val callback = pendingPurchaseCallback
        pendingPurchaseCallback = null

        when (billingResult.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                val purchase = purchases?.firstOrNull()
                if (purchase != null) {
                    callback?.invoke(Result.success(purchase))
                } else {
                    callback?.invoke(Result.failure(OpenCatException.PurchaseFailed("No purchase returned")))
                }
            }
            BillingClient.BillingResponseCode.USER_CANCELED -> {
                callback?.invoke(Result.failure(OpenCatException.PurchaseCancelled()))
            }
            else -> {
                callback?.invoke(Result.failure(
                    OpenCatException.StoreError(billingResult.responseCode, billingResult.debugMessage)
                ))
            }
        }
    }

    private val billingClient: BillingClient = BillingClient.newBuilder(context.applicationContext)
        .setListener(purchasesUpdatedListener)
        .enablePendingPurchases()
        .build()

    suspend fun ensureConnected() {
        if (billingClient.isReady) return
        suspendCancellableCoroutine { cont ->
            billingClient.startConnection(object : BillingClientStateListener {
                override fun onBillingSetupFinished(billingResult: BillingResult) {
                    if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                        cont.resume(Unit)
                    } else {
                        cont.resumeWithException(
                            OpenCatException.StoreError(billingResult.responseCode, billingResult.debugMessage)
                        )
                    }
                }

                override fun onBillingServiceDisconnected() {
                    // Auto-reconnect will happen on next ensureConnected() call
                }
            })
        }
    }

    suspend fun queryProductDetails(productIds: List<String>, type: String = BillingClient.ProductType.SUBS): List<ProductDetails> {
        ensureConnected()
        val productList = productIds.map { id ->
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(id)
                .setProductType(type)
                .build()
        }
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(productList)
            .build()

        return suspendCancellableCoroutine { cont ->
            billingClient.queryProductDetailsAsync(params) { billingResult, detailsList ->
                if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    cont.resume(detailsList)
                } else {
                    cont.resumeWithException(
                        OpenCatException.StoreError(billingResult.responseCode, billingResult.debugMessage)
                    )
                }
            }
        }
    }

    suspend fun purchase(activity: Activity, productDetails: ProductDetails): Purchase = mutex.withLock {
        ensureConnected()

        val offerToken = productDetails.subscriptionOfferDetails?.firstOrNull()?.offerToken

        val productDetailsParamsBuilder = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(productDetails)

        if (offerToken != null) {
            productDetailsParamsBuilder.setOfferToken(offerToken)
        }

        val flowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(productDetailsParamsBuilder.build()))
            .build()

        return suspendCancellableCoroutine { cont ->
            pendingPurchaseCallback = { result ->
                result.fold(
                    onSuccess = { cont.resume(it) },
                    onFailure = { cont.resumeWithException(it) },
                )
            }

            val result = billingClient.launchBillingFlow(activity, flowParams)
            if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                pendingPurchaseCallback = null
                cont.resumeWithException(
                    OpenCatException.StoreError(result.responseCode, result.debugMessage)
                )
            }
        }
    }

    suspend fun queryPurchases(type: String = BillingClient.ProductType.SUBS): List<Purchase> {
        ensureConnected()
        val params = QueryPurchasesParams.newBuilder()
            .setProductType(type)
            .build()

        return suspendCancellableCoroutine { cont ->
            billingClient.queryPurchasesAsync(params) { billingResult, purchasesList ->
                if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    cont.resume(purchasesList)
                } else {
                    cont.resumeWithException(
                        OpenCatException.StoreError(billingResult.responseCode, billingResult.debugMessage)
                    )
                }
            }
        }
    }

    suspend fun acknowledgePurchase(purchaseToken: String) {
        ensureConnected()
        val params = AcknowledgePurchaseParams.newBuilder()
            .setPurchaseToken(purchaseToken)
            .build()

        suspendCancellableCoroutine { cont ->
            billingClient.acknowledgePurchase(params) { billingResult ->
                if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    cont.resume(Unit)
                } else {
                    cont.resumeWithException(
                        OpenCatException.StoreError(billingResult.responseCode, billingResult.debugMessage)
                    )
                }
            }
        }
    }

    fun destroy() {
        if (billingClient.isReady) {
            billingClient.endConnection()
        }
    }
}
