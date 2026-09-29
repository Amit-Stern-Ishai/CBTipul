package com.cbtipul.app.data

import androidx.annotation.StringRes
import com.cbtipul.app.R
import kotlinx.serialization.Serializable

@Serializable
data class DiaryTwoEntryDraft(
    val event: String = "",
    val automaticThoughts: List<DiaryAutomaticThoughtDraft> = listOf(DiaryAutomaticThoughtDraft()),
    val feelings: List<DiaryFeelingDraft> = emptyList(),
    val thinkingErrors: List<ThinkingError> = emptyList(),
    val alternativeThoughts: List<DiaryAutomaticThoughtDraft> = listOf(DiaryAutomaticThoughtDraft()),
) {
    val persistedAutomaticThoughts get() = automaticThoughts.map { it.text.trim() }.filter { it.isNotEmpty() }
    val persistedAlternativeThoughts get() = alternativeThoughts.map { it.text.trim() }.filter { it.isNotEmpty() }
    @StringRes fun validationError(): Int? = when {
        event.isBlank() -> R.string.diary_one_validation_event
        persistedAutomaticThoughts.isEmpty() -> R.string.diary_one_validation_thought
        feelings.isEmpty() -> R.string.diary_one_validation_feelings
        feelings.any { it.name.isBlank() || it.intensity == null || it.intensity !in 0..100 } -> R.string.diary_one_validation_feeling_intensity
        feelings.map { it.name.trim() }.distinct().size != feelings.size -> R.string.diary_feeling_already_selected
        thinkingErrors.isEmpty() -> R.string.diary_two_validation_errors
        persistedAlternativeThoughts.isEmpty() -> R.string.diary_two_validation_alternatives
        else -> null
    }
    fun persistedFeelings(): List<DiaryFeeling> {
        check(validationError() == null)
        return feelings.map { DiaryFeeling(it.name.trim(), requireNotNull(it.intensity)) }
    }
    companion object {
        fun from(entry: DiaryTwoEntry) = DiaryTwoEntryDraft(
            event = entry.event,
            automaticThoughts = entry.automaticThoughts.map { DiaryAutomaticThoughtDraft(text = it) },
            feelings = entry.feelings.map { DiaryFeelingDraft(it) },
            thinkingErrors = entry.thinkingErrors,
            alternativeThoughts = entry.alternativeThoughts.map { DiaryAutomaticThoughtDraft(text = it) },
        )
    }
}
