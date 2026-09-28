package com.cbtipul.app.data

import android.content.Intent
import com.cbtipul.app.push.PatientPushPersonalizer

object NotificationIntent {
    fun payload(intent: Intent?): NotificationPayload? {
        val extras = intent?.extras ?: return null
        val map = mutableMapOf<String, String?>()
        extras.keySet().forEach { key ->
            map[key] = extras.get(key)?.toString()
        }
        map[PatientPushPersonalizer.EXTRA_TYPE]?.let { map.putIfAbsent("type", it) }
        map[PatientPushPersonalizer.EXTRA_PATIENT_ID]?.let { map.putIfAbsent("patientId", it) }
        map[PatientPushPersonalizer.EXTRA_ASSIGNMENT_ID]?.let { map.putIfAbsent("assignmentId", it) }
        map[PatientPushPersonalizer.EXTRA_SESSION_ID]?.let { map.putIfAbsent("sessionId", it) }
        map[PatientPushPersonalizer.EXTRA_RESOURCE_TYPE]?.let { map.putIfAbsent("resourceType", it) }
        map[PatientPushPersonalizer.EXTRA_RESOURCE_ID]?.let { map.putIfAbsent("resourceId", it) }
        map[PatientPushPersonalizer.EXTRA_NOTIFICATION_ID]?.let { map.putIfAbsent("notificationId", it) }
        return NotificationPayload.from(map)
    }

    fun clear(intent: Intent?) {
        if (intent == null) return
        KEYS.forEach { intent.removeExtra(it) }
    }

    private val KEYS = listOf(
        "type", "patientId", "patient_id", "assignmentId", "assignment_id",
        "sessionId", "session_id", "resourceType", "resource_type",
        "resourceId", "resource_id", "notificationId", "notification_id",
        PatientPushPersonalizer.EXTRA_TYPE,
        PatientPushPersonalizer.EXTRA_PATIENT_ID,
        PatientPushPersonalizer.EXTRA_ASSIGNMENT_ID,
        PatientPushPersonalizer.EXTRA_SESSION_ID,
        PatientPushPersonalizer.EXTRA_RESOURCE_TYPE,
        PatientPushPersonalizer.EXTRA_RESOURCE_ID,
        PatientPushPersonalizer.EXTRA_NOTIFICATION_ID,
    )
}
