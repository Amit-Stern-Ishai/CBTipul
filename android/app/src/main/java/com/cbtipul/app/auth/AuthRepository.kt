package com.cbtipul.app.auth

import android.content.Intent
import android.content.SharedPreferences
import io.github.jan.supabase.auth.providers.Apple
import io.github.jan.supabase.auth.parseSessionFromFragment
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.withTimeout
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.providers.builtin.IDToken
import io.ktor.client.call.body
import kotlinx.serialization.Serializable
import android.util.Base64
import com.cbtipul.app.data.SupabaseConfig
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.annotations.SupabaseInternal
import io.github.jan.supabase.auth.OtpType
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.exception.AuthErrorCode
import io.github.jan.supabase.auth.exception.AuthRestException
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.auth.status.SessionStatus
import io.github.jan.supabase.auth.user.UserSession
import io.github.jan.supabase.functions.functions
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.collect
import io.github.jan.supabase.auth.status.SessionSource
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

class AuthRepository(
    private val client: SupabaseClient,
    private val browserPreferences: SharedPreferences,
    private val clearCredentialState: suspend () -> Unit = {},
    private val unregisterPush: suspend () -> Unit = {},
) {
    private val callbackGate = BrowserCallbackGate(
        { browserPreferences.getString("consumed", null) },
        { browserPreferences.edit().putString("consumed", it).commit(); Unit },
    )
    private val _callbackCompleted = MutableStateFlow(0)
    val callbackCompleted = _callbackCompleted.asStateFlow()
    private val _callbackBusy = MutableStateFlow(false)
    val callbackBusy = _callbackBusy.asStateFlow()

    private fun abandonBrowserSignIn() {
        appleTelemetry?.event(com.cbtipul.app.telemetry.Stage.cancelled,error=com.cbtipul.app.telemetry.SafeError.cancelled); appleTelemetry=null
        callbackGate.invalidate()
        browserPreferences.edit().remove("apple_started").commit()
    }

    private var appleTelemetry: com.cbtipul.app.telemetry.Operation? = null
    suspend fun startAppleSignIn(openBrowser: (String) -> Unit) {
        ensureConfigured()
        client.auth.awaitInitialization()
        check(!hasSession() && !callbackGate.isBusy)
        cancelGoogleSignIn()
        abandonBrowserSignIn()
        val attempt = callbackGate.revision
        client.auth.codeVerifierCache.deleteCodeVerifier()
        // SDK 3.2.2 interpolates redirect_to without encoding. An unencoded
        // cbtipul:// value is dropped and Auth falls back to the site URL.
        val url = appleAuthorizationUrl(client)
        // SDK 3.2.2 saves asynchronously. Wait until the current URL's verifier
        // is in the SDK's persistent cache before handing control to the browser.
        val challenge = android.net.Uri.parse(url).getQueryParameter("code_challenge")
        withTimeout(5_000) {
            while (true) {
                val verifier = client.auth.codeVerifierCache.loadCodeVerifier()
                val actual = verifier?.let {
                    Base64.encodeToString(java.security.MessageDigest.getInstance("SHA-256")
                        .digest(it.toByteArray(Charsets.UTF_8)), Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
                }
                if (challenge != null && actual == challenge) break
                delay(20)
            }
        }
        if (attempt != callbackGate.revision || hasSession()) throw CancellationException()
        browserPreferences.edit().putLong("apple_started", System.currentTimeMillis()).commit()
        appleTelemetry=com.cbtipul.app.telemetry.Telemetry.client.begin(com.cbtipul.app.telemetry.Flow.authentication,method=com.cbtipul.app.telemetry.Method.apple)
        try { openBrowser(url) }
        catch (error: Exception) {
            appleTelemetry?.event(com.cbtipul.app.telemetry.Stage.failed,error=com.cbtipul.app.telemetry.SafeError.generic); appleTelemetry=null
            abandonBrowserSignIn()
            client.auth.codeVerifierCache.deleteCodeVerifier()
            throw error
        }
    }

    private val googleSignIn = GoogleSignInFlow()
    fun cancelGoogleSignIn() = googleSignIn.invalidate()

    suspend fun signInWithGoogle(credential: suspend (String) -> String) {
        return com.cbtipul.app.telemetry.Telemetry.measure(com.cbtipul.app.telemetry.Flow.authentication, method = com.cbtipul.app.telemetry.Method.google) {
            abandonBrowserSignIn()
            client.auth.codeVerifierCache.deleteCodeVerifier()
            ensureConfigured()
            googleSignIn.run(
                hasSession = ::hasSession,
                credential = credential,
                exchange = { token, rawNonce ->
                    var result: UserSession? = null
                    // Use the existing SDK transport, but defer import until the attempt
                    // is still current. signInWith would import before that check.
                    IDToken.login(client, onSuccess = { result = it }, redirectUrl = null) {
                        idToken = token
                        provider = Google
                        nonce = rawNonce
                    }
                    requireNotNull(result)
                },
                commit = { client.auth.importSession(it) },
            )

        }
    }

    internal val supabaseClient: SupabaseClient get() = client

    /** Credential-free revision: StateFlow UI identity equality must not hide reauthentication. */
    val contextSessionChanges = flow {
        var revision = 0L
        var restorationReported = false
        client.auth.sessionStatus.collect { status ->
            when (status) {
                is SessionStatus.Authenticated -> {
                    val identity = currentUserId()
                    if (identity != null && identity == status.session.user?.id) {
                        com.cbtipul.app.telemetry.Telemetry.client.setOwner(identity, if (isAnonymousSession()) com.cbtipul.app.telemetry.Role.patient else com.cbtipul.app.telemetry.Role.therapist)
                        if (!restorationReported) {
                            restorationReported = true
                            com.cbtipul.app.telemetry.Telemetry.client.operation(com.cbtipul.app.telemetry.Flow.restoration).event(com.cbtipul.app.telemetry.Stage.succeeded)
                        }
                        emit(AuthContextSession(identity, ++revision, status.source is SessionSource.Refresh))
                    }
                }
                is SessionStatus.NotAuthenticated -> if (!hasSession()) {
                    com.cbtipul.app.telemetry.Telemetry.client.setOwner(null, com.cbtipul.app.telemetry.Role.unknown)
                    if (!restorationReported) { restorationReported=true; com.cbtipul.app.telemetry.Telemetry.client.operation(com.cbtipul.app.telemetry.Flow.restoration).event(com.cbtipul.app.telemetry.Stage.failed,error=com.cbtipul.app.telemetry.SafeError.unavailable) }
                    emit(null)
                }
                // Refresh failure is not successful authentication. Invalidate
                // access without clearing stored credentials or resetting a retry
                // budget on each SDK background retry.
                is SessionStatus.RefreshFailure -> {
                    if (!restorationReported) { restorationReported=true; com.cbtipul.app.telemetry.Telemetry.client.operation(com.cbtipul.app.telemetry.Flow.restoration).event(com.cbtipul.app.telemetry.Stage.failed,error=com.cbtipul.app.telemetry.SafeError.unavailable) }
                    com.cbtipul.app.data.Entitlements.invalidate()
                    emit(null)
                }
                SessionStatus.Initializing -> Unit
            }
        }
    }

    val session = client.auth.sessionStatus.map { status ->
        when (status) {
            SessionStatus.Initializing -> AuthSession.Loading
            is SessionStatus.RefreshFailure -> AuthSession.Unavailable
            is SessionStatus.Authenticated -> AuthSession.SignedIn(
                email = status.session.user?.email,
                userId = status.session.user?.id,
                isAnonymous = isAnonymousSession(status.session),
            )
            is SessionStatus.NotAuthenticated -> AuthSession.SignedOut
        }.let(::sessionForRouting).also { state ->
            when (state) {
                is AuthSession.SignedIn -> com.cbtipul.app.data.Entitlements.setIdentity(state.userId)
                AuthSession.SignedOut -> com.cbtipul.app.data.Entitlements.setIdentity(null)
                AuthSession.Unavailable -> com.cbtipul.app.data.Entitlements.invalidate()
                AuthSession.Loading -> Unit
            }
        }
    }

    private val _isRecoveringPassword = MutableStateFlow(false)
    val isRecoveringPassword: StateFlow<Boolean> = _isRecoveringPassword.asStateFlow()

    private val _callbackError = MutableStateFlow<String?>(null)
    val callbackError: StateFlow<String?> = _callbackError.asStateFlow()

    private fun ensureConfigured() {
        if (!SupabaseConfig.isConfigured) {
            throw AuthException(AuthErrorKind.NotConfigured)
        }
    }

    suspend fun signIn(email: String, password: String) {
        return com.cbtipul.app.telemetry.Telemetry.measure(com.cbtipul.app.telemetry.Flow.authentication, method = com.cbtipul.app.telemetry.Method.email) {
            abandonBrowserSignIn()
            client.auth.codeVerifierCache.deleteCodeVerifier()
            cancelGoogleSignIn()
            ensureConfigured()
            try {
                client.auth.signInWith(Email) {
                    this.email = normalize(email)
                    this.password = password
                }
            } catch (error: AuthRestException) {
                if (error.errorCode == AuthErrorCode.EmailNotConfirmed) {
                    throw AuthException(AuthErrorKind.EmailNotConfirmed)
                }
                throw error
            }

        }
    }

    /** @return true when the user must confirm email before they can sign in. */
    suspend fun signUp(email: String, password: String): Boolean {
        abandonBrowserSignIn()
        cancelGoogleSignIn()
        ensureConfigured()
        client.auth.signUpWith(Email, redirectUrl = SupabaseConfig.AUTH_CALLBACK) {
            this.email = normalize(email)
            this.password = password
        }
        return client.auth.currentSessionOrNull() == null
    }

    suspend fun resendSignUpConfirmation(email: String) {
        ensureConfigured()
        try {
            client.auth.resendEmail(
                OtpType.Email.SIGNUP,
                normalize(email),
            )
        } catch (error: AuthRestException) {
            if (error.errorCode == AuthErrorCode.OverEmailSendRateLimit) {
                throw AuthException(AuthErrorKind.TooManyRequests)
            }
            throw error
        }
    }

    suspend fun resetPassword(email: String) {
        abandonBrowserSignIn()
        ensureConfigured()
        client.auth.resetPasswordForEmail(
            normalize(email),
            redirectUrl = SupabaseConfig.PASSWORD_RESET_CALLBACK,
        )
    }

    suspend fun updatePassword(password: String) {
        ensureConfigured()
        client.auth.updateUser {
            this.password = password
        }
        _isRecoveringPassword.value = false
    }

    suspend fun signOut() {
        abandonBrowserSignIn()
        client.auth.codeVerifierCache.deleteCodeVerifier()
        cancelGoogleSignIn()
        _isRecoveringPassword.value = false
        runCatching { unregisterPush() }
        runCatching { client.auth.signOut() }
        runCatching { clearCredentialState() }
    }

    suspend fun awaitInvitationSessionInitialization() {
        client.auth.awaitInitialization()
        // SDK 3.2.2 exposes no currentSession while refresh failed, even though
        // its stored anonymous identity still exists. Never replace it with a
        // new anonymous identity merely because restoration is temporarily unavailable.
        check(client.auth.sessionStatus.value !is SessionStatus.RefreshFailure)
    }

    suspend fun retrySessionRestoration() {
        withTimeout(8_000) {
            check(client.auth.loadFromStorage())
            check(client.auth.sessionStatus.value is SessionStatus.Authenticated)
        }
    }

    /** Invitation confirmation clears only this app's local authentication state. */
    suspend fun signOutLocallyForInvitation(expectedUserId: String) {
        client.auth.awaitInitialization()
        check(currentUserId() == expectedUserId && !isAnonymousSession())
        abandonBrowserSignIn()
        cancelGoogleSignIn()
        // Unlike signOut(), clearSession makes no logout request and cannot
        // swallow a failure that leaves a therapist session attached to claim.
        client.auth.clearSession()
        check(!hasSession())
        _isRecoveringPassword.value = false
        runCatching { clearCredentialState() }
    }

    suspend fun signInAnonymously() {
        return com.cbtipul.app.telemetry.Telemetry.measure(com.cbtipul.app.telemetry.Flow.authentication, method = com.cbtipul.app.telemetry.Method.anonymous) {
            abandonBrowserSignIn()
            client.auth.codeVerifierCache.deleteCodeVerifier()
            cancelGoogleSignIn()
            ensureConfigured()
            client.auth.signInAnonymously()

        }
    }

    fun sessionForRouting(observed: AuthSession): AuthSession = reconcileSessionObservation(observed,
        client.auth.currentSessionOrNull()?.let {
            AuthSession.SignedIn(it.user?.email, it.user?.id, isAnonymousSession(it))
        })

    fun currentUserId(): String? = client.auth.currentSessionOrNull()?.user?.id

    fun hasSession(): Boolean = client.auth.currentSessionOrNull() != null

    fun isAnonymousSession(): Boolean {
        val session = client.auth.currentSessionOrNull() ?: return false
        return isAnonymousSession(session)
    }

    suspend fun signOutPatientMode() {
        abandonBrowserSignIn()
        client.auth.codeVerifierCache.deleteCodeVerifier()
        cancelGoogleSignIn()
        if (!isAnonymousSession()) {
            throw AuthException(AuthErrorKind.VerificationFailed)
        }
        ensureConfigured()
        runCatching { unregisterPush() }
        client.auth.signOut()
        _isRecoveringPassword.value = false
    }

    suspend fun deleteAccount(): AccountDeletionResponse {
        abandonBrowserSignIn()
        cancelGoogleSignIn()
        ensureConfigured()
        val result = client.functions.invoke("delete-account").body<AccountDeletionResponse>()
        check(result.success)
        _isRecoveringPassword.value = false
        runCatching { unregisterPush() }
        runCatching { client.auth.signOut() }
        runCatching { clearCredentialState() }
        return result
    }

    @OptIn(kotlin.time.ExperimentalTime::class)
    suspend fun handleAuthIntent(intent: Intent?, verificationFailedMessage: String) {
        val callback = runCatching {
            intent?.data?.toString()?.let(BrowserAuthCallback::parse)
        }.getOrNull() ?: return
        if (_callbackBusy.value) return
        _callbackBusy.value = true
        val wasRecovering = _isRecoveringPassword.value
        try {
            client.auth.awaitInitialization()
            if (isAnonymousSession() || (hasSession() && !callback.recovery)) return
            val originalUser = currentUserId()
            cancelGoogleSignIn()
            callbackGate.handle(callback, resolve = {
                if (callback.error) {
                    if (callback.cancelled) throw CancellationException()
                    error("auth_callback_failed")
                }
                val appleStarted = browserPreferences.getLong("apple_started", 0)
                if (appleStarted != 0L) {
                    check(System.currentTimeMillis() - appleStarted in 0..600_000)
                    // Never downgrade an Apple PKCE attempt to an implicit callback.
                    check(callback.code != null)
                }
                when {
                    callback.code != null -> client.auth.exchangeCodeForSession(callback.code, saveSession = false)
                    callback.legacyFragment != null -> {
                        val session = client.auth.parseSessionFromFragment(callback.legacyFragment)
                        session.copy(user = client.auth.retrieveUser(session.accessToken))
                    }
                    else -> error("invalid_auth_callback")
                }
            }, commit = { session ->
                check(currentUserId() == originalUser && !isAnonymousSession())
                if (originalUser != null) check(session.user?.id == originalUser)
                _isRecoveringPassword.value = callback.recovery
                client.auth.importSession(session)
                _callbackError.value = null
                _callbackCompleted.value++
                appleTelemetry?.rebound()?.event(com.cbtipul.app.telemetry.Stage.succeeded); appleTelemetry=null
            })
        } catch (_: CancellationException) {
            appleTelemetry?.event(com.cbtipul.app.telemetry.Stage.cancelled,error=com.cbtipul.app.telemetry.SafeError.cancelled); appleTelemetry=null
            // Includes an explicit provider cancellation or superseded attempt.
        } catch (_: Exception) {
            appleTelemetry?.event(com.cbtipul.app.telemetry.Stage.failed,error=com.cbtipul.app.telemetry.SafeError.generic); appleTelemetry=null
            _isRecoveringPassword.value = wasRecovering
            _callbackError.value = verificationFailedMessage
        } finally {
            browserPreferences.edit().remove("apple_started").commit()
            _callbackBusy.value = false
        }
    }

    companion object {
        fun normalize(email: String): String = email.trim().lowercase()

        fun isAnonymousSession(session: UserSession): Boolean {
            val token = session.accessToken
            val parts = token.split('.')
            if (parts.size >= 2) {
                val payload = runCatching {
                    val decoded = Base64.decode(
                        parts[1],
                        Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
                    )
                    String(decoded, Charsets.UTF_8)
                }.getOrNull()
                val flag = payload?.let {
                    kotlinx.serialization.json.Json.parseToJsonElement(it)
                        .jsonObject["is_anonymous"]?.jsonPrimitive?.booleanOrNull
                }
                if (flag == true) return true
            }
            return session.user?.identities?.any { it.provider.equals("anonymous", ignoreCase = true) } == true
        }
    }
}

sealed interface AuthSession {
    data object Loading : AuthSession
    data object Unavailable : AuthSession
    data object SignedOut : AuthSession
    data class SignedIn(
        val email: String?,
        val userId: String? = null,
        val isAnonymous: Boolean = false,
    ) : AuthSession
}

/**
 * AuthViewModel can briefly treat a therapist as signed out for snappy logout.
 * That flag must never hide a later anonymous Patient Mode session.
 */
internal fun effectiveAuthSession(
    session: AuthSession,
    treatAsSignedOut: Boolean,
): AuthSession {
    if (!treatAsSignedOut) return session
    val signedIn = session as? AuthSession.SignedIn
    if (signedIn?.isAnonymous == true) return session
    return when (session) {
        AuthSession.Loading -> AuthSession.Loading
        else -> AuthSession.SignedOut
    }
}

enum class AuthErrorKind {
    NotConfigured,
    EmailNotConfirmed,
    TooManyRequests,
    VerificationFailed,
}

class AuthException(val kind: AuthErrorKind) : Exception()

internal fun appleAuthorizationUrl(client: SupabaseClient): String {
    val generated = client.auth.getOAuthUrl(Apple, redirectUrl = SupabaseConfig.AUTH_CALLBACK) {
        scopes.addAll(listOf("email", "name"))
    }
    return generated.withEncodedRedirect(SupabaseConfig.AUTH_CALLBACK)
}

private fun String.withEncodedRedirect(redirectUrl: String): String {
    val encoded = java.net.URLEncoder.encode(redirectUrl, Charsets.UTF_8)
    val prefix = "redirect_to="
    val start = indexOf(prefix)
    require(start >= 0) { "OAuth authorization URL omitted redirect_to" }
    val valueStart = start + prefix.length
    val valueEnd = indexOf('&', valueStart).let { if (it < 0) length else it }
    val current = substring(valueStart, valueEnd)
    require(current == redirectUrl || current == encoded) { "Unexpected redirect_to" }
    return if (current == encoded) this else replaceRange(valueStart, valueEnd, encoded)
}

@Serializable
data class AccountDeletionResponse(
    val success: Boolean,
    val appleManualRevocationRequired: Boolean = false,
)

/** Keep explicit logout/loading intact; reconcile signed-in snapshots with live SDK identity. */
internal fun reconcileSessionObservation(observed: AuthSession, current: AuthSession.SignedIn?): AuthSession =
    if (observed is AuthSession.SignedIn) current ?: AuthSession.Loading else observed

/** No token, email verification assertion, or entitlement is carried by an auth revision. */
data class AuthContextSession(val userId: String, val revision: Long, val isTokenRefresh: Boolean = false)
