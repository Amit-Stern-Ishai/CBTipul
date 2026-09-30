package com.cbtipul.app.data

import com.cbtipul.app.debug.InviteDebugLog
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.ktor.client.request.header
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import io.ktor.http.content.TextContent
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull

@Serializable
enum class InvitationKind {
    @kotlinx.serialization.SerialName("initial") Initial,
    @kotlinx.serialization.SerialName("replacement") Replacement,
}

@Serializable
data class PatientInvitation(
    val invitationId: String,
    val invitationUrl: String,
    val expiresAt: String,
)

@Serializable
enum class PatientInvitationPreviewStatus {
    @kotlinx.serialization.SerialName("valid") Valid,
    @kotlinx.serialization.SerialName("expired") Expired,
    @kotlinx.serialization.SerialName("claimed") Claimed,
    @kotlinx.serialization.SerialName("cancelled") Cancelled,
    @kotlinx.serialization.SerialName("invalid") Invalid,
}

@Serializable
data class PatientInvitationPreview(
    val status: PatientInvitationPreviewStatus,
    val therapistDisplayName: String? = null,
    val expiresAt: String? = null,
)

@Serializable
data class ClaimedPatientInvitation(
    val patientId: String,
    val therapistId: String,
)

@Serializable
internal data class CreatePatientInvitationRequest(
    val patientId: String,
    val kind: InvitationKind,
)

@Serializable
private data class GetPatientInvitationRequest(
    val token: String,
)

sealed class PatientInvitationClaimError : Exception() {
    data class Status(val status: PatientInvitationPreviewStatus) : PatientInvitationClaimError()
    data object Failed : PatientInvitationClaimError()
}

class PatientInvitationService(private val client: SupabaseClient) {
    suspend fun createPatientInvitation(patientId: String, kind: InvitationKind = InvitationKind.Initial): PatientInvitation {
        if (!SupabaseConfig.isConfigured) throw IllegalStateException("not_configured")
        val payload = encodeCreateRequest(patientId, kind)
        try {
            val http = client.functions.invoke("create-patient-invitation") {
                header(HttpHeaders.ContentType, ContentType.Application.Json.toString())
                setBody(TextContent(payload, ContentType.Application.Json))
            }
            return invitationFromEdgeJson(http.bodyAsText())
        } catch (error: Exception) {
            InviteDebugLog.e("create-patient-invitation", error)
            throw error
        }
    }

    suspend fun getPatientInvitation(token: String): PatientInvitationPreview {
        if (!SupabaseConfig.isConfigured) throw IllegalStateException("not_configured")
        val http = client.functions.invoke(
            function = "get-patient-invitation",
            body = GetPatientInvitationRequest(token = token),
            headers = jsonHeaders(),
        )
        return EdgePayload.json.decodeFromString(
            PatientInvitationPreview.serializer(),
            http.bodyAsText(),
        )
    }

    suspend fun claimPatientInvitation(token: String): ClaimedPatientInvitation {
        if (!SupabaseConfig.isConfigured) throw IllegalStateException("not_configured")
        try {
            val http = client.functions.invoke(
                function = "claim-patient-invitation",
                body = GetPatientInvitationRequest(token = token),
                headers = jsonHeaders(),
            )
            val claimed = EdgePayload.json.decodeFromString(
                ClaimedPatientInvitation.serializer(),
                http.bodyAsText(),
            )
            InviteDebugLog.d(
                "Claim response: patientId present = ${InviteDebugLog.present(claimed.patientId)}, " +
                    "therapistId present = ${InviteDebugLog.present(claimed.therapistId)}",
            )
            return claimed
        } catch (error: PatientInvitationClaimError) {
            throw error
        } catch (error: Exception) {
            InviteDebugLog.e("claim-patient-invitation", error)
            val body = EdgePayload.responseBody(error)
            val preview = runCatching {
                EdgePayload.json.decodeFromString(PatientInvitationPreview.serializer(), body)
            }.getOrNull()
            if (preview != null && preview.status != PatientInvitationPreviewStatus.Valid) {
                throw PatientInvitationClaimError.Status(preview.status)
            }
            throw PatientInvitationClaimError.Failed
        }
    }

    private fun jsonHeaders() = Headers.build {
        append(HttpHeaders.ContentType, ContentType.Application.Json.toString())
    }

    companion object {
        internal fun encodeCreateRequest(patientId: String, kind: InvitationKind = InvitationKind.Initial): String =
            EdgePayload.json.encodeToString(
                CreatePatientInvitationRequest.serializer(),
                CreatePatientInvitationRequest(
                    patientId = patientId,
                    kind = kind,
                ),
            )

        internal fun invitationFromEdgeJson(json: String): PatientInvitation {
            val root = EdgePayload.json.parseToJsonElement(json)
            val obj = root as? JsonObject ?: throw IllegalStateException("invalid_invitation")
            val invitation = obj["invitation"] as? JsonObject ?: obj
            fun field(vararg keys: String): String? =
                keys.firstNotNullOfOrNull { key ->
                    (invitation[key] as? JsonPrimitive)?.contentOrNull?.takeIf { it.isNotBlank() }
                }
            val invitationId = field("invitationId", "invitation_id")
                ?: throw IllegalStateException("invalid_invitation")
            val invitationUrl = field("invitationUrl", "invitation_url")
                ?: throw IllegalStateException("invalid_invitation")
            return PatientInvitation(
                invitationId = invitationId,
                invitationUrl = invitationUrl,
                expiresAt = field("expiresAt", "expires_at").orEmpty(),
            )
        }
    }
}

object PatientInvitationShare {
    const val SUBJECT = "הזמנה להתחבר ל-CBTipul"

    fun message(therapistName: String, invitationUrl: String): String =
        "היי,\n\n" +
            "$therapistName הזמין/ה אותך להתחבר ל-CBTipul.\n\n" +
            "דרך האפליקציה ניתן למלא שאלונים ויומנים ולצפות בתכנים שנשלחו אליך כחלק מהטיפול.\n\n" +
            "לפתיחת ההזמנה:\n" +
            "$invitationUrl\n\n" +
            "ההזמנה אישית ומיועדת עבורך בלבד."
}
