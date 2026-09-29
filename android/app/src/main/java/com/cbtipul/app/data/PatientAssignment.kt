package com.cbtipul.app.data

import com.cbtipul.app.debug.InviteDebugLog
import com.cbtipul.app.model.DatabaseId
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import io.ktor.client.request.header
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import io.ktor.http.content.TextContent
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
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
    DiaryThree("diary_three"),
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
    val sessionId: String? = null,
)

@Serializable
internal data class RequestPatientDiaryOneRequest(
    val patientId: String,
)

@Serializable
internal data class RequestPatientDiaryOneAssignmentDto(
    val id: String,
    val patientId: String,
    val therapistId: String? = null,
    val sessionId: String? = null,
    val type: String,
    val createdAt: String,
    val completedAt: String? = null,
    val cancelledAt: String? = null,
)

@Serializable
internal data class RequestPatientDiaryOneResponse(
    val success: Boolean = true,
    val assignment: RequestPatientDiaryOneAssignmentDto,
    val createdNew: Boolean = true,
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

/** A cached null ID means loaded and inactive, rather than still unknown. */
class AssignmentStatusCache {
    data class Snapshot(val assignmentId: String?)
    private data class Entry(val snapshot: Snapshot, val revision: Int)
    private val entries = mutableMapOf<Pair<String, String>, Entry>()
    fun value(account: String?, resource: String): Snapshot? = account?.let { entries[it to resource]?.snapshot }
    fun revision(account: String?, resource: String): Int = account?.let { entries[it to resource]?.revision } ?: 0
    fun store(id: String?, account: String?, resource: String, ifRevision: Int? = null) {
        if (account == null) return
        val current = revision(account, resource)
        if (ifRevision != null && ifRevision != current) return
        entries[account to resource] = Entry(Snapshot(id), current + 1)
    }
}

class PatientAssignmentRepository(private val client: SupabaseClient) {
    private val connectionCache = mutableMapOf<Pair<String, String>, Boolean>()
    private val assignmentCache = AssignmentStatusCache()
    private fun currentAccount() = client.auth.currentSessionOrNull()?.user?.id
    fun cachedOngoingAssignment(patientId: String, type: PatientAssignmentType) =
        assignmentCache.value(currentAccount(), "patient/$patientId/${type.raw}")
    fun cachedQuestionnaireAssignment(sessionId: String) =
        assignmentCache.value(currentAccount(), "session/$sessionId")
    private fun cacheAssignment(assignment: PatientAssignment, account: String?) {
        if (account != currentAccount()) return
        val type = assignment.type ?: return
        if (type == PatientAssignmentType.Questionnaire && assignment.sessionId != null) {
            assignmentCache.store(if (assignment.isOpen) assignment.id else null, account, "session/${assignment.sessionId}")
        } else {
            assignmentCache.store(if (assignment.cancelledAt == null) assignment.id else null, account, "patient/${assignment.patientId}/${type.raw}")
        }
    }

    fun cachedPatientConnection(patientId: String): Boolean? =
        client.auth.currentSessionOrNull()?.user?.id?.let { connectionCache[it to patientId] }

    suspend fun isPatientConnected(patientId: String): Boolean {
        ensureConfigured()
        val userId = client.auth.currentSessionOrNull()?.user?.id
        val result = client.postgrest.rpc(
            "is_patient_connected",
            buildJsonObject { put("p_patient_id", patientId) },
        )
        val connected = Json.parseToJsonElement(result.data).jsonPrimitive.boolean
        if (userId != null && userId == client.auth.currentSessionOrNull()?.user?.id) {
            connectionCache[userId to patientId] = connected
        }
        return connected
    }

    suspend fun openQuestionnaireAssignment(sessionId: String): PatientAssignment? {
        ensureConfigured()
        val account = currentAccount()
        val resource = "session/$sessionId"
        val revision = assignmentCache.revision(account, resource)
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
        if (account == currentAccount()) assignmentCache.store(rows.firstOrNull()?.id, account, resource, revision)
        return rows.firstOrNull()?.toDomain()
    }

    suspend fun sendQuestionnaireAssignment(patientId: String, sessionId: String? = null): PatientAssignment {
        ensureConfigured()
        val account = currentAccount()
        val payload = encodeQuestionnaireRequest(patientId, sessionId)
        InviteDebugLog.d("request-patient-questionnaire sessionIdPresent=${sessionId != null}")
        return try {
            val http = client.functions.invoke("request-patient-questionnaire") {
                header(HttpHeaders.ContentType, ContentType.Application.Json.toString())
                setBody(TextContent(payload, ContentType.Application.Json))
            }
            val body = http.bodyAsText()
            try {
                assignmentFromEdgeJson(body).also { cacheAssignment(it, account) }
            } catch (error: Exception) {
                InviteDebugLog.e("request-patient-questionnaire-parse", error)
                throw PatientAssignmentException.InvalidIdentifier
            }
        } catch (error: PatientAssignmentException) {
            throw error
        } catch (error: Exception) {
            InviteDebugLog.e("request-patient-questionnaire", error)
            throw mapRequestQuestionnaireError(error)
        }
    }

    suspend fun activeOngoingAssignment(patientId: String, type: PatientAssignmentType): PatientAssignment? {
        ensureConfigured()
        requireOngoing(type)
        val account = currentAccount()
        val resource = "patient/$patientId/${type.raw}"
        val revision = assignmentCache.revision(account, resource)
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
        if (account == currentAccount()) assignmentCache.store(rows.firstOrNull()?.id, account, resource, revision)
        return rows.firstOrNull()?.toDomain()
    }

    suspend fun activateOngoingAssignment(patientId: String, type: PatientAssignmentType): PatientAssignment {
        ensureConfigured()
        val account = currentAccount()
        requireOngoing(type)
        if (!isPatientConnected(patientId)) throw PatientAssignmentException.PatientNotConnected
        if (type == PatientAssignmentType.DiaryOne) {
            return requestPatientDiaryOne(patientId).also { cacheAssignment(it, account) }
        }
        if (type == PatientAssignmentType.DiaryTwo) {
            return requestPatientDiaryTwo(patientId).also { cacheAssignment(it, account) }
        }
        if (type == PatientAssignmentType.DiaryThree) {
            return requestPatientDiaryThree(patientId).also { cacheAssignment(it, account) }
        }
        throw PatientAssignmentException.InvalidIdentifier
    }

    private suspend fun requestPatientDiaryTwo(patientId: String): PatientAssignment {
        return try {
            val http = client.functions.invoke(
                function = FUNCTION_REQUEST_DIARY_TWO,
                body = RequestPatientDiaryOneRequest(patientId),
                headers = Headers.build { append(HttpHeaders.ContentType, ContentType.Application.Json.toString()) },
            )
            assignmentFromDiaryTwoResponse(http.bodyAsText()).also {
                if (!it.patientId.equals(patientId, ignoreCase = true)) throw PatientAssignmentException.InvalidIdentifier
            }
        } catch (error: PatientAssignmentException) {
            throw error
        } catch (error: Exception) {
            throw mapRequestDiaryOneError(error)
        }
    }

    private suspend fun requestPatientDiaryThree(patientId: String): PatientAssignment {
        return try {
            val http = client.functions.invoke(
                function = FUNCTION_REQUEST_DIARY_THREE,
                body = RequestPatientDiaryOneRequest(patientId),
                headers = Headers.build { append(HttpHeaders.ContentType, ContentType.Application.Json.toString()) },
            )
            assignmentFromDiaryThreeResponse(http.bodyAsText()).also {
                if (!it.patientId.equals(patientId, ignoreCase = true)) throw PatientAssignmentException.InvalidIdentifier
            }
        } catch (error: PatientAssignmentException) {
            throw error
        } catch (error: Exception) {
            throw mapRequestDiaryOneError(error)
        }
    }

    private suspend fun requestPatientDiaryOne(patientId: String): PatientAssignment {
        return try {
            val http = client.functions.invoke(
                function = FUNCTION_REQUEST_DIARY_ONE,
                body = RequestPatientDiaryOneRequest(patientId = patientId),
                headers = Headers.build {
                    append(HttpHeaders.ContentType, ContentType.Application.Json.toString())
                },
            )
            assignmentFromDiaryOneResponse(http.bodyAsText())
        } catch (error: PatientAssignmentException) {
            throw error
        } catch (error: Exception) {
            throw mapRequestDiaryOneError(error)
        }
    }

    suspend fun cancelOngoingAssignment(id: String) {
        ensureConfigured()
        val account = currentAccount()
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
        updated.forEach { cacheAssignment(it.toDomain(), account) }
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

    private suspend fun mapRequestDiaryOneError(error: Exception): PatientAssignmentException {
        val body = EdgePayload.responseBody(error)
        val (code, _) = EdgePayload.codeAndMessage(body)
        val status = EdgePayload.httpStatus(error)
        return mapRequestDiaryOneCode(code, status)
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

        internal const val FUNCTION_REQUEST_DIARY_ONE = "request-patient-diary-one"

        fun usesDiaryOneEdgeFunction(type: PatientAssignmentType): Boolean =
            type == PatientAssignmentType.DiaryOne

        fun usesDirectInsert(type: PatientAssignmentType): Boolean = false

        internal const val FUNCTION_REQUEST_DIARY_TWO = "request-patient-diary-two"
        fun usesDiaryTwoEdgeFunction(type: PatientAssignmentType) = type == PatientAssignmentType.DiaryTwo
        internal fun encodeDiaryTwoRequest(patientId: String) = encodeDiaryOneRequest(patientId)
        internal fun assignmentFromDiaryTwoResponse(json: String): PatientAssignment =
            assignmentFromDiaryOneResponse(json).also {
                if (it.type != PatientAssignmentType.DiaryTwo || it.sessionId != null || it.cancelledAt != null) {
                    throw PatientAssignmentException.InvalidIdentifier
                }
            }

        internal const val FUNCTION_REQUEST_DIARY_THREE = "request-patient-diary-three"
        fun usesDiaryThreeEdgeFunction(type: PatientAssignmentType) = type == PatientAssignmentType.DiaryThree
        internal fun encodeDiaryThreeRequest(patientId: String) = encodeDiaryOneRequest(patientId)
        internal fun assignmentFromDiaryThreeResponse(json: String): PatientAssignment =
            assignmentFromDiaryOneResponse(json).also {
                if (it.type != PatientAssignmentType.DiaryThree || it.sessionId != null || it.cancelledAt != null) {
                    throw PatientAssignmentException.InvalidIdentifier
                }
            }

        fun uuidOrNull(id: DatabaseId): String? =
            runCatching { UUID.fromString(id.queryValue).toString() }.getOrNull()

        internal fun encodeQuestionnaireRequest(patientId: String, sessionId: String?): String =
            EdgePayload.json.encodeToString(
                RequestPatientQuestionnaireRequest.serializer(),
                RequestPatientQuestionnaireRequest(patientId = patientId, sessionId = sessionId),
            )

        internal fun assignmentFromEdgeJson(json: String): PatientAssignment {
            val root = EdgePayload.json.parseToJsonElement(json)
            val obj = root as? JsonObject ?: throw PatientAssignmentException.InvalidIdentifier
            val assignment = obj["assignment"] as? JsonObject ?: obj
            fun field(vararg keys: String): String? =
                keys.firstNotNullOfOrNull { key ->
                    (assignment[key] as? JsonPrimitive)?.contentOrNull?.takeIf { it.isNotBlank() }
                }
            val id = field("id") ?: throw PatientAssignmentException.InvalidIdentifier
            val patientId = field("patientId", "patient_id")
                ?: throw PatientAssignmentException.InvalidIdentifier
            val typeValue = field("type", "typeValue")
                ?: throw PatientAssignmentException.InvalidIdentifier
            val createdAt = field("createdAt", "created_at")
                ?: throw PatientAssignmentException.InvalidIdentifier
            return PatientAssignment(
                id = id,
                patientId = patientId,
                therapistId = field("therapistId", "therapist_id"),
                sessionId = field("sessionId", "session_id"),
                typeValue = typeValue,
                createdAt = parseAssignmentTimestamp(createdAt),
                completedAt = field("completedAt", "completed_at")?.let(::parseAssignmentTimestamp),
                cancelledAt = field("cancelledAt", "cancelled_at")?.let(::parseAssignmentTimestamp),
            )
        }

        internal fun mapRequestQuestionnaireCode(code: String, status: Int?): PatientAssignmentException {
            return when (code.lowercase()) {
                "patient_not_connected" -> PatientAssignmentException.PatientNotConnected
                "unauthorized" -> PatientAssignmentException.NotSignedIn
                else -> if (status == 401 || status == 403) {
                    PatientAssignmentException.NotSignedIn
                } else {
                    PatientAssignmentException.InvalidIdentifier
                }
            }
        }

        internal fun mapRequestDiaryOneCode(code: String, status: Int?): PatientAssignmentException {
            return when (code) {
                "patient_not_connected" -> PatientAssignmentException.PatientNotConnected
                "unauthorized", "therapist_mode_required" -> PatientAssignmentException.NotSignedIn
                "patient_not_found", "invalid_request" -> PatientAssignmentException.InvalidIdentifier
                else -> if (status == 401 || status == 403) {
                    PatientAssignmentException.NotSignedIn
                } else {
                    PatientAssignmentException.InvalidIdentifier
                }
            }
        }

        internal fun encodeDiaryOneRequest(patientId: String): String =
            EdgePayload.json.encodeToString(
                RequestPatientDiaryOneRequest.serializer(),
                RequestPatientDiaryOneRequest(patientId),
            )

        internal fun assignmentFromDiaryOneResponse(json: String): PatientAssignment {
            val response = EdgePayload.json.decodeFromString(
                RequestPatientDiaryOneResponse.serializer(),
                json,
            )
            if (!response.success) throw PatientAssignmentException.InvalidIdentifier
            val dto = response.assignment
            return PatientAssignment(
                id = dto.id,
                patientId = dto.patientId,
                therapistId = dto.therapistId,
                sessionId = dto.sessionId,
                typeValue = dto.type,
                createdAt = parseAssignmentTimestamp(dto.createdAt),
                completedAt = dto.completedAt?.let(::parseAssignmentTimestamp),
                cancelledAt = dto.cancelledAt?.let(::parseAssignmentTimestamp),
            )
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
