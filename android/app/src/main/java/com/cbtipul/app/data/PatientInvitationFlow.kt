package com.cbtipul.app.data

import com.cbtipul.app.auth.AuthRepository
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

internal data class InvitationSession(val userId: String, val isAnonymous: Boolean)
internal data class InvitationDependencies(
    val preview: suspend (String) -> PatientInvitationPreview,
    val awaitInitialization: suspend () -> Unit,
    val session: () -> InvitationSession?,
    val signOutLocally: suspend (String) -> Unit,
    val signInAnonymously: suspend () -> Unit,
    val clearContext: () -> Unit,
    val context: suspend () -> AppContext,
    val claim: suspend (String) -> String,
)

sealed interface InvitationPhase {
    data object Idle : InvitationPhase
    data object Loading : InvitationPhase
    data class Preview(val therapistDisplayName: String) : InvitationPhase
    data class Unavailable(val status: PatientInvitationPreviewStatus) : InvitationPhase
    data object Failed : InvitationPhase
    data object Consent : InvitationPhase
    data object ConfirmTherapistSwitch : InvitationPhase
    data object ExistingPatient : InvitationPhase
    data object Activating : InvitationPhase
    data class ActivationFailed(val failure: ActivationFailure) : InvitationPhase
}
sealed interface ActivationFailure {
    data object SignIn : ActivationFailure
    data class Claim(val status: PatientInvitationPreviewStatus?) : ActivationFailure
    data object Context : ActivationFailure
}

