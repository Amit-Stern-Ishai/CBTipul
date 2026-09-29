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
class DiaryThreeViewModelTest {
    @Test fun createEditDeleteRefreshHistoryAndDraftSurvivesRecreation() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        val client = createSupabaseClient("https://example.invalid", "test") {}
        try {
            val repo = DiaryThreeRepository(client)
            val assignments = PatientAssignmentRepository(client)
            val patient = DatabaseId.Text("demo-vm-test")
            val saved = SavedStateHandle()
            val vm = DiaryThreeViewModel(patient, repo, assignments, true, saved)
            advanceUntilIdle()
            assertEquals(DiaryThreeConnection.NotConnected, vm.state.value.connection)
            vm.openEditor(null)
            val draft = DiaryThreeEntryDraft(situation = " situation ",
                automaticThoughts = listOf(DiaryThreeAutomaticThoughtDraft(text = " one ", beliefBefore = 100, beliefAfter = 0), DiaryThreeAutomaticThoughtDraft(text = "two", beliefBefore = 90, beliefAfter = 35)),
                feelings = listOf(DiaryThreeFeelingDraft(name = "עצוב", intensityBefore = 85, intensityAfter = 40)),
                thinkingErrors = listOf(ThinkingError.MindReading),
                alternativeThoughts = listOf(DiaryThreeAlternativeThoughtDraft(text = "a", belief = 0), DiaryThreeAlternativeThoughtDraft(text = "b", belief = 100)))
            vm.changeDraft(draft)
            assertTrue(vm.hasChanges())
            val restored = DiaryThreeViewModel(patient, repo, assignments, true, saved)
            restored.openEditor(null)
            assertEquals(draft, restored.draft.value)
            var returnedToHistory = false
            restored.save(null) { returnedToHistory = true }
            advanceUntilIdle()
            assertTrue(returnedToHistory)
            val entry = repo.entriesFor(patient).single()
            assertEquals("situation", entry.situation)
            assertEquals(listOf("one", "two"), entry.automaticThoughts.map { it.text })
            restored.openEditor(entry.id)
            assertEquals(listOf("a", "b"), restored.draft.value.persistedAlternativeThoughts.map { it.text })
            restored.changeDraft(restored.draft.value.copy(situation = "edited"))
            var returnedToDetail = false
            restored.save(entry.id) { returnedToDetail = true }
            advanceUntilIdle()
            assertTrue(returnedToDetail)
            assertEquals("edited", repo.entriesFor(patient).single().situation)
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
