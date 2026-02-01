package com.opencat.sdk

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class CustomerInfo(
    @SerialName("app_user_id") val appUserId: String,
    @SerialName("active_entitlements") val activeEntitlements: Map<String, EntitlementInfo> = emptyMap(),
    @SerialName("all_transactions") val allTransactions: List<TransactionInfo> = emptyList(),
    @SerialName("first_seen_at") val firstSeenAt: String? = null,
)

@Serializable
data class EntitlementInfo(
    val id: String,
    @SerialName("is_active") val isActive: Boolean,
    @SerialName("expiration_date") val expirationDate: String? = null,
    @SerialName("product_id") val productId: String,
    val store: String = "google",
    @SerialName("will_renew") val willRenew: Boolean = false,
    @SerialName("purchase_date") val purchaseDate: String,
)

@Serializable
data class TransactionInfo(
    @SerialName("transaction_id") val transactionId: String,
    @SerialName("product_id") val productId: String,
    @SerialName("purchase_date") val purchaseDate: String,
    @SerialName("expiration_date") val expirationDate: String? = null,
    val status: TransactionStatus = TransactionStatus.ACTIVE,
)

@Serializable
enum class TransactionStatus {
    @SerialName("active") ACTIVE,
    @SerialName("expired") EXPIRED,
    @SerialName("refunded") REFUNDED,
    @SerialName("grace_period") GRACE_PERIOD,
    @SerialName("billing_retry") BILLING_RETRY,
}
