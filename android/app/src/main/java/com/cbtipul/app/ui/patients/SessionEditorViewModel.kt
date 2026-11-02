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
    val audioName: String? = null,
    val audioSeconds: Double = 0.0,
    val transcriptReady: Boolean = false,
    val preparedSource: String? = null,
    val preparedText: String? = null,
    val pendingCreation: Boolean = false,
    val started: Boolean = false,
)

class SessionEditorDraft(val initial: Session) {
    private var recoveryStore: com.cbtipul.app.data.DeviceDraftStorage? = null
    private var recoveryKey: String? = null
    private var recoveryClosed = false
    private var unreadRecovery = false
    var audioName by mutableStateOf<String?>(null)
    var audioSeconds by mutableStateOf(0.0)
    var transcriptReady by mutableStateOf(false)
    var preparedSource by mutableStateOf<String?>(null)
    var preparedText by mutableStateOf<String?>(null)
    var pendingCreation by mutableStateOf(false)
    val prepared: String? get() = preparedText?.takeIf { preparedSource == notes }
    fun audioFile(context: android.content.Context): java.io.File? {
        val name = audioName ?: return null
        require(Regex("[a-fA-F0-9-]+\\.(m4a|aac)").matches(name))
        return java.io.File(audioDirectory(context), name)
    }
    private fun audioDirectory(context: android.content.Context): java.io.File {
        val key = requireNotNull(recoveryKey)
        val owner = java.security.MessageDigest.getInstance("SHA-256").digest(key.toByteArray()).joinToString("") { "%02x".format(it) }
        return java.io.File(context.noBackupFilesDir, "session-audio/$owner").also { check(it.mkdirs() || it.isDirectory) }
    }
    fun beginAudio(context: android.content.Context): java.io.File {
        check(audioName == null)
        audioName = "${java.util.UUID.randomUUID()}.aac"
        transcriptReady = false
        check(persistRecovery()) { "Local draft unavailable" }
        return requireNotNull(audioFile(context))
    }
    fun clearAudio(context: android.content.Context): Boolean = try {
        audioFile(context)?.let { check(!it.exists() || it.delete()) }
        audioName = null; audioSeconds = 0.0; transcriptReady = false
        persistRecovery()
    } catch (_: Exception) { recoveryFailed = true; false }

    var recoveryFailed by mutableStateOf(false)
        private set
    var recoverySaved by mutableStateOf(false)
        private set
    var recoveryRestored by mutableStateOf(false)
        private set
    private val json = kotlinx.serialization.json.Json { ignoreUnknownKeys = true; encodeDefaults = true }

    fun configureRecovery(store: com.cbtipul.app.data.DeviceDraftStorage, key: String) {
        if (recoveryKey != null) {
            check(recoveryKey == key) { "Draft account changed" }
            return
        }
        recoveryStore = store
        recoveryKey = key
        unreadRecovery = true
        try {
            store.read(key)?.let {
                val saved = json.decodeFromString(SessionRecovery.serializer(), it)
                date = java.util.Date(saved.date)
                notes = saved.notes
                type = saved.type
                structuredNotes = saved.structuredNotes
                selectedPatientId = saved.selectedPatientId
                audioName = saved.audioName
                audioSeconds = saved.audioSeconds
                transcriptReady = saved.transcriptReady
                preparedSource = saved.preparedSource
                preparedText = saved.preparedText
                pendingCreation = saved.pendingCreation
                hasSummaryDraft = saved.started || notes.isNotBlank() || audioName != null
                recoverySaved = true
                recoveryRestored = true
            }
            unreadRecovery = false
        } catch (_: Exception) { recoveryFailed = true; unreadRecovery = true }
    }

    fun persistRecovery(): Boolean {
        if (recoveryClosed || recoveryKey == null) return false
        return try {
            if (!unreadRecovery && !recoverySaved && !pendingCreation && audioName == null && date == baselineDate && notes == baselineNotes && type == baselineType && structuredNotes == baselineStructured) return true
            // Never overwrite a draft whose initial read failed.
            if (unreadRecovery) {
                check(recoveryStore!!.read(recoveryKey!!) == null)
                unreadRecovery = false
            }
            recoveryStore!!.write(recoveryKey!!, json.encodeToString(SessionRecovery.serializer(),
                SessionRecovery(date.time, notes, type, structuredNotes, selectedPatientId,
                    audioName, audioSeconds, transcriptReady, preparedSource, preparedText, pendingCreation, hasSummaryDraft)))
            recoverySaved = true
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
            if (recoveryKey != null && !unreadRecovery) persistRecovery()
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
        val wasPending = pendingCreation
        pendingCreation = false
        if (!clearRecovery(close = initial.databaseId == null)) {
            pendingCreation = wasPending
            recoveryClosed = true // Do not overwrite the retained receipt-uncertain manifest on dispose.
        }
        baselineDate = saved.date
        baselineNotes = saved.notes
        baselineType = saved.type
        baselineStructured = saved.structuredNotes
        saveRevision += 1
    }

    fun snapshot(): Session = initial.copy(date = date, notes = notes, type = type, structuredNotes = structuredNotes)
}
