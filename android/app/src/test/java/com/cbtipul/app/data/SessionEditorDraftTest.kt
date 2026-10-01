package com.cbtipul.app.data

import com.cbtipul.app.model.CBTSessionAnalysis
import com.cbtipul.app.model.Session
import com.cbtipul.app.model.SessionType
import com.cbtipul.app.ui.patients.SessionEditorViewModel
import org.junit.Assert.*
import org.junit.Test
import java.util.Date

class SessionEditorDraftTest {
    @Test fun editingNotesAllowsRegenerationUntilUpdatedDraftIsAccepted() {
        val original = CBTSessionAnalysis(sessionSummary = "Original summary")
        val draft = SessionEditorViewModel().getOrCreate(Session(notes = "Original notes", structuredNotes = original))
        assertFalse(draft.canGenerateAnalysis)
        draft.notes = "Updated notes"
        assertTrue(draft.canGenerateAnalysis)
        draft.generatedAnalysisSource = draft.notes
        // Merely generating or leaving review does not replace the accepted summary.
        assertEquals(original, draft.structuredNotes)
        assertTrue(draft.canGenerateAnalysis)
        draft.acceptAnalysis(CBTSessionAnalysis(sessionSummary = "Updated summary"), generated = true)
        assertFalse(draft.canGenerateAnalysis)
        draft.notes = "Another edit"
        draft.markSaved(draft.snapshot())
        assertTrue(draft.canGenerateAnalysis)
        draft.notes = ""
        assertFalse(draft.canGenerateAnalysis)
    }

    @Test fun returningFromDiscardedAiSummaryKeepsTranscriptionAndSessionDetails() {
        val owner = SessionEditorViewModel()
        val original = Session()
        val draft = owner.getOrCreate(original)
        draft.selectedPatientId = "patient-a"
        draft.date = Date(1_800_000_000_000L)
        draft.type = SessionType.entries.first()
        draft.notes = "Recorded and transcribed session notes"
        draft.structuredNotes = CBTSessionAnalysis(sessionSummary = "AI summary")

        // The summary's Leave without saving action discards only the AI result.
        draft.structuredNotes = null
        val returned = owner.getOrCreate(Session())
        assertSame(draft, returned)
        assertEquals(original.id, returned.snapshot().id)
        assertEquals("Recorded and transcribed session notes", returned.notes)
        assertEquals("patient-a", returned.selectedPatientId)
        assertEquals(Date(1_800_000_000_000L), returned.date)
        assertEquals(SessionType.entries.first(), returned.type)
        assertNull(returned.structuredNotes)
        assertEquals("", returned.baselineNotes)
    }

    @Test fun savingAiEditsUpdatesTheSameDraftWithoutReplacingTheTranscript() {
        val owner = SessionEditorViewModel()
        val draft = owner.getOrCreate(Session(notes = "transcript"))
        draft.structuredNotes = CBTSessionAnalysis(sessionSummary = "Edited AI summary")
        assertEquals("transcript", owner.getOrCreate(Session()).snapshot().notes)
        assertEquals("Edited AI summary", owner.draft?.snapshot()?.structuredNotes?.sessionSummary)
    }
    @Test fun immediateLocalSaveMarksDraftCleanAndLaterEditsRemainUnsaved() {
        val draft = SessionEditorViewModel().getOrCreate(Session())
        draft.notes = "Local sample note"
        draft.type = SessionType.entries.first()
        val saved = draft.snapshot()

        // A local save can finish before Compose ever observes a loading state.
        draft.markSaved(saved)
        assertEquals(draft.notes, draft.baselineNotes)
        assertEquals(draft.type, draft.baselineType)
        draft.notes = "Changed after saving"
        assertNotEquals(draft.notes, draft.baselineNotes)
        assertEquals("Local sample note", draft.baselineNotes)
    }
}
