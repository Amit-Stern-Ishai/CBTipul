package com.cbtipul.app.data

import com.cbtipul.app.telemetry.*
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.runCurrent
import org.junit.Assert.*
import org.junit.Test
import org.junit.After
import java.util.UUID
import java.io.IOException

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class TelemetryFlowTest {
    private val previous=Telemetry.client
    private val captured=RecordingCapture()
    private fun client()=TelemetryClient({Metadata()},captured)
    @After fun reset(){Telemetry.install(previous);Entitlements.clear()}
    @Test fun invitationConfirmationCancellationAndSuccessDoNotContainTokensOrNames()=runTest {
        val c=client();c.setOwner("therapist-secret",Role.therapist)
        var session:InvitationSession?=InvitationSession("therapist-secret",false)
        var claimed=false;var claims=0
        val deps=InvitationDependencies(preview={PatientInvitationPreview(PatientInvitationPreviewStatus.Valid,"clinical therapist name")},awaitInitialization={},session={session},signOutLocally={session=null;c.setOwner(null,Role.unknown)},signInAnonymously={session=InvitationSession("patient-secret",true);c.setOwner("patient-secret",Role.patient)},clearContext={},context={AppContext(role=AppRole.Patient,activation=if(claimed) PatientActivation.Active else PatientActivation.Incomplete,patientId=if(claimed) "clinical-patient-id" else null)},claim={claimed=true;claims++;"clinical-patient-id"})
        val flow=PatientInvitationFlow(deps,this,c);flow.start("secret-token",Start.cold);runCurrent()
        val correlation=captured.events.first().correlationID
        assertTrue(captured.events.any {it.stage==Stage.previewShown});flow.continueToConsent();flow.accept();runCurrent()
        assertEquals(InvitationPhase.ConfirmTherapistSwitch,flow.phase.value)
        flow.confirmTherapistSwitch();runCurrent();assertEquals(InvitationPhase.Idle,flow.phase.value);assertEquals(1,claims)
        assertTrue(captured.events.any {it.stage==Stage.roleSwitchConfirmed && it.previousRole==Role.therapist})
        assertTrue(captured.events.any {it.stage==Stage.succeeded});assertTrue(captured.events.all {it.correlationID==correlation})
        val json=kotlinx.serialization.json.Json.encodeToString(kotlinx.serialization.builtins.ListSerializer(Event.serializer()),captured.events)
        for(secret in listOf("secret-token","clinical therapist name","patient-secret","clinical-patient-id")) assertFalse(json.contains(secret))
        flow.start("warm-secret",Start.warm);runCurrent();flow.dismiss();assertTrue(captured.events.any {it.stage==Stage.cancelled})
    }
    @Test fun accessRetryAndConfirmedReadOnlyAreDistinctFromMissingContext()=runTest {
        val c=client();Telemetry.install(c);var requests=0
        val repo=AppContextRepository(AppContextDependencies({}, {"local-private-id"}, {requests++;if(requests==1) throw IOException("clinical response");AppContext(role=AppRole.Therapist,entitlement=AppEntitlement(EntitlementAccess.ReadOnly))},{},retryDelaysMillis=listOf(1)))
        repo.getCurrentAppContext();assertTrue(captured.events.any {it.flow==Flow.access && it.stage==Stage.retry && it.attempt==2})
        assertTrue(captured.events.any {it.flow==Flow.access && it.access==Access.read_only})
        val missing=AppContextRepository(AppContextDependencies({}, {"local-private-id"},{AppContext(role=AppRole.Therapist)},{},retryDelaysMillis=emptyList()))
        missing.getCurrentAppContext();assertTrue(captured.events.any {it.error==SafeError.unresolved && it.access==null})
        assertTrue(captured.events.none {it.flow==Flow.access && it.stage==Stage.failed && it.access!=null})
    }
    @Test fun submissionRequestSharesCorrelationAndPreservesOriginalError()=runTest {
        val c=client();Telemetry.install(c);val failure=IllegalArgumentException("clinical data")
        try {Telemetry.measure(Flow.submission,form=Form.questionnaire) {op->telemetryRequest(Request.questionnaireSubmit,parent=op){throw failure}};fail()}catch(e:IllegalArgumentException){assertSame(failure,e)}
        val events=captured.events;assertTrue(events.any {it.flow==Flow.request});assertEquals(1,events.map {it.correlationID}.distinct().size)
        assertTrue(events.all {it.valid()})
    }
}
