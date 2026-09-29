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

class SessionEditorDraft(val initial: Session) {
    var selectedPatientId by mutableStateOf<String?>(null)
    var date by mutableStateOf(initial.date)
    var notes by mutableStateOf(initial.notes)
    var type by mutableStateOf(initial.type)
    var structuredNotes by mutableStateOf(initial.structuredNotes)
    var baselineDate by mutableStateOf(initial.date)
    var baselineNotes by mutableStateOf(initial.notes)
    var baselineType by mutableStateOf(initial.type)
    var baselineStructured by mutableStateOf(initial.structuredNotes)
    fun markSaved(saved: Session) {
        baselineDate = saved.date
        baselineNotes = saved.notes
        baselineType = saved.type
        baselineStructured = saved.structuredNotes
    }

    fun snapshot(): Session = initial.copy(date = date, notes = notes, type = type, structuredNotes = structuredNotes)
}
