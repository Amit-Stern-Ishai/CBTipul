package com.cbtipul.app.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.util.Date

@Serializable
private data class NotificationRow(
    val id: String,
    val type: String,
    @SerialName("patient_id") val patientId: String? = null,
    @SerialName("session_id") val sessionId: String? = null,
    @SerialName("assignment_id") val assignmentId: String? = null,
    @SerialName("resource_type") val resourceType: String? = null,
    @SerialName("resource_id") val resourceId: String? = null,
    @SerialName("created_at") val createdAt: String,
    @SerialName("seen_at") val seenAt: String? = null,
    @SerialName("read_at") val readAt: String? = null,
)

class NotificationRepository(private val client: SupabaseClient) {
    private val _items = MutableStateFlow<List<AppNotification>>(emptyList())
    val items: StateFlow<List<AppNotification>> = _items.asStateFlow()
    private val _unseenCount = MutableStateFlow(0)
    val unseenCount: StateFlow<Int> = _unseenCount.asStateFlow()
    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()
    private val _failed = MutableStateFlow(false)
    val failed: StateFlow<Boolean> = _failed.asStateFlow()

    private var hasLoaded = false

    var isDemoInbox: Boolean = false
    private var uiTestItems: List<AppNotification>? = null

    internal fun seedUITestingNotifications(patientId: String, questionnaireId: String?) {
        if (!com.cbtipul.app.BuildConfig.DEBUG || !isDemoInbox) return
        fun item(type: String, resource: String?, id: String?, target: String = patientId) =
            AppNotification(java.util.UUID.randomUUID().toString(), type, target, null, null,
                resource, id, Date(), null, null)
        uiTestItems = listOf(
            item(AppNotificationTypes.QUESTIONNAIRE_COMPLETED, "questionnaire", questionnaireId),
            item(AppNotificationTypes.PATIENT_CONNECTED, null, null),
            item(AppNotificationTypes.DIARY_ONE_ENTRY_ADDED, null, null, "missing-test-patient"),
        )
        _items.value = uiTestItems.orEmpty()
    }

    fun clear() {
        uiTestItems = null
        hasLoaded = false
        _items.value = emptyList()
        _unseenCount.value = 0
        _failed.value = false
        _isLoading.value = false
    }

    suspend fun refresh(showLoading: Boolean = false) {
        if (com.cbtipul.app.BuildConfig.DEBUG && isDemoInbox && uiTestItems != null) {
            _items.value = uiTestItems.orEmpty()
            return
        }
        if (isDemoInbox || !SupabaseConfig.isConfigured) {
            clear()
            return
        }
        _isLoading.value = showLoading || !hasLoaded
        _failed.value = false
        try {
            val rows = client.from("notifications")
                .select(columns) { order("created_at", Order.DESCENDING) }
                .decodeList<NotificationRow>()
            if (isDemoInbox) { clear(); return }
            _items.value = rows.map { it.toDomain() }
            hasLoaded = true
            _unseenCount.value = fetchUnseenCount() ?: NotificationInbox.unseenCount(_items.value)
        } catch (error: CancellationException) {
            throw error
        } catch (_: Exception) {
            _failed.value = true
        } finally {
            _isLoading.value = false
        }
    }

    suspend fun markInboxSeen() {
        if (isDemoInbox || !SupabaseConfig.isConfigured) return
        if (NotificationInbox.unseenCount(_items.value) == 0 && _unseenCount.value == 0) return
        try {
            client.postgrest.rpc("mark_notifications_seen")
            _items.value = NotificationInbox.applyingSeen(_items.value, Date())
            _unseenCount.value = 0
        } catch (_: Exception) {
            // Keep unseen until the next successful refresh.
        }
    }

    suspend fun markRead(notification: AppNotification) {
        if (!notification.isUnread || isDemoInbox || !SupabaseConfig.isConfigured) return
        try {
            client.postgrest.rpc(
                "mark_notification_read",
                buildJsonObject { put("p_notification_id", notification.id) },
            )
            val opened = notification.opened(Date())
            _items.value = _items.value.map { if (it.id == opened.id) opened else it }
            _unseenCount.value = fetchUnseenCount() ?: NotificationInbox.unseenCount(_items.value)
        } catch (_: Exception) {
            // Keep unread until a later refresh.
        }
    }

    private suspend fun fetchUnseenCount(): Int? = try {
        val result = client.postgrest.rpc("get_unseen_notification_count")
        Json.parseToJsonElement(result.data).jsonPrimitive.intOrNull
    } catch (_: Exception) {
        null
    }

    companion object {
        private val columns = Columns.raw(
            "id, type, patient_id, session_id, assignment_id, resource_type, resource_id, created_at, seen_at, read_at",
        )

        private fun NotificationRow.toDomain() = AppNotification(
            id = id,
            type = type,
            patientId = patientId,
            sessionId = sessionId,
            assignmentId = assignmentId,
            resourceType = resourceType,
            resourceId = resourceId,
            createdAt = PatientAssignmentRepository.parseAssignmentTimestamp(createdAt),
            seenAt = seenAt?.let(PatientAssignmentRepository::parseAssignmentTimestamp),
            readAt = readAt?.let(PatientAssignmentRepository::parseAssignmentTimestamp),
        )
    }
}
