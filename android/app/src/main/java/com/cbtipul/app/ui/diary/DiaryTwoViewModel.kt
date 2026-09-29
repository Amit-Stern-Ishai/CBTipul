package com.cbtipul.app.ui.diary

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.cbtipul.app.R
import com.cbtipul.app.data.*
import com.cbtipul.app.model.DatabaseId
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json

internal enum class DiaryTwoConnection { Loading, Connected, NotConnected, Inactive, Active, Failed }
internal data class DiaryTwoState(
    val loading: Boolean = true,
    val loadFailed: Boolean = false,
    val connection: DiaryTwoConnection = DiaryTwoConnection.Loading,
    val assignmentId: String? = null,
    val busy: Boolean = false,
    val error: Int? = null,
)

internal class DiaryTwoViewModel(
    private val patientId: DatabaseId,
    private val diary: DiaryTwoRepository,
    private val assignments: PatientAssignmentRepository,
    private val isDemo: Boolean,
    private val saved: SavedStateHandle,
) : ViewModel() {
    val entries = diary.entries
    private val mutable = MutableStateFlow(DiaryTwoState(connection = cachedConnection() ?: DiaryTwoConnection.Loading))
    val state = mutable.asStateFlow()
    private val draftState = MutableStateFlow(saved.get<String>("draft")?.let {
        runCatching { Json.decodeFromString<DiaryTwoEntryDraft>(it) }.getOrNull()
    } ?: DiaryTwoEntryDraft())
    val draft = draftState.asStateFlow()
    private var revision = 0

    init { refresh() }

    fun openEditor(id: String?) {
        val key = id ?: "new"
        if (saved.get<String>("editor") == key) return
        val initial = id?.let { entryId -> diary.entriesFor(patientId).find { it.id == entryId } }
            ?.let(DiaryTwoEntryDraft::from) ?: DiaryTwoEntryDraft()
        saved["editor"] = key
        saved["initial"] = Json.encodeToString(DiaryTwoEntryDraft.serializer(), initial)
        changeDraft(initial)
        mutable.value = mutable.value.copy(error = null)
    }
    fun changeDraft(value: DiaryTwoEntryDraft) {
        draftState.value = value
        saved["draft"] = Json.encodeToString(DiaryTwoEntryDraft.serializer(), value)
    }
    fun hasChanges() = saved.get<String>("draft") != saved.get<String>("initial")
    fun closeEditor() { saved.remove<String>("editor"); mutable.value = mutable.value.copy(error = null) }
    private fun cachedConnection(): DiaryTwoConnection? {
        if (isDemo || DemoData.isDemoId(patientId)) return DiaryTwoConnection.NotConnected
        val id = PatientAssignmentRepository.uuidOrNull(patientId) ?: return null
        val connected = assignments.cachedPatientConnection(id) ?: return null
        if (!connected) return DiaryTwoConnection.NotConnected
        val snapshot = assignments.cachedOngoingAssignment(id, PatientAssignmentType.DiaryTwo) ?: return DiaryTwoConnection.Connected
        return if (snapshot.assignmentId == null) DiaryTwoConnection.Inactive else DiaryTwoConnection.Active
    }
    fun refresh() {
        viewModelScope.launch {
            try {
                diary.loadEntries(patientId)
                mutable.value = mutable.value.copy(loading = false, loadFailed = false)
            } catch (e: CancellationException) { throw e }
            catch (_: Exception) { mutable.value = mutable.value.copy(loading = false, loadFailed = true) }
        }
        refreshConnection()
    }
    fun refreshConnection() {
        if (mutable.value.busy) return
        viewModelScope.launch { loadConnection() }
    }
    private suspend fun loadConnection() {
        val current = ++revision
        cachedConnection()?.let { mutable.value = mutable.value.copy(connection = it) }
        if (isDemo || DemoData.isDemoId(patientId)) return
        val id = PatientAssignmentRepository.uuidOrNull(patientId) ?: return
        try {
            if (!assignments.isPatientConnected(id)) {
                if (current == revision) mutable.value = mutable.value.copy(connection = DiaryTwoConnection.NotConnected, assignmentId = null)
                return
            }
            assignments.activeOngoingAssignment(id, PatientAssignmentType.DiaryTwo)
            if (current == revision) mutable.value = mutable.value.copy(
                connection = cachedConnection() ?: DiaryTwoConnection.Connected,
                assignmentId = assignments.cachedOngoingAssignment(id, PatientAssignmentType.DiaryTwo)?.assignmentId,
            )
        } catch (e: CancellationException) { throw e }
        catch (_: Exception) {
            if (current == revision) mutable.value = mutable.value.copy(connection = cachedConnection() ?: DiaryTwoConnection.Failed)
        }
    }
    fun activate() = assignmentMutation(R.string.diary_patient_mode_activate_failed) {
        val id = requireNotNull(PatientAssignmentRepository.uuidOrNull(patientId))
        assignments.activateOngoingAssignment(id, PatientAssignmentType.DiaryTwo)
    }
    fun cancel() = assignmentMutation(R.string.diary_patient_mode_stop_failed) {
        val id = mutable.value.assignmentId ?: PatientAssignmentRepository.uuidOrNull(patientId)?.let {
            assignments.cachedOngoingAssignment(it, PatientAssignmentType.DiaryTwo)?.assignmentId
        }
        assignments.cancelOngoingAssignment(requireNotNull(id))
    }
    private fun assignmentMutation(failureMessage: Int, action: suspend () -> Unit) {
        if (mutable.value.busy) return
        revision++
        mutable.value = mutable.value.copy(busy = true, error = null)
        viewModelScope.launch {
            try { action(); loadConnection() }
            catch (e: CancellationException) { throw e }
            catch (_: PatientAssignmentException.PatientNotConnected) {
                mutable.value = mutable.value.copy(connection = DiaryTwoConnection.NotConnected)
            } catch (_: Exception) { mutable.value = mutable.value.copy(error = failureMessage) }
            finally { mutable.value = mutable.value.copy(busy = false) }
        }
    }
    fun save(id: String?, onSaved: () -> Unit) {
        val value = draft.value
        if (mutable.value.busy || value.validationError() != null) return
        mutate(R.string.diary_one_save_failed, onSaved) {
            if (id == null) diary.createEntry(patientId, value.event.trim(), value.persistedAutomaticThoughts,
                value.persistedFeelings(), value.thinkingErrors, value.persistedAlternativeThoughts)
            else diary.updateEntry(id, patientId, value.event.trim(), value.persistedAutomaticThoughts,
                value.persistedFeelings(), value.thinkingErrors, value.persistedAlternativeThoughts)
            closeEditor()
        }
    }
    fun delete(id: String, onDeleted: () -> Unit) = mutate(R.string.diary_one_delete_failed, onDeleted) {
        diary.deleteEntry(id, patientId)
    }
    private fun mutate(error: Int, done: () -> Unit, action: suspend () -> Unit) {
        if (mutable.value.busy) return
        mutable.value = mutable.value.copy(busy = true, error = null)
        viewModelScope.launch {
            try { action(); done() }
            catch (e: CancellationException) { throw e }
            catch (_: Exception) { mutable.value = mutable.value.copy(error = error) }
            finally { mutable.value = mutable.value.copy(busy = false) }
        }
    }
}
