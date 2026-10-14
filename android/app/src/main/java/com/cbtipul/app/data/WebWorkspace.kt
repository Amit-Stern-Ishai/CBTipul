package com.cbtipul.app.data

import com.cbtipul.app.model.CombinedMoodQuestionnaire
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.*
import java.util.UUID

@Serializable data class WebWorkspaceSummary(val id: String, val started_at: String, val finished_at: String, val reference_label: String? = null, val item_count: Int, val has_notes: Boolean)
@Serializable data class WebWorkspace(val id: String, val status: String, val started_at: String, val finished_at: String? = null, val reference_label: String? = null, val payload: WebWorkspacePayload)
@Serializable data class WebWorkspacePayload(val version: Int, val notes: String, val items: List<WebWorksheet>) {
    val hasNotes get() = notes.isNotBlank()
    val hasQuestionnaire get() = items.any { it.type == "questionnaire" }
}
@Serializable data class WebQuestionnaire(val gad7_answers: List<Int>, val phq9_answers: List<Int>, val interference_level: Int, val notes: String? = null) {
    init { require(gad7_answers.size == 7 && phq9_answers.size == 9 && (gad7_answers + phq9_answers + interference_level).all { it in 0..3 }) }
    val questionnaire get() = CombinedMoodQuestionnaire(gad7_answers, phq9_answers, interference_level)
    val flagsQuestionNine get() = phq9_answers[8] > 0
}
@Serializable data class WebDiary(val event: String, val automatic_thoughts: List<String>, val feelings: List<DiaryFeeling>, val behaviour: String? = null, val physical_symptoms: String? = null, val thinking_errors: List<ThinkingError>? = null, val alternative_thoughts: List<String>? = null)
@Serializable data class WebDiaryThree(val situation: String, val automatic_thoughts: List<DiaryThreeAutomaticThought>, val feelings: List<DiaryThreeFeeling>, val thinking_errors: List<ThinkingError>, val alternative_thoughts: List<DiaryThreeAlternativeThought>)
@Serializable data class WebWorksheet(val id: String, val type: String, val completed_at: String, val measurement_date: String? = null, val data: JsonObject) {
    fun questionnaire() = webWorkspaceJson.decodeFromJsonElement<WebQuestionnaire>(data)
    fun diary() = webWorkspaceJson.decodeFromJsonElement<WebDiary>(data)
    fun diaryThree() = webWorkspaceJson.decodeFromJsonElement<WebDiaryThree>(data)
    fun validate() {
        UUID.fromString(id)
        when (type) {
            "questionnaire" -> { questionnaire(); require(measurement_date != null) }
            "diary_one", "diary_two" -> diary()
            "diary_three" -> diaryThree()
            else -> error("unknown_worksheet")
        }
    }
}
val webWorkspaceJson = Json { ignoreUnknownKeys = true; encodeDefaults = true }

/** Routing identifiers only; never upload local patient names. */
@Serializable data class WebAssociationRequest(
    val p_workspace_id: String, val p_patient_id: String,
    val p_existing_session_id: String? = null, val p_create_session: Boolean = false,
    val p_link_questionnaire: Boolean = false, val p_session_date: String? = null,
    val p_session_type: String? = null,
) {
    fun valid(hasNotes: Boolean, hasQuestionnaire: Boolean): Boolean =
        NotificationRouting.uuidOrNull(p_patient_id) != null &&
        !(p_create_session && p_existing_session_id != null) &&
        (!p_link_questionnaire || hasQuestionnaire) &&
        (p_create_session || p_existing_session_id != null) == (hasNotes || p_link_questionnaire) &&
        if (p_create_session) p_session_date != null && !p_session_type.isNullOrBlank() else p_session_date == null && p_session_type == null
}
@Serializable data class WebAssociationResource(val item_id: String, val type: String, val id: String)
@Serializable data class WebAssociationResult(val workspace_id: String, val patient_id: String, val session_id: String? = null, val resources: List<WebAssociationResource>)

