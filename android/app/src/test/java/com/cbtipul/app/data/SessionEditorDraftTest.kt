package com.cbtipul.app.data

import com.cbtipul.app.model.CBTSessionAnalysis
import com.cbtipul.app.model.Session
import com.cbtipul.app.model.SessionType
import com.cbtipul.app.ui.patients.SessionEditorViewModel
import org.junit.Assert.*
import org.junit.Test
import java.util.Date

class SessionEditorDraftTest {
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
}
