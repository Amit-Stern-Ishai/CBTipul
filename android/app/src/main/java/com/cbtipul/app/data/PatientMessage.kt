package com.cbtipul.app.data

import io.github.jan.supabase.SupabaseClient
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
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.util.Date

data class PatientMessage(
    val id: String,
    val patientId: String,
    val body: String,
    val createdAt: Date,
    val readAt: Date?,
) {
    val isUnread: Boolean get() = readAt == null
    fun markedRead(at: Date) = copy(readAt = readAt ?: at)
}

sealed class PatientMessageSendError : Exception() {
    data object Empty : PatientMessageSendError()
    data object TooLong : PatientMessageSendError()
    data object PatientNotFound : PatientMessageSendError()
    data object PatientNotConnected : PatientMessageSendError()
    data object NotSignedIn : PatientMessageSendError()
    data object Failed : PatientMessageSendError()
}

object PatientMessageDraft {
    const val MAX_LENGTH = 4000

    fun normalized(raw: String) = raw.trim()

    fun canSend(raw: String): Boolean {
        val body = normalized(raw)
        return body.isNotEmpty() && body.length <= MAX_LENGTH
    }
}

object PatientHomeMessages {
    const val PREVIEW_LIMIT = 2

    fun unread(messages: List<PatientMessage>) =
        messages.filter { it.isUnread }.sortedByDescending { it.createdAt.time }

    fun previews(messages: List<PatientMessage>) = unread(messages).take(PREVIEW_LIMIT)

    fun remainingUnreadCount(messages: List<PatientMessage>) =
        (unread(messages).size - PREVIEW_LIMIT).coerceAtLeast(0)
}

@Serializable
private data class PatientMessageRow(
    val id: String,
    @SerialName("patient_id") val patientId: String,
    val body: String,
    @SerialName("created_at") val createdAt: String,
    @SerialName("read_at") val readAt: String? = null,
)

@Serializable
private data class SendPatientMessageRequest(val patientId: String, val body: String)

@Serializable
private data class SendPatientMessageResponse(
    val success: Boolean? = null,
    val messageId: String? = null,
)

class PatientMessageRepository(private val client: SupabaseClient) {
    suspend fun messages(patientId: String): List<PatientMessage> {
        ensureConfigured()
        val rows = client.from("patient_messages")
            .select(columns) {
                filter { eq("patient_id", patientId) }
                order("created_at", Order.DESCENDING)
            }
            .decodeList<PatientMessageRow>()
        return rows.map { it.toDomain() }
    }

    suspend fun message(id: String): PatientMessage? {
        ensureConfigured()
        val rows = client.from("patient_messages")
            .select(columns) {
                filter { eq("id", id) }
                limit(1)
            }
            .decodeList<PatientMessageRow>()
        return rows.firstOrNull()?.toDomain()
    }

    suspend fun send(patientId: String, rawBody: String) {
        Entitlements.requireWrite()
        ensureConfigured()
        val body = PatientMessageDraft.normalized(rawBody)
        if (body.isEmpty()) throw PatientMessageSendError.Empty
        if (body.length > PatientMessageDraft.MAX_LENGTH) throw PatientMessageSendError.TooLong
        try {
            val http = client.functions.invoke(
                function = "send-patient-message",
                body = SendPatientMessageRequest(patientId = patientId, body = body),
                headers = Headers.build {
                    append(HttpHeaders.ContentType, ContentType.Application.Json.toString())
                },
            )
            val response = EdgePayload.json.decodeFromString(
                SendPatientMessageResponse.serializer(),
                http.bodyAsText(),
            )
            if (response.success == false) throw PatientMessageSendError.Failed
        } catch (error: PatientMessageSendError) {
            throw error
        } catch (error: Exception) {
            throw mapSendError(error)
        }
    }

    suspend fun markRead(id: String) {
        ensureConfigured()
        client.postgrest.rpc(
            "mark_patient_message_read",
            buildJsonObject { put("p_message_id", id) },
        )
    }

    private suspend fun mapSendError(error: Exception): PatientMessageSendError {
        val body = EdgePayload.responseBody(error)
        val (code, _) = EdgePayload.codeAndMessage(body)
        val status = EdgePayload.httpStatus(error)
        return when (code.uppercase()) {
            "PATIENT_NOT_FOUND" -> PatientMessageSendError.PatientNotFound
            "PATIENT_NOT_CONNECTED" -> PatientMessageSendError.PatientNotConnected
            "MESSAGE_EMPTY" -> PatientMessageSendError.Empty
            "MESSAGE_TOO_LONG" -> PatientMessageSendError.TooLong
            "UNAUTHORIZED", "FORBIDDEN" -> PatientMessageSendError.NotSignedIn
            else -> if (status == 401 || status == 403) {
                PatientMessageSendError.NotSignedIn
            } else {
                PatientMessageSendError.Failed
            }
        }
    }

    private fun ensureConfigured() {
        if (!SupabaseConfig.isConfigured) throw PatientMessageSendError.Failed
    }

    companion object {
        private val columns = Columns.raw("id, patient_id, body, created_at, read_at")

        private fun PatientMessageRow.toDomain() = PatientMessage(
            id = id,
            patientId = patientId,
            body = body,
            createdAt = PatientAssignmentRepository.parseAssignmentTimestamp(createdAt),
            readAt = readAt?.let(PatientAssignmentRepository::parseAssignmentTimestamp),
        )
    }
}
