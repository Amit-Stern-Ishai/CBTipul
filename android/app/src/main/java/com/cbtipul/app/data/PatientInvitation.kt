package com.cbtipul.app.data

import com.cbtipul.app.debug.InviteDebugLog
import com.cbtipul.app.auth.AuthRepository
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.network.supabaseApi
import io.ktor.client.request.header
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
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
    suspend fun emailInvitationStatus(patientId: String): String {
        val owner = client.auth.currentUserOrNull()?.id ?: error("not_signed_in")
        val status = client.postgrest.rpc("get_patient_email_invitation_status",
            JsonObject(mapOf("p_patient_id" to JsonPrimitive(patientId)))).decodeAs<String>()
        check(owner == client.auth.currentUserOrNull()?.id)
        check(status in setOf("pending", "connected", "no_invitation")) { "invalid_invitation_status" }
        return status
    }
    suspend fun saveEmailInvitation(patientId: String, email: String): String {
        Entitlements.requireWrite()
        check(Entitlements.state.value.role == AppRole.Therapist)
        val owner = client.auth.currentUserOrNull()?.id ?: error("not_signed_in")
        try {
            val response = client.functions.invoke("save-patient-email-invitation", body = JsonObject(mapOf(
                "patient_id" to JsonPrimitive(patientId), "email" to JsonPrimitive(email))))
            check(owner == client.auth.currentUserOrNull()?.id)
            val json = EdgePayload.json.decodeFromString<JsonObject>(response.bodyAsText())
            val outcome = (json["status"] as? JsonPrimitive)?.contentOrNull ?: "invalid_response"
            logEmailInvitation(response.status.value, outcome)
            check(outcome != "invalid_response")
            return outcome
        } catch (cancel: kotlinx.coroutines.CancellationException) { throw cancel }
        catch (error: Exception) {
            logEmailInvitation(EdgePayload.httpStatus(error), EdgePayload.codeAndMessage(EdgePayload.responseBody(error)).first)
            throw error
        }
    }

    suspend fun createPatientInvitation(patientId: String, kind: InvitationKind = InvitationKind.Initial): PatientInvitation {
        return com.cbtipul.app.telemetry.Telemetry.measure(com.cbtipul.app.telemetry.Flow.sharing,feature=com.cbtipul.app.telemetry.Feature.invitationCreation) {
        Entitlements.requireWrite()
        if (!SupabaseConfig.isConfigured) throw IllegalStateException("not_configured")
        val payload = encodeCreateRequest(patientId, kind)
        try {
            val http = client.functions.invoke("create-patient-invitation") {
                header(HttpHeaders.ContentType, ContentType.Application.Json.toString())
                setBody(TextContent(payload, ContentType.Application.Json))
            }
            return@measure invitationFromEdgeJson(http.bodyAsText())
        } catch (error: Exception) {
            InviteDebugLog.e("create-patient-invitation", error)
            throw error
        }

        }
    }

    suspend fun getPatientInvitation(token: String): PatientInvitationPreview {
        if (!SupabaseConfig.isConfigured) throw IllegalStateException("not_configured")
        // Public preview bypasses authenticatedSupabaseApi and any restored
        // therapist session refresh. This matches the no-session request auth.
        val http = client.supabaseApi(client.functions).post("get-patient-invitation") {
            header(HttpHeaders.Authorization, "Bearer ${SupabaseConfig.ANON_KEY}")
            header(HttpHeaders.ContentType, ContentType.Application.Json.toString())
            setBody(TextContent(EdgePayload.json.encodeToString(
                GetPatientInvitationRequest.serializer(), GetPatientInvitationRequest(token),
            ), ContentType.Application.Json))
        }
        return EdgePayload.json.decodeFromString(
            PatientInvitationPreview.serializer(),
            http.bodyAsText(),
        )
    }

    suspend fun claimPatientInvitation(token: String): ClaimedPatientInvitation {
        if (!SupabaseConfig.isConfigured) throw IllegalStateException("not_configured")
        val session = client.auth.currentSessionOrNull()
        if (session == null || !AuthRepository.isAnonymousSession(session)) throw PatientInvitationClaimError.Failed
        try {
            // SDK 3.2.2 adds dynamic auth before this builder. Replace it with
            // the anonymous session checked above, even if auth changes later.
            val http = client.functions.invoke("claim-patient-invitation") {
                headers.remove(HttpHeaders.Authorization)
                header(HttpHeaders.Authorization, "Bearer ${session.accessToken}")
                header(HttpHeaders.ContentType, ContentType.Application.Json.toString())
                setBody(TextContent(EdgePayload.json.encodeToString(
                    GetPatientInvitationRequest.serializer(), GetPatientInvitationRequest(token),
                ), ContentType.Application.Json))
            }
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
            InviteDebugLog.d("Invitation claim failed")
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

    /** Escape dynamic values before placing them into the localized HTML template. */
    fun emailHtml(template: String, therapistName: String, invitationUrl: String): String {
        fun escape(value: String) = value.replace("&", "&amp;")
            .replace("<", "&lt;").replace(">", "&gt;")
            .replace("\"", "&quot;").replace("'", "&#39;")
        return String.format(java.util.Locale.ROOT, template, escape(therapistName), escape(invitationUrl))
    }


    fun message(therapistName: String, invitationUrl: String): String =
        "היי,\n\n" +
            "$therapistName הזמין/ה אותך להתחבר ל-CBTipul.\n\n" +
            "דרך האפליקציה ניתן למלא שאלוני מצב רוח ויומני מחשבות ולצפות בתכנים שנשלחו אליך כחלק מהטיפול.\n\n" +
            "לפתיחת ההזמנה:\n" +
            "$invitationUrl\n\n" +
            "ההזמנה אישית ומיועדת עבורך בלבד."
}

/** Only allowlisted outcomes and HTTP status, never server messages or request data. */
private fun logEmailInvitation(status: Int?, outcome: String) {
    if (!com.cbtipul.app.BuildConfig.DEBUG) return
    val safe = outcome.takeIf { it in setOf("waiting_for_sign_in", "waiting_for_confirmation", "already_connected", "email_unavailable", "invalid_email", "invalid_response") } ?: "request_failed"
    android.util.Log.d("CBTipulEmailInvite", "http=${status ?: 0} outcome=$safe")
}
