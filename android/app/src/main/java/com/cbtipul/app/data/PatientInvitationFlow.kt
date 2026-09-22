package com.cbtipul.app.data

import com.cbtipul.app.auth.AuthRepository
import com.cbtipul.app.debug.InviteDebugLog
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
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
    private val scope: CoroutineScope,
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

    fun accept() {
        InviteDebugLog.d("Launching accept from PatientInvitationFlow applicationScope")
        InviteDebugLog.d("Activation owner Job = ${scope.coroutineContext[Job]}")
        scope.launch { activate() }
    }

    private suspend fun activate() {
        mutex.withLock {
            val current = _phase.value
            if (current !is InvitationPhase.Consent && current !is InvitationPhase.ActivationFailed) return
            _phase.value = InvitationPhase.Activating
            InviteDebugLog.d("Accept flow started")
            InviteDebugLog.d("Phase set to Activating")
            InviteDebugLog.d("activate() Job = ${currentCoroutineContext()[Job]}")
            InviteDebugLog.d("Token available: ${token != null}")
            InviteDebugLog.d("Current auth state: ${authStateLabel()}")
            try {
                if (!didSucceedClaim) {
                    ensureAnonymousSession()
                    val currentToken = token ?: run {
                        InviteDebugLog.e("claim-patient-invitation", IllegalStateException("token unavailable"))
                        _phase.value = InvitationPhase.ActivationFailed(ActivationFailure.Claim(null))
                        return
                    }
                    InviteDebugLog.d("Calling claim-patient-invitation...")
                    invitations.claimPatientInvitation(currentToken)
                    InviteDebugLog.d("Claim succeeded")
                    didSucceedClaim = true
                    token = null
                } else {
                    InviteDebugLog.d("Claim already succeeded, skipping claim")
                }
                InviteDebugLog.d("Calling get-app-context...")
                val context = appContext.getCurrentAppContext()
                InviteDebugLog.d("get-app-context succeeded")
                InviteDebugLog.d("role = ${context.role.name.lowercase()}")
                InviteDebugLog.d("activation = ${context.activation?.name?.lowercase() ?: "null"}")
                InviteDebugLog.d("patientId present = ${InviteDebugLog.present(context.patientId)}")
                if (!context.isActivePatient) {
                    InviteDebugLog.d("[ERROR] Patient Mode context is not active after get-app-context")
                    _phase.value = InvitationPhase.ActivationFailed(ActivationFailure.Context)
                    return
                }
                therapistDisplayName = null
                InviteDebugLog.d("session exists: ${auth.hasSession()}")
                InviteDebugLog.d("isAnonymous: ${auth.isAnonymousSession()}")
                InviteDebugLog.d("claim succeeded: $didSucceedClaim")
                InviteDebugLog.d("root destination selected: anonymouspatient")
                _phase.value = InvitationPhase.Idle
                InviteDebugLog.d("Patient Mode activation complete")
            } catch (error: CancellationException) {
                InviteDebugLog.d("[CANCELLED] activate() coroutine was cancelled")
                InviteDebugLog.e("activate (cancelled)", error)
                throw error
            } catch (error: PatientInvitationClaimError.Status) {
                InviteDebugLog.e("claim-patient-invitation", error)
                _phase.value = InvitationPhase.ActivationFailed(ActivationFailure.Claim(error.status))
            } catch (error: PatientInvitationClaimError.Failed) {
                InviteDebugLog.e("claim-patient-invitation", error)
                _phase.value = InvitationPhase.ActivationFailed(ActivationFailure.Claim(null))
            } catch (error: Exception) {
                val mapped = when {
                    didSucceedClaim -> ActivationFailure.Context
                    auth.isAnonymousSession() -> ActivationFailure.Claim(null)
                    else -> ActivationFailure.SignIn
                }
                val step = when (mapped) {
                    ActivationFailure.SignIn -> "anonymous sign-in"
                    is ActivationFailure.Claim -> "claim-patient-invitation"
                    ActivationFailure.Context -> "get-app-context"
                }
                InviteDebugLog.e(step, error)
                _phase.value = InvitationPhase.ActivationFailed(mapped)
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
        if (auth.hasSession() && auth.isAnonymousSession()) {
            InviteDebugLog.d("Existing anonymous session, skipping sign-in")
            InviteDebugLog.d("Anonymous user id: ${InviteDebugLog.shortId(auth.currentUserId())}")
            InviteDebugLog.d("user.isAnonymous = true")
            return
        }
        if (auth.hasSession() && !auth.isAnonymousSession()) {
            InviteDebugLog.d("Signing out existing therapist session...")
            try {
                auth.signOut()
                patients.clearAllCaches()
                InviteDebugLog.d("Therapist sign-out succeeded")
            } catch (error: Exception) {
                InviteDebugLog.e("therapist sign-out", error)
                throw error
            }
        }
        InviteDebugLog.d("Starting anonymous sign-in...")
        val before = currentCoroutineContext()
        InviteDebugLog.d("signInAnonymously coroutine Job = ${before[Job]}")
        InviteDebugLog.d("signInAnonymously coroutine active before call = ${before.isActive}")
        try {
            auth.signInAnonymously()
            InviteDebugLog.d("signInAnonymously returned")
            InviteDebugLog.d(
                "signInAnonymously coroutine active after return = ${currentCoroutineContext().isActive}",
            )
        } catch (error: CancellationException) {
            InviteDebugLog.d("[CANCELLED] anonymous sign-in coroutine was cancelled")
            InviteDebugLog.d("signInAnonymously coroutine active after cancel = ${before.isActive}")
            InviteDebugLog.e("anonymous sign-in (cancelled)", error)
            throw error
        } catch (error: Exception) {
            InviteDebugLog.e("anonymous sign-in", error)
            throw error
        }
        val anonymous = auth.hasSession() && auth.isAnonymousSession()
        InviteDebugLog.d("Anonymous user id: ${InviteDebugLog.shortId(auth.currentUserId())}")
        InviteDebugLog.d("user.isAnonymous = $anonymous")
        if (!anonymous) {
            val error = IllegalStateException("anonymous_sign_in_failed")
            InviteDebugLog.e("anonymous sign-in", error)
            throw error
        }
        InviteDebugLog.d("Anonymous sign-in succeeded")
    }

    private fun authStateLabel(): String = when {
        !auth.hasSession() -> "no_session"
        auth.isAnonymousSession() -> "anonymous"
        else -> "therapist"
    }
}
