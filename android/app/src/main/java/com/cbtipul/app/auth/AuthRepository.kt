package com.cbtipul.app.auth

import android.content.Intent
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
import io.github.jan.supabase.functions.functions
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map

class AuthRepository(private val client: SupabaseClient) {

    val currentUserEmail = client.auth.sessionStatus.map { status ->
        when (status) {
            is SessionStatus.Authenticated -> status.session.user?.email
            else -> null
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
        _isRecoveringPassword.value = false
        runCatching { client.auth.signOut() }
    }

    suspend fun deleteAccount() {
        ensureConfigured()
        client.functions.invoke("delete-account")
        _isRecoveringPassword.value = false
        runCatching { client.auth.signOut() }
    }

    @OptIn(SupabaseInternal::class)
    suspend fun handleAuthIntent(intent: Intent?, verificationFailedMessage: String) {
        val uri = intent?.data ?: return
        if (uri.scheme != "cbtipul") return
        val host = uri.host ?: return
        if (host != "auth-callback" && host != "password-reset") return
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
    }
}

enum class AuthErrorKind {
    NotConfigured,
    EmailNotConfirmed,
    TooManyRequests,
}

class AuthException(val kind: AuthErrorKind) : Exception()
