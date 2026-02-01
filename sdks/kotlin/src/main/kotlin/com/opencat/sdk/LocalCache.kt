package com.opencat.sdk

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

internal class LocalCache(context: Context) {

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    private val prefs: SharedPreferences = try {
        val masterKeyAlias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)
        EncryptedSharedPreferences.create(
            "opencat_cache",
            masterKeyAlias,
            context.applicationContext,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    } catch (_: Exception) {
        // Fallback to regular SharedPreferences if encryption unavailable
        context.applicationContext.getSharedPreferences("opencat_cache", Context.MODE_PRIVATE)
    }

    fun saveCustomerInfo(customerInfo: CustomerInfo) {
        val serialized = json.encodeToString(customerInfo)
        prefs.edit().putString(KEY_CUSTOMER_INFO, serialized).apply()
    }

    fun loadCustomerInfo(): CustomerInfo? {
        val serialized = prefs.getString(KEY_CUSTOMER_INFO, null) ?: return null
        return try {
            json.decodeFromString<CustomerInfo>(serialized)
        } catch (_: Exception) {
            null
        }
    }

    fun clear() {
        prefs.edit().clear().apply()
    }

    companion object {
        private const val KEY_CUSTOMER_INFO = "customer_info"
    }
}
