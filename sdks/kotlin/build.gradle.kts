plugins {
    id("com.android.library") version "8.2.0"
    kotlin("android") version "1.9.22"
    kotlin("plugin.serialization") version "1.9.22"
}

group = "com.opencat"
version = "0.1.0"

android {
    namespace = "com.opencat.sdk"
    compileSdk = 34

    defaultConfig {
        minSdk = 24
        consumerProguardFiles("consumer-rules.pro")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    // Google Play Billing Library 7
    implementation("com.android.billingclient:billing-ktx:7.0.0")

    // Kotlin Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.0")

    // Serialization
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")

    // OkHttp for server mode
    implementation("com.squareup.okhttp3:okhttp:4.12.0")

    // EncryptedSharedPreferences
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
}
