package com.cbtipul.app.ui.patient

import androidx.lifecycle.SavedStateHandle
import com.cbtipul.app.data.*
import com.cbtipul.app.model.DatabaseId
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.*
import org.junit.Assert.*
import org.junit.Test
import java.util.Date

@OptIn(ExperimentalCoroutinesApi::class)
class PatientDiaryThreeViewModelTest {
    @org.junit.Before fun grantFullAccess() {
        com.cbtipul.app.data.Entitlements.apply(com.cbtipul.app.data.AppContext(role = com.cbtipul.app.data.AppRole.Therapist, entitlement = com.cbtipul.app.data.AppEntitlement(com.cbtipul.app.data.EntitlementAccess.Full)))
    }
    @org.junit.After fun clearAccess() { com.cbtipul.app.data.Entitlements.clear() }

    private class Service : PatientDiaryThreeAccess {
        var calls = 0; var rows = emptyList<DiaryThreeEntry>()
        var error: PatientDiaryThreeSubmitError? = null
        var gate: CompletableDeferred<Unit>? = null
        override suspend fun loadPatientCreatedEntries(patientId: String) = rows
        override suspend fun submitEntry(request: SubmitDiaryThreeEntryRequest): String {
            calls++; gate?.await(); error?.let { throw it }
            rows = listOf(DiaryThreeEntry("entry-id", DatabaseId.Text("p1"), "t1", DiaryOneEntryCreator.Patient,
                request.situation, request.automaticThoughts, request.feelings, request.thinkingErrors, request.alternativeThoughts, Date(1), Date(1))) + rows
            return "entry-id"
        }
    }
    private fun draft() = PatientDiaryThreeDraft(DiaryThreeEntryDraft(situation = "e", automaticThoughts = listOf(DiaryThreeAutomaticThoughtDraft(text = "a", beliefBefore = 100, beliefAfter = 0)), feelings = listOf(DiaryThreeFeelingDraft(name = "עצוב", intensityBefore = 100, intensityAfter = 0)), thinkingErrors = listOf(ThinkingError.MindReading), alternativeThoughts = listOf(DiaryThreeAlternativeThoughtDraft(text = "b", belief = 100))), 7)
    @Test fun stateRestorationRetainsSameObjectsAndStepAcrossBackForwardAndNewViewModel() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            var disk: String? = null
            val storage = PatientDiaryThreeDraftPersistence({ disk }, { disk = it }, { disk = null })
            val saved = SavedStateHandle(); val service = Service()
            val vm = PatientDiaryThreeViewModel("p1", service, saved, storage)
            val original = draft()
            vm.update(original.copy(currentStep = 5)); vm.back(); vm.next()
            assertEquals(original.copy(currentStep = 5), vm.state.value.draft)
            vm.update(original); vm.back(); vm.next(); assertEquals(original, vm.state.value.draft)
            val restored = PatientDiaryThreeViewModel("p1", service, SavedStateHandle(mapOf("draft" to saved.get<String>("draft"))), storage)
            assertEquals(original, restored.state.value.draft)
            assertEquals(original, PatientDiaryThreeViewModel("p1", service, SavedStateHandle(), storage).state.value.draft)
            val patient = "22222222-2222-2222-2222-222222222222"
            val assignmentId = "11111111-1111-1111-1111-111111111111"
            val payload = NotificationPayload("diary_3_assigned", "push-id", patient, null, assignmentId, "assignment", assignmentId)
            val pending = PendingDestinationStore(); pending.offer(payload)
            assertTrue(pending.consume() is AppDestination.PatientDiaryThreeForm)
            val active = PatientAssignment(assignmentId, patient, null, null, "diary_three", Date(), null, null)
            assertEquals(active, PatientDiaryThreeNotificationRouting.resolve(payload, patient) { listOf(active) })
            // Push opens the same wizard/ViewModel and device draft, rather than constructing another draft from metadata.
            assertEquals(original, PatientDiaryThreeViewModel("p1", service, SavedStateHandle(), storage).state.value.draft)
            assertEquals(1, PatientDiaryThreeViewModel("fresh", service, SavedStateHandle()).state.value.draft.currentStep)
            assertTrue(restored.clearDraft()); assertNull(disk)
        } finally { Dispatchers.resetMain() }
    }
    @Test fun submissionIsSingleShotCleanupCanRetryAndNavigationIsConsumedOnce() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            val service = Service().apply { gate = CompletableDeferred() }
            var failCleanup = true
            val saved = SavedStateHandle()
            val persistence = PatientDiaryThreeDraftPersistence({ null }, {}, { check(!failCleanup) })
            val vm = PatientDiaryThreeViewModel("p1", service, saved, persistence)
            vm.update(draft()); vm.submit(); vm.submit(); runCurrent(); assertEquals(1, service.calls)
            service.gate!!.complete(Unit); advanceUntilIdle()
            assertEquals("entry-id", vm.state.value.submittedId)
            assertFalse(vm.consumeSuccessfulSubmission()); assertTrue(vm.state.value.navigationPending)
            vm.submit(); advanceUntilIdle(); assertEquals(1, service.calls)
            val restored = PatientDiaryThreeViewModel("p1", service, saved, persistence)
            failCleanup = false
            assertTrue(restored.consumeSuccessfulSubmission()); assertFalse(restored.consumeSuccessfulSubmission())
            assertFalse(restored.state.value.draft.hasMeaningfulContent)
            restored.submit(); advanceUntilIdle(); assertEquals(1, service.calls)
            val hub = PatientDiaryThreeViewModel("p1", service, SavedStateHandle())
            hub.refresh(); advanceUntilIdle(); assertEquals("entry-id", hub.state.value.entries.single().id)
        } finally { Dispatchers.resetMain() }
    }
    @Test fun invalidStagesNeverSubmitAndCancellationBlocksFurtherAttempts() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            val service = Service().apply { error = PatientDiaryThreeService.mapError("diary_three_not_active", 400) }
            val vm = PatientDiaryThreeViewModel("p1", service, SavedStateHandle())
            vm.next(); assertEquals(1, vm.state.value.draft.currentStep); assertNotNull(vm.state.value.error)
            vm.update(draft().copy(entry = draft().entry.copy(automaticThoughts = listOf(DiaryThreeAutomaticThoughtDraft(text = "a", beliefBefore = 50)))))
            vm.submit(); advanceUntilIdle(); assertEquals(0, service.calls); assertEquals(6, vm.state.value.draft.currentStep)
            vm.update(draft()); vm.submit(); advanceUntilIdle()
            assertEquals(PatientDiaryThreeSubmitError.Kind.NotActive, vm.state.value.error?.kind)
            assertNull(vm.state.value.submittedId); assertFalse(vm.state.value.submitting)
            vm.submit(); advanceUntilIdle(); assertEquals(1, service.calls)
        } finally { Dispatchers.resetMain() }
    }
}
