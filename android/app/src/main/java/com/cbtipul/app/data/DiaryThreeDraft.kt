package com.cbtipul.app.data

import androidx.annotation.StringRes
import com.cbtipul.app.R
import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
data class DiaryThreeAutomaticThoughtDraft(val id: String = UUID.randomUUID().toString(), val text: String = "", val beliefBefore: Int? = null, val beliefAfter: Int? = null)
@Serializable
data class DiaryThreeFeelingDraft(val id: String = UUID.randomUUID().toString(), val name: String, val intensityBefore: Int? = 80, val intensityAfter: Int? = 80)
@Serializable
data class DiaryThreeAlternativeThoughtDraft(val id: String = UUID.randomUUID().toString(), val text: String = "", val belief: Int? = null)

@Serializable
data class DiaryThreeEntryDraft(
    val situation: String = "",
    val automaticThoughts: List<DiaryThreeAutomaticThoughtDraft> = listOf(DiaryThreeAutomaticThoughtDraft()),
    val feelings: List<DiaryThreeFeelingDraft> = emptyList(),
    val thinkingErrors: List<ThinkingError> = emptyList(),
    val alternativeThoughts: List<DiaryThreeAlternativeThoughtDraft> = listOf(DiaryThreeAlternativeThoughtDraft()),
) {
    private fun valid(value: Int?) = value != null && value in 0..100
    @StringRes fun validationError(): Int? = when {
        situation.isBlank() -> R.string.diary_three_validation_situation
        automaticThoughts.isEmpty() || automaticThoughts.any { it.text.isBlank() } -> R.string.diary_one_validation_thought
        automaticThoughts.any { !valid(it.beliefBefore) || !valid(it.beliefAfter) } -> R.string.diary_three_validation_ratings
        feelings.isEmpty() -> R.string.diary_one_validation_feelings
        feelings.any { it.name.isBlank() || !valid(it.intensityBefore) || !valid(it.intensityAfter) } -> R.string.diary_three_validation_ratings
        feelings.map { it.name.trim() }.distinct().size != feelings.size -> R.string.diary_feeling_already_selected
        thinkingErrors.isEmpty() -> R.string.diary_two_validation_errors
        thinkingErrors.distinct().size != thinkingErrors.size -> R.string.diary_two_duplicate_thinking_error
        alternativeThoughts.isEmpty() || alternativeThoughts.any { it.text.isBlank() } -> R.string.diary_two_validation_alternatives
        alternativeThoughts.any { !valid(it.belief) } -> R.string.diary_three_validation_ratings
        else -> null
    }
    val persistedAutomaticThoughts get(): List<DiaryThreeAutomaticThought> {
        check(validationError() == null)
        return automaticThoughts.map { DiaryThreeAutomaticThought(it.text.trim(), requireNotNull(it.beliefBefore), requireNotNull(it.beliefAfter)) }
    }
    val persistedAlternativeThoughts get(): List<DiaryThreeAlternativeThought> {
        check(validationError() == null)
        return alternativeThoughts.map { DiaryThreeAlternativeThought(it.text.trim(), requireNotNull(it.belief)) }
    }
    fun persistedFeelings(): List<DiaryThreeFeeling> {
        check(validationError() == null)
        return feelings.map { DiaryThreeFeeling(it.name.trim(), requireNotNull(it.intensityBefore), requireNotNull(it.intensityAfter)) }
    }
    companion object {
        fun from(entry: DiaryThreeEntry) = DiaryThreeEntryDraft(entry.situation,
            entry.automaticThoughts.map { DiaryThreeAutomaticThoughtDraft(text = it.text, beliefBefore = it.beliefBefore, beliefAfter = it.beliefAfter) },
            entry.feelings.map { DiaryThreeFeelingDraft(name = it.name, intensityBefore = it.intensityBefore, intensityAfter = it.intensityAfter) },
            entry.thinkingErrors,
            entry.alternativeThoughts.map { DiaryThreeAlternativeThoughtDraft(text = it.text, belief = it.belief) })
    }
}
