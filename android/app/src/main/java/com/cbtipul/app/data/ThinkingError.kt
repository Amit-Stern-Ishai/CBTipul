package com.cbtipul.app.data

import androidx.annotation.StringRes
import com.cbtipul.app.R
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class ThinkingError(val code: String, @StringRes val title: Int, @StringRes val explanation: Int) {
    @SerialName("all_or_nothing") AllOrNothing("all_or_nothing", R.string.thinking_error_all_or_nothing, R.string.thinking_error_all_or_nothing_explanation),
    @SerialName("overgeneralization") Overgeneralization("overgeneralization", R.string.thinking_error_overgeneralization, R.string.thinking_error_overgeneralization_explanation),
    @SerialName("negative_filter") NegativeFilter("negative_filter", R.string.thinking_error_negative_filter, R.string.thinking_error_negative_filter_explanation),
    @SerialName("discounting_positives") DiscountingPositives("discounting_positives", R.string.thinking_error_discounting_positives, R.string.thinking_error_discounting_positives_explanation),
    @SerialName("jumping_to_conclusions") JumpingToConclusions("jumping_to_conclusions", R.string.thinking_error_jumping_to_conclusions, R.string.thinking_error_jumping_to_conclusions_explanation),
    @SerialName("mind_reading") MindReading("mind_reading", R.string.thinking_error_mind_reading, R.string.thinking_error_mind_reading_explanation),
    @SerialName("fortune_telling") FortuneTelling("fortune_telling", R.string.thinking_error_fortune_telling, R.string.thinking_error_fortune_telling_explanation),
    @SerialName("magnification_minimization") MagnificationMinimization("magnification_minimization", R.string.thinking_error_magnification_minimization, R.string.thinking_error_magnification_minimization_explanation),
    @SerialName("emotional_reasoning") EmotionalReasoning("emotional_reasoning", R.string.thinking_error_emotional_reasoning, R.string.thinking_error_emotional_reasoning_explanation),
    @SerialName("should_statements") ShouldStatements("should_statements", R.string.thinking_error_should_statements, R.string.thinking_error_should_statements_explanation),
    @SerialName("labeling") Labeling("labeling", R.string.thinking_error_labeling, R.string.thinking_error_labeling_explanation),
    @SerialName("blame") Blame("blame", R.string.thinking_error_blame, R.string.thinking_error_blame_explanation);
}
