package com.cbtipul.app.data

import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class PatientDiaryThreeTest {
    private fun valid() = PatientDiaryThreeDraft(DiaryThreeEntryDraft(situation = " event ",
        automaticThoughts = listOf(DiaryThreeAutomaticThoughtDraft(text = " first ", beliefBefore = 100, beliefAfter = 0), DiaryThreeAutomaticThoughtDraft(text = "second", beliefBefore = 0, beliefAfter = 100)),
        feelings = listOf(DiaryThreeFeelingDraft(name = "עצוב", intensityBefore = 100, intensityAfter = 0), DiaryThreeFeelingDraft(name = "מודאג", intensityBefore = 0, intensityAfter = 100)),
        thinkingErrors = listOf(ThinkingError.MindReading, ThinkingError.FortuneTelling),
        alternativeThoughts = listOf(DiaryThreeAlternativeThoughtDraft(text = " a ", belief = 0), DiaryThreeAlternativeThoughtDraft(text = "b", belief = 100))))
    @Test fun stagesValidateRequiredFieldsAndEveryRatingWithoutPrematureAfterValues() {
        val d = valid(); val e = d.entry
        assertNull(d.firstInvalidStep)
        listOf(
            1 to e.copy(situation = " \n"),
            2 to e.copy(automaticThoughts = emptyList()),
            2 to e.copy(automaticThoughts = listOf(e.automaticThoughts[0].copy(text = " "))),
            3 to e.copy(feelings = emptyList()),
            3 to e.copy(feelings = e.feelings + e.feelings),
            4 to e.copy(thinkingErrors = emptyList()),
            5 to e.copy(alternativeThoughts = emptyList()),
            5 to e.copy(alternativeThoughts = listOf(e.alternativeThoughts[0].copy(text = " "))),
        ).forEach { (step, entry) -> assertNotNull(d.copy(entry = entry).validationError(step)) }
        for (rating in listOf(null, -1, 101)) {
            listOf(
                2 to e.copy(automaticThoughts = e.automaticThoughts.mapIndexed { i, it -> if (i == 1) it.copy(beliefBefore = rating) else it }),
                3 to e.copy(feelings = e.feelings.mapIndexed { i, it -> if (i == 1) it.copy(intensityBefore = rating) else it }),
                5 to e.copy(alternativeThoughts = e.alternativeThoughts.mapIndexed { i, it -> if (i == 1) it.copy(belief = rating) else it }),
                6 to e.copy(automaticThoughts = e.automaticThoughts.mapIndexed { i, it -> if (i == 1) it.copy(beliefAfter = rating) else it }),
                7 to e.copy(feelings = e.feelings.mapIndexed { i, it -> if (i == 1) it.copy(intensityAfter = rating) else it }),
            ).forEach { (step, entry) -> assertNotNull(d.copy(entry = entry).validationError(step)) }
        }
        val beforeOnly = d.copy(entry = e.copy(automaticThoughts = e.automaticThoughts.map { it.copy(beliefAfter = null) }, feelings = e.feelings.map { it.copy(intensityAfter = null) }))
        (1..5).forEach { assertNull(beforeOnly.validationError(it)) }
        assertEquals(6, beforeOnly.firstInvalidStep)
        assertFalse(PatientDiaryThreeDraft().hasMeaningfulContent)
        assertEquals(1, PatientDiaryThreeDraft().advance().currentStep)
    }
    @Test fun afterRatingsUseSameRowsAndStructuralRemovalPreservesOtherRows() {
        val original = valid()
        val rated = original.copy(entry = original.entry.copy(
            automaticThoughts = original.entry.automaticThoughts.map { it.copy(beliefAfter = 35) },
            feelings = original.entry.feelings.map { it.copy(intensityAfter = 40) }))
        assertEquals(original.entry.automaticThoughts.map { it.id }, rated.entry.automaticThoughts.map { it.id })
        assertEquals(original.entry.feelings.map { it.id }, rated.entry.feelings.map { it.id })
        assertEquals(listOf(100, 0), rated.entry.automaticThoughts.map { it.beliefBefore })
        assertEquals(listOf(100, 0), rated.entry.feelings.map { it.intensityBefore })
        val removed = rated.copy(entry = rated.entry.copy(automaticThoughts = rated.entry.automaticThoughts.drop(1), feelings = rated.entry.feelings.drop(1)))
        assertEquals(rated.entry.automaticThoughts[1], removed.entry.automaticThoughts.single())
        assertEquals(rated.entry.feelings[1], removed.entry.feelings.single())
        val added = removed.copy(entry = removed.entry.copy(automaticThoughts = removed.entry.automaticThoughts + DiaryThreeAutomaticThoughtDraft(text = "new", beliefBefore = 0), feelings = removed.entry.feelings + DiaryThreeFeelingDraft(name = "כועס", intensityBefore = 100)))
        assertNotNull(added.validationError(6)); assertNotNull(added.validationError(7))
    }
    @Test fun backwardForwardAndSerializationKeepOrderRatingsAndIds() {
        val d = valid().copy(currentStep = 5)
        assertEquals(d, d.back().advance())
        val last = d.copy(currentStep = 7)
        assertEquals(last, last.back().advance())
        assertEquals(last, Json.decodeFromString(PatientDiaryThreeDraft.serializer(), Json.encodeToString(PatientDiaryThreeDraft.serializer(), last)))
    }
    @Test fun exactClinicalKeysExcludeDraftStateAndUseStableThinkingErrorCodes() {
        val body = Json.encodeToJsonElement(SubmitDiaryThreeEntryRequest.serializer(), SubmitDiaryThreeEntryRequest.from(valid().entry)).jsonObject
        assertEquals(setOf("situation", "automaticThoughts", "feelings", "thinkingErrors", "alternativeThoughts"), body.keys)
        assertEquals("event", body.getValue("situation").jsonPrimitive.content)
        assertEquals(setOf("text", "beliefBefore", "beliefAfter"), body.getValue("automaticThoughts").jsonArray[0].jsonObject.keys)
        assertEquals(setOf("name", "intensityBefore", "intensityAfter"), body.getValue("feelings").jsonArray[0].jsonObject.keys)
        assertEquals(setOf("text", "belief"), body.getValue("alternativeThoughts").jsonArray[0].jsonObject.keys)
        assertEquals(listOf("mind_reading", "fortune_telling"), body.getValue("thinkingErrors").jsonArray.map { it.jsonPrimitive.content })
        assertEquals("submit-diary-three-entry", PatientDiaryThreeService.FUNCTION_NAME)
    }
    @Test fun errorMappingAndResponseValidationArePatientSafe() {
        assertEquals(PatientDiaryThreeSubmitError.Kind.NotActive, PatientDiaryThreeService.mapError("diary_three_not_active", 400).kind)
        listOf("patient_access_not_found", "patient_therapist_mismatch").forEach { assertEquals(PatientDiaryThreeSubmitError.Kind.AccessDenied, PatientDiaryThreeService.mapError(it, 403).kind) }
        listOf("invalid_situation", "invalid_automatic_thoughts", "invalid_feelings", "duplicate_feeling", "invalid_thinking_errors", "duplicate_thinking_error", "invalid_alternative_thoughts").forEach {
            assertEquals(PatientDiaryThreeSubmitError.Kind.Invalid, PatientDiaryThreeService.mapError(it, 400).kind)
        }
        val id = "11111111-1111-1111-1111-111111111111"
        assertEquals(id, PatientDiaryThreeService.decodeSuccess("""{"success":true,"entryId":"$id"}"""))
        assertTrue(runCatching { PatientDiaryThreeService.decodeSuccess("""{"success":false,"entryId":"$id"}""") }.isFailure)
    }
}
