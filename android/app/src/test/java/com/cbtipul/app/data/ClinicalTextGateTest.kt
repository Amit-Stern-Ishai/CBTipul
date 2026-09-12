package com.cbtipul.app.data

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ClinicalTextGateTest {

    private class MockAnonymizer {
        val receivedTexts = mutableListOf<String>()
        var failsOn: Set<String> = emptySet()

        suspend fun anonymize(text: String): String {
            receivedTexts += text
            if (text in failsOn) throw ClinicalTextAnonymizerError()
            return "ANON<$text>"
        }

        fun makeGate() = ClinicalTextGate { anonymize(it) }
    }

    @Test
    fun successfulAnonymizationReturnsOnlyTheAnonymizedText() = runTest {
        val mock = MockAnonymizer()
        val prepared = mock.makeGate().prepare("note naming the patient")
        assertEquals("ANON<note naming the patient>", prepared)
        assertEquals(listOf("note naming the patient"), mock.receivedTexts)
    }

    @Test
    fun inputIsTrimmedBeforeAnonymization() = runTest {
        val mock = MockAnonymizer()
        val prepared = mock.makeGate().prepare("  note  \n")
        assertEquals("ANON<note>", prepared)
        assertEquals(listOf("note"), mock.receivedTexts)
    }

    @Test
    fun failurePreventsProducingAValueToSave() = runTest {
        val mock = MockAnonymizer().apply { failsOn = setOf("sensitive") }
        val gate = mock.makeGate()
        var threw = false
        try {
            gate.prepare("sensitive")
        } catch (_: ClinicalTextAnonymizerError) {
            threw = true
        }
        assertTrue(threw)
    }

    @Test
    fun multipleNotesKeepTheirQuestionIndices() = runTest {
        val mock = MockAnonymizer()
        val prepared = mock.makeGate().prepare(notes = listOf("first", "", "third"))
        assertEquals(listOf("ANON<first>", "", "ANON<third>"), prepared)
        assertEquals(listOf("first", "third"), mock.receivedTexts)
    }

    @Test
    fun emptyFieldsDoNotInvokeTheFunction() = runTest {
        val mock = MockAnonymizer()
        val prepared = mock.makeGate().prepare("   \n ")
        assertNull(prepared)
        assertTrue(mock.receivedTexts.isEmpty())
    }

    @Test
    fun unchangedTextLoadedFromSupabaseIsNotReprocessed() = runTest {
        val mock = MockAnonymizer()
        val gate = mock.makeGate()
        gate.markSafe("already stored note")
        val prepared = gate.prepare("already stored note")
        assertEquals("already stored note", prepared)
        assertTrue(mock.receivedTexts.isEmpty())
    }

    @Test
    fun repeatedSavesOfASavedValueDoNotRepeatRequests() = runTest {
        val mock = MockAnonymizer()
        val gate = mock.makeGate()
        val first = gate.prepare("fresh note")
        assertEquals("ANON<fresh note>", first)
        val second = gate.prepare(first.orEmpty())
        assertEquals(first, second)
        assertEquals(listOf("fresh note"), mock.receivedTexts)
    }

    @Test
    fun oneFailingFieldAbortsBeforeRemainingFieldsAreSent() = runTest {
        val mock = MockAnonymizer().apply { failsOn = setOf("second") }
        var threw = false
        try {
            mock.makeGate().prepare(notes = listOf("first", "second", "third"))
        } catch (_: ClinicalTextAnonymizerError) {
            threw = true
        }
        assertTrue(threw)
        assertEquals(listOf("first", "second"), mock.receivedTexts)
    }
}
