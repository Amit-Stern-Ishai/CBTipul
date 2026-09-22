package com.cbtipul.app.push

/**
 * Device-only patient-name substitution for push notifications.
 * Does not talk to the network. Callers must never log names or id/name pairs.
 */
object PatientPushCopy {
    const val APP_TITLE = "CBTipul"
    const val GENERIC_PATIENT_CONNECTED = "המטופל/ת התחבר/ה בהצלחה ל-CBTipul"
    const val GENERIC_QUESTIONNAIRE_COMPLETED = "מטופל/ת מילא/ה שאלון חדש"

    fun patientConnectedBody(name: String): String = "$name התחבר/ה בהצלחה ל-CBTipul"

    fun questionnaireCompletedBody(name: String): String = "$name מילא/ה שאלון חדש"
}

object PatientPushPersonalizer {
    const val TYPE_PATIENT_CONNECTED = "patient_connected"
    const val TYPE_QUESTIONNAIRE_COMPLETED = "questionnaire_completed"
    const val EXTRA_TYPE = "cbtipul.push.type"
    const val EXTRA_PATIENT_ID = "cbtipul.push.patientId"
    const val EXTRA_ASSIGNMENT_ID = "cbtipul.push.assignmentId"
    const val EXTRA_SESSION_ID = "cbtipul.push.sessionId"

    data class Result(
        val title: String,
        val body: String,
        val type: String?,
        val patientId: String?,
        val assignmentId: String? = null,
        val sessionId: String? = null,
    )

    fun personalize(
        type: String?,
        patientId: String?,
        fallbackTitle: String?,
        fallbackBody: String?,
        assignmentId: String? = null,
        sessionId: String? = null,
        nameForPatientId: (String) -> String?,
    ): Result {
        val resolvedType = type?.trim()?.takeIf { it.isNotEmpty() }
        val resolvedId = patientId?.trim()?.takeIf { it.isNotEmpty() }
        val resolvedAssignment = assignmentId?.trim()?.takeIf { it.isNotEmpty() }
        val resolvedSession = sessionId?.trim()?.takeIf { it.isNotEmpty() }
        val title = fallbackTitle?.trim()?.takeIf { it.isNotEmpty() } ?: PatientPushCopy.APP_TITLE
        val name = resolvedId?.let { id ->
            runCatching { nameForPatientId(id) }.getOrNull()
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
        }
        return when (resolvedType) {
            TYPE_PATIENT_CONNECTED -> Result(
                title = title,
                body = namedOrFallback(
                    name = name,
                    namedBody = PatientPushCopy::patientConnectedBody,
                    fallbackBody = fallbackBody,
                    generic = PatientPushCopy.GENERIC_PATIENT_CONNECTED,
                ),
                type = resolvedType,
                patientId = resolvedId,
                assignmentId = resolvedAssignment,
                sessionId = resolvedSession,
            )
            TYPE_QUESTIONNAIRE_COMPLETED -> Result(
                title = title,
                body = namedOrFallback(
                    name = name,
                    namedBody = PatientPushCopy::questionnaireCompletedBody,
                    fallbackBody = fallbackBody,
                    generic = PatientPushCopy.GENERIC_QUESTIONNAIRE_COMPLETED,
                ),
                type = resolvedType,
                patientId = resolvedId,
                assignmentId = resolvedAssignment,
                sessionId = resolvedSession,
            )
            else -> Result(
                title = title,
                body = fallbackBody.orEmpty(),
                type = resolvedType,
                patientId = resolvedId,
                assignmentId = resolvedAssignment,
                sessionId = resolvedSession,
            )
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
