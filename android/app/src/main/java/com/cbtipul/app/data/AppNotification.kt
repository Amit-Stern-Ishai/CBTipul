package com.cbtipul.app.data

import com.cbtipul.app.model.DatabaseId
import java.util.Date
import java.util.UUID

object AppNotificationTypes {
    const val PATIENT_CONNECTED = "patient_connected"
    const val QUESTIONNAIRE_ASSIGNED = "questionnaire_assigned"
    const val QUESTIONNAIRE_COMPLETED = "questionnaire_completed"
    const val MESSAGE_RECEIVED = "message_received"
    const val DIARY_ONE_ASSIGNED = "diary_1_assigned"
    const val DIARY_ONE_ENTRY_ADDED = "diary_1_entry_added"
}

data class AppNotification(
    val id: String,
    val type: String,
    val patientId: String?,
    val sessionId: String?,
    val assignmentId: String?,
    val resourceType: String?,
    val resourceId: String?,
    val createdAt: Date,
    val seenAt: Date?,
    val readAt: Date?,
) {
    val isUnseen: Boolean get() = seenAt == null
    val isUnread: Boolean get() = readAt == null

    fun acknowledged(seenAt: Date) = copy(seenAt = this.seenAt ?: seenAt)
    fun opened(readAt: Date) = copy(seenAt = seenAt ?: readAt, readAt = readAt)
}

data class NotificationPayload(
    val type: String,
    val notificationId: String?,
    val patientId: String?,
    val sessionId: String?,
    val assignmentId: String?,
    val resourceType: String?,
    val resourceId: String?,
) {
    fun isPatientMode(): Boolean = when (type) {
        AppNotificationTypes.QUESTIONNAIRE_ASSIGNED,
        AppNotificationTypes.MESSAGE_RECEIVED,
        AppNotificationTypes.DIARY_ONE_ASSIGNED,
        -> true
        else -> false
    }

    companion object {
        fun from(map: Map<String, String?>): NotificationPayload? {
            val type = first(map, "type") ?: return null
            return NotificationPayload(
                type = type,
                notificationId = first(map, "notificationId", "notification_id"),
                patientId = first(map, "patientId", "patient_id"),
                sessionId = first(map, "sessionId", "session_id"),
                assignmentId = first(map, "assignmentId", "assignment_id"),
                resourceType = first(map, "resourceType", "resource_type"),
                resourceId = first(map, "resourceId", "resource_id"),
            )
        }

        fun from(notification: AppNotification) = NotificationPayload(
            type = notification.type,
            notificationId = notification.id,
            patientId = notification.patientId,
            sessionId = notification.sessionId,
            assignmentId = notification.assignmentId,
            resourceType = notification.resourceType,
            resourceId = notification.resourceId,
        )

        private fun first(map: Map<String, String?>, vararg keys: String): String? {
            keys.forEach { key ->
                val value = map[key]?.trim()?.takeIf { it.isNotEmpty() }
                if (value != null) return value
            }
            return null
        }
    }
}

sealed class AppDestination {
    data class PatientDetail(val patientId: String) : AppDestination()
    data class QuestionnaireResult(val patientId: String, val moodId: String?) : AppDestination()
    data class DiaryOneEntry(val patientId: String, val entryId: String?) : AppDestination()
    data class PatientQuestionnaire(val assignmentId: String) : AppDestination()
    data class PatientMessage(val messageId: String?) : AppDestination()
    data class PatientDiaryOneForm(val assignmentId: String) : AppDestination()
}

object NotificationRouting {
    fun destination(payload: NotificationPayload): AppDestination? = when (payload.type) {
        AppNotificationTypes.PATIENT_CONNECTED ->
            payload.patientId?.let(AppDestination::PatientDetail)
        AppNotificationTypes.QUESTIONNAIRE_COMPLETED ->
            payload.patientId?.let { AppDestination.QuestionnaireResult(it, combinedMoodId(payload.resourceType, payload.resourceId)) }
        AppNotificationTypes.DIARY_ONE_ENTRY_ADDED ->
            payload.patientId?.let {
                AppDestination.DiaryOneEntry(it, diaryEntryId(payload.resourceType, payload.resourceId))
            }
        AppNotificationTypes.QUESTIONNAIRE_ASSIGNED ->
            assignmentId(payload)?.let(AppDestination::PatientQuestionnaire)
        AppNotificationTypes.MESSAGE_RECEIVED ->
            AppDestination.PatientMessage(messageId(payload.resourceType, payload.resourceId))
        AppNotificationTypes.DIARY_ONE_ASSIGNED ->
            assignmentId(payload)?.let(AppDestination::PatientDiaryOneForm)
        else -> null
    }

    fun combinedMoodId(resourceType: String?, resourceId: String?): String? {
        if (resourceType != "questionnaire") return null
        val raw = resourceId?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        raw.toLongOrNull()?.takeIf { it.toString() == raw } ?: return null
        return raw
    }

    fun diaryEntryId(resourceType: String?, resourceId: String?): String? {
        if (resourceType != "diary_one_entry") return null
        return uuidOrNull(resourceId)
    }

    fun messageId(resourceType: String?, resourceId: String?): String? {
        if (resourceType != "message") return null
        return uuidOrNull(resourceId)
    }

    fun assignmentId(payload: NotificationPayload): String? {
        uuidOrNull(payload.assignmentId)?.let { return it }
        if (payload.resourceType == "assignment") return uuidOrNull(payload.resourceId)
        return null
    }

    fun uuidOrNull(raw: String?): String? {
        val trimmed = raw?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        return runCatching { UUID.fromString(trimmed).toString() }.getOrNull()
    }

    fun matchingOpenAssignment(
        assignments: List<PatientAssignment>,
        assignmentId: String,
        type: PatientAssignmentType,
    ): PatientAssignment? = assignments.firstOrNull {
        it.id.equals(assignmentId, ignoreCase = true) && it.type == type && it.isOpen
    }

    fun acceptedDiaryEntry(entry: DiaryOneEntry?, patientId: DatabaseId): DiaryOneEntry? {
        if (entry == null) return null
        return if (entry.patientId.matches(patientId.queryValue)) entry else null
    }

    fun inboxCopy(type: String): InboxCopyKind = when (type) {
        AppNotificationTypes.QUESTIONNAIRE_COMPLETED -> InboxCopyKind.QuestionnaireCompleted
        AppNotificationTypes.PATIENT_CONNECTED -> InboxCopyKind.PatientConnected
        AppNotificationTypes.DIARY_ONE_ENTRY_ADDED -> InboxCopyKind.DiaryOneEntryAdded
        else -> InboxCopyKind.Generic
    }
}

enum class InboxCopyKind {
    QuestionnaireCompleted,
    PatientConnected,
    DiaryOneEntryAdded,
    Generic,
}

object NotificationInbox {
    fun unread(items: List<AppNotification>) =
        items.filter { it.isUnread }.sortedByDescending { it.createdAt.time }

    fun read(items: List<AppNotification>) =
        items.filter { !it.isUnread }.sortedByDescending { it.createdAt.time }

    fun unseenCount(items: List<AppNotification>) = items.count { it.isUnseen }

    fun applyingSeen(items: List<AppNotification>, seenAt: Date) =
        items.map { it.acknowledged(seenAt) }
}

object TherapistRootTabs {
    val ordered = listOf("patients", "sessions", "notifications", "settings")
    const val DEFAULT = "patients"
}
