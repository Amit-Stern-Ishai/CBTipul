package com.cbtipul.app.data

import com.cbtipul.app.model.*
import com.cbtipul.app.ui.patients.fullContext
import kotlinx.serialization.json.Json
import org.junit.Assert.*
import org.junit.Test
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AIChatProvenanceTest {
    @Test fun clinicalContextCarriesProvenanceWithoutLosingContentOrIdentityLeak() {
        val analysis = Json.decodeFromString<CBTSessionAnalysis>("""{"session_summary":"review-summary","key_situations":[],"possible_nats":[{"thought":"possible-thought","situation":"trigger","emotion":"emotion","behavior":"behavior","source":"inferred","confidence":"medium","cognitive_patterns":[]}],"cbt_cycles":[{"trigger_situation":"cycle-trigger","automatic_thought":"cycle-thought","emotion":"cycle-emotion","behavior":"cycle-behavior","short_term_consequence":"short-effect","long_term_consequence":"long-effect","evidence":"evidence","confidence":"medium"}],"therapist_hypotheses":[{"hypothesis":"ai-hypothesis","evidence":"evidence","confidence":"low"}],"follow_up_questions":[{"question":"open-question","reason":"reason"},{"question":"closed-question","reason":"reason","status":"discussed"}],"assignments_for_next_week":[{"assignment":"homework","details":"homework-details"}]}""")
        val date = Date(1_700_000_000_000)
        val format = SimpleDateFormat("yyyy-MM-dd", Locale.ROOT)
        val patient = Patient(id = DatabaseId.Text("private-id"), localName = "PRIVATE_DISPLAY_NAME", notes = "general-notes",
            sessions = listOf(Session(date = date, notes = "raw-notes", type = SessionType.Intake, structuredNotes = analysis)),
            formulation = PatientFormulation(treatmentGoal = "goal", coreBelief = "core-belief",
                therapistHypothesis = "formulation-hypothesis", keyAutomaticThoughts = listOf("key-thought"),
                maintainingBehaviors = listOf("maintaining-behavior")))
        val q = CombinedMoodQuestionnaire(gad7Answers = listOf(2), phq9Answers = listOf(1),
            gad7Notes = listOf("question-note"), interferenceLevel = 1, interferenceNote = "interference-note")
        val result = fullContext(patient, listOf(CompletedQuestionnaire(DatabaseId.Text("q"), null, date, q)),
            listOf("GAD question"), listOf("PHQ question"), listOf("none", "some"), format, { "severity" }, { "severity" })
        assertTrue(result.contains("Patient notes (general, not tied to a session):\nsource: therapist\ngeneral-notes"))
        assertTrue(result.contains("source: therapist\nmaterialType: therapist_formulation (clinical formulation, not established facts)"))
        assertTrue(result.contains("Raw session notes (source: therapist): raw-notes"))
        assertTrue(result.contains("Previous structured AI review (source: ai_generated; applies to all content in this review)"))
        assertTrue(result.contains("AI-generated hypotheses:"))
        assertTrue(result.contains("field-level edit history is unavailable"))
        assertFalse(result.contains("Therapist hypotheses:"))
        assertTrue(result.contains("Questionnaires:\nsource: patient_reported_measurement"))
        assertTrue(result.contains("Session date: ${format.format(date)}"))
        assertTrue(result.contains("GAD-7 total: 2"))
        assertTrue(result.contains("PHQ-9 total: 1"))
        assertFalse(result.contains("PRIVATE_DISPLAY_NAME"))
        assertFalse(result.contains("private-id"))
        assertFalse(result.contains("closed-question"))
        listOf("review-summary", "possible-thought", "cycle-trigger", "cycle-thought", "cycle-emotion", "cycle-behavior", "short-effect", "long-effect", "ai-hypothesis", "open-question", "homework", "homework-details", "general-notes", "raw-notes", "goal", "core-belief", "formulation-hypothesis", "key-thought", "maintaining-behavior", "question-note", "interference-note").forEach { assertTrue(it, result.contains(it)) }
    }

    @Test fun diariesPreserveAuthorsRecordingTimeAndClinicalFields() {
        val date = Date(1_700_000_000_000)
        val id = DatabaseId.Text("private-id")
        val one = DiaryOneEntry("private-entry", id, "private-owner", DiaryOneEntryCreator.Patient,
            "event-one", listOf("thought-one"), listOf(DiaryFeeling("sad", 0)), "behavior-one", "physical-one", date, date)
        val two = DiaryTwoEntry("private-entry", id, "private-owner", DiaryOneEntryCreator.Therapist,
            "event-two", listOf("thought-two"), listOf(DiaryFeeling("angry", 80)), listOf(ThinkingError.AllOrNothing), listOf("alternative-two"), date, date)
        val three = DiaryThreeEntry("private-entry", id, "private-owner", DiaryOneEntryCreator.Patient,
            "situation-three", listOf(DiaryThreeAutomaticThought("thought-three", 90, 20)), listOf(DiaryThreeFeeling("fear", 80, 10)),
            listOf(ThinkingError.AllOrNothing), listOf(DiaryThreeAlternativeThought("alternative-three", 70)), date, date)
        val result = diaryChatContext(listOf(one), listOf(two), listOf(three), emptyList())
        assertTrue(result.contains("Diary 1\nauthor: patient\nrecordedAt:"))
        assertTrue(result.contains("Diary 2\nauthor: therapist\nrecordedAt:"))
        assertTrue(result.contains("Diary 3\nauthor: patient\nrecordedAt:"))
        assertEquals(4, result.split("recordedAtMeaning: record creation time; the described event may have occurred at another time").size)
        assertFalse(result.contains("private-"))
        assertTrue(result.contains(date.toInstant().toString()))
        listOf("event-one", "thought-one", "sad: 0%", "behavior-one", "physical-one", "event-two", "thought-two", "angry: 80%", "all_or_nothing", "alternative-two", "situation-three", "thought-three", "belief before: 90%, after: 20%", "intensity before: 80%, after: 10%", "alternative-three", "belief: 70%").forEach { assertTrue(it, result.contains(it)) }
    }

    @Test fun unavailableDiaryRemainsUnknown() {
        val warning = "Diary 2 could not be loaded. Its history is unknown; do not infer that it is empty."
        val result = diaryChatContext(emptyList(), emptyList(), emptyList(), listOf(warning))
        assertTrue(result.contains(warning))
        assertTrue(result.contains("No entries in successfully loaded diaries."))
    }
}
