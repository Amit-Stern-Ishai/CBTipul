package com.cbtipul.app.data

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import kotlinx.serialization.json.*

/** Per-authentication-session memory only; the server remains the role authority. */
internal class EmailInvitationClaim(
    private val eligible: () -> Boolean,
    private val request: suspend (String?) -> Response,
) {
    enum class State { Idle, Checking, Confirmation, Unavailable, Verification, Failed, Done }
    private val mutableState = MutableStateFlow(State.Idle)
    val state = mutableState.asStateFlow()
    private var generation = 0
    data class Response(val status: String, val invitationRevision: String? = null)
    private var revision: String? = null
    private var confirmedRevision: String? = null
    private var awaitingPatient = false
    private var attempted = false
    fun reset() { generation++; mutableState.value = State.Idle; revision = null; confirmedRevision = null; awaitingPatient = false; attempted = false }
    fun retry(confirmSwitch: Boolean = false) {
        if (state.value == State.Checking) return
        if (confirmSwitch) {
            if (state.value != State.Confirmation || revision == null) return
            confirmedRevision = revision
        }
        mutableState.value = State.Idle
    }
    fun decline() {
        if (state.value in setOf(State.Confirmation, State.Unavailable)) mutableState.value = State.Done
    }
    suspend fun resolve(context: AppContext, reload: suspend () -> AppContext): AppContext? {
        if (context.isActivePatient) { awaitingPatient = false; mutableState.value = State.Done; return context }
        if (context.role == AppRole.Patient && !eligible()) return context
        if (state.value == State.Done) return context
        if (state.value != State.Idle) return null
        if (!attempted && !eligible()) return context
        attempted = true
        val epoch = generation
        mutableState.value = State.Checking
        fun ensureCurrent() { if (epoch != generation) throw CancellationException() }
        try {
            check(!awaitingPatient) { "claim_role_not_confirmed" }
            val wasConfirmation = confirmedRevision != null
            var response = request(confirmedRevision)
            ensureCurrent()
            if (response.status == "invitation_changed") {
                revision = null; confirmedRevision = null
                response = request(null); ensureCurrent()
            }
            when (response.status) {
                "connected" -> {
                    awaitingPatient = true
                    val updated = reload(); ensureCurrent()
                    check(updated.isActivePatient) { "claim_role_not_confirmed" }
                    awaitingPatient = false; mutableState.value = State.Done; return updated
                }
                "no_match" -> {
                    val updated = if (wasConfirmation) reload() else context
                    ensureCurrent(); mutableState.value = State.Done; return updated
                }
                "confirmation_required" -> {
                    val value = response.invitationRevision
                    check(value != null && runCatching { java.util.UUID.fromString(value).toString().equals(value, true) }.getOrDefault(false)) { "invalid_claim_response" }
                    revision = value; confirmedRevision = null
                    mutableState.value = State.Confirmation
                }
                "invitation_changed" -> {
                    revision = null; confirmedRevision = null
                    error("invitation_changed")
                }
                "connection_unavailable" -> mutableState.value = State.Unavailable
                "email_not_verified" -> mutableState.value = State.Verification
                else -> error("invalid_claim_response")
            }
            return null
        } catch (error: Exception) {
            if (epoch == generation) mutableState.value = State.Failed
            throw error
        }
    }
    companion object {
        @OptIn(kotlin.time.ExperimentalTime::class)
        fun live(client: SupabaseClient) = EmailInvitationClaim(eligible = {
            val user = client.auth.currentSessionOrNull()?.user
            user != null && !com.cbtipul.app.auth.AuthRepository.isAnonymousSession(client.auth.currentSessionOrNull()!!) && user.emailConfirmedAt != null && !user.email.isNullOrBlank()
        }, request = { revision ->
            try {
                val response = client.functions.invoke("claim-patient-email-invitation", body = buildJsonObject {
                    put("version", 2)
                    revision?.let { put("invitation_revision", it) }
                })
                val payload = EdgePayload.json.parseToJsonElement(response.bodyAsText()).jsonObject
                Response(payload["status"]?.jsonPrimitive?.content ?: error("invalid_claim_response"),
                    payload["invitation_revision"]?.jsonPrimitive?.contentOrNull)
            } catch (error: Exception) {
                val code = EdgePayload.codeAndMessage(EdgePayload.responseBody(error)).first
                if (code in setOf("connection_unavailable", "email_not_verified", "invitation_changed")) Response(code!!) else throw error
            }
        })
    }
}
