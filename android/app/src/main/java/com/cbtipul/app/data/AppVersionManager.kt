package com.cbtipul.app.data

import android.content.Context
import android.util.Log
import com.cbtipul.app.BuildConfig
import io.ktor.client.HttpClient
import io.ktor.client.engine.okhttp.OkHttp
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.request.post
import io.ktor.client.request.header
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.net.URI

@Serializable
data class AppVersionPolicy(val platform: String, val latestBuild: Long, val minimumBuild: Long,
    val latestVersion: String, val storeUrl: String) {
    fun valid(platform: String): Boolean = this.platform == platform && latestBuild > 0 && minimumBuild > 0 &&
        minimumBuild <= latestBuild && runCatching {
            val url = URI(storeUrl)
            url.scheme.equals("https", true) && !url.host.isNullOrBlank() && url.userInfo == null
        }.getOrDefault(false)
}

enum class AppVersionDecision { Current, Optional, Required;
    companion object {
        fun evaluate(installed: Long, policy: AppVersionPolicy, platform: String): AppVersionDecision = when {
            installed <= 0 || !policy.valid(platform) -> Current
            installed < policy.minimumBuild -> Required
            installed < policy.latestBuild -> Optional
            else -> Current
        }
    }
}

data class AppVersionState(val checkingInitially: Boolean = true,
    val decision: AppVersionDecision = AppVersionDecision.Current,
    val policy: AppVersionPolicy? = null, val optionalVisible: Boolean = false)

class AppVersionManager(
    private val installed: Long,
    private val fetch: suspend (String) -> AppVersionPolicy,
    private val readDismissed: () -> Long,
    private val saveDismissed: (Long) -> Unit,
    private val now: () -> Long = System::currentTimeMillis,
    private val logFailure: () -> Unit = {},
) {
    private val mutable = MutableStateFlow(AppVersionState())
    val state = mutable.asStateFlow()
    private val mutex = Mutex()
    private var lastSuccess: Long? = null
    private var lastAttempt: Long? = null

    suspend fun check(coldLaunch: Boolean = false) {
        if (!mutex.tryLock()) return
        try {
            val date = now()
            if (!coldLaunch && mutable.value.decision != AppVersionDecision.Required) {
                if (lastSuccess?.let { date - it < REFRESH_MS } == true) return
                if (lastAttempt?.let { date - it < 60_000 } == true) return
            }
            lastAttempt = date
            if (installed <= 0) { failOpen(); return }
            try {
                val policy = withTimeout(TIMEOUT_MS) { fetch("android") }
                if (!policy.valid("android")) { failOpen(); return }
                val decision = AppVersionDecision.evaluate(installed, policy, "android")
                mutable.value = AppVersionState(false, decision, policy,
                    decision == AppVersionDecision.Optional && readDismissed() != policy.latestBuild)
                lastSuccess = now()
            } catch (_: TimeoutCancellationException) {
                failOpen()
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Exception) {
                failOpen()
            }
        } finally { mutex.unlock() }
    }

    fun dismissOptional() {
        val current = mutable.value
        if (current.decision != AppVersionDecision.Optional) return
        current.policy?.let { saveDismissed(it.latestBuild) }
        mutable.value = current.copy(optionalVisible = false)
    }

    private fun failOpen() {
        mutable.value = AppVersionState(checkingInitially = false)
        logFailure()
    }

    companion object {
        const val TIMEOUT_MS = 4_000L
        const val REFRESH_MS = 6 * 60 * 60 * 1_000L
        const val DISMISSAL_KEY = "dismissedOptionalUpdateBuild"
        fun create(context: Context): AppVersionManager {
            val preferences = context.getSharedPreferences("app_version_policy", Context.MODE_PRIVATE)
            return AppVersionManager(BuildConfig.VERSION_CODE.toLong(), AppVersionService::fetch,
                { preferences.getLong(DISMISSAL_KEY, 0) },
                { preferences.edit().putLong(DISMISSAL_KEY, it).apply() },
                logFailure = { Log.w("AppVersion", "Version policy unavailable or invalid; continuing normally") })
        }
    }
}

object AppVersionService {
    private val json = Json { ignoreUnknownKeys = true }
    private val client = HttpClient(OkHttp) {
        install(HttpTimeout) {
            requestTimeoutMillis = AppVersionManager.TIMEOUT_MS
            connectTimeoutMillis = AppVersionManager.TIMEOUT_MS
            socketTimeoutMillis = AppVersionManager.TIMEOUT_MS
        }
    }
    fun requestBody(platform: String) = json.encodeToString(mapOf("platform" to platform))
    suspend fun fetch(platform: String): AppVersionPolicy {
        val response = client.post("${SupabaseConfig.URL}/functions/v1/get-app-version-policy") {
            header("Content-Type", "application/json")
            header("apikey", SupabaseConfig.ANON_KEY)
            setBody(requestBody(platform))
        }
        check(response.status.value in 200..299)
        return json.decodeFromString<AppVersionPolicy>(response.bodyAsText())
    }
}
