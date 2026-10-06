package com.cbtipul.app.data

import com.cbtipul.app.debug.InviteDebugLog
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable

@Serializable
enum class AppRole {
    @kotlinx.serialization.SerialName("therapist") Therapist,
    @kotlinx.serialization.SerialName("patient") Patient,
}

@Serializable
enum class PatientActivation {
    @kotlinx.serialization.SerialName("active") Active,
    @kotlinx.serialization.SerialName("incomplete") Incomplete,
}

@Serializable
data class AppContext(
    val version: Int = 1,
    val role: AppRole,
    val activation: PatientActivation? = null,
    val patientId: String? = null,
    @Serializable(with = LenientEntitlementSerializer::class) val entitlement: AppEntitlement? = null,
) {
    val isActivePatient: Boolean
        get() = role == AppRole.Patient && activation == PatientActivation.Active && !patientId.isNullOrBlank()

    val isIncompletePatient: Boolean
        get() = role == AppRole.Patient && activation == PatientActivation.Incomplete
}

class AppContextRepository(private val client: SupabaseClient) {
    private val refreshMutex = Mutex()
    private var generation = 0L
    private var lastRefresh = 0L
    private var account: String? = null
    private val _current = MutableStateFlow<AppContext?>(null)
    val current: StateFlow<AppContext?> = _current.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    suspend fun getCurrentAppContext(): AppContext = refreshMutex.withLock { fetchCurrentAppContext() }

    private suspend fun fetchCurrentAppContext(): AppContext {
        if (!SupabaseConfig.isConfigured) throw IllegalStateException("not_configured")
        client.auth.awaitInitialization()
        val identity = client.auth.currentSessionOrNull()?.user?.id ?: throw IllegalStateException("not_signed_in")
        val requestGeneration = generation
        if (account != identity) { _current.value = null; lastRefresh = 0; account = identity }
        Entitlements.setIdentity(identity)
        _isLoading.value = true
        return try {
            suspend fun request(): AppContext {
                val http = client.functions.invoke(
                    function = "get-app-context",
                    headers = Headers.build {
                        append(HttpHeaders.ContentType, ContentType.Application.Json.toString())
                    },
                )
                return EdgePayload.json.decodeFromString(AppContext.serializer(), http.bodyAsText())
            }
            val context = try {
                request()
            } catch (error: Exception) {
                if (error is CancellationException || EdgePayload.httpStatus(error) != 401) throw error
                // The restored session may no longer be accepted by the server. Refresh once.
                if (identity != client.auth.currentSessionOrNull()?.user?.id || requestGeneration != generation) throw CancellationException()
                client.auth.refreshCurrentSession()
                if (identity != client.auth.currentSessionOrNull()?.user?.id || requestGeneration != generation) throw CancellationException()
                request()
            }
            if (identity != client.auth.currentSessionOrNull()?.user?.id || identity != account || requestGeneration != generation) throw CancellationException()
            _current.value = context
            lastRefresh = System.currentTimeMillis()
            Entitlements.apply(context)
            runCatching { InviteDebugLog.d("get-app-context resolved: role=${context.role}, access=${context.entitlement?.access ?: "unknown"}") }
            context
        } catch (error: CancellationException) {
            throw error
        } catch (error: Exception) {
            if (requestGeneration == generation && identity == account && identity == client.auth.currentSessionOrNull()?.user?.id) Entitlements.invalidate()
            runCatching { InviteDebugLog.e("get-app-context", error) }
            throw error
        } finally {
            if (requestGeneration == generation) _isLoading.value = false
        }
    }

    suspend fun refreshOnForeground() {
        if (client.auth.currentSessionOrNull() == null || _isLoading.value || System.currentTimeMillis() - lastRefresh < 60_000) return
        runCatching { getCurrentAppContext() }
    }
    fun clear() {
        generation++
        account = null; lastRefresh = 0
        Entitlements.clear()
        _current.value = null
        _isLoading.value = false
    }
}
