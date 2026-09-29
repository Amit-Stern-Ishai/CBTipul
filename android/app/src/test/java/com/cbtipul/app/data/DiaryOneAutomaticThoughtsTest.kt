package com.cbtipul.app.data

import com.cbtipul.app.model.DatabaseId
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Date
import java.util.UUID

class DiaryOneAutomaticThoughtsTest {
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true; explicitNulls = true }

    @Test
    fun rowDecodeUsesAutomaticThoughtsAndPreservesOrder() {
        val raw = """
            {"id":"${UUID.randomUUID()}","patient_id":"p1","therapist_id":"t1","created_by":"patient",
            "event":"אירוע","automatic_thoughts":["ראשונה","שנייה"],"feelings":[],
            "behaviour":"התנהגות","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
        """.trimIndent()
        val row = json.decodeFromString(DiaryOneEntryRow.serializer(), raw)
        assertEquals(listOf("ראשונה", "שנייה"), row.automaticThoughts)
    }

    @Test
    fun legacyThoughtFieldIsIgnoredAndNotRequired() {
        val raw = """
            {"id":"${UUID.randomUUID()}","patient_id":"p1","therapist_id":"t1","created_by":"patient",
            "event":"אירוע","thought":"legacy","automatic_thoughts":["חדשה"],"feelings":[],
            "behaviour":"התנהגות","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
        """.trimIndent()
        val row = json.decodeFromString(DiaryOneEntryRow.serializer(), raw)
        assertEquals(listOf("חדשה"), row.automaticThoughts)
    }

    @Test
    fun draftValidationTrimsBlankRowsAndRequiresOneThought() {
        val event = "אירוע"
        val behaviour = "התנהגות"
        val feelings = listOf(DiaryFeelingDraft(name = "עצוב", intensity = 40))
        fun message(thoughts: List<DiaryAutomaticThoughtDraft>) = DiaryOneEntryDraft(
            event = event,
            automaticThoughts = thoughts,
            feelings = feelings,
            behaviour = behaviour,
        ).validationMessage("e", "thoughts", "feelings", "name", { "i" }, "b")

        assertEquals("thoughts", message(listOf(DiaryAutomaticThoughtDraft(text = ""))))
        assertEquals("thoughts", message(listOf(DiaryAutomaticThoughtDraft(text = "  "), DiaryAutomaticThoughtDraft(text = ""))))
        assertNull(message(listOf(DiaryAutomaticThoughtDraft(text = "  מחשבה  "))))
        val multiple = DiaryOneEntryDraft(
            event = event,
            automaticThoughts = listOf(
                DiaryAutomaticThoughtDraft(text = "אחת"),
                DiaryAutomaticThoughtDraft(text = "  "),
                DiaryAutomaticThoughtDraft(text = "שתיים"),
            ),
            feelings = feelings,
            behaviour = behaviour,
        )
        assertEquals(listOf("אחת", "שתיים"), multiple.persistedAutomaticThoughts)
        assertNull(multiple.validationMessage("e", "thoughts", "feelings", "name", { "i" }, "b"))
    }

    @Test
    fun submitRequestUsesAutomaticThoughtsAndOmitsThought() {
        val encoded = json.encodeToString(
            SubmitDiaryOneEntryRequest.serializer(),
            SubmitDiaryOneEntryRequest(
                event = "אירוע",
                automaticThoughts = listOf("א", "ב"),
                feelings = listOf(DiaryFeeling("עצוב", 20)),
                behaviour = "התנהגות",
                physicalSymptoms = null,
            ),
        )
        assertTrue(encoded.contains("\"automaticThoughts\""))
        assertFalse(encoded.contains("\"thought\":"))
        assertTrue(encoded.contains("א"))
    }

    @Test
    fun invalidAutomaticThoughtsMapsToProvidedHebrewMessage() {
        val error = PatientDiaryOneService.mapSubmitCode(
            "invalid_automatic_thoughts",
            "server",
            400,
            "fallback",
            "יש למלא לפחות מחשבה אוטומטית אחת.",
        )
        assertTrue(error is PatientDiaryOneSubmitError.Invalid)
        assertEquals("יש למלא לפחות מחשבה אוטומטית אחת.", error.userMessage)
    }

    @Test
    fun patientHistoryKeepsNewestPatientCreatedOnly() {
        val patientId = DatabaseId.Text("p1")
        fun entry(id: String, createdBy: DiaryOneEntryCreator, at: Long, thought: String) = DiaryOneEntry(
            id = id,
            patientId = patientId,
            therapistId = "t1",
            createdBy = createdBy,
            event = "e",
            automaticThoughts = listOf(thought),
            feelings = emptyList(),
            behaviour = "b",
            physicalSymptoms = null,
            createdAt = Date(at),
            updatedAt = Date(at),
        )
        val visible = PatientDiaryOneHistory.visible(
            listOf(
                entry("therapist", DiaryOneEntryCreator.Therapist, 3, "מטפל"),
                entry("old", DiaryOneEntryCreator.Patient, 1, "ישן"),
                entry("new", DiaryOneEntryCreator.Patient, 2, "חדש"),
            ),
        )
        assertEquals(listOf("new", "old"), visible.map { it.id })
        assertTrue(visible.all { it.createdBy == DiaryOneEntryCreator.Patient })
    }

    @Test
    fun editDraftLoadsAllThoughtsInOrder() {
        val entry = DiaryOneEntry(
            id = "e1",
            patientId = DatabaseId.Text("p1"),
            therapistId = "t1",
            createdBy = DiaryOneEntryCreator.Therapist,
            event = "e",
            automaticThoughts = listOf("ראשונה", "שנייה"),
            feelings = emptyList(),
            behaviour = "b",
            physicalSymptoms = null,
            createdAt = Date(),
            updatedAt = Date(),
        )
        assertEquals(listOf("ראשונה", "שנייה"), DiaryOneEntryDraft.from(entry).automaticThoughts.map { it.text })
        assertTrue(entry.automaticThoughtsPreview.contains("ראשונה"))
        assertTrue(entry.automaticThoughtsPreview.contains("+1"))
    }
}
