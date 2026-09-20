package com.cbtipul.app.data

import com.cbtipul.app.auth.AuthRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

sealed interface InvitationPhase {
    data object Idle : InvitationPhase
    data object Loading : InvitationPhase
    data class Preview(val therapistDisplayName: String) : InvitationPhase
    data class Unavailable(val status: PatientInvitationPreviewStatus) : InvitationPhase
    data object Failed : InvitationPhase
    data object Consent : InvitationPhase
    data object Activating : InvitationPhase
    data class ActivationFailed(val failure: ActivationFailure) : InvitationPhase
}

sealed interface ActivationFailure {
    data object SignIn : ActivationFailure
    data class Claim(val status: PatientInvitationPreviewStatus?) : ActivationFailure
    data object Context : ActivationFailure
}

class PatientInvitationFlow(
    private val invitations: PatientInvitationService,
    private val auth: AuthRepository,
    private val appContext: AppContextRepository,
    private val patients: PatientRepository,
) {
    private val mutex = Mutex()
    private val _phase = MutableStateFlow<InvitationPhase>(InvitationPhase.Idle)
    val phase: StateFlow<InvitationPhase> = _phase.asStateFlow()

    var token: String? = null
        private set
    var therapistDisplayName: String? = null
        private set
    var didSucceedClaim: Boolean = false
        private set

    val isActive: Boolean get() = _phase.value !is InvitationPhase.Idle

    suspend fun start(token: String) {
        this.token = token
        didSucceedClaim = false
        _phase.value = InvitationPhase.Loading
        try {
            val preview = invitations.getPatientInvitation(token)
            if (this.token != token) return
            when (preview.status) {
                PatientInvitationPreviewStatus.Valid -> {
                    val name = preview.therapistDisplayName?.trim().orEmpty()
                    therapistDisplayName = name
                    _phase.value = InvitationPhase.Preview(name)
                }
                else -> _phase.value = InvitationPhase.Unavailable(preview.status)
            }
        } catch (error: Exception) {
            if (this.token != token) return
            _phase.value = InvitationPhase.Failed
        }
    }

    fun continueToConsent() {
        if (_phase.value is InvitationPhase.Preview) {
            _phase.value = InvitationPhase.Consent
        }
    }

    fun returnToPreview() {
        if (token == null) return
        _phase.value = InvitationPhase.Preview(therapistDisplayName.orEmpty())
    }

    suspend fun activate() {
        mutex.withLock {
            val current = _phase.value
            if (current !is InvitationPhase.Consent && current !is InvitationPhase.ActivationFailed) return
            _phase.value = InvitationPhase.Activating
            try {
                if (!didSucceedClaim) {
                    ensureAnonymousSession()
                    val currentToken = token ?: run {
                        _phase.value = InvitationPhase.ActivationFailed(ActivationFailure.Claim(null))
                        return
                    }
                    invitations.claimPatientInvitation(currentToken)
                    didSucceedClaim = true
                    token = null
                }
                val context = appContext.getCurrentAppContext()
                if (!context.isActivePatient) {
                    _phase.value = InvitationPhase.ActivationFailed(ActivationFailure.Context)
                    return
                }
                therapistDisplayName = null
                _phase.value = InvitationPhase.Idle
            } catch (error: PatientInvitationClaimError.Status) {
                _phase.value = InvitationPhase.ActivationFailed(ActivationFailure.Claim(error.status))
            } catch (_: PatientInvitationClaimError.Failed) {
                _phase.value = InvitationPhase.ActivationFailed(ActivationFailure.Claim(null))
            } catch (_: Exception) {
                _phase.value = when {
                    didSucceedClaim -> InvitationPhase.ActivationFailed(ActivationFailure.Context)
                    auth.isAnonymousSession() -> InvitationPhase.ActivationFailed(ActivationFailure.Claim(null))
                    else -> InvitationPhase.ActivationFailed(ActivationFailure.SignIn)
                }
            }
        }
    }

    fun dismiss() {
        token = null
        therapistDisplayName = null
        didSucceedClaim = false
        _phase.value = InvitationPhase.Idle
    }

    private suspend fun ensureAnonymousSession() {
        if (auth.hasSession() && auth.isAnonymousSession()) return
        if (auth.hasSession() && !auth.isAnonymousSession()) {
            auth.signOut()
            patients.clearAllCaches()
        }
        auth.signInAnonymously()
        if (!auth.hasSession() || !auth.isAnonymousSession()) {
            throw IllegalStateException("anonymous_sign_in_failed")
        }
    }
}
