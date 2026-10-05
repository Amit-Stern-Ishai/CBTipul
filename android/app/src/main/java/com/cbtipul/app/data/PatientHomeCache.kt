package com.cbtipul.app.data

import com.cbtipul.app.model.CompletedQuestionnaire

data class PatientHomeSnapshot(
    val assignments: List<PatientAssignment>? = null,
    val questionnaires: List<CompletedQuestionnaire>? = null,
    val diaryOne: List<DiaryOneEntry>? = null,
    val diaryTwo: List<DiaryTwoEntry>? = null,
    val diaryThree: List<DiaryThreeEntry>? = null,
) {
    fun hasHistory(type: PatientAssignmentType): Boolean = when (type) {
        PatientAssignmentType.Questionnaire -> !questionnaires.isNullOrEmpty()
        PatientAssignmentType.DiaryOne -> !diaryOne.isNullOrEmpty()
        PatientAssignmentType.DiaryTwo -> !diaryTwo.isNullOrEmpty()
        PatientAssignmentType.DiaryThree -> !diaryThree.isNullOrEmpty()
    }
    fun isVisible(type: PatientAssignmentType, active: Boolean) = active || hasHistory(type)
}

/** Session-only; a different auth identity or patient never inherits cached tools. */
object PatientHomeCache {
    private var owner: String? = null
    private var snapshot = PatientHomeSnapshot()
    @Synchronized fun read(key: String): PatientHomeSnapshot {
        if (owner != key) { owner = key; snapshot = PatientHomeSnapshot() }
        return snapshot
    }
    @Synchronized fun save(key: String, value: PatientHomeSnapshot) {
        if (owner == key) snapshot = value
    }
    @Synchronized fun clear() { owner = null; snapshot = PatientHomeSnapshot() }
}
