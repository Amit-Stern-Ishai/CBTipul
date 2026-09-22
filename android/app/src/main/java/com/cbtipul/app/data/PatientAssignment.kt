package com.cbtipul.app.data

import com.cbtipul.app.model.DatabaseId
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.text.SimpleDateFormat
import java.time.Instant
import java.time.OffsetDateTime
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

enum class PatientAssignmentType(val raw: String) {
    Questionnaire("questionnaire"),
    DiaryOne("diary_one"),
    DiaryTwo("diary_two"),
    ;

    companion object {
        fun fromRaw(value: String): PatientAssignmentType? = entries.find { it.raw == value }
    }
}

data class PatientAssignment(
    val id: String,
    val patientId: String,
    val therapistId: String?,
    val sessionId: String?,
    val typeValue: String,
    val createdAt: Date,
    val completedAt: Date?,
    val cancelledAt: Date?,
) {
    val type: PatientAssignmentType? get() = PatientAssignmentType.fromRaw(typeValue)
    val isOpen: Boolean get() = completedAt == null && cancelledAt == null
}

@Serializable
private data class PatientAssignmentRow(
    val id: String,
    @SerialName("patient_id") val patientId: String,
    @SerialName("therapist_id") val therapistId: String? = null,
    @SerialName("session_id") val sessionId: String? = null,
    val type: String,
    @SerialName("created_at") val createdAt: String,
    @SerialName("completed_at") val completedAt: String? = null,
    @SerialName("cancelled_at") val cancelledAt: String? = null,
)

@Serializable
internal data class RequestPatientQuestionnaireRequest(
    val patientId: String,
    val sessionId: String,
)

@Serializable
private data class SubmitPatientQuestionnaireRequest(
    val assignmentId: String,
    val gad7Answers: List<Int>,
    val phq9Answers: List<Int>,
    val interferenceLevel: Int,
)

@Serializable
private data class SubmitPatientQuestionnaireResponse(
    val success: Boolean? = null,
    val combinedMoodId: Int? = null,
    val sessionId: String? = null,
)

sealed class PatientQuestionnaireSubmitError : Exception() {
    data object AlreadyCompleted : PatientQuestionnaireSubmitError()
    data object Cancelled : PatientQuestionnaireSubmitError()
    data object AccessDenied : PatientQuestionnaireSubmitError()
    data object InvalidAnswers : PatientQuestionnaireSubmitError()
    data object Failed : PatientQuestionnaireSubmitError()
}

sealed class PatientAssignmentException : Exception() {
    data object NotConfigured : PatientAssignmentException()
    data object NotSignedIn : PatientAssignmentException()
    data object InvalidIdentifier : PatientAssignmentException()
    data object PatientNotConnected : PatientAssignmentException()
}

class PatientAssignmentRepository(private val client: SupabaseClient) {
    suspend fun isPatientConnected(patientId: String): Boolean {
        ensureConfigured()
        val result = client.postgrest.rpc(
            "is_patient_connected",
            buildJsonObject { put("p_patient_id", patientId) },
        )
        return Json.parseToJsonElement(result.data).jsonPrimitive.boolean
    }

    suspend fun openQuestionnaireAssignment(sessionId: String): PatientAssignment? {
        ensureConfigured()
        val rows = client.from("patient_assignments")
            .select(assignmentColumns) {
                filter {
                    eq("session_id", sessionId)
                    eq("type", PatientAssignmentType.Questionnaire.raw)
                    exact("completed_at", null)
                    exact("cancelled_at", null)
                }
                limit(1)
            }
            .decodeList<PatientAssignmentRow>()
        return rows.firstOrNull()?.toDomain()
    }

    suspend fun sendQuestionnaireAssignment(patientId: String, sessionId: String): PatientAssignment {
        ensureConfigured()
        return try {
            val http = client.functions.invoke(
                function = "request-patient-questionnaire",
                body = RequestPatientQuestionnaireRequest(
                    patientId = patientId,
                    sessionId = sessionId,
                ),
                headers = Headers.build {
                    append(HttpHeaders.ContentType, ContentType.Application.Json.toString())
                },
            )
            assignmentFromEdgeJson(http.bodyAsText())
        } catch (error: PatientAssignmentException) {
            throw error
        } catch (error: Exception) {
            throw mapRequestQuestionnaireError(error)
        }
    }