/** Main-thread, application-owned flow. Only injected effects touch auth/backend. */
class PatientInvitationFlow internal constructor(
    private val dependencies: InvitationDependencies,
    private val scope: CoroutineScope,
    private val telemetryClient: com.cbtipul.app.telemetry.TelemetryClient = com.cbtipul.app.telemetry.Telemetry.client,
) {
    constructor(invitations: PatientInvitationService, auth: AuthRepository,
                appContext: AppContextRepository, scope: CoroutineScope) : this(
        InvitationDependencies(
            preview = { invitations.getPatientInvitation(it) },
            awaitInitialization = { auth.awaitInvitationSessionInitialization() },
            session = { auth.currentUserId()?.let { InvitationSession(it, auth.isAnonymousSession()) } },
            signOutLocally = { auth.signOutLocallyForInvitation(it) },
            signInAnonymously = { auth.signInAnonymously() },
            clearContext = { appContext.clear() },
            context = { appContext.getCurrentAppContext() },
            claim = { invitations.claimPatientInvitation(it).patientId },
        ), scope,
    )

    private val _phase = MutableStateFlow<InvitationPhase>(InvitationPhase.Idle)
    val phase: StateFlow<InvitationPhase> = _phase.asStateFlow()
    var token: String? = null
        private set
    var therapistDisplayName: String? = null
        private set
    var didSucceedClaim = false
        private set
    private var telemetry: com.cbtipul.app.telemetry.Operation? = null
    private var generation = 0L
    private var inFlight = false
    private var switchUserId: String? = null
    private var activationIdentity: InvitationSession? = null
    private var claimedPatientId: String? = null
    val isActive: Boolean get() = _phase.value !is InvitationPhase.Idle

    /** Reserve the root synchronously before restoration or Compose can route. */
    fun start(token: String, start: com.cbtipul.app.telemetry.Start = com.cbtipul.app.telemetry.Start.unknown) {
        if (inFlight) return
        if (this.token == token && isActive) return
        telemetry = telemetryClient.operation(com.cbtipul.app.telemetry.Flow.invitation)
        telemetry?.event(com.cbtipul.app.telemetry.Stage.received, start=start)
        generation++
        val request = generation
        this.token = token
        therapistDisplayName = null
        didSucceedClaim = false
        activationIdentity = null
        claimedPatientId = null
        switchUserId = null
        _phase.value = InvitationPhase.Loading
        scope.launch {
            try {
                val preview = com.cbtipul.app.telemetry.telemetryRequest(com.cbtipul.app.telemetry.Request.invitationPreview,parent=telemetry) { dependencies.preview(token) }
                if (request != generation || _phase.value !is InvitationPhase.Loading) return@launch
                if (preview.status == PatientInvitationPreviewStatus.Valid) {
                    therapistDisplayName = preview.therapistDisplayName?.trim().orEmpty()
                    _phase.value = InvitationPhase.Preview(therapistDisplayName.orEmpty())
                    telemetry?.event(com.cbtipul.app.telemetry.Stage.previewShown)
                } else {
                    _phase.value = InvitationPhase.Unavailable(preview.status)
                    telemetry?.event(com.cbtipul.app.telemetry.Stage.failed,error=com.cbtipul.app.telemetry.SafeError.unavailable)
                }
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                if (request == generation && _phase.value is InvitationPhase.Loading) { _phase.value = InvitationPhase.Failed; telemetry?.event(com.cbtipul.app.telemetry.Stage.failed,error=com.cbtipul.app.telemetry.SafeError.generic) }
            }
        }
    }

    fun continueToConsent() {
        if (_phase.value is InvitationPhase.Preview) _phase.value = InvitationPhase.Consent
    }
    fun returnToPreview() {
        if (!inFlight && token != null) _phase.value = InvitationPhase.Preview(therapistDisplayName.orEmpty())
    }
    fun accept() {
        if (_phase.value !is InvitationPhase.Consent && _phase.value !is InvitationPhase.ActivationFailed) return
        launchActivation(null)
    }
    fun confirmTherapistSwitch() {
        if (_phase.value !is InvitationPhase.ConfirmTherapistSwitch) return
        val identity = switchUserId ?: return
        launchActivation(identity)
    }

    private fun launchActivation(confirmedTherapist: String?) {
        if (inFlight) return
        telemetry?.event(com.cbtipul.app.telemetry.Stage.started)
        var telemetrySuccess = false
        inFlight = true
        _phase.value = InvitationPhase.Activating
        scope.launch {
            val d = dependencies
            var failure: ActivationFailure = ActivationFailure.SignIn
            try {
                d.awaitInitialization()
                telemetry=telemetry?.rebound()
                var session = d.session()
                if (activationIdentity != null && session != activationIdentity) {
                    _phase.value = InvitationPhase.ActivationFailed(ActivationFailure.SignIn)
                    return@launch
                }
                if (session != null && !session.isAnonymous) {
                    if (didSucceedClaim) {
                        _phase.value = InvitationPhase.ActivationFailed(ActivationFailure.Context); return@launch
                    }
                    if (confirmedTherapist != session.userId) {
                        switchUserId = session.userId
                        _phase.value = InvitationPhase.ConfirmTherapistSwitch
                        telemetrySuccess = true
                        return@launch
                    }
                    telemetry?.event(com.cbtipul.app.telemetry.Stage.roleSwitchConfirmed,previous=com.cbtipul.app.telemetry.Role.therapist)
                    d.clearContext()
                    d.signOutLocally(session.userId)
                    check(d.session() == null)
                    session = null
                } else if (confirmedTherapist != null) {
                    _phase.value = InvitationPhase.ActivationFailed(ActivationFailure.SignIn); return@launch
                }
                if (!didSucceedClaim) {
                    if (session != null) {
                        failure = ActivationFailure.Context
                        val context = d.context()
                        check(d.session() == session)
                        // The public preview has no patient ID. Do not guess whether
                        // this is the same patient or silently rebind a connected one.
                        // Incomplete does not establish that a restored identity
                        // has never been bound. Reuse only our current activation's
                        // newly created anonymous identity for same-token retries.
                        if (activationIdentity == null || context.patientId != null || context.isActivePatient) {
                            _phase.value = InvitationPhase.ExistingPatient; return@launch
                        }
                        check(context.isIncompletePatient)
                    } else {
                        failure = ActivationFailure.SignIn
                        d.signInAnonymously()
                    }
                    val anonymous = d.session()
                    check(anonymous != null && anonymous.isAnonymous)
                    telemetry = telemetry?.rebound()
                    if(confirmedTherapist!=null) telemetry?.event(com.cbtipul.app.telemetry.Stage.roleSwitchConfirmed,previous=com.cbtipul.app.telemetry.Role.therapist)
                    activationIdentity = anonymous
                    failure = ActivationFailure.Claim(null)
                    val currentToken = checkNotNull(token)
                    claimedPatientId = com.cbtipul.app.telemetry.telemetryRequest(com.cbtipul.app.telemetry.Request.invitationClaim,parent=telemetry) { d.claim(currentToken) }
                    didSucceedClaim = true
                }
                failure = ActivationFailure.Context
                check(d.session() == activationIdentity)
                d.clearContext()
                val context = d.context()
                check(d.session() == activationIdentity && context.isActivePatient && context.patientId == claimedPatientId)
                telemetry?.event(com.cbtipul.app.telemetry.Stage.succeeded)
                telemetrySuccess = true
                token = null
                therapistDisplayName = null
                _phase.value = InvitationPhase.Idle
            } catch (error: CancellationException) {
                telemetry?.event(com.cbtipul.app.telemetry.Stage.cancelled,error=com.cbtipul.app.telemetry.SafeError.cancelled)
                telemetrySuccess = true
                _phase.value = InvitationPhase.ActivationFailed(failure)
                throw error
            } catch (error: PatientInvitationClaimError.Status) {
                _phase.value = InvitationPhase.ActivationFailed(ActivationFailure.Claim(error.status))
            } catch (_: PatientInvitationClaimError.Failed) {
                _phase.value = InvitationPhase.ActivationFailed(ActivationFailure.Claim(null))
            } catch (_: Exception) {
                _phase.value = InvitationPhase.ActivationFailed(failure)
            } finally {
                if (!telemetrySuccess) telemetry?.event(com.cbtipul.app.telemetry.Stage.failed,error=com.cbtipul.app.telemetry.SafeError.generic)
                inFlight = false
            }
        }
    }

    fun dismiss() {
        if (inFlight) return
        if(isActive) telemetry?.event(com.cbtipul.app.telemetry.Stage.cancelled,error=com.cbtipul.app.telemetry.SafeError.cancelled)
        telemetry=null
        generation++
        token = null
        therapistDisplayName = null
        didSucceedClaim = false
        activationIdentity = null
        claimedPatientId = null
        switchUserId = null
        _phase.value = InvitationPhase.Idle
    }
}
