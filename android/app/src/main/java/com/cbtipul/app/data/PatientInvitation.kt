package com.cbtipul.app.data

import com.cbtipul.app.debug.InviteDebugLog
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import kotlinx.serialization.Serializable

@Serializable
enum class InvitationKind {
    @kotlinx.serialization.SerialName("initial") Initial,
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
private data class CreatePatientInvitationRequest(
    val patientId: String,
    val kind: InvitationKind = InvitationKind.Initial,
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
    suspend fun createPatientInvitation(patientId: String): PatientInvitation {
        if (!SupabaseConfig.isConfigured) throw IllegalStateException("not_configured")
        val http = client.functions.invoke(
            function = "create-patient-invitation",
            body = CreatePatientInvitationRequest(patientId = patientId),
            headers = jsonHeaders(),
        )
        return EdgePayload.json.decodeFromString(PatientInvitation.serializer(), http.bodyAsText())
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
}