    suspend fun activeOngoingAssignment(patientId: String, type: PatientAssignmentType): PatientAssignment? {
        ensureConfigured()
        requireOngoing(type)
        val rows = client.from("patient_assignments")
            .select(assignmentColumns) {
                filter {
                    eq("patient_id", patientId)
                    eq("type", type.raw)
                    exact("cancelled_at", null)
                }
                limit(1)
            }
            .decodeList<PatientAssignmentRow>()
        return rows.firstOrNull()?.toDomain()
    }

    suspend fun activateOngoingAssignment(patientId: String, type: PatientAssignmentType): PatientAssignment {
        ensureConfigured()
        requireOngoing(type)
        if (!isPatientConnected(patientId)) throw PatientAssignmentException.PatientNotConnected
        activeOngoingAssignment(patientId, type)?.let { return it }
        val therapistId = requireTherapistId()
        val body = buildJsonObject {
            put("patient_id", patientId)
            put("therapist_id", therapistId)
            put("session_id", JsonNull)
            put("type", type.raw)
            put("completed_at", JsonNull)
            put("cancelled_at", JsonNull)
        }
        return try {
            client.from("patient_assignments")
                .insert(body) { select(assignmentColumns) }
                .decodeSingle<PatientAssignmentRow>()
                .toDomain()
        } catch (error: Exception) {
            if (isUniqueViolation(error)) {
                activeOngoingAssignment(patientId, type)?.let { return it }
            }
            throw error
        }
    }

    suspend fun cancelOngoingAssignment(id: String) {
        ensureConfigured()
        val body = buildJsonObject { put("cancelled_at", timestampNow()) }
        val updated = client.from("patient_assignments")
            .update(body) {
                filter {
                    eq("id", id)
                    exact("cancelled_at", null)
                }
                select(assignmentColumns)
            }
            .decodeList<PatientAssignmentRow>()
        if (updated.isEmpty()) throw PatientAssignmentException.InvalidIdentifier
    }

    suspend fun patientAssignments(patientId: String?): List<PatientAssignment> {
        ensureConfigured()
        val rows = client.from("patient_assignments")
            .select(
                Columns.raw("id, patient_id, session_id, type, created_at, completed_at, cancelled_at"),
            ) {
                filter {
                    exact("cancelled_at", null)
                    if (patientId != null) eq("patient_id", patientId)
                }
                order("created_at", Order.DESCENDING)
            }
            .decodeList<PatientAssignmentRow>()
        return rows.map { it.toDomain() }
    }

    suspend fun submitPatientQuestionnaire(
        assignmentId: String,
        gad7Answers: List<Int>,
        phq9Answers: List<Int>,
        interferenceLevel: Int,
    ) {
        ensureConfigured()
        val valid = (0..3).toSet()
        if (gad7Answers.size != 7 || phq9Answers.size != 9 ||
            gad7Answers.any { it !in valid } || phq9Answers.any { it !in valid } ||
            interferenceLevel !in valid
        ) {
            throw PatientQuestionnaireSubmitError.InvalidAnswers
        }
        try {
            val http = client.functions.invoke(
                function = "submit-patient-questionnaire",
                body = SubmitPatientQuestionnaireRequest(
                    assignmentId = assignmentId,
                    gad7Answers = gad7Answers,
                    phq9Answers = phq9Answers,
                    interferenceLevel = interferenceLevel,
                ),
                headers = Headers.build {
                    append(HttpHeaders.ContentType, ContentType.Application.Json.toString())
                },
            )
            val response = EdgePayload.json.decodeFromString(
                SubmitPatientQuestionnaireResponse.serializer(),
                http.bodyAsText(),
            )
            if (response.success == false) throw PatientQuestionnaireSubmitError.Failed
        } catch (error: PatientQuestionnaireSubmitError) {
            throw error
        } catch (error: Exception) {
            throw mapQuestionnaireError(error)
        }
    }

