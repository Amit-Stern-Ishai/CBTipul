package com.cbtipul.app.data

import com.cbtipul.app.model.*
import com.cbtipul.app.ui.patients.SessionEditorDraft
import org.junit.Assert.*
import org.junit.Test
import java.util.Date

class SessionRecoveryTest {
    private class MemoryStorage : DeviceDraftStorage {
        val values = mutableMapOf<String, String>()
        var failReads = false
        var failWrites = false
        override fun read(key: String): String? { check(!failReads); return values[key] }
        override fun write(key: String, value: String) { check(!failWrites); values[key] = value }
        override fun clear(key: String) { values.remove(key) }
    }
    @Test fun newEditorRestoresAllFieldsWithoutSavingClinicalRecord() {
        val storage = MemoryStorage()
        val first = SessionEditorDraft(Session())
        first.configureRecovery(storage, "account:patient:new")
        first.notes = "Typed or transcribed notes"
        first.date = Date(1234567)
        first.type = SessionType.Intake
        first.selectedPatientId = "patient-a"
        first.structuredNotes = CBTSessionAnalysis(sessionSummary = "Accepted AI summary")
        assertTrue(first.persistRecovery())
        val restored = SessionEditorDraft(Session())
        restored.configureRecovery(storage, "account:patient:new")
        assertEquals(first.notes, restored.notes)
        assertEquals(first.date, restored.date)
        assertEquals(first.type, restored.type)
        assertEquals(first.structuredNotes, restored.structuredNotes)
        assertEquals("patient-a", restored.selectedPatientId)
        assertTrue(restored.recoveryRestored)
        assertTrue(restored.hasSummaryDraft)
        assertNull(restored.snapshot().databaseId)
        assertEquals("", restored.baselineNotes)
    }
    @Test fun savedOrDiscardedNewSessionDoesNotReappearOnDispose() {
        for (save in listOf(true, false)) {
            val storage = MemoryStorage()
            val draft = SessionEditorDraft(Session())
            draft.configureRecovery(storage, "key")
            draft.notes = "New notes"
            draft.persistRecovery()
            if (save) draft.markSaved(draft.snapshot()) else draft.clearRecovery(close = true)
            draft.persistRecovery()
            assertNull(storage.read("key"))
        }
    }
    @Test fun failedRestoreDoesNotEraseThePreviousSnapshot() {
        val storage = MemoryStorage()
        storage.values["key"] = "previous snapshot"
        storage.failReads = true
        val draft = SessionEditorDraft(Session())
        draft.configureRecovery(storage, "key")
        assertFalse(draft.persistRecovery())
        assertEquals("previous snapshot", storage.values["key"])
        assertTrue(draft.recoveryFailed)
    }
    @Test fun recoveryIsIsolatedAndFailuresAreNotReportedAsSaved() {
        val storage = MemoryStorage()
        val draft = SessionEditorDraft(Session())
        draft.configureRecovery(storage, "account-a:patient-a")
        draft.notes = "Private notes"
        draft.persistRecovery()
        val other = SessionEditorDraft(Session())
        other.configureRecovery(storage, "account-b:patient-a")
        assertEquals("", other.notes)
        storage.failWrites = true
        other.notes = "New work"
        assertFalse(other.persistRecovery())
        assertTrue(other.recoveryFailed)
        assertFalse(other.recoverySaved)
    }
    @Test fun restoredNewDetailsWithoutSummaryKeepCreationSimple() {
        val storage = MemoryStorage()
        val first = SessionEditorDraft(Session())
        first.configureRecovery(storage, "new")
        first.type = SessionType.Intake
        first.date = Date(1234567)
        assertTrue(first.persistRecovery())
        val restored = SessionEditorDraft(Session())
        restored.configureRecovery(storage, "new")
        assertTrue(restored.recoveryRestored)
        assertFalse(restored.hasSummaryDraft)
        assertEquals(SessionType.Intake, restored.type)
    }

    @Test fun recoveredStructuredSummaryRemainsAccessibleAfterClearingIt() {
        val storage = MemoryStorage()
        val first = SessionEditorDraft(Session())
        first.configureRecovery(storage, "new")
        first.structuredNotes = CBTSessionAnalysis(sessionSummary = "Recovered AI draft")
        assertTrue(first.persistRecovery())
        val restored = SessionEditorDraft(Session())
        restored.configureRecovery(storage, "new")
        assertTrue(restored.hasSummaryDraft)
        restored.structuredNotes = null
        assertTrue(restored.hasSummaryDraft)
    }

    @Test fun recoveryWritesAndFailuresDoNotSignalASuccessfulSessionSave() {
        val storage = MemoryStorage()
        val draft = SessionEditorDraft(Session())
        draft.configureRecovery(storage, "new")
        draft.notes = "Unsaved text"
        val beforeSave = draft.saveRevision
        assertTrue(draft.persistRecovery())
        assertEquals(beforeSave, draft.saveRevision)
        storage.failWrites = true
        draft.notes = "Text after failed save"
        assertFalse(draft.persistRecovery())
        assertEquals(beforeSave, draft.saveRevision)
        assertEquals("", draft.baselineNotes)
        assertEquals("Text after failed save", draft.notes)
        draft.markSaved(draft.snapshot())
        assertEquals(beforeSave + 1, draft.saveRevision)
        assertEquals(draft.notes, draft.baselineNotes)
    }

}
