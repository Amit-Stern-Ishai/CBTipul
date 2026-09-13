package com.cbtipul.app.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.cbtipul.app.settings.AppPreferences
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class AuthUiState(
    val mode: AuthMode = AuthMode.SignIn,
    val email: String = "",
    val password: String = "",
    val confirmPassword: String = "",
    val isWorking: Boolean = false,
    val errorMessage: String? = null,
    val infoMessage: String? = null,
    val verificationEmail: String? = null,
    val isResendBlocked: Boolean = false,
    val newPassword: String = "",
    val newPasswordConfirm: String = "",
    val newPasswordError: String? = null,
)

enum class AuthMode { SignIn, SignUp }

class AuthViewModel(
    private val auth: AuthRepository,
    private val preferences: AppPreferences,
    private val patients: com.cbtipul.app.data.PatientRepository,
) : ViewModel() {

    private val _treatAsSignedOut = MutableStateFlow(false)

    val session: StateFlow<AuthSession> = combine(
        auth.session,
        _treatAsSignedOut,
    ) { session, signedOut -> if (signedOut) AuthSession.SignedOut else session }
        .stateIn(viewModelScope, SharingStarted.Eagerly, AuthSession.Loading)

    private val _listSession = MutableStateFlow(0)
    val listSession: StateFlow<Int> = _listSession.asStateFlow()

    val isRecoveringPassword: StateFlow<Boolean> = auth.isRecoveringPassword
    val callbackError: StateFlow<String?> = auth.callbackError

    private val _ui = MutableStateFlow(AuthUiState())
    val ui: StateFlow<AuthUiState> = _ui.asStateFlow()

    fun updateEmail(value: String) = _ui.update { it.copy(email = value, errorMessage = null) }
    fun updatePassword(value: String) = _ui.update { it.copy(password = value, errorMessage = null) }
    fun updateConfirmPassword(value: String) = _ui.update { it.copy(confirmPassword = value) }
    fun setMode(mode: AuthMode) = _ui.update {
        it.copy(mode = mode, confirmPassword = "", errorMessage = null, infoMessage = null)
    }
    fun updateNewPassword(value: String) = _ui.update { it.copy(newPassword = value, newPasswordError = null) }
    fun updateNewPasswordConfirm(value: String) = _ui.update { it.copy(newPasswordConfirm = value) }

    fun submit(
        notConfigured: String,
        emailNotConfirmed: String,
        tooManyRequests: String,
        passwordsDontMatch: String,
    ) {
        val state = _ui.value
        if (state.mode == AuthMode.SignUp) {
            if (!PasswordRule.allSatisfied(state.password)) return
            if (state.password != state.confirmPassword) {
                _ui.update { it.copy(errorMessage = passwordsDontMatch) }
                return
            }
        }
        runAuth(notConfigured, emailNotConfirmed, tooManyRequests) {
            when (state.mode) {
                AuthMode.SignIn -> {
                    auth.signIn(state.email, state.password)
                    null
                }
                AuthMode.SignUp -> {
                    val needsConfirmation = auth.signUp(state.email, state.password)
                    if (needsConfirmation) {
                        _ui.update {
                            it.copy(verificationEmail = AuthRepository.normalize(state.email))
                        }
                    }
                    null
                }
            }
        }
    }

    fun resendVerification(
        notConfigured: String,
        emailNotConfirmed: String,
        tooManyRequests: String,
        resentMessage: String,
    ) {
        val email = _ui.value.verificationEmail ?: return
        runAuth(notConfigured, emailNotConfirmed, tooManyRequests) {
            auth.resendSignUpConfirmation(email)
            _ui.update { it.copy(isResendBlocked = true) }
            viewModelScope.launch {
                delay(30_000)
                _ui.update { it.copy(isResendBlocked = false) }
            }
            resentMessage
        }
    }

    fun forgotPassword(
        notConfigured: String,
        emailNotConfirmed: String,
        tooManyRequests: String,
        enterEmailFirst: String,
        sentMessage: String,
    ) {
        if (_ui.value.email.isBlank()) {
            _ui.update { it.copy(errorMessage = enterEmailFirst, infoMessage = null) }
            return
        }
        runAuth(notConfigured, emailNotConfirmed, tooManyRequests) {
            auth.resetPassword(_ui.value.email)
            sentMessage
        }
    }

    fun backToSignIn() {
        _ui.update {
            it.copy(
                verificationEmail = null,
                errorMessage = null,
                infoMessage = null,
                mode = AuthMode.SignIn,
            )
        }
    }

    fun saveNewPassword(
        notConfigured: String,
        emailNotConfirmed: String,
        tooManyRequests: String,
        passwordsDontMatch: String,
    ) {
        val state = _ui.value
        if (!PasswordRule.allSatisfied(state.newPassword) || state.newPassword != state.newPasswordConfirm) {
            if (state.newPassword != state.newPasswordConfirm) {
                _ui.update { it.copy(newPasswordError = passwordsDontMatch) }
            }
            return
        }
        viewModelScope.launch {
            _ui.update { it.copy(isWorking = true, newPasswordError = null) }
            try {
                auth.updatePassword(state.newPassword)
                _ui.update { it.copy(isWorking = false, newPassword = "", newPasswordConfirm = "") }
            } catch (error: Exception) {
                _ui.update {
                    it.copy(
                        isWorking = false,
                        newPasswordError = mapError(error, notConfigured, emailNotConfirmed, tooManyRequests),
                    )
                }
            }
        }
    }

    fun cancelRecovery() {
        signOut()
        _ui.update { it.copy(newPassword = "", newPasswordConfirm = "", newPasswordError = null) }
    }

    fun signOut() {
        _treatAsSignedOut.value = true
        _listSession.update { it + 1 }
        _ui.value = AuthUiState()
        viewModelScope.launch {
            auth.signOut()
            patients.clearAllCaches()
        }
    }

    fun deleteAccount(
        notConfigured: String,
        emailNotConfirmed: String,
        tooManyRequests: String,
        onSuccess: () -> Unit,
        onError: (String) -> Unit,
    ) {
        viewModelScope.launch {
            try {
                auth.deleteAccount()
                patients.wipeLocalData()
                _ui.value = AuthUiState()
                _listSession.update { it + 1 }
                onSuccess()
            } catch (error: Exception) {
                onError(mapError(error, notConfigured, emailNotConfirmed, tooManyRequests))
            }
        }
    }

    suspend fun acceptTerms(email: String) {
        preferences.setAcceptedTerms(email)
    }

    private fun runAuth(
        notConfigured: String,
        emailNotConfirmed: String,
        tooManyRequests: String,
        action: suspend () -> String?,
    ) {
        viewModelScope.launch {
            _treatAsSignedOut.value = false
            _ui.update { it.copy(isWorking = true, errorMessage = null, infoMessage = null) }
            try {
                val info = action()
                _ui.update { it.copy(isWorking = false, infoMessage = info) }
            } catch (error: Exception) {
                _ui.update {
                    it.copy(
                        isWorking = false,
                        errorMessage = mapError(error, notConfigured, emailNotConfirmed, tooManyRequests),
                    )
                }
            }
        }
    }

    private fun mapError(
        error: Exception,
        notConfigured: String,
        emailNotConfirmed: String,
        tooManyRequests: String,
    ): String = when (error) {
        is AuthException -> when (error.kind) {
            AuthErrorKind.NotConfigured -> notConfigured
            AuthErrorKind.EmailNotConfirmed -> emailNotConfirmed
            AuthErrorKind.TooManyRequests -> tooManyRequests
        }
        else -> error.message ?: error.toString()
    }

    class Factory(
        private val auth: AuthRepository,
        private val preferences: AppPreferences,
        private val patients: com.cbtipul.app.data.PatientRepository,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            AuthViewModel(auth, preferences, patients) as T
    }
}
