package com.cbtipul.app.data

import com.cbtipul.app.model.CBTSessionAnalysis
import com.cbtipul.app.model.Session
import com.cbtipul.app.model.SessionType
import com.cbtipul.app.ui.patients.SessionEditorViewModel
import org.junit.Assert.*
import org.junit.Test
import java.util.Date

class SessionEditorDraftTest {
    @Test fun clearedSummaryWritesExplicitNullInsteadOfOmittingTheUpdate() = kotlinx.coroutines.runBlocking {
        val draft = SessionEditorViewModel().getOrCreate(Session(notes = "Saved summary"))
        draft.notes = ""
        assertNotEquals(draft.baselineNotes, draft.snapshot().notes)
        val gate = ClinicalTextGate { error("Empty notes must not require AI") }
        val prepared = gate.prepare(draft.snapshot().notes)
        val body = PatientRepository.sessionWriteBody(draft.date, prepared, draft.type)
        assertTrue(body.containsKey("notes"))
        assertEquals(kotlinx.serialization.json.JsonNull, body["notes"])
        val populated = PatientRepository.sessionWriteBody(draft.date, "Summary", draft.type)
        assertEquals(kotlinx.serialization.json.JsonPrimitive("Summary"), populated["notes"])
    }

    @Test fun acceptingAiSummaryChangesOnlyTheDraftUntilTheSessionIsSaved() {
        val original = CBTSessionAnalysis(sessionSummary = "Original summary")
        val draft = SessionEditorViewModel().getOrCreate(Session(notes = "Authored notes", structuredNotes = original))
        val updated = CBTSessionAnalysis(sessionSummary = "Reviewed AI summary")
        val beforeSave = draft.saveRevision

        draft.acceptAnalysis(updated)
        assertEquals(updated, draft.snapshot().structuredNotes)
        assertEquals(original, draft.baselineStructured)
        assertEquals("Authored notes", draft.notes)
        assertEquals("Authored notes", draft.baselineNotes)
        assertEquals(beforeSave, draft.saveRevision)

        draft.markSaved(draft.snapshot())
        assertEquals(updated, draft.baselineStructured)
        assertEquals("Authored notes", draft.notes)
        assertEquals(beforeSave + 1, draft.saveRevision)
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
        val beforeSave = draft.saveRevision
        draft.markSaved(saved)
        assertEquals(beforeSave + 1, draft.saveRevision)
        assertEquals(draft.notes, draft.baselineNotes)
        assertEquals(draft.type, draft.baselineType)
        draft.notes = "Changed after saving"
        assertNotEquals(draft.notes, draft.baselineNotes)
        assertEquals("Local sample note", draft.baselineNotes)
        assertEquals(beforeSave + 1, draft.saveRevision)
    }

    @Test fun newSessionDetailsDoNotRevealOrRequireSummaryTools() {
        val draft = SessionEditorViewModel().getOrCreate(Session())
        draft.date = Date(1_800_000_000_000L)
        draft.type = SessionType.Intake
        draft.notes = "  "
        assertFalse(draft.hasSummaryDraft)
        assertNull(draft.snapshot().structuredNotes)
    }

    @Test fun clearingSummaryKeepsItsEditorToolsAvailableForTheCurrentDraft() {
        val owner = SessionEditorViewModel()
        val draft = owner.getOrCreate(Session(notes = "Recovered notes"))
        draft.notes = ""
        assertTrue(draft.hasSummaryDraft)
        assertTrue(owner.getOrCreate(Session()).hasSummaryDraft)
        assertEquals("", draft.snapshot().notes)
    }
}
