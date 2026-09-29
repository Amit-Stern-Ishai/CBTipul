package com.cbtipul.app.ui.patient

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.cbtipul.app.R
import com.cbtipul.app.data.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

internal data class PatientDiaryThreeDraftPersistence(val read: () -> String?, val write: (String) -> Unit, val clear: () -> Unit)
internal data class PatientDiaryThreeState(
    val entries: List<DiaryThreeEntry> = emptyList(),
    val loading: Boolean = true,
    val historyFailed: Boolean = false,
    val draft: PatientDiaryThreeDraft = PatientDiaryThreeDraft(),
    val draftFailed: Boolean = false,
    val draftSaved: Boolean = false,
    val submitting: Boolean = false,
    val submittedId: String? = null,
    val navigationPending: Boolean = false,
    val error: PatientDiaryThreeSubmitError? = null,
)

internal class PatientDiaryThreeViewModel(
    private val patientId: String,
    private val service: PatientDiaryThreeAccess,
    private val saved: SavedStateHandle,
    private val persistence: PatientDiaryThreeDraftPersistence? = null,
) : ViewModel() {
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private val mutable = MutableStateFlow(PatientDiaryThreeState(submittedId = saved["submittedEntryId"], navigationPending = saved["navigationPending"] ?: false))
    val state = mutable.asStateFlow()
    private var loading = false
    init {
        try {
            val encoded = saved.get<String>("draft") ?: persistence?.read()
            if (encoded != null && mutable.value.submittedId == null) {
                val draft = json.decodeFromString<PatientDiaryThreeDraft>(encoded)
                mutable.value = mutable.value.copy(draft = draft.copy(currentStep = draft.currentStep.coerceIn(1, 7)), draftSaved = persistence != null)
            }
        } catch (_: Exception) { mutable.value = mutable.value.copy(draftFailed = true) }
    }
    fun update(draft: PatientDiaryThreeDraft) {
        if (mutable.value.submitting || mutable.value.submittedId != null || accessUnavailable) return
        mutable.value = mutable.value.copy(draft = draft, error = null)
        persistDraft()
    }
    private val accessUnavailable get() = mutable.value.error?.kind in listOf(PatientDiaryThreeSubmitError.Kind.NotActive, PatientDiaryThreeSubmitError.Kind.AccessDenied)
    fun persistDraft(): Boolean = try {
        val draft = mutable.value.draft
        val encoded = json.encodeToString(draft)
        saved["draft"] = encoded
        if (draft.hasMeaningfulContent) persistence?.write?.invoke(encoded) else persistence?.clear?.invoke()
        mutable.value = mutable.value.copy(draftFailed = false, draftSaved = draft.hasMeaningfulContent && persistence != null)
        true
    } catch (_: Exception) { mutable.value = mutable.value.copy(draftFailed = true); false }
    fun clearDraft(): Boolean = try {
        persistence?.clear?.invoke()
        saved.remove<String>("draft")
        mutable.value = mutable.value.copy(draft = PatientDiaryThreeDraft(), draftFailed = false, draftSaved = false)
        true
    } catch (_: Exception) { mutable.value = mutable.value.copy(draftFailed = true); false }
    fun next() {
        val draft = mutable.value.draft
        draft.validationError()?.let { invalid(it); return }
        update(draft.advance())
    }
    fun back() { update(mutable.value.draft.back()) }
    private fun invalid(message: Int) { mutable.value = mutable.value.copy(error = PatientDiaryThreeSubmitError(PatientDiaryThreeSubmitError.Kind.Invalid, message)) }
    fun clearError() { if (!accessUnavailable) mutable.value = mutable.value.copy(error = null) }
    fun refresh() {
        if (loading) return
        loading = true
        viewModelScope.launch {
            try {
                val entries = PatientDiaryThreeHistory.visible(service.loadPatientCreatedEntries(patientId), patientId)
                mutable.value = mutable.value.copy(entries = entries, loading = false, historyFailed = false)
            } catch (e: CancellationException) { throw e }
            catch (_: Exception) { mutable.value = mutable.value.copy(loading = false, historyFailed = true) }
            finally { loading = false }
        }
    }
    fun submit() {
        val state = mutable.value
        if (state.submitting || state.submittedId != null || accessUnavailable) return
        val invalidStep = state.draft.firstInvalidStep
        if (invalidStep != null) {
            update(state.draft.copy(currentStep = invalidStep))
            invalid(requireNotNull(state.draft.validationError(invalidStep)))
            return
        }
        if (state.draft.currentStep != 7) return
        mutable.value = state.copy(submitting = true, error = null)
        viewModelScope.launch {
            try {
                val id = service.submitEntry(SubmitDiaryThreeEntryRequest.from(state.draft.entry))
                saved["submittedEntryId"] = id
                saved["navigationPending"] = true
                mutable.value = mutable.value.copy(submitting = false, submittedId = id, navigationPending = true)
            } catch (e: CancellationException) { throw e }
            catch (e: PatientDiaryThreeSubmitError) { mutable.value = mutable.value.copy(submitting = false, error = e) }
            catch (_: Exception) { mutable.value = mutable.value.copy(submitting = false, error = PatientDiaryThreeSubmitError(PatientDiaryThreeSubmitError.Kind.Failed, R.string.patient_diary_one_submit_error)) }
        }
    }
    /** Consume only after local cleanup succeeds. Submitted ID still guards against another POST. */
    fun consumeSuccessfulSubmission(): Boolean {
        if (!mutable.value.navigationPending || mutable.value.submittedId == null || !clearDraft()) return false
        saved["navigationPending"] = false
        mutable.value = mutable.value.copy(navigationPending = false)
        return true
    }
}
