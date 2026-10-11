package com.cbtipul.app.auth

import android.content.Intent
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
import io.github.jan.supabase.auth.handleDeeplinks
import io.github.jan.supabase.auth.parseFragmentAndImportSession
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.auth.status.SessionStatus
import io.github.jan.supabase.auth.user.UserSession
import io.github.jan.supabase.functions.functions
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

class AuthRepository(
    private val client: SupabaseClient,
    private val clearCredentialState: suspend () -> Unit = {},
    private val unregisterPush: suspend () -> Unit = {},
) {
    private val googleSignIn = GoogleSignInFlow()
    fun cancelGoogleSignIn() = googleSignIn.invalidate()

    suspend fun signInWithGoogle(credential: suspend (String) -> String) {
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

    internal val supabaseClient: SupabaseClient get() = client

    val session = client.auth.sessionStatus.map { status ->
        when (status) {
            SessionStatus.Initializing, is SessionStatus.RefreshFailure -> AuthSession.Loading
            is SessionStatus.Authenticated -> AuthSession.SignedIn(
                email = status.session.user?.email,
                userId = status.session.user?.id,
                isAnonymous = isAnonymousSession(status.session),
            )
            is SessionStatus.NotAuthenticated -> AuthSession.SignedOut
        }.also { state ->
            if (state !is AuthSession.Loading) com.cbtipul.app.data.Entitlements.setIdentity((state as? AuthSession.SignedIn)?.userId)
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

    /** @return true when the user must confirm email before they can sign in. */
    suspend fun signUp(email: String, password: String): Boolean {
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
        cancelGoogleSignIn()
        _isRecoveringPassword.value = false
        runCatching { unregisterPush() }
        runCatching { client.auth.signOut() }
        runCatching { clearCredentialState() }
    }

    suspend fun signInAnonymously() {
        cancelGoogleSignIn()
        ensureConfigured()
        client.auth.signInAnonymously()
    }

    fun currentUserId(): String? = client.auth.currentSessionOrNull()?.user?.id

    fun hasSession(): Boolean = client.auth.currentSessionOrNull() != null

    fun isAnonymousSession(): Boolean {
        val session = client.auth.currentSessionOrNull() ?: return false
        return isAnonymousSession(session)
    }

    suspend fun signOutPatientMode() {
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

    @OptIn(SupabaseInternal::class)
    suspend fun handleAuthIntent(intent: Intent?, verificationFailedMessage: String) {
        val uri = intent?.data ?: return
        if (uri.scheme != "cbtipul") return
        val host = uri.host ?: return
        if (host != "auth-callback" && host != "password-reset") return
        cancelGoogleSignIn()
        try {
            if (host == "password-reset") {
                val fragment = uri.fragment ?: uri.query.orEmpty()
                client.auth.parseFragmentAndImportSession(fragment) {
                    _isRecoveringPassword.value = true
                    _callbackError.value = null
                }
            } else {
                client.handleDeeplinks(intent) {
                    _callbackError.value = null
                }
            }
        } catch (_: Exception) {
            _callbackError.value = verificationFailedMessage
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

@Serializable
data class AccountDeletionResponse(
    val success: Boolean,
    val appleManualRevocationRequired: Boolean = false,
)
