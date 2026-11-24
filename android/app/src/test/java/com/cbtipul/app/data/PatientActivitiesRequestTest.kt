package com.cbtipul.app.data

import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

class PatientActivitiesRequestTest {
    @Test fun readsThenSendsAndRestoresPending() = runBlocking {
        val model = PatientActivitiesRequest()
        val calls = mutableListOf<Boolean>()
        model.run(false, { true }) { calls += it; "no_request" }
        assertEquals(PatientActivitiesRequest.State.Ready, model.state.value)
        model.run(true, { true }) { calls += it; "pending" }
        model.run(true, { true }) { calls += it; "pending" }
        assertEquals(listOf(false, true), calls)
        val reopened = PatientActivitiesRequest()
        reopened.run(false, { true }) { "pending" }
        assertEquals(PatientActivitiesRequest.State.Pending, reopened.state.value)
    }
    @Test fun lostResponseRechecksWithoutResending() = runBlocking {
        val model = PatientActivitiesRequest()
        model.run(false, { true }) { "no_request" }
        val calls = mutableListOf<Boolean>()
        model.run(true, { true }) { send -> calls += send; if (send) throw java.io.IOException(); "pending" }
        assertEquals(listOf(true, false), calls)
        assertEquals(PatientActivitiesRequest.State.Pending, model.state.value)
        assertFalse(model.uncertain.value)
    }
    @Test fun failedStatusBlocksSendUntilReadRetry() = runBlocking {
        val model = PatientActivitiesRequest()
        model.run(false, { true }) { throw java.io.IOException() }
        assertEquals(PatientActivitiesRequest.State.Failed, model.state.value)
        var sent = false
        model.run(true, { true }) { sent = true; "pending" }
        assertFalse(sent)
        model.run(false, { true }) { "activities_available" }
        assertEquals(PatientActivitiesRequest.State.Available, model.state.value)
    }
    @Test fun accountSwitchAndUnknownStatusAreNotSuccess() = runBlocking {
        val model = PatientActivitiesRequest()
        var current = true
        model.run(false, { current }) { current = false; "pending" }
        assertNotEquals(PatientActivitiesRequest.State.Pending, model.state.value)
        model.run(false, { true }) { "unexpected" }
        assertEquals(PatientActivitiesRequest.State.Failed, model.state.value)
    }
    @Test fun failedRecheckRequiresReadRetry() = runBlocking {
        val model = PatientActivitiesRequest()
        model.run(false, { true }) { "no_request" }
        val calls = mutableListOf<Boolean>()
        model.run(true, { true }) { calls += it; throw java.io.IOException() }
        assertEquals(listOf(true, false), calls)
        assertEquals(PatientActivitiesRequest.State.Failed, model.state.value)
        assertTrue(model.uncertain.value)
        model.run(false, { true }) { "no_request" }
        assertEquals(PatientActivitiesRequest.State.Ready, model.state.value)
    }
    @Test fun duplicateTapDuringSubmissionIsIgnored() = runBlocking {
        val model = PatientActivitiesRequest()
        model.run(false, { true }) { "no_request" }
        var duplicate = false
        model.run(true, { true }) {
            model.run(true, { true }) { duplicate = true; "pending" }
            "pending"
        }
        assertFalse(duplicate)
    }
    @Test fun pushSurvivesColdStartAndReusesInboxActionsRoute() {
        val payload = NotificationPayload.from(mapOf("type" to "patient_activities_requested", "patient_id" to "synthetic-patient"))!!
        val store = PendingDestinationStore()
        store.offer(payload)
        assertEquals(AppDestination.PatientDetail("synthetic-patient"), store.pending.value)
        assertEquals("patient/synthetic-patient?connection=send", NotificationRouting.inboxRoute(store.consume()!!))
        assertNull(store.consume())
    }
    @Test fun notificationOpensExactPatientActions() {
        val payload = NotificationPayload(AppNotificationTypes.PATIENT_ACTIVITIES_REQUESTED, null, "synthetic-patient", null, null, null, null)
        val destination = NotificationRouting.destination(payload)!!
        assertEquals(AppDestination.PatientDetail("synthetic-patient"), destination)
        assertEquals("patient/synthetic-patient?connection=send", NotificationRouting.inboxRoute(destination))
        assertEquals(InboxCopyKind.PatientActivitiesRequested, NotificationRouting.inboxCopy(payload.type))
    }
}
