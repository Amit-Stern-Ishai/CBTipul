package com.cbtipul.app.data

import com.cbtipul.app.model.DatabaseId
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test
import java.util.Date

class PatientDiaryTwoTest {
    private fun valid() = DiaryTwoEntryDraft(event = " event ",
        automaticThoughts = listOf(DiaryAutomaticThoughtDraft(text = " first "), DiaryAutomaticThoughtDraft(text = " "), DiaryAutomaticThoughtDraft(text = "second")),
        feelings = listOf(DiaryFeelingDraft(name = "עצוב", intensity = 0), DiaryFeelingDraft(name = "מודאג", intensity = 100)),
        thinkingErrors = listOf(ThinkingError.MindReading, ThinkingError.FortuneTelling),
        alternativeThoughts = listOf(DiaryAutomaticThoughtDraft(text = " a "), DiaryAutomaticThoughtDraft(text = "\n"), DiaryAutomaticThoughtDraft(text = "b")))

    @Test fun validatesEveryRequiredFieldAndIntensity() {
        val draft = valid()
        assertNull(draft.validationError())
        listOf(
            draft.copy(event = " "), draft.copy(automaticThoughts = emptyList()),
            draft.copy(automaticThoughts = listOf(DiaryAutomaticThoughtDraft())),
            draft.copy(feelings = emptyList()),
            draft.copy(feelings = listOf(DiaryFeelingDraft(name = "עצוב", intensity = -1))),
            draft.copy(feelings = listOf(DiaryFeelingDraft(name = "עצוב", intensity = 101))),
            draft.copy(feelings = listOf(DiaryFeelingDraft(name = "עצוב", intensity = null))),
            draft.copy(feelings = draft.feelings + draft.feelings),
            draft.copy(thinkingErrors = emptyList()),
            draft.copy(alternativeThoughts = emptyList()),
            draft.copy(alternativeThoughts = listOf(DiaryAutomaticThoughtDraft(text = " "))),
        ).forEach { assertNotNull(it.validationError()) }
        assertNull(draft.copy(automaticThoughts = listOf(DiaryAutomaticThoughtDraft(text = "one"))).validationError())
    }
    @Test fun defaultFeelingIntensityIsAcceptedWithoutMovingTheSlider() {
        val draft = valid().copy(feelings = listOf(DiaryFeelingDraft(name = "עצוב")))
        assertNull(draft.validationError())
        assertEquals(80, draft.persistedFeelings().single().intensity)
        assertEquals(0, DiaryFeelingDraft(DiaryFeeling("עצוב", 0)).intensity)
        assertEquals(80, DiaryThreeFeelingDraft(name = "עצוב").intensityBefore)
        assertEquals(80, DiaryThreeFeelingDraft(name = "עצוב").intensityAfter)
    }
    @Test fun requestContainsExactlyFiveClinicalKeysAndStableCodes() {
        val request = SubmitDiaryTwoEntryRequest.from(valid())
        val encoded = Json.encodeToJsonElement(SubmitDiaryTwoEntryRequest.serializer(), request).jsonObject
        assertEquals(setOf("event", "automaticThoughts", "feelings", "thinkingErrors", "alternativeThoughts"), encoded.keys)
        assertEquals("event", encoded.getValue("event").jsonPrimitive.content)
        assertEquals(listOf("first", "second"), encoded.getValue("automaticThoughts").jsonArray.map { it.jsonPrimitive.content })
        assertEquals(listOf("a", "b"), encoded.getValue("alternativeThoughts").jsonArray.map { it.jsonPrimitive.content })
        assertEquals(listOf("mind_reading", "fortune_telling"), encoded.getValue("thinkingErrors").jsonArray.map { it.jsonPrimitive.content })
        assertEquals(2, encoded.getValue("feelings").jsonArray.size)
        assertEquals("submit-diary-two-entry", PatientDiaryTwoService.FUNCTION_NAME)
    }
    @Test fun successRequiresTrueAndValidEntryId() {
        val id = "11111111-1111-1111-1111-111111111111"
        assertEquals(id, PatientDiaryTwoService.decodeSuccess("""{"success":true,"entryId":"$id"}"""))
        listOf("""{"success":false,"entryId":"$id"}""", """{"success":true}""", """{"success":true,"entryId":"invalid"}""").forEach {
            assertTrue(runCatching { PatientDiaryTwoService.decodeSuccess(it) }.isFailure)
        }
    }
    @Test fun backendErrorsAreTypedAndUseLocalizedResources() {
        assertEquals(PatientDiaryTwoSubmitError.Kind.NotActive, PatientDiaryTwoService.mapError("diary_two_not_active", 400).kind)
        listOf("patient_access_not_found", "patient_therapist_mismatch").forEach {
            assertEquals(PatientDiaryTwoSubmitError.Kind.AccessDenied, PatientDiaryTwoService.mapError(it, 403).kind)
        }
        listOf("invalid_event", "invalid_automatic_thoughts", "invalid_feelings", "duplicate_feeling", "invalid_thinking_errors", "duplicate_thinking_error", "invalid_alternative_thoughts").forEach {
            val error = PatientDiaryTwoService.mapError(it, 400)
            assertEquals(PatientDiaryTwoSubmitError.Kind.Invalid, error.kind)
            assertNotEquals(0, error.messageRes)
        }
    }
    @Test fun historyKeepsOnlyCurrentPatientsOwnRowsNewestFirst() {
        val entries = listOf(row("old", "p1", DiaryOneEntryCreator.Patient, 1), row("therapist", "p1", DiaryOneEntryCreator.Therapist, 4),
            row("new", "p1", DiaryOneEntryCreator.Patient, 3), row("other", "p2", DiaryOneEntryCreator.Patient, 5))
        val shown = PatientDiaryTwoHistory.visible(entries, "p1")
        assertEquals(listOf("new", "old"), shown.map { it.id })
        val selected = shown.first { it.id == "old" }
        assertEquals(listOf("first", "second"), selected.automaticThoughts)
        assertEquals(ThinkingError.MindReading, selected.thinkingErrors.single())
        assertNotEquals(0, selected.thinkingErrors.single().title)
    }
    private fun row(id: String, patient: String, source: DiaryOneEntryCreator, time: Long) = DiaryTwoEntry(id, DatabaseId.Text(patient), "t1", source,
        "event", listOf("first", "second"), listOf(DiaryFeeling("עצוב", 20)), listOf(ThinkingError.MindReading), listOf("a", "b"), Date(time), Date(time))
}
