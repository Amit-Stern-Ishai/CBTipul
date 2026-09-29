package com.cbtipul.app.data

import androidx.annotation.StringRes
import com.cbtipul.app.R
import com.cbtipul.app.model.DatabaseId
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import kotlinx.coroutines.CancellationException
import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
data class SubmitDiaryTwoEntryRequest(
    val event: String,
    val automaticThoughts: List<String>,
    val feelings: List<DiaryFeeling>,
    val thinkingErrors: List<ThinkingError>,
    val alternativeThoughts: List<String>,
) {
    companion object {
        fun from(draft: DiaryTwoEntryDraft): SubmitDiaryTwoEntryRequest {
            require(draft.validationError() == null)
            return SubmitDiaryTwoEntryRequest(draft.event.trim(), draft.persistedAutomaticThoughts,
                draft.persistedFeelings(), draft.thinkingErrors, draft.persistedAlternativeThoughts)
        }
    }
}
@Serializable
internal data class SubmitDiaryTwoEntryResponse(val success: Boolean, val entryId: String)

class PatientDiaryTwoSubmitError(val kind: Kind, @StringRes val messageRes: Int) : Exception() {
    enum class Kind { NotActive, AccessDenied, Invalid, Failed }
}

interface PatientDiaryTwoAccess {
    suspend fun loadPatientCreatedEntries(patientId: String): List<DiaryTwoEntry>
    suspend fun submitEntry(request: SubmitDiaryTwoEntryRequest): String
}

object PatientDiaryTwoHistory {
    fun visible(entries: List<DiaryTwoEntry>, patientId: String) = entries.filter {
        it.createdBy == DiaryOneEntryCreator.Patient && it.patientId.queryValue.equals(patientId, true)
    }.sortedByDescending { it.createdAt }
}

/** Patient session/RLS only. This service has no INSERT, UPDATE or DELETE path. */
class PatientDiaryTwoService(private val client: SupabaseClient) : PatientDiaryTwoAccess {
    override suspend fun loadPatientCreatedEntries(patientId: String): List<DiaryTwoEntry> {
        val id = UUID.fromString(patientId).toString()
        val rows = client.from("diary_two_entries").select(Columns.raw(
            "id, patient_id, therapist_id, created_by, event, automatic_thoughts, feelings, thinking_errors, alternative_thoughts, created_at, updated_at",
        )) {
            filter { eq("patient_id", id); eq("created_by", "patient") }
            order("created_at", Order.DESCENDING)
        }.decodeList<DiaryTwoEntryRow>()
        return PatientDiaryTwoHistory.visible(rows.map { row ->
            DiaryTwoEntry(row.id, requireNotNull(DatabaseId.parse(row.patientId)), row.therapistId,
                DiaryOneEntryCreator.fromRaw(row.createdBy), row.event, row.automaticThoughts, row.feelings,
                row.thinkingErrors, row.alternativeThoughts,
                PatientAssignmentRepository.parseAssignmentTimestamp(row.createdAt),
                PatientAssignmentRepository.parseAssignmentTimestamp(row.updatedAt))
        }, id)
    }

    override suspend fun submitEntry(request: SubmitDiaryTwoEntryRequest): String {
        try {
            val http = client.functions.invoke(function = FUNCTION_NAME, body = request,
                headers = Headers.build { append(HttpHeaders.ContentType, ContentType.Application.Json.toString()) })
            return decodeSuccess(http.bodyAsText())
        } catch (error: CancellationException) { throw error }
        catch (error: PatientDiaryTwoSubmitError) { throw error }
        catch (error: Exception) {
            val (code, _) = EdgePayload.codeAndMessage(EdgePayload.responseBody(error))
            throw mapError(code, EdgePayload.httpStatus(error))
        }
    }

    companion object {
        const val FUNCTION_NAME = "submit-diary-two-entry"
        internal fun decodeSuccess(body: String): String {
            val response = EdgePayload.json.decodeFromString<SubmitDiaryTwoEntryResponse>(body)
            if (!response.success) throw mapError("", null)
            return UUID.fromString(response.entryId).toString()
        }
        fun mapError(code: String, status: Int?): PatientDiaryTwoSubmitError {
            val kind: PatientDiaryTwoSubmitError.Kind
            val message: Int
            when (code) {
                "diary_two_not_active" -> { kind = PatientDiaryTwoSubmitError.Kind.NotActive; message = R.string.patient_diary_two_not_active }
                "unauthorized", "patient_mode_required", "patient_access_not_found", "patient_therapist_mismatch" -> {
                    kind = PatientDiaryTwoSubmitError.Kind.AccessDenied; message = R.string.patient_diary_two_access_denied
                }
                "invalid_event" -> { kind = PatientDiaryTwoSubmitError.Kind.Invalid; message = R.string.diary_one_validation_event }
                "invalid_automatic_thoughts" -> { kind = PatientDiaryTwoSubmitError.Kind.Invalid; message = R.string.diary_one_validation_thought }
                "invalid_feelings" -> { kind = PatientDiaryTwoSubmitError.Kind.Invalid; message = R.string.patient_diary_two_invalid_feelings }
                "duplicate_feeling" -> { kind = PatientDiaryTwoSubmitError.Kind.Invalid; message = R.string.diary_feeling_already_selected }
                "duplicate_thinking_error" -> { kind = PatientDiaryTwoSubmitError.Kind.Invalid; message = R.string.diary_two_duplicate_thinking_error }
                "invalid_thinking_errors" -> { kind = PatientDiaryTwoSubmitError.Kind.Invalid; message = R.string.diary_two_validation_errors }
                "invalid_alternative_thoughts" -> { kind = PatientDiaryTwoSubmitError.Kind.Invalid; message = R.string.diary_two_validation_alternatives }
                else -> {
                    kind = if (status == 401 || status == 403) PatientDiaryTwoSubmitError.Kind.AccessDenied else PatientDiaryTwoSubmitError.Kind.Failed
                    message = if (kind == PatientDiaryTwoSubmitError.Kind.AccessDenied) R.string.patient_diary_two_access_denied else R.string.patient_diary_one_submit_error
                }
            }
            return PatientDiaryTwoSubmitError(kind, message)
        }
    }
}
