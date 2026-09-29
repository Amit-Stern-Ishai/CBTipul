package com.cbtipul.app.data

import com.cbtipul.app.R
import kotlinx.serialization.Serializable

/** A single staged exercise; later stages retain the original row identities and ratings. */
@Serializable
data class PatientDiaryThreeDraft(val entry: DiaryThreeEntryDraft = DiaryThreeEntryDraft(), val currentStep: Int = 1) {
    val hasMeaningfulContent get() = entry.situation.isNotBlank() ||
        entry.automaticThoughts.any { it.text.isNotBlank() || it.beliefBefore != null || it.beliefAfter != null } ||
        entry.feelings.isNotEmpty() || entry.thinkingErrors.isNotEmpty() ||
        entry.alternativeThoughts.any { it.text.isNotBlank() || it.belief != null }
    private fun valid(value: Int?) = value != null && value in 0..100
    fun validationError(step: Int = currentStep): Int? = when (step) {
        1 -> if (entry.situation.isBlank()) R.string.diary_three_validation_situation else null
        2 -> when {
            entry.automaticThoughts.isEmpty() || entry.automaticThoughts.any { it.text.isBlank() } -> R.string.diary_one_validation_thought
            entry.automaticThoughts.any { !valid(it.beliefBefore) } -> R.string.patient_diary_three_rate_every_item
            else -> null
        }
        3 -> when {
            entry.feelings.isEmpty() -> R.string.diary_one_validation_feelings
            entry.feelings.map { it.name.trim() }.distinct().size != entry.feelings.size -> R.string.diary_feeling_already_selected
            entry.feelings.any { it.name.isBlank() || !valid(it.intensityBefore) } -> R.string.patient_diary_three_rate_every_item
            else -> null
        }
        4 -> when {
            entry.thinkingErrors.isEmpty() -> R.string.diary_two_validation_errors
            entry.thinkingErrors.distinct().size != entry.thinkingErrors.size -> R.string.diary_two_duplicate_thinking_error
            else -> null
        }
        5 -> when {
            entry.alternativeThoughts.isEmpty() || entry.alternativeThoughts.any { it.text.isBlank() } -> R.string.diary_two_validation_alternatives
            entry.alternativeThoughts.any { !valid(it.belief) } -> R.string.patient_diary_three_rate_every_item
            else -> null
        }
        6 -> if (entry.automaticThoughts.isEmpty() || entry.automaticThoughts.any { !valid(it.beliefAfter) }) R.string.patient_diary_three_rate_every_item else null
        7 -> if (entry.feelings.isEmpty() || entry.feelings.any { !valid(it.intensityAfter) }) R.string.patient_diary_three_rate_every_item else null
        else -> R.string.diary_three_validation_situation
    }
    val firstInvalidStep get() = (1..7).firstOrNull { validationError(it) != null }
    fun advance() = if (currentStep < 7 && validationError() == null) copy(currentStep = currentStep + 1) else this
    fun back() = copy(currentStep = (currentStep - 1).coerceAtLeast(1))
}
