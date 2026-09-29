package com.cbtipul.app.model

/** Input is chronological. Missing or invalid answers are not zero scores. */
enum class QuestionnaireTrend {
    Improving, Worsening, Unchanged, Mixed, Insufficient;

    companion object {
        fun classify(answers: List<Int?>): QuestionnaireTrend {
            val values = answers.filterNotNull().filter { it in 0..3 }
            if (values.size < 2) return Insufficient
            if (values.all { it == values.first() }) return Unchanged
            if (values.zipWithNext().all { (previous, next) -> previous >= next }) return Improving
            if (values.zipWithNext().all { (previous, next) -> previous <= next }) return Worsening
            return Mixed
        }
    }
}
