package com.cbtipul.app.data

import com.cbtipul.app.model.QuestionnaireTrend
import org.junit.Assert.assertEquals
import org.junit.Test

class QuestionnaireTrendTest {
    @Test fun allowsPlateausButKeepsConstantAnswersSeparate() {
        assertEquals(QuestionnaireTrend.Improving, QuestionnaireTrend.classify(listOf(3, 3, 2, 2, 0)))
        assertEquals(QuestionnaireTrend.Worsening, QuestionnaireTrend.classify(listOf(0, 0, 1, 1, 3)))
        assertEquals(QuestionnaireTrend.Unchanged, QuestionnaireTrend.classify(listOf(2, 2, 2)))
        assertEquals(QuestionnaireTrend.Unchanged, QuestionnaireTrend.classify(listOf(0, 0)))
    }
    @Test fun checksEveryStepRatherThanOnlyEndpoints() {
        assertEquals(QuestionnaireTrend.BetterThanBeginning, QuestionnaireTrend.classify(listOf(3, 1, 2)))
        assertEquals(QuestionnaireTrend.WorseThanBeginning, QuestionnaireTrend.classify(listOf(0, 2, 1)))
        assertEquals(QuestionnaireTrend.Unchanged, QuestionnaireTrend.classify(listOf(2, 1, 2)))
    }
    @Test fun missingAndInvalidAnswersNeverBecomeZeros() {
        assertEquals(QuestionnaireTrend.Improving, QuestionnaireTrend.classify(listOf(3, null, 2, -1, 4, 1)))
        assertEquals(QuestionnaireTrend.Unchanged, QuestionnaireTrend.classify(listOf(1, null, 1)))
        assertEquals(QuestionnaireTrend.Insufficient, QuestionnaireTrend.classify(listOf(null, 2, null)))
        assertEquals(QuestionnaireTrend.Insufficient, QuestionnaireTrend.classify(emptyList()))
        assertEquals(QuestionnaireTrend.Insufficient, QuestionnaireTrend.classify(listOf(null, -1, 4)))
    }
}
