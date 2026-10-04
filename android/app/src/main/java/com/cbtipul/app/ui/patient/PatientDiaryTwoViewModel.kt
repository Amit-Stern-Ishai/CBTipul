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

internal data class PatientDiaryTwoState(
    val entries: List<DiaryTwoEntry> = emptyList(),
    val loading: Boolean = true,
    val historyFailed: Boolean = false,
    val submitting: Boolean = false,
    val submittedId: String? = null,
    val error: PatientDiaryTwoSubmitError? = null,
)

internal class PatientDiaryTwoViewModel(
    private val patientId: String,
    private val service: PatientDiaryTwoAccess,
    private val saved: SavedStateHandle,
) : ViewModel() {
    private val mutable = MutableStateFlow(PatientDiaryTwoState(submittedId = saved["submittedEntryId"]))
    val state = mutable.asStateFlow()
    private var loading = false

    fun refresh() {
        if (loading) return
        loading = true
        viewModelScope.launch {
            try {
                val entries = PatientDiaryTwoHistory.visible(service.loadPatientCreatedEntries(patientId), patientId)
                mutable.value = mutable.value.copy(entries = entries, loading = false, historyFailed = false)
            } catch (e: CancellationException) { throw e }
            catch (_: Exception) { mutable.value = mutable.value.copy(loading = false, historyFailed = true) }
            finally { loading = false }
        }
    }

    fun submit(draft: DiaryTwoEntryDraft) {
        if (!com.cbtipul.app.data.Entitlements.allowMutation()) return
        if (mutable.value.submitting || mutable.value.submittedId != null) return
        draft.validationError()?.let {
            mutable.value = mutable.value.copy(error = PatientDiaryTwoSubmitError(PatientDiaryTwoSubmitError.Kind.Invalid, it))
            return
        }
        mutable.value = mutable.value.copy(submitting = true, error = null)
        viewModelScope.launch {
            try {
                val id = service.submitEntry(SubmitDiaryTwoEntryRequest.from(draft))
                saved["submittedEntryId"] = id
                mutable.value = mutable.value.copy(submitting = false, submittedId = id)
            } catch (e: CancellationException) { throw e }
            catch (e: PatientDiaryTwoSubmitError) { mutable.value = mutable.value.copy(submitting = false, error = e) }
            catch (_: Exception) {
                mutable.value = mutable.value.copy(submitting = false, error = PatientDiaryTwoSubmitError(
                    PatientDiaryTwoSubmitError.Kind.Failed, R.string.patient_diary_one_submit_error))
            }
        }
    }
}
