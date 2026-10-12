package com.cbtipul.app.data

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PatientInvitationFlowTest {
    private val therapist = InvitationSession("therapist", false)
    private val patient = InvitationSession("patient", true)
    private class Fixture(var session: InvitationSession? = null) {
        var initialize: suspend () -> Unit = {}
        var preview: suspend (String) -> PatientInvitationPreview = { PatientInvitationPreview(PatientInvitationPreviewStatus.Valid, "מטפל/ת") }
        var existingContext = AppContext(role = AppRole.Patient, activation = PatientActivation.Incomplete)
        var signOuts = 0; var signIns = 0; var claims = 0; var clears = 0
        var claimFailures = 0; var contextFailures = 0; var existingContextFailures = 0; var signInFailures = 0
        var claimed = false
        var signInReturnsTherapist = false
        var afterClaim: () -> Unit = {}
        fun flow(scope: CoroutineScope) = PatientInvitationFlow(InvitationDependencies(
            preview = { preview(it) },
            awaitInitialization = { initialize() },
            session = { session },
            signOutLocally = { expected ->
                assertEquals(expected, session?.userId); assertEquals(false, session?.isAnonymous)
                signOuts++; session = null
            },
            signInAnonymously = {
                signIns++
                if (signInFailures > 0) { signInFailures--; error("fixture sign in failure") }
                session = InvitationSession("anonymous", !signInReturnsTherapist)
            },
            clearContext = { clears++ },
            context = {
                if (!claimed) {
                    if (existingContextFailures > 0) { existingContextFailures--; error("fixture context failure") }
                    existingContext
                } else {
                    if (contextFailures > 0) { contextFailures--; error("fixture context failure") }
                    AppContext(role = AppRole.Patient, activation = PatientActivation.Active, patientId = "mock-patient")
                }
            },
            claim = { token ->
                assertTrue(session?.isAnonymous == true); assertEquals("mock-invitation", token)
                claims++
                if (claimFailures > 0) { claimFailures--; throw PatientInvitationClaimError.Failed }
                claimed = true; afterClaim(); "mock-patient"
            },
        ), scope)
    }

    @Test fun coldAndWarmStartReserveRootBeforeAsyncPreview() = runTest {
        for (warm in listOf(false, true)) {
            val f = Fixture(if (warm) therapist else null); val flow = f.flow(this)
            flow.start("mock-invitation")
            assertEquals(InvitationPhase.Loading, flow.phase.value)
            assertEquals(AppRootDestination.Invitation, AppRootRouting.destination(flow.isActive, warm, false))
            runCurrent(); assertTrue(flow.phase.value is InvitationPhase.Preview)
        }
    }

    @Test fun restoredTherapistNeedsConfirmationAndCancelPreservesSession() = runTest {
        val f = Fixture(therapist); val flow = f.flow(this)
        flow.start("mock-invitation"); runCurrent(); flow.continueToConsent(); flow.accept(); runCurrent()
        assertEquals(InvitationPhase.ConfirmTherapistSwitch, flow.phase.value)
        assertEquals(0, f.signOuts); assertEquals(0, f.signIns); assertEquals(0, f.claims); assertEquals(0, f.clears)
        flow.dismiss(); assertEquals(therapist, f.session)
        assertEquals(AppRootDestination.Therapist, AppRootRouting.destination(flow.isActive, true, false))
    }

    @Test fun confirmedSwitchSignsOutLocallyThenCreatesAnonymousSessionAndClaims() = runTest {
        val f = Fixture(therapist); val flow = f.flow(this)
        flow.start("mock-invitation"); runCurrent(); flow.continueToConsent(); flow.accept(); runCurrent()
        flow.confirmTherapistSwitch(); runCurrent()
        assertEquals(InvitationPhase.Idle, flow.phase.value)
        assertEquals(1, f.signOuts); assertEquals(1, f.signIns); assertEquals(1, f.claims)
        assertTrue(f.session?.isAnonymous == true); assertNull(flow.token)
    }

    @Test fun delayedSessionRestoreCannotSkipConfirmation() = runTest {
        val gate = CompletableDeferred<Unit>(); val f = Fixture(); f.initialize = { gate.await() }
        val flow = f.flow(this)
        flow.start("mock-invitation"); runCurrent(); flow.continueToConsent(); flow.accept(); runCurrent()
        assertEquals(InvitationPhase.Activating, flow.phase.value)
        f.session = therapist; gate.complete(Unit); runCurrent()
        assertEquals(InvitationPhase.ConfirmTherapistSwitch, flow.phase.value)
        assertEquals(0, f.claims); assertEquals(0, f.signIns)
    }

    @Test fun differentTherapistWhileConfirmingRequiresFreshConfirmation() = runTest {
        val f = Fixture(therapist); val flow = f.flow(this)
        flow.start("mock-invitation"); runCurrent(); flow.continueToConsent(); flow.accept(); runCurrent()
        f.session = InvitationSession("other", false)
        flow.confirmTherapistSwitch(); runCurrent()
        assertEquals(InvitationPhase.ConfirmTherapistSwitch, flow.phase.value)
        assertEquals(0, f.signOuts); assertEquals(0, f.claims)
    }

    @Test fun claimFailureRetainsTokenAndRetryUsesSameAnonymousSession() = runTest {
        val f = Fixture(); f.claimFailures = 1; val flow = f.flow(this)
        flow.start("mock-invitation"); runCurrent(); flow.continueToConsent(); flow.accept(); runCurrent()
        assertEquals(InvitationPhase.ActivationFailed(ActivationFailure.Claim(null)), flow.phase.value)
        assertEquals("mock-invitation", flow.token)
        flow.accept(); runCurrent()
        assertEquals(InvitationPhase.Idle, flow.phase.value); assertEquals(2, f.claims); assertEquals(1, f.signIns)
    }

    @Test fun contextRetryAfterClaimDoesNotClaimTwice() = runTest {
        val f = Fixture(); f.contextFailures = 1; val flow = f.flow(this)
        flow.start("mock-invitation"); runCurrent(); flow.continueToConsent(); flow.accept(); runCurrent()
        assertEquals(InvitationPhase.ActivationFailed(ActivationFailure.Context), flow.phase.value)
        assertTrue(flow.didSucceedClaim)
        flow.accept(); runCurrent()
        assertEquals(InvitationPhase.Idle, flow.phase.value); assertEquals(1, f.claims); assertEquals(1, f.signIns)
    }

    @Test fun anonymousSignInFailureAfterSwitchCanRetry() = runTest {
        val f = Fixture(therapist); f.signInFailures = 1; val flow = f.flow(this)
        flow.start("mock-invitation"); runCurrent(); flow.continueToConsent(); flow.accept(); runCurrent()
        flow.confirmTherapistSwitch(); runCurrent()
        assertEquals(InvitationPhase.ActivationFailed(ActivationFailure.SignIn), flow.phase.value)
        assertNotNull(flow.token); assertEquals(0, f.claims)
        flow.accept(); runCurrent()
        assertEquals(InvitationPhase.Idle, flow.phase.value); assertEquals(1, f.signOuts); assertEquals(2, f.signIns)
    }

    @Test fun sameAndDifferentInvitationsNeverRebindConnectedPatient() = runTest {
        for (token in listOf("same-invitation", "different-invitation")) {
            val f = Fixture(patient)
            f.existingContext = AppContext(role = AppRole.Patient, activation = PatientActivation.Active, patientId = "current-patient")
            val flow = f.flow(this)
            flow.start(token); runCurrent(); flow.continueToConsent(); flow.accept(); runCurrent()
            assertEquals(InvitationPhase.ExistingPatient, flow.phase.value)
            assertEquals(patient, f.session); assertEquals(0, f.signOuts); assertEquals(0, f.signIns); assertEquals(0, f.claims)
            flow.dismiss(); assertEquals(patient, f.session)
        }
    }

    @Test fun existingPatientContextFailurePreservesConnectionAndRetryCannotClaimBlindly() = runTest {
        val f = Fixture(patient); f.existingContextFailures = 1
        f.existingContext = AppContext(role = AppRole.Patient, activation = PatientActivation.Active, patientId = "current-patient")
        val flow = f.flow(this)
        flow.start("mock-invitation"); runCurrent(); flow.continueToConsent(); flow.accept(); runCurrent()
        assertEquals(InvitationPhase.ActivationFailed(ActivationFailure.Context), flow.phase.value)
        assertEquals(patient, f.session); flow.accept(); runCurrent()
        assertEquals(InvitationPhase.ExistingPatient, flow.phase.value)
        assertEquals(0, f.claims); assertEquals(0, f.signOuts)
    }

    @Test fun restoredIncompletePatientCannotBeAssumedUnbound() = runTest {
        val f = Fixture(patient); val flow = f.flow(this)
        flow.start("mock-invitation"); runCurrent(); flow.continueToConsent(); flow.accept(); runCurrent()
        assertEquals(InvitationPhase.ExistingPatient, flow.phase.value); assertEquals(patient, f.session)
        assertEquals(0, f.signIns); assertEquals(0, f.claims)
    }

    @Test fun unexpectedTherapistAfterSignInCannotClaim() = runTest {
        val f = Fixture(); f.signInReturnsTherapist = true; val flow = f.flow(this)
        flow.start("mock-invitation"); runCurrent(); flow.continueToConsent(); flow.accept(); runCurrent()
        assertEquals(0, f.claims); assertTrue(flow.isActive)
    }

    @Test fun changedIdentityAfterClaimCannotFinishOrReclaim() = runTest {
        val f = Fixture(); f.afterClaim = { f.session = therapist }; val flow = f.flow(this)
        flow.start("mock-invitation"); runCurrent(); flow.continueToConsent(); flow.accept(); runCurrent()
        assertEquals(InvitationPhase.ActivationFailed(ActivationFailure.Context), flow.phase.value)
        flow.accept(); runCurrent(); assertEquals(1, f.claims); assertTrue(flow.isActive)
    }

    @Test fun stalePreviewAndDuplicateIntentDoNotOverrideConsent() = runTest {
        val gate = CompletableDeferred<Unit>(); val f = Fixture()
        f.preview = { token ->
            if (token == "old") gate.await()
            PatientInvitationPreview(PatientInvitationPreviewStatus.Valid, token)
        }
        val flow = f.flow(this)
        flow.start("old"); runCurrent(); flow.start("mock-invitation"); runCurrent()
        flow.continueToConsent(); flow.start("mock-invitation"); gate.complete(Unit); runCurrent()
        assertEquals(InvitationPhase.Consent, flow.phase.value); assertEquals("mock-invitation", flow.token)
    }

    @Test fun incomingIntentAndDismissCannotLoseAcceptedTokenWhileActivating() = runTest {
        val gate = CompletableDeferred<Unit>(); val f = Fixture(); f.initialize = { gate.await() }; val flow = f.flow(this)
        flow.start("mock-invitation"); runCurrent(); flow.continueToConsent(); flow.accept(); runCurrent()
        flow.start("other"); flow.dismiss(); assertEquals("mock-invitation", flow.token)
        gate.complete(Unit); runCurrent(); assertEquals(InvitationPhase.Idle, flow.phase.value)
    }

    @Test fun ordinaryUpdateAndRestoredLegacyBackupNeverClearSessionOnInitialization() = runTest {
        for (scenario in listOf("ordinary-update-pre-marker", "legacy-restored-backup", "device-transfer")) {
            val f = Fixture(therapist); val flow = f.flow(this)
            assertEquals(therapist, f.session); assertEquals(0, f.signOuts)
            flow.start("mock-invitation"); runCurrent(); flow.dismiss()
            assertEquals(therapist, f.session); assertEquals(0, f.signOuts); assertEquals(0, f.claims)
        }
    }
}
