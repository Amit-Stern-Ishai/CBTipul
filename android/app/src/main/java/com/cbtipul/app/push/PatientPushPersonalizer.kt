package com.cbtipul.app.push

object PatientPushCopy {
    const val APP_TITLE = "CBTipul"
    const val GENERIC_PATIENT_CONNECTED = "המטופל/ת התחבר/ה בהצלחה ל-CBTipul"
    const val GENERIC_QUESTIONNAIRE_COMPLETED = "מטופל/ת מילא/ה שאלוני מצב רוח"
    const val GENERIC_PATIENT = "מטופל/ת"
    const val GENERIC_DIARY_TWO_ENTRY = "הוסיף/ה רשומה חדשה ליומן מחשבות 2"
    const val GENERIC_DIARY_THREE_ENTRY = "הוסיף/ה רשומה חדשה ליומן מחשבות 3"
    const val GENERIC_DIARY_TWO_ASSIGNED = "הופעל יומן מחשבות 2"
    const val GENERIC_DIARY_THREE_ASSIGNED = "הופעל יומן מחשבות 3"
    const val GENERIC_DIARY_ONE_ENTRY = "הוסיף/ה רשומה חדשה ליומן מחשבות 1"
    const val GENERIC_DIARY_ONE_ASSIGNED = "הופעל יומן מחשבות 1"
    const val GENERIC_MESSAGE_RECEIVED = "הודעה חדשה מהמטפל/ת"
    const val GENERIC_QUESTIONNAIRE_ASSIGNED = "הגישה לשאלוני מצב רוח הופעלה"

    fun patientConnectedBody(name: String): String = "$name התחבר/ה בהצלחה ל-CBTipul"

    fun questionnaireCompletedBody(name: String): String = "$name מילא/ה שאלוני מצב רוח"
}

object PatientPushPersonalizer {
    const val TYPE_PATIENT_CONNECTED = "patient_connected"
    const val TYPE_QUESTIONNAIRE_COMPLETED = "questionnaire_completed"
    const val TYPE_QUESTIONNAIRE_ASSIGNED = "questionnaire_assigned"
    const val TYPE_MESSAGE_RECEIVED = "message_received"
    const val TYPE_DIARY_TWO_ASSIGNED = "diary_2_assigned"
    const val TYPE_DIARY_THREE_ASSIGNED = "diary_3_assigned"
    const val TYPE_DIARY_TWO_ENTRY_ADDED = "diary_2_entry_added"
    const val TYPE_DIARY_THREE_ENTRY_ADDED = "diary_3_entry_added"
    const val TYPE_DIARY_ONE_ASSIGNED = "diary_1_assigned"
    const val TYPE_DIARY_ONE_ENTRY_ADDED = "diary_1_entry_added"
    const val EXTRA_TYPE = "cbtipul.push.type"
    const val EXTRA_PATIENT_ID = "cbtipul.push.patientId"
    const val EXTRA_ASSIGNMENT_ID = "cbtipul.push.assignmentId"
    const val EXTRA_SESSION_ID = "cbtipul.push.sessionId"
    const val EXTRA_RESOURCE_TYPE = "cbtipul.push.resourceType"
    const val EXTRA_RESOURCE_ID = "cbtipul.push.resourceId"
    const val EXTRA_NOTIFICATION_ID = "cbtipul.push.notificationId"

    data class Result(
        val title: String,
        val body: String,
        val type: String?,
        val patientId: String?,
        val assignmentId: String? = null,
        val sessionId: String? = null,
        val resourceType: String? = null,
        val resourceId: String? = null,
        val notificationId: String? = null,
    )

    fun personalize(
        type: String?,
        patientId: String?,
        fallbackTitle: String?,
        fallbackBody: String?,
        assignmentId: String? = null,
        sessionId: String? = null,
        resourceType: String? = null,
        resourceId: String? = null,
        notificationId: String? = null,
        nameForPatientId: (String) -> String?,
    ): Result {
        val resolvedType = type?.trim()?.takeIf { it.isNotEmpty() }
        val resolvedId = patientId?.trim()?.takeIf { it.isNotEmpty() }
        val name = resolvedId?.let { id ->
            runCatching { nameForPatientId(id) }.getOrNull()?.trim()?.takeIf { it.isNotEmpty() }
        }
        val title = fallbackTitle?.trim()?.takeIf { it.isNotEmpty() } ?: PatientPushCopy.APP_TITLE
        val meta = Result(
            title = title,
            body = "",
            type = resolvedType,
            patientId = resolvedId,
            assignmentId = assignmentId?.trim()?.takeIf { it.isNotEmpty() },
            sessionId = sessionId?.trim()?.takeIf { it.isNotEmpty() },
            resourceType = resourceType?.trim()?.takeIf { it.isNotEmpty() },
            resourceId = resourceId?.trim()?.takeIf { it.isNotEmpty() },
            notificationId = notificationId?.trim()?.takeIf { it.isNotEmpty() },
        )
        return when (resolvedType) {
            TYPE_PATIENT_CONNECTED -> meta.copy(
                body = namedOrFallback(name, PatientPushCopy::patientConnectedBody, fallbackBody, PatientPushCopy.GENERIC_PATIENT_CONNECTED),
            )
            TYPE_QUESTIONNAIRE_COMPLETED -> meta.copy(
                body = namedOrFallback(name, PatientPushCopy::questionnaireCompletedBody, fallbackBody, PatientPushCopy.GENERIC_QUESTIONNAIRE_COMPLETED),
            )
            TYPE_DIARY_TWO_ENTRY_ADDED -> meta.copy(
                title = name ?: PatientPushCopy.GENERIC_PATIENT,
                body = PatientPushCopy.GENERIC_DIARY_TWO_ENTRY,
            )
            TYPE_DIARY_TWO_ASSIGNED -> meta.copy(title = PatientPushCopy.APP_TITLE, body = PatientPushCopy.GENERIC_DIARY_TWO_ASSIGNED)
            TYPE_DIARY_THREE_ENTRY_ADDED -> meta.copy(
                title = name ?: PatientPushCopy.GENERIC_PATIENT,
                body = PatientPushCopy.GENERIC_DIARY_THREE_ENTRY,
            )
            TYPE_DIARY_THREE_ASSIGNED -> meta.copy(title = PatientPushCopy.APP_TITLE, body = PatientPushCopy.GENERIC_DIARY_THREE_ASSIGNED)
            TYPE_DIARY_ONE_ENTRY_ADDED -> meta.copy(
                title = name ?: title,
                body = PatientPushCopy.GENERIC_DIARY_ONE_ENTRY,
            )
            TYPE_DIARY_ONE_ASSIGNED -> meta.copy(body = PatientPushCopy.GENERIC_DIARY_ONE_ASSIGNED)
            TYPE_MESSAGE_RECEIVED -> meta.copy(body = PatientPushCopy.GENERIC_MESSAGE_RECEIVED)
            TYPE_QUESTIONNAIRE_ASSIGNED -> meta.copy(
                body = fallbackBody?.trim()?.takeIf { it.isNotEmpty() } ?: PatientPushCopy.GENERIC_QUESTIONNAIRE_ASSIGNED,
            )
            else -> meta.copy(body = fallbackBody.orEmpty())
        }
    }

    private fun namedOrFallback(
        name: String?,
        namedBody: (String) -> String,
        fallbackBody: String?,
        generic: String,
    ): String {
        if (name != null) return namedBody(name)
        return fallbackBody?.trim()?.takeIf { it.isNotEmpty() } ?: generic
    }
}
