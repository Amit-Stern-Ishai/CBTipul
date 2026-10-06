package com.cbtipul.app.data

import java.util.Date

data class PatientInboxItem(val id: String, val message: PatientMessage?, val notification: AppNotification?) {
    val isUnread: Boolean get() = message?.isUnread ?: notification!!.isUnread
    val createdAt: Date get() = message?.createdAt ?: notification!!.createdAt
    val isMessage: Boolean get() = message != null || notification?.type == AppNotificationTypes.MESSAGE_RECEIVED
}

object PatientInbox {
    fun assignmentType(type: String): PatientAssignmentType? = when (type) {
        AppNotificationTypes.QUESTIONNAIRE_ASSIGNED -> PatientAssignmentType.Questionnaire
        AppNotificationTypes.DIARY_ONE_ASSIGNED -> PatientAssignmentType.DiaryOne
        AppNotificationTypes.DIARY_TWO_ASSIGNED -> PatientAssignmentType.DiaryTwo
        AppNotificationTypes.DIARY_THREE_ASSIGNED -> PatientAssignmentType.DiaryThree
        else -> null
    }
    fun assignmentId(payload: NotificationPayload): String? {
        val explicit = payload.assignmentId
        val resource = payload.resourceId.takeIf { payload.resourceType == "assignment" }
        if (explicit != null && resource != null && !explicit.equals(resource, true)) return null
        return (explicit ?: resource)?.takeIf { runCatching { java.util.UUID.fromString(it) }.isSuccess }
    }
    fun assignment(payload: NotificationPayload, patientId: String, assignments: List<PatientAssignment>): PatientAssignment? {
        if (!payload.patientId.equals(patientId, true)) return null
        val type = assignmentType(payload.type) ?: return null
        val id = assignmentId(payload) ?: return null
        return assignments.firstOrNull { it.id.equals(id, true) && it.patientId.equals(patientId, true) && it.type == type && it.cancelledAt == null }
    }
    fun items(patientId: String, messages: List<PatientMessage>, notifications: List<AppNotification>): List<PatientInboxItem> {
        val personal = messages.filter { it.patientId.equals(patientId, true) }.distinctBy { it.id.lowercase() }
        val ids = personal.map { it.id.lowercase() }.toSet()
        return (personal.map { PatientInboxItem("message:${it.id.lowercase()}", it, null) } +
            notifications.filter { it.patientId.equals(patientId, true) && NotificationPayload.from(it).isPatientMode() }
                .filterNot { it.type == AppNotificationTypes.MESSAGE_RECEIVED && it.resourceType == "message" && it.resourceId?.lowercase() in ids }
                .distinctBy { if (it.type == AppNotificationTypes.MESSAGE_RECEIVED && it.resourceType == "message" && it.resourceId != null) "message:${it.resourceId?.lowercase()}" else it.id }
                .map { PatientInboxItem(it.id, null, it) }).sortedByDescending { it.createdAt }
    }
}
