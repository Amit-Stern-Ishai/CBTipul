package com.cbtipul.app.data

import com.cbtipul.app.model.DatabaseId
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test
import java.util.Date

class DiaryThreeTest {
    private val thoughts = listOf(DiaryThreeAutomaticThought("first", 100, 0), DiaryThreeAutomaticThought("second", 90, 35))
    private val feelings = listOf(DiaryThreeFeeling("עצוב", 100, 0), DiaryThreeFeeling("מודאג", 85, 40))
    private val alternatives = listOf(DiaryThreeAlternativeThought("a", 0), DiaryThreeAlternativeThought("b", 100))
    private val errors = listOf(ThinkingError.MindReading, ThinkingError.FortuneTelling)
    private val entry = DiaryThreeEntry("e", DatabaseId.Text("p"), "t", DiaryOneEntryCreator.Patient, "situation", thoughts, feelings, errors, alternatives, Date(1), Date(2))

    @Test fun exactNestedKeysDecodingOrderingAndProvenance() {
        val body = DiaryThreeRepository.createPayload("p", "t", "situation", thoughts, feelings, errors, alternatives)
        assertEquals(setOf("patient_id", "therapist_id", "created_by", "situation", "automatic_thoughts", "feelings", "thinking_errors", "alternative_thoughts"), body.keys)
        assertEquals("therapist", body.getValue("created_by").jsonPrimitive.content)
        assertEquals(setOf("text", "beliefBefore", "beliefAfter"), body.getValue("automatic_thoughts").jsonArray[0].jsonObject.keys)
        assertEquals(setOf("name", "intensityBefore", "intensityAfter"), body.getValue("feelings").jsonArray[0].jsonObject.keys)
        assertEquals(setOf("text", "belief"), body.getValue("alternative_thoughts").jsonArray[0].jsonObject.keys)
        assertEquals(listOf("mind_reading", "fortune_telling"), body.getValue("thinking_errors").jsonArray.map { it.jsonPrimitive.content })
        val row = Json.decodeFromJsonElement<DiaryThreeEntryRow>(JsonObject(body + mapOf("id" to JsonPrimitive("e"), "created_at" to JsonPrimitive("2026-09-01T12:00:00Z"), "updated_at" to JsonPrimitive("2026-09-02T12:00:00Z"))))
        assertEquals(thoughts, row.automaticThoughts); assertEquals(feelings, row.feelings)
        assertEquals(alternatives, row.alternativeThoughts); assertEquals(errors, row.thinkingErrors)
        val update = DiaryThreeRepository.updatePayload("s", thoughts, feelings, errors, alternatives, "now")
        assertEquals(setOf("situation", "automatic_thoughts", "feelings", "thinking_errors", "alternative_thoughts", "updated_at"), update.keys)
    }
    @Test fun everyRequiredFieldAndEveryRatingIsValidated() {
        val draft = DiaryThreeEntryDraft.from(entry)
        assertNull(draft.validationError())
        assertEquals(thoughts, draft.persistedAutomaticThoughts)
        assertEquals(feelings, draft.persistedFeelings())
        assertEquals(alternatives, draft.persistedAlternativeThoughts)
        for (value in listOf(null, -1, 101)) {
            assertNotNull(draft.copy(automaticThoughts = listOf(draft.automaticThoughts[0].copy(beliefBefore = value))).validationError())
            assertNotNull(draft.copy(automaticThoughts = listOf(draft.automaticThoughts[0].copy(beliefAfter = value))).validationError())
            assertNotNull(draft.copy(feelings = listOf(draft.feelings[0].copy(intensityBefore = value))).validationError())
            assertNotNull(draft.copy(feelings = listOf(draft.feelings[0].copy(intensityAfter = value))).validationError())
            assertNotNull(draft.copy(alternativeThoughts = listOf(draft.alternativeThoughts[0].copy(belief = value))).validationError())
        }
        for (value in listOf(0, 100)) {
            assertNull(draft.copy(automaticThoughts = listOf(draft.automaticThoughts[0].copy(beliefBefore = value, beliefAfter = value)),
                feelings = listOf(draft.feelings[0].copy(intensityBefore = value, intensityAfter = value)),
                alternativeThoughts = listOf(draft.alternativeThoughts[0].copy(belief = value))).validationError())
        }
        assertNotNull(draft.copy(situation = " \n").validationError())
        assertNotNull(draft.copy(automaticThoughts = emptyList()).validationError())
        assertNotNull(draft.copy(automaticThoughts = listOf(draft.automaticThoughts[0].copy(text = " "))).validationError())
        assertNotNull(draft.copy(feelings = emptyList()).validationError())
        assertNotNull(draft.copy(feelings = draft.feelings + draft.feelings[0]).validationError())
        assertNotNull(draft.copy(thinkingErrors = emptyList()).validationError())
        assertNotNull(draft.copy(thinkingErrors = errors + errors[0]).validationError())
        assertNotNull(draft.copy(alternativeThoughts = emptyList()).validationError())
        assertNotNull(draft.copy(alternativeThoughts = listOf(draft.alternativeThoughts[0].copy(text = " "))).validationError())
    }
    @Test fun stableIdsKeepOnlyTheRemainingRatingsAndRestoreInOrder() {
        val original = DiaryThreeEntryDraft.from(entry)
        val changed = original.copy(automaticThoughts = original.automaticThoughts.drop(1), feelings = original.feelings.drop(1))
        assertEquals(original.automaticThoughts[1], changed.automaticThoughts.single())
        assertEquals(original.feelings[1], changed.feelings.single())
        assertEquals(changed, Json.decodeFromString<DiaryThreeEntryDraft>(Json.encodeToString(DiaryThreeEntryDraft.serializer(), changed)))
    }
    @Test fun activationUsesEdgeOnlyAndAcceptsBothCreatedNewResults() {
        assertEquals("request-patient-diary-three", PatientAssignmentRepository.FUNCTION_REQUEST_DIARY_THREE)
        assertTrue(PatientAssignmentRepository.usesDiaryThreeEdgeFunction(PatientAssignmentType.DiaryThree))
        assertFalse(PatientAssignmentRepository.usesDirectInsert(PatientAssignmentType.DiaryThree))
        assertEquals(setOf("patientId"), Json.parseToJsonElement(PatientAssignmentRepository.encodeDiaryThreeRequest("p")).jsonObject.keys)
        for (created in listOf(true, false)) {
            val response = """{"success":true,"createdNew":$created,"assignment":{"id":"a","patientId":"p","therapistId":"t","sessionId":null,"type":"diary_three","createdAt":"2026-09-01T12:00:00Z","completedAt":null,"cancelledAt":null}}"""
            assertEquals(PatientAssignmentType.DiaryThree, PatientAssignmentRepository.assignmentFromDiaryThreeResponse(response).type)
            assertTrue(runCatching { PatientAssignmentRepository.assignmentFromDiaryThreeResponse(response.replace("diary_three", "diary_two")) }.isFailure)
        }
    }
}
