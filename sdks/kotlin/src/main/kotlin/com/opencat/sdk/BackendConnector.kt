package com.opencat.sdk

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.util.concurrent.TimeUnit

internal class BackendConnector(
    private val serverUrl: String,
    private val apiKey: String,
) {
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private val jsonMediaType = "application/json".toMediaType()

    suspend fun getCustomerInfo(appUserId: String): CustomerInfo = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url("$serverUrl/v1/subscribers/$appUserId")
            .addHeader("Authorization", "Bearer $apiKey")
            .get()
            .build()

        execute(request)
    }

    suspend fun postReceipt(appUserId: String, productId: String, purchaseToken: String): CustomerInfo =
        withContext(Dispatchers.IO) {
            val body = json.encodeToString(
                mapOf(
                    "app_user_id" to appUserId,
                    "store" to "google",
                    "product_id" to productId,
                    "receipt_data" to purchaseToken,
                )
            )
            val request = Request.Builder()
                .url("$serverUrl/v1/receipts")
                .addHeader("Authorization", "Bearer $apiKey")
                .post(body.toRequestBody(jsonMediaType))
                .build()

            execute(request)
        }

    suspend fun restorePurchases(appUserId: String, purchaseTokens: List<Map<String, String>>): CustomerInfo =
        withContext(Dispatchers.IO) {
            val body = json.encodeToString(
                mapOf(
                    "app_user_id" to appUserId,
                    "store" to "google",
                    "purchases" to purchaseTokens.map { it.toString() },
                )
            )
            val request = Request.Builder()
                .url("$serverUrl/v1/subscribers/$appUserId/restore")
                .addHeader("Authorization", "Bearer $apiKey")
                .post(body.toRequestBody(jsonMediaType))
                .build()

            execute(request)
        }

    private inline fun <reified T> execute(request: Request): T {
        val response = try {
            client.newCall(request).execute()
        } catch (e: IOException) {
            throw OpenCatException.NetworkError(e.message ?: "Network error", e)
        }

        val responseBody = response.body?.string() ?: ""

        if (!response.isSuccessful) {
            throw OpenCatException.NetworkError("HTTP ${response.code}: $responseBody")
        }

        return try {
            json.decodeFromString<T>(responseBody)
        } catch (e: Exception) {
            throw OpenCatException.NetworkError("Failed to parse response: ${e.message}", e)
        }
    }
}
