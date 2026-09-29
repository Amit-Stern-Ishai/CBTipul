package com.cbtipul.app.data

import com.cbtipul.app.model.DatabaseId
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import kotlinx.serialization.Serializable

object PatientDiaryOneHistory {
    fun visible(entries: List<DiaryOneEntry>): List<DiaryOneEntry> =
        entries
            .filter { it.createdBy == DiaryOneEntryCreator.Patient }
            .sortedByDescending { it.createdAt.time }
}

@Serializable
data class SubmitDiaryOneEntryRequest(
    val event: String,
    val automaticThoughts: List<String>,
    val feelings: List<DiaryFeeling>,
    val behaviour: String,
    val physicalSymptoms: String?,
)

@Serializable
private data class SubmitDiaryOneEntryResponse(
    val success: Boolean? = null,
    val entryId: String? = null,
)

sealed class PatientDiaryOneSubmitError(open val userMessage: String) : Exception(userMessage) {
    data class NotActive(override val userMessage: String) : PatientDiaryOneSubmitError(userMessage)
    data class AccessDenied(override val userMessage: String) : PatientDiaryOneSubmitError(userMessage)
    data class Invalid(override val userMessage: String) : PatientDiaryOneSubmitError(userMessage)
    data class Failed(override val userMessage: String) : PatientDiaryOneSubmitError(userMessage)
}

class PatientDiaryOneService(
    private val client: SupabaseClient,
    private val diaryOne: DiaryOneRepository,
) {
    suspend fun loadPatientCreatedEntries(patientId: String): List<DiaryOneEntry> {
        val id = DatabaseId.parse(patientId) ?: throw IllegalStateException("not_configured")
        return diaryOne.loadPatientCreatedEntries(id)
    }

    suspend fun submitEntry(
        event: String,
        automaticThoughts: List<String>,
        feelings: List<DiaryFeeling>,
        behaviour: String,
        physicalSymptoms: String?,
        fallbackMessage: String,
        invalidThoughtsMessage: String,
    ) {
        if (!SupabaseConfig.isConfigured) throw PatientDiaryOneSubmitError.Failed(fallbackMessage)
        try {
            val http = client.functions.invoke(
                function = "submit-diary-one-entry",
                body = SubmitDiaryOneEntryRequest(
                    event = event,
                    automaticThoughts = automaticThoughts,
                    feelings = feelings,
                    behaviour = behaviour,
                    physicalSymptoms = physicalSymptoms,
                ),
                headers = Headers.build {
                    append(HttpHeaders.ContentType, ContentType.Application.Json.toString())
                },
            )
            val response = EdgePayload.json.decodeFromString(
                SubmitDiaryOneEntryResponse.serializer(),
                http.bodyAsText(),
            )
            if (response.success == false) throw PatientDiaryOneSubmitError.Failed(fallbackMessage)
        } catch (error: PatientDiaryOneSubmitError) {
            throw error
        } catch (error: Exception) {
            throw mapError(error, fallbackMessage, invalidThoughtsMessage)
        }
    }

    private suspend fun mapError(
        error: Exception,
        fallback: String,
        invalidThoughtsMessage: String,
    ): PatientDiaryOneSubmitError {
        val body = EdgePayload.responseBody(error)
        val (code, message) = EdgePayload.codeAndMessage(body)
        val status = EdgePayload.httpStatus(error)
        return mapSubmitCode(code, message, status, fallback, invalidThoughtsMessage)
    }

    companion object {
        fun mapSubmitCode(
            code: String,
            message: String,
            status: Int?,
            fallback: String,
            invalidThoughtsMessage: String,
        ): PatientDiaryOneSubmitError {
            val text = message.ifBlank { fallback }
            return when (code) {
                "diary_one_not_active" -> PatientDiaryOneSubmitError.NotActive(text)
                "unauthorized", "patient_mode_required", "patient_access_not_found",
                "patient_therapist_mismatch",
                -> PatientDiaryOneSubmitError.AccessDenied(text)
                "invalid_automatic_thoughts" -> PatientDiaryOneSubmitError.Invalid(invalidThoughtsMessage)
                "invalid_event", "invalid_behaviour",
                "invalid_feelings", "duplicate_feeling", "invalid_request",
                -> PatientDiaryOneSubmitError.Invalid(text)
                else -> if (status == 401 || status == 403) {
                    PatientDiaryOneSubmitError.AccessDenied(text)
                } else {
                    PatientDiaryOneSubmitError.Failed(text)
                }
            }
        }
    }
}
