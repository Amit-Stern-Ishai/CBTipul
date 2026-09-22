plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

import java.util.Properties

// Load ~/.gradle/gradle.properties explicitly so signing works even when
// GRADLE_USER_HOME is redirected (e.g. CI/agent sandboxes). Never commit secrets.
val homeGradleProperties = Properties().apply {
    val file = file("${System.getProperty("user.home")}/.gradle/gradle.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}

fun signingValue(propertyName: String, envName: String): String? {
    val fromGradle = providers.gradleProperty(propertyName).orNull?.takeIf { it.isNotBlank() }
    val fromHome = homeGradleProperties.getProperty(propertyName)?.takeIf { it.isNotBlank() }
    val fromEnv = providers.environmentVariable(envName).orNull?.takeIf { it.isNotBlank() }
    return fromGradle ?: fromHome ?: fromEnv
}

android {
    namespace = "com.cbtipul.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.CBTipul.app"
        minSdk = 26
        targetSdk = 36
        versionCode = 2
        versionName = "1.0.1"
        androidResources {
            localeFilters += listOf("iw")
        }
    }

    signingConfigs {
        create("release") {
            val storePath = signingValue("cbtipul.storeFile", "CBTIPUL_STORE_FILE")
            val storePass = signingValue("cbtipul.storePassword", "CBTIPUL_STORE_PASSWORD")
            val alias = signingValue("cbtipul.keyAlias", "CBTIPUL_KEY_ALIAS")
            val keyPass = signingValue("cbtipul.keyPassword", "CBTIPUL_KEY_PASSWORD")
            if (storePath != null && storePass != null && alias != null && keyPass != null) {
                storeFile = file(storePath)
                storePassword = storePass
                keyAlias = alias
                keyPassword = keyPass
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfig = signingConfigs.getByName("release")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            optIn.add("io.github.jan.supabase.annotations.SupabaseInternal")
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2025.01.00")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.datastore:datastore-preferences:1.1.2")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation(platform("io.github.jan-tennert.supabase:bom:3.2.2"))
    implementation("io.github.jan-tennert.supabase:auth-kt")
    implementation("io.github.jan-tennert.supabase:postgrest-kt")
    implementation("io.github.jan-tennert.supabase:functions-kt")
    implementation("io.ktor:ktor-client-okhttp:3.1.1")
    implementation(platform("com.google.firebase:firebase-bom:33.12.0"))
    implementation("com.google.firebase:firebase-messaging")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.10.1")
    implementation("androidx.navigation:navigation-compose:2.8.5")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.1")
    debugImplementation("androidx.compose.ui:ui-tooling")
}

if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