    private suspend fun mapQuestionnaireError(error: Exception): PatientQuestionnaireSubmitError {
        val body = EdgePayload.responseBody(error)
        val (code, _) = EdgePayload.codeAndMessage(body)
        val status = EdgePayload.httpStatus(error)
        return when (code) {
            "assignment_already_completed", "already_completed" -> PatientQuestionnaireSubmitError.AlreadyCompleted
            "assignment_cancelled", "cancelled" -> PatientQuestionnaireSubmitError.Cancelled
            "access_denied", "forbidden", "unauthorized" -> PatientQuestionnaireSubmitError.AccessDenied
            else -> if (status == 401 || status == 403) {
                PatientQuestionnaireSubmitError.AccessDenied
            } else {
                PatientQuestionnaireSubmitError.Failed
            }
        }
    }

    private suspend fun mapRequestQuestionnaireError(error: Exception): PatientAssignmentException {
        val body = EdgePayload.responseBody(error)
        val (code, _) = EdgePayload.codeAndMessage(body)
        val status = EdgePayload.httpStatus(error)
        return mapRequestQuestionnaireCode(code, status)
    }

    private suspend fun requireTherapistId(): String {
        return client.auth.currentSessionOrNull()?.user?.id
            ?: throw PatientAssignmentException.NotSignedIn
    }

    private fun ensureConfigured() {
        if (!SupabaseConfig.isConfigured) throw PatientAssignmentException.NotConfigured
    }

    private fun requireOngoing(type: PatientAssignmentType) {
        if (type == PatientAssignmentType.Questionnaire) {
            throw PatientAssignmentException.InvalidIdentifier
        }
    }

    private fun isUniqueViolation(error: Throwable): Boolean {
        return error.message?.contains("23505") == true
    }

    private fun timestampNow(): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US)
        formatter.timeZone = TimeZone.getTimeZone("UTC")
        return formatter.format(Date())
    }

    companion object {
        private val assignmentColumns = Columns.raw(
            "id, patient_id, therapist_id, session_id, type, created_at, completed_at, cancelled_at",
        )

        fun uuidOrNull(id: DatabaseId): String? =
            runCatching { UUID.fromString(id.queryValue).toString() }.getOrNull()

        internal fun encodeQuestionnaireRequest(patientId: String, sessionId: String): String =
            EdgePayload.json.encodeToString(
                RequestPatientQuestionnaireRequest.serializer(),
                RequestPatientQuestionnaireRequest(patientId = patientId, sessionId = sessionId),
            )

        internal fun assignmentFromEdgeJson(json: String): PatientAssignment =
            EdgePayload.json.decodeFromString(PatientAssignmentRow.serializer(), json).toDomain()

        internal fun mapRequestQuestionnaireCode(code: String, status: Int?): PatientAssignmentException {
            return when (code) {
                "patient_not_connected" -> PatientAssignmentException.PatientNotConnected
                "unauthorized" -> PatientAssignmentException.NotSignedIn
                else -> if (status == 401 || status == 403) {
                    PatientAssignmentException.NotSignedIn
                } else {
                    PatientAssignmentException.InvalidIdentifier
                }
            }
        }

        internal fun parseAssignmentTimestamp(raw: String): Date {
            val trimmed = raw.trim()
            require(trimmed.isNotEmpty())
            runCatching { Date.from(OffsetDateTime.parse(trimmed).toInstant()) }.getOrNull()?.let { return it }
            runCatching { Date.from(Instant.parse(trimmed)) }.getOrNull()?.let { return it }
            listOf(
                SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US),
                SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US),
                SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSX", Locale.US),
                SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssX", Locale.US),
            ).forEach { formatter ->
                formatter.timeZone = TimeZone.getTimeZone("UTC")
                formatter.parse(trimmed)?.let { return it }
            }
            throw IllegalArgumentException("invalid_timestamp")
        }

        private fun parseIso(raw: String): Date = parseAssignmentTimestamp(raw)

        private fun PatientAssignmentRow.toDomain() = PatientAssignment(
            id = id,
            patientId = patientId,
            therapistId = therapistId,
            sessionId = sessionId,
            typeValue = type,
            createdAt = parseIso(createdAt),
            completedAt = completedAt?.let(::parseIso),
            cancelledAt = cancelledAt?.let(::parseIso),
        )
    }
}
