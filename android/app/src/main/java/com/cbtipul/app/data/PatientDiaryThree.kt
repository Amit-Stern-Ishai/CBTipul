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
data class SubmitDiaryThreeEntryRequest(
    val situation: String,
    val automaticThoughts: List<DiaryThreeAutomaticThought>,
    val feelings: List<DiaryThreeFeeling>,
    val thinkingErrors: List<ThinkingError>,
    val alternativeThoughts: List<DiaryThreeAlternativeThought>,
) {
    companion object {
        fun from(draft: DiaryThreeEntryDraft): SubmitDiaryThreeEntryRequest {
            require(draft.validationError() == null)
            return SubmitDiaryThreeEntryRequest(draft.situation.trim(), draft.persistedAutomaticThoughts,
                draft.persistedFeelings(), draft.thinkingErrors, draft.persistedAlternativeThoughts)
        }
    }
}
@Serializable
internal data class SubmitDiaryThreeEntryResponse(val success: Boolean, val entryId: String)

class PatientDiaryThreeSubmitError(val kind: Kind, @StringRes val messageRes: Int) : Exception() {
    enum class Kind { NotActive, AccessDenied, Invalid, Failed }
}

interface PatientDiaryThreeAccess {
    suspend fun loadPatientCreatedEntries(patientId: String): List<DiaryThreeEntry>
    suspend fun submitEntry(request: SubmitDiaryThreeEntryRequest): String
}

object PatientDiaryThreeHistory {
    fun visible(entries: List<DiaryThreeEntry>, patientId: String) = entries.filter {
        it.createdBy == DiaryOneEntryCreator.Patient && it.patientId.queryValue.equals(patientId, true)
    }.sortedByDescending { it.createdAt }
}

/** Patient session/RLS only. This service has no INSERT, UPDATE or DELETE path. */
class PatientDiaryThreeService(private val client: SupabaseClient) : PatientDiaryThreeAccess {
    override suspend fun loadPatientCreatedEntries(patientId: String): List<DiaryThreeEntry> {
        val id = UUID.fromString(patientId).toString()
        val rows = client.from("diary_three_entries").select(Columns.raw(
            "id, patient_id, therapist_id, created_by, situation, automatic_thoughts, feelings, thinking_errors, alternative_thoughts, created_at, updated_at",
        )) {
            filter { eq("patient_id", id); eq("created_by", "patient") }
            order("created_at", Order.DESCENDING)
        }.decodeList<DiaryThreeEntryRow>()
        return PatientDiaryThreeHistory.visible(rows.map { row ->
            DiaryThreeEntry(row.id, requireNotNull(DatabaseId.parse(row.patientId)), row.therapistId,
                DiaryOneEntryCreator.fromRaw(row.createdBy), row.situation, row.automaticThoughts, row.feelings,
                row.thinkingErrors, row.alternativeThoughts,
                PatientAssignmentRepository.parseAssignmentTimestamp(row.createdAt),
                PatientAssignmentRepository.parseAssignmentTimestamp(row.updatedAt))
        }, id)
    }

    override suspend fun submitEntry(request: SubmitDiaryThreeEntryRequest): String {
        try {
            val http = client.functions.invoke(function = FUNCTION_NAME, body = request,
                headers = Headers.build { append(HttpHeaders.ContentType, ContentType.Application.Json.toString()) })
            return decodeSuccess(http.bodyAsText())
        } catch (error: CancellationException) { throw error }
        catch (error: PatientDiaryThreeSubmitError) { throw error }
        catch (error: Exception) {
            val (code, _) = EdgePayload.codeAndMessage(EdgePayload.responseBody(error))
            throw mapError(code, EdgePayload.httpStatus(error))
        }
    }

    companion object {
        const val FUNCTION_NAME = "submit-diary-three-entry"
        internal fun decodeSuccess(body: String): String {
            val response = EdgePayload.json.decodeFromString<SubmitDiaryThreeEntryResponse>(body)
            if (!response.success) throw mapError("", null)
            return UUID.fromString(response.entryId).toString()
        }
        fun mapError(code: String, status: Int?): PatientDiaryThreeSubmitError {
            val kind: PatientDiaryThreeSubmitError.Kind
            val message: Int
            when (code) {
                "diary_three_not_active" -> { kind = PatientDiaryThreeSubmitError.Kind.NotActive; message = R.string.patient_diary_three_not_active }
                "unauthorized", "patient_mode_required", "patient_access_not_found", "patient_therapist_mismatch" -> {
                    kind = PatientDiaryThreeSubmitError.Kind.AccessDenied; message = R.string.patient_diary_two_access_denied
                }
                "invalid_situation" -> { kind = PatientDiaryThreeSubmitError.Kind.Invalid; message = R.string.diary_three_validation_situation }
                "invalid_automatic_thoughts" -> { kind = PatientDiaryThreeSubmitError.Kind.Invalid; message = R.string.diary_one_validation_thought }
                "invalid_feelings" -> { kind = PatientDiaryThreeSubmitError.Kind.Invalid; message = R.string.diary_three_validation_ratings }
                "duplicate_feeling" -> { kind = PatientDiaryThreeSubmitError.Kind.Invalid; message = R.string.diary_feeling_already_selected }
                "duplicate_thinking_error" -> { kind = PatientDiaryThreeSubmitError.Kind.Invalid; message = R.string.diary_two_duplicate_thinking_error }
                "invalid_thinking_errors" -> { kind = PatientDiaryThreeSubmitError.Kind.Invalid; message = R.string.diary_two_validation_errors }
                "invalid_alternative_thoughts" -> { kind = PatientDiaryThreeSubmitError.Kind.Invalid; message = R.string.diary_two_validation_alternatives }
                else -> {
                    kind = if (status == 401 || status == 403) PatientDiaryThreeSubmitError.Kind.AccessDenied else PatientDiaryThreeSubmitError.Kind.Failed
                    message = if (kind == PatientDiaryThreeSubmitError.Kind.AccessDenied) R.string.patient_diary_two_access_denied else R.string.patient_diary_one_submit_error
                }
            }
            return PatientDiaryThreeSubmitError(kind, message)
        }
    }
}
