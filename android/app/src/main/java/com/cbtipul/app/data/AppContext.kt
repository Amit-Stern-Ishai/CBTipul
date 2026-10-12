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
import kotlinx.coroutines.delay
import kotlinx.coroutines.withTimeoutOrNull
import java.io.IOException
import io.ktor.client.plugins.HttpRequestTimeoutException
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

internal data class AppContextDependencies(
    val awaitInitialization: suspend () -> Unit,
    val identity: () -> String?,
    val request: suspend () -> AppContext,
    val refreshSession: suspend () -> Unit,
    val nowMillis: () -> Long = System::currentTimeMillis,
    val timeoutMillis: Long = 8_000,
    val retryDelaysMillis: List<Long> = listOf(500, 1_500),
)

sealed interface AppContextLoadState {
    data object Unresolved : AppContextLoadState
    data class Loading(val attempt: Int) : AppContextLoadState
    data object Ready : AppContextLoadState
    data class Failed(val reason: AppContextFailure) : AppContextLoadState
}
enum class AppContextFailure { SessionInitialization, Connection, ServerResponse, MissingEntitlement }
private class ContextRequestTimeout : IOException()
private class ContextInitializationTimeout : Exception()

class AppContextRepository internal constructor(private val dependencies: AppContextDependencies) {
    constructor(client: SupabaseClient) : this(AppContextDependencies(
        awaitInitialization = { client.auth.awaitInitialization() },
        identity = { client.auth.currentSessionOrNull()?.user?.id },
        request = {
            if (!SupabaseConfig.isConfigured) throw IllegalStateException("not_configured")
            val http = client.functions.invoke(
                function = "get-app-context",
                headers = Headers.build { append(HttpHeaders.ContentType, ContentType.Application.Json.toString()) },
            )
            EdgePayload.json.decodeFromString(AppContext.serializer(), http.bodyAsText())
        },
        refreshSession = { client.auth.refreshCurrentSession() },
    ))
    private val refreshMutex = Mutex()
    private var generation = 0L
    private var lastRefresh = 0L
    private var account: String? = null
    private val _current = MutableStateFlow<AppContext?>(null)
    val current: StateFlow<AppContext?> = _current.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()
    private val _loadState = MutableStateFlow<AppContextLoadState>(AppContextLoadState.Unresolved)
    val loadState: StateFlow<AppContextLoadState> = _loadState.asStateFlow()
    internal val boundIdentity: String? get() = account

    suspend fun getCurrentAppContext(): AppContext = refreshMutex.withLock { fetchCurrentAppContext() }

    /** Called on real auth changes, including same-account reauthentication. */
    internal fun authenticationChanged(identity: String?) {
        clear()
        account = identity
        Entitlements.setIdentity(identity)
    }

    private fun ensureCurrent(identity: String?, requestGeneration: Long) {
        if (requestGeneration != generation || identity != dependencies.identity()) throw CancellationException()
    }

    private suspend fun fetchCurrentAppContext(): AppContext {
        val requestGeneration = generation
        var identity: String? = null
        _isLoading.value = true
        _loadState.value = AppContextLoadState.Loading(1)
        return try {
            val initialized = withTimeoutOrNull(dependencies.timeoutMillis) { dependencies.awaitInitialization(); true }
            if (initialized != true) throw ContextInitializationTimeout()
            if (requestGeneration != generation) throw CancellationException()
            identity = dependencies.identity() ?: throw IllegalStateException("not_signed_in")
            if (account != identity) { _current.value = null; lastRefresh = 0; account = identity }
            Entitlements.setIdentity(identity)
            val context = requestWithRecovery(identity, requestGeneration)
            ensureCurrent(identity, requestGeneration)
            if (identity != account) throw CancellationException()
            _current.value = context
            lastRefresh = dependencies.nowMillis()
            Entitlements.apply(context)
            _loadState.value = if (!context.isIncompletePatient && context.entitlement == null)
                AppContextLoadState.Failed(AppContextFailure.MissingEntitlement) else AppContextLoadState.Ready
            context
        } catch (error: CancellationException) {
            // Cancellation never turns a confirmed entitlement into read_only.
            if (requestGeneration == generation) {
                _loadState.value = if (_current.value?.entitlement != null) AppContextLoadState.Ready else AppContextLoadState.Unresolved
            }
            throw error
        } catch (error: Exception) {
            if (requestGeneration == generation && (identity == null || identity == dependencies.identity())) {
                Entitlements.invalidate()
                _loadState.value = AppContextLoadState.Failed(when {
                    error is ContextInitializationTimeout -> AppContextFailure.SessionInitialization
                    transientContextFailure(error) -> AppContextFailure.Connection
                    else -> AppContextFailure.ServerResponse
                })
                runCatching { InviteDebugLog.d("App context resolution failed; status=${EdgePayload.httpStatus(error) ?: "unavailable"}") }
            }
            throw error
        } finally {
            if (requestGeneration == generation) _isLoading.value = false
        }
    }

    private suspend fun requestWithRecovery(identity: String, requestGeneration: Long): AppContext {
        var refreshedAuth = false
        val attempts = dependencies.retryDelaysMillis.size + 1
        for (attempt in 1..attempts) {
            ensureCurrent(identity, requestGeneration)
            _loadState.value = AppContextLoadState.Loading(attempt)
            try {
                return withTimeoutOrNull(dependencies.timeoutMillis) { dependencies.request() } ?: throw ContextRequestTimeout()
            } catch (error: CancellationException) { throw error }
            catch (error: Exception) {
                ensureCurrent(identity, requestGeneration)
                if (EdgePayload.httpStatus(error) == 401 && !refreshedAuth && attempt < attempts) {
                    refreshedAuth = true
                    try {
                        withTimeoutOrNull(dependencies.timeoutMillis) { dependencies.refreshSession(); true } ?: throw ContextRequestTimeout()
                    } catch (refreshError: CancellationException) { throw refreshError }
                    catch (refreshError: Exception) {
                        ensureCurrent(identity, requestGeneration)
                        if (!transientContextFailure(refreshError)) throw refreshError
                        refreshedAuth = false
                        delay(dependencies.retryDelaysMillis[attempt - 1])
                    }
                    ensureCurrent(identity, requestGeneration)
                    continue
                }
                if (!transientContextFailure(error) || attempt == attempts) throw error
                delay(dependencies.retryDelaysMillis[attempt - 1])
                ensureCurrent(identity, requestGeneration)
            }
        }
        error("context_attempts_exhausted")
    }

    suspend fun refreshOnForeground() {
        if (dependencies.identity() == null || _isLoading.value) return
        // The cooldown applies only to confirmed access, never failed/missing context.
        if (_loadState.value is AppContextLoadState.Ready && Entitlements.state.value.access != null &&
            dependencies.nowMillis() - lastRefresh < 60_000) return
        runCatching { getCurrentAppContext() }
    }
    fun clear() {
        generation++
        account = null; lastRefresh = 0
        Entitlements.clear()
        _current.value = null
        _isLoading.value = false
        _loadState.value = AppContextLoadState.Unresolved
    }
}

internal fun transientContextFailure(error: Throwable): Boolean {
    val status = EdgePayload.httpStatus(error)
    if (status != null) return status in setOf(408, 425, 429, 500, 502, 503, 504)
    return generateSequence(error) { it.cause }.any { it is IOException || it is HttpRequestTimeoutException }
}