enum class WebWorkspaceFailure { InvalidSelection, Unavailable, Conflict, PatientMissing, SessionMissing, ReadOnly, Uncertain;
    companion object {
        fun classify(error: Throwable): WebWorkspaceFailure {
            // Match only known server rejection tokens. Unknown/transport failures keep the exact request.
            val message = error.message.orEmpty()
            return when {
                message.contains("session_already_has_questionnaire") -> Conflict
                listOf("workspace_not_found", "workspace_not_pending", "already_associated").any(message::contains) -> Unavailable
                message.contains("patient_not_found") -> PatientMissing
                message.contains("session_not_found") -> SessionMissing
                listOf("read_only", "therapist_access_required", "unauthorized").any(message::contains) -> ReadOnly
                listOf("invalid_association", "session_required", "unused_session_target", "new_session_details_required", "unexpected_session_details", "no_questionnaire").any(message::contains) -> InvalidSelection
                else -> Uncertain
            }
        }
    }
}
class WebWorkspaceException(val failure: WebWorkspaceFailure) : Exception(failure.name)
data class WebWorkspaceState(val items: List<WebWorkspaceSummary> = emptyList(), val loading: Boolean = false, val failed: Boolean = false, val busy: Set<String> = emptySet(), val requests: Map<String, WebAssociationRequest> = emptyMap(), val refreshFailed: Boolean = false, val closedIDs: Set<String> = emptySet())

