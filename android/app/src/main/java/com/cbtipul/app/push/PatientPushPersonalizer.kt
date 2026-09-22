package com.cbtipul.app.push

/**
 * Device-only patient-name substitution for push notifications.
 * Does not talk to the network. Callers must never log names or id/name pairs.
 */
object PatientPushCopy {
    const val APP_TITLE = "CBTipul"
    const val GENERIC_PATIENT_CONNECTED = "המטופל/ת התחבר/ה בהצלחה ל-CBTipul"

    fun patientConnectedBody(name: String): String = "$name התחבר/ה בהצלחה ל-CBTipul"
}

object PatientPushPersonalizer {
    const val TYPE_PATIENT_CONNECTED = "patient_connected"
    const val EXTRA_TYPE = "cbtipul.push.type"
    const val EXTRA_PATIENT_ID = "cbtipul.push.patientId"

    data class Result(
        val title: String,
        val body: String,
        val type: String?,
        val patientId: String?,
    )

    fun personalize(
        type: String?,
        patientId: String?,
        fallbackTitle: String?,
        fallbackBody: String?,
        nameForPatientId: (String) -> String?,
    ): Result {
        val resolvedType = type?.trim()?.takeIf { it.isNotEmpty() }
        val resolvedId = patientId?.trim()?.takeIf { it.isNotEmpty() }
        val title = fallbackTitle?.trim()?.takeIf { it.isNotEmpty() } ?: PatientPushCopy.APP_TITLE
        when (resolvedType) {
            TYPE_PATIENT_CONNECTED -> {
                val fallback = fallbackBody?.trim()?.takeIf { it.isNotEmpty() }
                    ?: PatientPushCopy.GENERIC_PATIENT_CONNECTED
                val name = resolvedId?.let { id ->
                    runCatching { nameForPatientId(id) }.getOrNull()
                        ?.trim()
                        ?.takeIf { it.isNotEmpty() }
                }
                val body = if (name != null) {
                    PatientPushCopy.patientConnectedBody(name)
                } else {
                    fallback
                }
                return Result(title = title, body = body, type = resolvedType, patientId = resolvedId)
            }
            else -> {
                return Result(
                    title = title,
                    body = fallbackBody.orEmpty(),
                    type = resolvedType,
                    patientId = resolvedId,
                )
            }
        }
    }
}
