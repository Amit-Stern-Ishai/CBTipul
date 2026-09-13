package com.cbtipul.app.data

import com.cbtipul.app.model.AssignmentForNextWeek
import com.cbtipul.app.model.CBTCycle
import com.cbtipul.app.model.CompletedQuestionnaire
import com.cbtipul.app.model.FollowUpStatus
import com.cbtipul.app.model.Patient
import com.cbtipul.app.model.SessionType
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Serializable
data class PatientContext(
    val overview: Overview,
    val assessments: List<Assessment>,
    @SerialName("recent_sessions") val recentSessions: List<SessionNote>,
    @SerialName("recent_reviews") val recentReviews: List<SessionReview>,
    @SerialName("open_follow_ups") val openFollowUps: List<OpenFollowUp>,
    val formulation: Formulation = Formulation(),
    val metadata: Metadata,
) {
    @Serializable
    data class Overview(
        val age: Int? = null,
        val gender: String? = null,
        @SerialName("presenting_problems") val presentingProblems: String? = null,
        @SerialName("treatment_goals") val treatmentGoals: String? = null,
        val background: String? = null,
    )

    @Serializable
    data class Assessment(
        val date: String,
        @SerialName("gad7_answers") val gad7Answers: List<Int?>,
        @SerialName("gad7_score") val gad7Score: Int,
        @SerialName("phq9_answers") val phq9Answers: List<Int?>,
        @SerialName("phq9_score") val phq9Score: Int,
        @SerialName("interference_level") val interferenceLevel: Int? = null,
        @SerialName("gad7_notes") val gad7Notes: List<String> = emptyList(),
        @SerialName("phq9_notes") val phq9Notes: List<String> = emptyList(),
        @SerialName("interference_note") val interferenceNote: String? = null,
    )

    @Serializable
    data class SessionNote(
        val date: String,
        val notes: String,
        val type: SessionType? = null,
    )

    @Serializable
    data class SessionReview(
        val date: String,
        val summary: String,
        @SerialName("possible_nats") val possibleNats: List<com.cbtipul.app.model.PossibleNAT>,
        @SerialName("cbt_cycles") val cbtCycles: List<com.cbtipul.app.model.CBTCycle>,
        @SerialName("therapist_hypotheses") val therapistHypotheses: List<com.cbtipul.app.model.TherapistHypothesis>,
        @SerialName("assignments_for_next_week") val assignmentsForNextWeek: List<AssignmentForNextWeek>,
    )

    @Serializable
    data class OpenFollowUp(
        @SerialName("session_date") val sessionDate: String,
        val question: String,
        val reason: String,
    )

    @Serializable
    data class Formulation(
        val formulation: String? = null,
        @SerialName("treatment_goals") val treatmentGoals: String? = null,
        @SerialName("current_focus") val currentFocus: String? = null,
        @SerialName("key_automatic_thoughts") val keyAutomaticThoughts: List<String> = emptyList(),
        @SerialName("maintaining_behaviors") val maintainingBehaviors: List<String> = emptyList(),
        @SerialName("key_cbt_cycle") val keyCbtCycle: CBTCycle? = null,
    )

    @Serializable
    data class Metadata(
        @SerialName("session_count") val sessionCount: Int,
        @SerialName("last_session_date") val lastSessionDate: String? = null,
        @SerialName("upcoming_focus") val upcomingFocus: String? = null,
    )

    companion object {
        private val dateOnly = SimpleDateFormat("yyyy-MM-dd", Locale.US)

        fun make(patient: Patient, questionnaires: List<CompletedQuestionnaire>): PatientContext {
            val sessions = patient.sessions.sortedByDescending { it.date.time }
            val background = patient.notes.trim().ifEmpty { null }
            val assessments = questionnaires
                .sortedByDescending { it.answeredDate.time }
                .map { record ->
                    Assessment(
                        date = dateOnly.format(record.answeredDate),
                        gad7Answers = record.questionnaire.gad7Answers,
                        gad7Score = record.questionnaire.gad7Score,
                        phq9Answers = record.questionnaire.phq9Answers,
                        phq9Score = record.questionnaire.phq9Score,
                        interferenceLevel = record.questionnaire.interferenceLevel,
                        gad7Notes = record.questionnaire.gad7Notes,
                        phq9Notes = record.questionnaire.phq9Notes,
                        interferenceNote = record.questionnaire.interferenceNote.trim().ifEmpty { null },
                    )
                }
            val recentSessions = sessions.map {
                SessionNote(
                    date = dateOnly.format(it.date),
                    notes = it.notes,
                    type = it.type,
                )
            }
            val recentReviews = sessions.mapNotNull { session ->
                session.structuredNotes?.let { analysis ->
                    SessionReview(
                        date = dateOnly.format(session.date),
                        summary = analysis.sessionSummary,
                        possibleNats = analysis.possibleNats,
                        cbtCycles = analysis.cbtCycles,
                        therapistHypotheses = analysis.therapistHypotheses,
                        assignmentsForNextWeek = analysis.assignmentsForNextWeek,
                    )
                }
            }
            val openFollowUps = sessions.flatMap { session ->
                (session.structuredNotes?.followUpQuestions ?: emptyList())
                    .filter { it.status != FollowUpStatus.Discussed && it.status != FollowUpStatus.NotRelevant }
                    .map {
                        OpenFollowUp(dateOnly.format(session.date), it.question, it.reason)
                    }
            }
            return PatientContext(
                overview = Overview(background = background),
                assessments = assessments,
                recentSessions = recentSessions,
                recentReviews = recentReviews,
                openFollowUps = openFollowUps,
                metadata = Metadata(
                    sessionCount = patient.sessions.size,
                    lastSessionDate = sessions.firstOrNull()?.let { dateOnly.format(it.date) },
                ),
                formulation = PatientContext.Formulation(
                    formulation = patient.formulation?.therapistHypothesis?.trim()?.ifEmpty { null },
                    treatmentGoals = patient.formulation?.treatmentGoal?.trim()?.ifEmpty { null },
                    currentFocus = patient.formulation?.coreBelief?.trim()?.ifEmpty { null },
                    keyAutomaticThoughts = patient.formulation?.keyAutomaticThoughts.orEmpty()
                        .map { it.trim() }.filter { it.isNotEmpty() },
                    maintainingBehaviors = patient.formulation?.maintainingBehaviors.orEmpty()
                        .map { it.trim() }.filter { it.isNotEmpty() },
                    keyCbtCycle = patient.formulation?.keyCBTCycle,
                ),
            )
        }

        fun lastSessionAssignments(patient: Patient, now: Date = Date()): List<AssignmentForNextWeek>? {
            val startOfTomorrow = java.util.Calendar.getInstance().apply {
                time = now
                set(java.util.Calendar.HOUR_OF_DAY, 0)
                set(java.util.Calendar.MINUTE, 0)
                set(java.util.Calendar.SECOND, 0)
                set(java.util.Calendar.MILLISECOND, 0)
                add(java.util.Calendar.DAY_OF_YEAR, 1)
            }.time
            val assignments = patient.sessions
                .filter { it.date < startOfTomorrow }
                .maxByOrNull { it.date.time }
                ?.structuredNotes
                ?.assignmentsForNextWeek
            return assignments?.takeIf { it.isNotEmpty() }
        }
    }
}
