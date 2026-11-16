package com.cbtipul.app.data

enum class PatientMilestone { SecondSession, DiaryOne, DiaryTwo;
    val assignment: PatientAssignmentType get() = when (this) {
        SecondSession -> PatientAssignmentType.Questionnaire
        DiaryOne -> PatientAssignmentType.DiaryOne
        DiaryTwo -> PatientAssignmentType.DiaryTwo
    }
}
data class PatientMilestoneRequest(val patient: String, val milestone: PatientMilestone, val standalone: Boolean,
    val id: String = java.util.UUID.randomUUID().toString())

object DiscoveryRules {
    fun patientFeature(patient: String, feature: String) = "patient.${patient.lowercase(java.util.Locale.ROOT)}.$feature"
    fun sessionMilestone(type: com.cbtipul.app.model.SessionType?, matchingCount: Int, total: Int): PatientMilestone? {
        if (matchingCount == 1) {
            if (type == com.cbtipul.app.model.SessionType.DiaryOne) return PatientMilestone.DiaryOne
            if (type == com.cbtipul.app.model.SessionType.DiaryTwo) return PatientMilestone.DiaryTwo
        }
        return if (total == 2) PatientMilestone.SecondSession else null
    }
    // true = invite, false = activity settings, null = no authoritative suggestion.
    fun suggestion(connected: Boolean?, enabled: Boolean?): Boolean? = when {
        connected == null -> null
        !connected -> true
        enabled == false -> false
        else -> null
    }

    fun key(account: String, feature: String) = "discovery.$feature.${account.lowercase(java.util.Locale.ROOT)}"
    fun voice(userEdit: Boolean, nonempty: Boolean, therapist: Boolean, demo: Boolean, seen: Boolean) = userEdit && nonempty && therapist && !demo && !seen
    fun present(pending: Boolean, busy: Boolean, feedback: Boolean, obstructed: Boolean, valid: Boolean) = pending && !busy && !feedback && !obstructed && valid
}
