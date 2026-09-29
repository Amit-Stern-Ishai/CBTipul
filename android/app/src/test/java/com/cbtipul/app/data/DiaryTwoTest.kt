package com.cbtipul.app.data

import com.cbtipul.app.model.DatabaseId
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.postgrest.Postgrest
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test
import java.util.Date

class DiaryTwoTest {
    private val raw = """{"id":"e1","patient_id":"p1","therapist_id":"t1","created_by":"patient",
        "event":"event","automatic_thoughts":["one","two"],"feelings":[{"name":"עצוב","intensity":0}],
        "thinking_errors":["mind_reading","all_or_nothing"],"alternative_thoughts":["a","b"],
        "created_at":"2026-09-01T12:00:00Z","updated_at":"2026-09-02T12:00:00Z"}"""
    private val feelings = listOf(DiaryFeeling("עצוב", 0))
    private val errors = listOf(ThinkingError.MindReading, ThinkingError.AllOrNothing)

    @Test fun decodeEveryFieldAndArrayInOrder() {
        val row = Json.decodeFromString<DiaryTwoEntryRow>(raw)
        assertEquals(listOf("one", "two"), row.automaticThoughts)
        assertEquals(listOf("a", "b"), row.alternativeThoughts)
        assertEquals(feelings, row.feelings)
        assertEquals(errors, row.thinkingErrors)
        assertEquals("patient", row.createdBy)
        assertTrue(PatientAssignmentRepository.parseAssignmentTimestamp(row.updatedAt) > PatientAssignmentRepository.parseAssignmentTimestamp(row.createdAt))
    }
    @Test fun allTwelveCodesRoundTrip() {
        val codes = listOf("all_or_nothing", "overgeneralization", "negative_filter", "discounting_positives", "jumping_to_conclusions", "mind_reading", "fortune_telling", "magnification_minimization", "emotional_reasoning", "should_statements", "labeling", "blame")
        assertEquals(codes, ThinkingError.entries.map { it.code })
        ThinkingError.entries.forEach {
            assertEquals("\"${it.code}\"", Json.encodeToString(ThinkingError.serializer(), it))
            assertEquals(it, Json.decodeFromString<ThinkingError>("\"${it.code}\""))
            assertNotEquals(0, it.title); assertNotEquals(0, it.explanation)
        }
    }
    @Test(expected = SerializationException::class) fun unknownCodeFailsSafely() { Json.decodeFromString<ThinkingError>("\"unknown\"") }
    @Test fun createAndUpdateOnlyWriteAllowedFields() {
        val created = DiaryTwoRepository.createPayload("p1", "t1", "e", listOf("one", "two"), feelings, errors, listOf("a", "b"))
        assertEquals("therapist", created.getValue("created_by").jsonPrimitive.content)
        assertEquals(listOf("one", "two"), created.getValue("automatic_thoughts").jsonArray.map { it.jsonPrimitive.content })
        assertEquals(listOf("a", "b"), created.getValue("alternative_thoughts").jsonArray.map { it.jsonPrimitive.content })
        assertEquals(errors.map { it.code }, created.getValue("thinking_errors").jsonArray.map { it.jsonPrimitive.content })
        assertEquals(0, created.getValue("feelings").jsonArray[0].jsonObject.getValue("intensity").jsonPrimitive.int)
        val edited = DiaryTwoRepository.updatePayload("e", listOf("one", "two"), feelings, errors, listOf("a", "b"), "2026-09-02T12:00:00Z")
        assertEquals(setOf("event", "automatic_thoughts", "feelings", "thinking_errors", "alternative_thoughts", "updated_at"), edited.keys)
    }
    @Test fun editorRestoresArraysAndValidationTrimsBlankRows() {
        val entry = DiaryTwoEntry("e1", DatabaseId.Text("p1"), "t1", DiaryOneEntryCreator.Patient, "event", listOf("one", "two"), feelings, errors, listOf("a", "b"), Date(1), Date(2))
        val draft = DiaryTwoEntryDraft.from(entry)
        assertEquals(entry.automaticThoughts, draft.persistedAutomaticThoughts)
        assertEquals(entry.alternativeThoughts, draft.persistedAlternativeThoughts)
        assertEquals(entry.thinkingErrors, draft.thinkingErrors)
        assertEquals(entry.feelings, draft.persistedFeelings())
        assertNull(draft.validationError())
        val dirty = draft.copy(automaticThoughts = listOf(DiaryAutomaticThoughtDraft(text = " one "), DiaryAutomaticThoughtDraft(text = " "), DiaryAutomaticThoughtDraft(text = "two")))
        assertEquals(listOf("one", "two"), dirty.persistedAutomaticThoughts)
        assertNotNull(draft.copy(thinkingErrors = emptyList()).validationError())
        assertNotNull(draft.copy(alternativeThoughts = listOf(DiaryAutomaticThoughtDraft())).validationError())
        assertNotNull(draft.copy(feelings = draft.feelings + draft.feelings).validationError())
        assertNotNull(draft.copy(feelings = listOf(DiaryFeelingDraft("bad", "עצוב", 101))).validationError())
        assertEquals(draft, Json.decodeFromString<DiaryTwoEntryDraft>(Json.encodeToString(DiaryTwoEntryDraft.serializer(), draft)))
    }
    @Test fun activationUsesEdgeWithOnlyPatientIdAndBothCreatedNewValuesSucceed() {
        assertEquals("request-patient-diary-two", PatientAssignmentRepository.FUNCTION_REQUEST_DIARY_TWO)
        assertTrue(PatientAssignmentRepository.usesDiaryTwoEdgeFunction(PatientAssignmentType.DiaryTwo))
        assertFalse(PatientAssignmentRepository.usesDirectInsert(PatientAssignmentType.DiaryTwo))
        val body = Json.parseToJsonElement(PatientAssignmentRepository.encodeDiaryTwoRequest("p1")).jsonObject
        assertEquals(setOf("patientId"), body.keys)
        assertEquals("p1", body.getValue("patientId").jsonPrimitive.content)
        listOf(true, false).forEach { created ->
            val value = PatientAssignmentRepository.assignmentFromDiaryTwoResponse("""{"success":true,"createdNew":$created,
                "assignment":{"id":"a1","patientId":"p1","therapistId":"t1","sessionId":null,"type":"diary_two",
                "createdAt":"2026-09-01T12:00:00Z","completedAt":null,"cancelledAt":null}}""")
            assertEquals(PatientAssignmentType.DiaryTwo, value.type)
            assertTrue(value.isOpen); assertNull(value.sessionId)
        }
        assertEquals(PatientAssignmentException.PatientNotConnected, PatientAssignmentRepository.mapRequestDiaryOneCode("patient_not_connected", 400))
    }
    @Test fun localCrudKeepsSourceAndCreationMetadataAndDeletesOnlyEntry() = runTest {
        val client = createSupabaseClient("https://example.invalid", "test") {
            install(Postgrest)
        }
        try {
            val repo = DiaryTwoRepository(client)
            val patient = DatabaseId.Text("demo-test")
            assertTrue(repo.loadEntries(patient).isEmpty())
            val first = repo.createEntry(patient, "first", listOf("one", "two"), feelings, errors, listOf("a", "b"))
            val second = repo.createEntry(patient, "second", listOf("one"), feelings, errors, listOf("a"))
            assertEquals(listOf(second.id, first.id), repo.entriesFor(patient).map { it.id })
            val edited = repo.updateEntry(first.id, patient, "edited", listOf("two", "one"), feelings, errors, listOf("b", "a"))
            assertEquals(DiaryOneEntryCreator.Therapist, edited.createdBy)
            assertEquals(first.createdAt, edited.createdAt); assertEquals(first.therapistId, edited.therapistId)
            assertEquals(listOf("two", "one"), edited.automaticThoughts)
            assertEquals(listOf("b", "a"), edited.alternativeThoughts)
            repo.deleteEntry(first.id, patient)
            assertEquals(listOf(second.id), repo.entriesFor(patient).map { it.id })
        } finally { client.close() }
    }
}
