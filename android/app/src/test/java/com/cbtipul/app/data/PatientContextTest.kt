package com.cbtipul.app.data

import com.cbtipul.app.model.CBTCycle
import com.cbtipul.app.model.CBTSessionAnalysis
import com.cbtipul.app.model.CombinedMoodQuestionnaire
import com.cbtipul.app.model.CompletedQuestionnaire
import com.cbtipul.app.model.DatabaseId
import com.cbtipul.app.model.Patient
import com.cbtipul.app.model.PatientFormulation
import com.cbtipul.app.model.Session
import com.cbtipul.app.model.SessionType
import kotlinx.serialization.json.Json
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Date
import java.util.GregorianCalendar

class PatientContextTest {

    private val json = Json { encodeDefaults = true }

    @Test
    fun contextOmitsPatientNameAndIncludesClinicalData() {
        val name = "SECRETNAME"
        val patient = Patient(
            id = DatabaseId.Integer(42),
            firstName = name,
            lastName = "FAMILYNAME",
            localName = "$name FAMILYNAME",
            notes = "Worries about work presentations.",
            formulation = PatientFormulation(
                treatmentGoal = "Reduce avoidance of meetings",
                coreBelief = "I am incompetent",
                keyAutomaticThoughts = listOf("They will notice I am unprepared"),
                maintainingBehaviors = listOf("Cancels team meetings"),
                keyCBTCycle = CBTCycle(triggerSituation = "Calendar invite"),
                therapistHypothesis = "Avoidance maintains anxiety",
            ),
            sessions = listOf(
                Session(
                    date = GregorianCalendar(2026, 0, 10).time,
                    notes = "Practiced a thought record.",
                    type = SessionType.Intake,
                    structuredNotes = CBTSessionAnalysis(sessionSummary = "Practiced identifying NATs."),
                ),
                Session(
                    date = GregorianCalendar(2026, 0, 17).time,
                    notes = "Reviewed homework.",
                    type = SessionType.BehavioralInterventions,
                ),
            ),
        )
        val questionnaires = listOf(
            CompletedQuestionnaire(
                databaseId = DatabaseId.Integer(1),
                sessionId = null,
                answeredDate = Date(patient.sessions.first().date.time),
                questionnaire = CombinedMoodQuestionnaire(
                    gad7Answers = List(7) { 1 },
                    phq9Answers = List(9) { 2 },
                    interferenceLevel = 1,
                    gad7Notes = listOf("Note about restlessness") + List(6) { "" },
                    phq9Notes = List(9) { "" },
                    interferenceNote = "Hard to concentrate at work",
                ),
            ),
        )

        val encoded = json.encodeToString(PatientContext.serializer(), PatientContext.make(patient, questionnaires))

        assertFalse(encoded.contains(name))
        assertFalse(encoded.contains("FAMILYNAME"))
        assertFalse(encoded.contains("42"))
        assertTrue(encoded.contains("Worries about work presentations."))
        assertTrue(encoded.contains("Practiced a thought record."))
        assertTrue(encoded.contains("Reviewed homework."))
        assertTrue(encoded.contains("Practiced identifying NATs."))
        assertTrue(encoded.contains("Reduce avoidance of meetings"))
        assertTrue(encoded.contains("I am incompetent"))
        assertTrue(encoded.contains("They will notice I am unprepared"))
        assertTrue(encoded.contains("Cancels team meetings"))
        assertTrue(encoded.contains("Avoidance maintains anxiety"))
        assertTrue(encoded.contains("Note about restlessness"))
        assertTrue(encoded.contains("Hard to concentrate at work"))
        assertTrue(encoded.contains("intake"))
        assertTrue(encoded.contains("behavioral_interventions"))
    }
}
