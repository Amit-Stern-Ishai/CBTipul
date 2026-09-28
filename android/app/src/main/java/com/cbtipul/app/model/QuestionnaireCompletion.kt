package com.cbtipul.app.model

fun CombinedMoodQuestionnaire.missingRequiredAnswers(requireInterference: Boolean): List<Int> = buildList {
    repeat(CombinedMoodQuestionnaire.GAD7_COUNT) { if (gad7Answers.getOrNull(it) !in 0..3) add(it) }
    repeat(CombinedMoodQuestionnaire.PHQ9_COUNT) { if (phq9Answers.getOrNull(it) !in 0..3) add(it + CombinedMoodQuestionnaire.GAD7_COUNT) }
    if (requireInterference && interferenceLevel !in 0..3) add(16)
}
