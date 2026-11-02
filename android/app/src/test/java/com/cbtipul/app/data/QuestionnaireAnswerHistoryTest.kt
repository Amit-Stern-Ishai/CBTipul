package com.cbtipul.app.data

import org.junit.Assert.*
import org.junit.Test

class QuestionnaireAnswerHistoryTest {
    @Test fun recencyAndFrequencyHaveSeparateDenominators() {
        val h = QuestionnaireAnswerHistory.calculate(listOf(2, 1, 1), 2)
        assertEquals(4.0/7, h.weight, .000001)
        assertEquals(1f/3, h.frequency, .000001f)
        assertEquals(2, h.band)
        assertEquals(1.0, (0..3).sumOf { QuestionnaireAnswerHistory.calculate(listOf(2, 1, 1), it).weight }, .000001)
    }
    @Test fun missingValuesRetainTheirAge() {
        val h = QuestionnaireAnswerHistory.calculate(listOf(2, null, 1, 9), 2)
        assertEquals(.8, h.weight, .000001)
        assertEquals(2, h.total)
        assertEquals(0f, QuestionnaireAnswerHistory.calculate(emptyList(), 0).frequency)
        assertEquals(0.0, QuestionnaireAnswerHistory.calculate(listOf(null, 9), 0).weight, 0.0)
    }
    @Test fun paletteBandsMatchIos() {
        val answers = listOf(2, 1, 0, 3)
        assertEquals(2, QuestionnaireAnswerHistory.calculate(answers, 2).band)
        assertEquals(1, QuestionnaireAnswerHistory.calculate(answers, 1).band)
        assertEquals(0, QuestionnaireAnswerHistory.calculate(answers, 3).band)
    }
}
