package com.cbtipul.app.ui.diary

import androidx.lifecycle.SavedStateHandle
import com.cbtipul.app.data.*
import com.cbtipul.app.model.DatabaseId
import io.github.jan.supabase.createSupabaseClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.*
import org.junit.Assert.*
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class DiaryTwoViewModelTest {
    @org.junit.Before fun grantAccess() { Entitlements.apply(AppContext(role = AppRole.Therapist, entitlement = AppEntitlement(EntitlementAccess.Full))) }
    @org.junit.After fun clearAccess() { Entitlements.clear() }
    @Test fun createEditDeleteRefreshHistoryAndDraftSurvivesRecreation() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        val client = createSupabaseClient("https://example.invalid", "test") {}
        try {
            val repo = DiaryTwoRepository(client)
            val assignments = PatientAssignmentRepository(client)
            val patient = DatabaseId.Text("demo-vm-test")
            val saved = SavedStateHandle()
            val vm = DiaryTwoViewModel(patient, repo, assignments, true, saved)
            advanceUntilIdle()
            assertEquals(DiaryTwoConnection.NotConnected, vm.state.value.connection)
            vm.openEditor(null)
            val draft = DiaryTwoEntryDraft(event = " event ",
                automaticThoughts = listOf(DiaryAutomaticThoughtDraft(text = " one "), DiaryAutomaticThoughtDraft(text = "two")),
                feelings = listOf(DiaryFeelingDraft(name = "עצוב", intensity = 25)),
                thinkingErrors = listOf(ThinkingError.MindReading),
                alternativeThoughts = listOf(DiaryAutomaticThoughtDraft(text = "a"), DiaryAutomaticThoughtDraft(text = "b")))
            vm.changeDraft(draft)
            assertTrue(vm.hasChanges())
            val restored = DiaryTwoViewModel(patient, repo, assignments, true, saved)
            restored.openEditor(null)
            assertEquals(draft, restored.draft.value)
            var returnedToHistory = false
            restored.save(null) { returnedToHistory = true }
            advanceUntilIdle()
            assertTrue(returnedToHistory)
            val entry = repo.entriesFor(patient).single()
            assertEquals("event", entry.event)
            assertEquals(listOf("one", "two"), entry.automaticThoughts)
            restored.openEditor(entry.id)
            assertEquals(listOf("a", "b"), restored.draft.value.persistedAlternativeThoughts)
            restored.changeDraft(restored.draft.value.copy(event = "edited"))
            var returnedToDetail = false
            restored.save(entry.id) { returnedToDetail = true }
            advanceUntilIdle()
            assertTrue(returnedToDetail)
            assertEquals("edited", repo.entriesFor(patient).single().event)
            assertEquals(entry.createdAt, repo.entriesFor(patient).single().createdAt)
            var deleted = false
            restored.delete(entry.id) { deleted = true }
            advanceUntilIdle()
            assertTrue(deleted); assertTrue(repo.entriesFor(patient).isEmpty())
            // No Auth or Functions plugin is installed: any assignment operation would fail this test.
            assertNull(restored.state.value.error)
        } finally { client.close(); Dispatchers.resetMain() }
    }
}
