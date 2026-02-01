package com.opencat.sdk

import android.content.Context

sealed class Configuration {
    abstract val context: Context
    abstract val appUserId: String

    data class StandaloneConfiguration(
        override val context: Context,
        override val appUserId: String,
    ) : Configuration()

    data class ServerConfiguration(
        override val context: Context,
        val serverUrl: String,
        val apiKey: String,
        override val appUserId: String,
    ) : Configuration()
}
