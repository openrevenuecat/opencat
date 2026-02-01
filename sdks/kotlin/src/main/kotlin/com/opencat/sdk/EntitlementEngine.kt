package com.opencat.sdk

import java.time.Instant
import java.time.format.DateTimeParseException

internal object EntitlementEngine {

    fun isEntitled(customerInfo: CustomerInfo?, entitlementId: String): Boolean {
        val entitlement = customerInfo?.activeEntitlements?.get(entitlementId) ?: return false
        return isActive(entitlement)
    }

    fun isActive(entitlement: EntitlementInfo): Boolean {
        if (!entitlement.isActive) return false
        val expiration = entitlement.expirationDate ?: return true
        return try {
            Instant.parse(expiration).isAfter(Instant.now())
        } catch (_: DateTimeParseException) {
            false
        }
    }

    fun resolveEntitlements(
        purchases: List<TransactionInfo>,
        productEntitlementMap: Map<String, List<String>>,
    ): Map<String, EntitlementInfo> {
        val result = mutableMapOf<String, EntitlementInfo>()

        for (transaction in purchases) {
            val entitlementIds = productEntitlementMap[transaction.productId] ?: continue
            for (entitlementId in entitlementIds) {
                val isActive = when (transaction.status) {
                    TransactionStatus.ACTIVE, TransactionStatus.GRACE_PERIOD, TransactionStatus.BILLING_RETRY -> true
                    TransactionStatus.EXPIRED, TransactionStatus.REFUNDED -> false
                }
                val existing = result[entitlementId]
                if (existing == null || (isActive && !existing.isActive)) {
                    result[entitlementId] = EntitlementInfo(
                        id = entitlementId,
                        isActive = isActive,
                        expirationDate = transaction.expirationDate,
                        productId = transaction.productId,
                        store = "google",
                        willRenew = transaction.status == TransactionStatus.ACTIVE && transaction.expirationDate != null,
                        purchaseDate = transaction.purchaseDate,
                    )
                }
            }
        }

        return result
    }
}