/** The injected RPC transport and receipt persistence allow lost-response regression checks. */
class WebWorkspaceRepository(
    private val rpc: suspend (String, JsonObject) -> String,
    private val currentUser: () -> String?,
    private val readRequests: (String) -> String?,
    private val writeRequests: (String, String) -> Unit,
    private val canWrite: () -> Boolean = { Entitlements.state.value.access == EntitlementAccess.Full },
) {
    private val mutable = MutableStateFlow(WebWorkspaceState())
    val state = mutable.asStateFlow()
    private var owner: String? = null
    private var generation = 0
    var refreshRecords: (suspend (String) -> Boolean)? = null
    var refreshNotifications: (suspend () -> Unit)? = null
    private var lastPatient: String? = null
    fun clear() { generation++; owner = null; lastPatient = null; mutable.value = WebWorkspaceState() }
    private fun identify(): String {
        val user = currentUser() ?: throw WebWorkspaceException(WebWorkspaceFailure.ReadOnly)
        if (owner != user) {
            clear(); owner = user
            val requests = readRequests(user)?.let { runCatching { webWorkspaceJson.decodeFromString<Map<String, WebAssociationRequest>>(it) }.getOrNull() }.orEmpty()
            mutable.value = mutable.value.copy(requests = requests)
        }
        return user
    }
    private fun request(id: String, value: WebAssociationRequest?) {
        val requests = mutable.value.requests.toMutableMap().apply { if (value == null) remove(id) else put(id, value) }
        mutable.value = mutable.value.copy(requests = requests)
        owner?.let { writeRequests(it, webWorkspaceJson.encodeToString(requests)) }
    }
    suspend fun refresh() {
        if (mutable.value.loading) return
        val user = try { identify() } catch (_: Exception) { return }
        val revision = generation
        mutable.value = mutable.value.copy(loading = true)
        try {
            val all = mutableListOf<WebWorkspaceSummary>()
            do {
                val page = webWorkspaceJson.decodeFromString<List<WebWorkspaceSummary>>(rpc("list_pending_web_workspaces", buildJsonObject { put("p_limit", 100); put("p_offset", all.size) }))
                all.addAll(page)
            } while (page.size == 100)
            if (owner == user && generation == revision) mutable.value = mutable.value.copy(items = all.distinctBy { it.id }, failed = false)
        } catch (e: CancellationException) { throw e }
        catch (_: Exception) { if (generation == revision) mutable.value = mutable.value.copy(failed = true) }
        finally { if (generation == revision) mutable.value = mutable.value.copy(loading = false) }
    }
    suspend fun load(id: String): WebWorkspace {
        identify()
        return webWorkspaceJson.decodeFromString<WebWorkspace>(rpc("get_pending_web_workspace", buildJsonObject { put("p_workspace_id", id) })).also {
            require(it.payload.version == 1 && it.status == "pending")
            it.payload.items.forEach(WebWorksheet::validate)
        }
    }
    suspend fun associate(proposed: WebAssociationRequest) {
        val user = identify()
        if (!canWrite()) throw WebWorkspaceException(WebWorkspaceFailure.ReadOnly)
        val id = proposed.p_workspace_id
        if (id in mutable.value.closedIDs) throw WebWorkspaceException(WebWorkspaceFailure.Unavailable)
        if (id in mutable.value.busy) throw WebWorkspaceException(WebWorkspaceFailure.Uncertain)
        val request = mutable.value.requests[id] ?: proposed
        request(id, request)
        mutable.value = mutable.value.copy(busy = mutable.value.busy + id)
        try {
            val result = webWorkspaceJson.decodeFromString<WebAssociationResult>(rpc("associate_web_workspace", webWorkspaceJson.encodeToJsonElement(request).jsonObject))
            if (owner != user) return
            request(id, null)
            lastPatient = result.patient_id
            mutable.value = mutable.value.copy(items = mutable.value.items.filterNot { it.id == id })
            refreshAfterSuccess()
        } catch (e: CancellationException) { throw e }
        catch (e: Exception) {
            val failure = (e as? WebWorkspaceException)?.failure ?: WebWorkspaceFailure.classify(e)
            if (owner == user && failure != WebWorkspaceFailure.Uncertain) request(id, null)
            if (failure == WebWorkspaceFailure.Unavailable) { markUnavailable(id); refresh() }
            throw WebWorkspaceException(failure)
        } finally { if (owner == user) mutable.value = mutable.value.copy(busy = mutable.value.busy - id) }
    }
    fun markUnavailable(id: String) { mutable.value = mutable.value.copy(closedIDs = mutable.value.closedIDs + id, items = mutable.value.items.filterNot { it.id == id }) }
    suspend fun refreshAfterSuccess() {
        val success = lastPatient?.let { refreshRecords?.invoke(it) } ?: true
        mutable.value = mutable.value.copy(refreshFailed = !success)
        refreshNotifications?.invoke()
        refresh()
    }
    suspend fun discard(id: String) {
        val user = identify()
        if (!canWrite()) throw WebWorkspaceException(WebWorkspaceFailure.ReadOnly)
        if (id in mutable.value.busy || id in mutable.value.requests) throw WebWorkspaceException(WebWorkspaceFailure.Uncertain)
        mutable.value = mutable.value.copy(busy = mutable.value.busy + id)
        try {
            rpc("discard_web_workspace", buildJsonObject { put("p_workspace_id", id); put("p_lease_token", JsonNull) })
            if (owner != user) return
            mutable.value = mutable.value.copy(items = mutable.value.items.filterNot { it.id == id })
            refreshNotifications?.invoke(); refresh()
        } catch (e: CancellationException) { throw e }
        catch (e: Exception) {
            val failure = WebWorkspaceFailure.classify(e)
            if (failure == WebWorkspaceFailure.Unavailable) { markUnavailable(id); refresh() }
            throw WebWorkspaceException(failure)
        }
        finally { if (owner == user) mutable.value = mutable.value.copy(busy = mutable.value.busy - id) }
    }
}

/** Material date pickers represent calendar dates at UTC midnight, independent of device timezone. */
object WebWorkspaceDates {
    fun fromPicker(millis: Long, zone: java.time.ZoneId = java.time.ZoneId.systemDefault()): Long =
        java.time.Instant.ofEpochMilli(millis).atZone(java.time.ZoneOffset.UTC).toLocalDate().atStartOfDay(zone).toInstant().toEpochMilli()
    fun toPicker(millis: Long, zone: java.time.ZoneId = java.time.ZoneId.systemDefault()): Long =
        java.time.Instant.ofEpochMilli(millis).atZone(zone).toLocalDate().atStartOfDay(java.time.ZoneOffset.UTC).toInstant().toEpochMilli()
}
