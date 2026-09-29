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
class PatientDiaryTwoViewModelTest {
    private class FakeService : PatientDiaryTwoAccess {
        var calls = 0
        var rows = emptyList<DiaryTwoEntry>()
        var error: PatientDiaryTwoSubmitError? = null
        var gate: CompletableDeferred<Unit>? = null
        override suspend fun loadPatientCreatedEntries(patientId: String) = rows
        override suspend fun submitEntry(request: SubmitDiaryTwoEntryRequest): String {
            calls++; gate?.await(); error?.let { throw it }
            rows = listOf(DiaryTwoEntry("entry-id", DatabaseId.Text("p1"), "t1", DiaryOneEntryCreator.Patient,
                request.event, request.automaticThoughts, request.feelings, request.thinkingErrors, request.alternativeThoughts, Date(1), Date(1))) + rows
            return "entry-id"
        }
    }
    private val draft = DiaryTwoEntryDraft(event = "e", automaticThoughts = listOf(DiaryAutomaticThoughtDraft(text = "a")),
        feelings = listOf(DiaryFeelingDraft(name = "עצוב", intensity = 20)), thinkingErrors = listOf(ThinkingError.MindReading),
        alternativeThoughts = listOf(DiaryAutomaticThoughtDraft(text = "b")))

    @Test fun successfulSubmitIsSingleShotAcrossRecreationAndHubRefreshShowsEntry() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            val service = FakeService().apply { gate = CompletableDeferred() }
            val saved = SavedStateHandle()
            val form = PatientDiaryTwoViewModel("p1", service, saved)
            form.submit(draft); form.submit(draft)
            runCurrent(); assertEquals(1, service.calls)
            assertTrue(form.state.value.submitting)
            service.gate!!.complete(Unit); advanceUntilIdle()
            assertEquals("entry-id", form.state.value.submittedId)
            form.submit(draft); advanceUntilIdle(); assertEquals(1, service.calls)
            val recreated = PatientDiaryTwoViewModel("p1", service, saved)
            recreated.submit(draft); advanceUntilIdle(); assertEquals(1, service.calls)
            val hub = PatientDiaryTwoViewModel("p1", service, SavedStateHandle())
            hub.refresh(); advanceUntilIdle()
            assertEquals("entry-id", hub.state.value.entries.single().id)
            assertFalse(hub.state.value.historyFailed)
            // Patient service deliberately exposes no complete/cancel assignment operation.
            val nextForm = PatientDiaryTwoViewModel("p1", service, SavedStateHandle())
            nextForm.submit(draft); advanceUntilIdle(); assertEquals(2, service.calls)
        } finally { Dispatchers.resetMain() }
    }
    @Test fun cancelledAssignmentProducesExitStateAndInvalidFormsNeverSubmit() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            val service = FakeService().apply { error = PatientDiaryTwoService.mapError("diary_two_not_active", 400) }
            val form = PatientDiaryTwoViewModel("p1", service, SavedStateHandle())
            form.submit(draft.copy(event = " ")); advanceUntilIdle()
            assertEquals(0, service.calls)
            form.submit(draft); advanceUntilIdle()
            assertEquals(PatientDiaryTwoSubmitError.Kind.NotActive, form.state.value.error?.kind)
            assertNull(form.state.value.submittedId)
            assertFalse(form.state.value.submitting)
        } finally { Dispatchers.resetMain() }
    }
}
