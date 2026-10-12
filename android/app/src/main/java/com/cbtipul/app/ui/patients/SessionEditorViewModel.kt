package com.cbtipul.app.ui.patients

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import com.cbtipul.app.model.Session

/** Owned by the editor's back-stack entry, so visiting an AI summary keeps the draft alive. */
class SessionEditorViewModel : ViewModel() {
    var draft: SessionEditorDraft? = null
        private set

    fun getOrCreate(initial: Session): SessionEditorDraft = draft ?: SessionEditorDraft(initial).also { draft = it }
}

@kotlinx.serialization.Serializable
private data class SessionRecovery(
    val date: Long,
    val notes: String,
    val type: com.cbtipul.app.model.SessionType?,
    val structuredNotes: com.cbtipul.app.model.CBTSessionAnalysis?,
    val selectedPatientId: String?,
)

class SessionEditorDraft(val initial: Session) {
    private var recoveryStore: com.cbtipul.app.data.DeviceDraftStorage? = null
    private var recoveryKey: String? = null
    private var recoveryClosed = false
    var recoveryFailed by mutableStateOf(false)
        private set
    var recoverySaved by mutableStateOf(false)
        private set
    var recoveryRestored by mutableStateOf(false)
        private set
    private val json = kotlinx.serialization.json.Json { ignoreUnknownKeys = true; encodeDefaults = true }

    fun configureRecovery(store: com.cbtipul.app.data.DeviceDraftStorage, key: String) {
        if (recoveryKey != null) return
        recoveryStore = store
        recoveryKey = key
        try {
            store.read(key)?.let {
                val saved = json.decodeFromString(SessionRecovery.serializer(), it)
                date = java.util.Date(saved.date)
                notes = saved.notes
                type = saved.type
                structuredNotes = saved.structuredNotes
                selectedPatientId = saved.selectedPatientId
                recoverySaved = true
                recoveryRestored = true
            }
        } catch (_: Exception) { recoveryFailed = true }
    }

    fun persistRecovery(): Boolean {
        if (recoveryClosed || recoveryKey == null) return false
        return try {
            val unchanged = date == baselineDate && notes == baselineNotes && type == baselineType && structuredNotes == baselineStructured
            if (unchanged && recoveryFailed && !recoverySaved) return false
            if (unchanged || (initial.databaseId == null && notes.isBlank() && type == null && structuredNotes == null)) {
                recoveryStore!!.clear(recoveryKey!!)
                recoverySaved = false
            } else {
                recoveryStore!!.write(recoveryKey!!, json.encodeToString(SessionRecovery.serializer(), SessionRecovery(date.time, notes, type, structuredNotes, selectedPatientId)))
                recoverySaved = true
            }
            recoveryFailed = false
            true
        } catch (_: Exception) { recoveryFailed = true; false }
    }

    fun clearRecovery(close: Boolean = false): Boolean = try {
        recoveryKey?.let { recoveryStore?.clear(it) }
        recoveryClosed = close
        recoverySaved = false
        recoveryRestored = false
        recoveryFailed = false
        true
    } catch (_: Exception) { recoveryFailed = true; false }

    var selectedPatientId by mutableStateOf<String?>(null)
    var date by mutableStateOf(initial.date)
    // Keep recovered summary tools available for this draft even if its text is cleared.
    var hasSummaryDraft by mutableStateOf(initial.notes.isNotBlank() || initial.structuredNotes != null)
        private set
    private var draftNotes by mutableStateOf(initial.notes)
    var notes: String
        get() = draftNotes
        set(value) {
            draftNotes = value
            if (value.isNotBlank()) hasSummaryDraft = true
        }
    var type by mutableStateOf(initial.type)
    private var draftStructuredNotes by mutableStateOf(initial.structuredNotes)
    var structuredNotes: com.cbtipul.app.model.CBTSessionAnalysis?
        get() = draftStructuredNotes
        set(value) {
            draftStructuredNotes = value
            if (value != null) hasSummaryDraft = true
        }
    fun acceptAnalysis(analysis: com.cbtipul.app.model.CBTSessionAnalysis) {
        structuredNotes = analysis
    }
    var baselineDate by mutableStateOf(initial.date)
    var baselineNotes by mutableStateOf(initial.notes)
    var baselineType by mutableStateOf(initial.type)
    var baselineStructured by mutableStateOf(initial.structuredNotes)
    var saveRevision by mutableStateOf(0)
        private set

    fun markSaved(saved: Session) {
        clearRecovery(close = initial.databaseId == null)
        baselineDate = saved.date
        baselineNotes = saved.notes
        baselineType = saved.type
        baselineStructured = saved.structuredNotes
        saveRevision += 1
    }

    fun snapshot(): Session = initial.copy(date = date, notes = notes, type = type, structuredNotes = structuredNotes)
}
