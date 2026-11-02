package com.cbtipul.app.data

import kotlin.math.pow

/** Newest-first answers. Missing answers retain their age and never count as zero. */
data class QuestionnaireAnswerHistory(val count: Int, val total: Int, val weight: Double) {
    val frequency: Float get() = if (total == 0) 0f else count.toFloat() / total
    val band: Int get() = if (weight <= .1) 0 else if (weight <= .4) 1 else 2
    companion object {
        fun calculate(answers: List<Int?>, value: Int): QuestionnaireAnswerHistory {
            var count = 0; var total = 0; var numerator = 0.0; var denominator = 0.0
            answers.forEachIndexed { index, answer ->
                if (answer != null && answer in 0..3) {
                    val contribution = .5.pow(index)
                    total++; denominator += contribution
                    if (answer == value) { count++; numerator += contribution }
                }
            }
            return QuestionnaireAnswerHistory(count, total, if (denominator > 0) numerator / denominator else 0.0)
        }
    }
}
