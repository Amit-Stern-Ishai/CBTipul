package com.cbtipul.app.ui.onboarding

import androidx.annotation.StringRes
import com.cbtipul.app.R
import com.cbtipul.app.data.DemoData
import com.cbtipul.app.model.CompletedQuestionnaire
import com.cbtipul.app.model.DatabaseId
import com.cbtipul.app.model.Patient
import com.cbtipul.app.model.Session

enum class GettingStartedStep {
    CreatePatient,
    CreateSession,
    FillQuestionnaire,
    RecordSessionSummary,
    CreateAISummary,
    ;

    @get:StringRes
    val titleRes: Int
        get() = when (this) {
            CreatePatient -> R.string.getting_started_step_add_patient
            CreateSession -> R.string.getting_started_step_first_session
            FillQuestionnaire -> R.string.getting_started_step_questionnaire
            RecordSessionSummary -> R.string.getting_started_step_session_summary
            CreateAISummary -> R.string.getting_started_step_ai_summary
        }
}

enum class TutorialCoachPlacement {
    PatientList,
    AddPatient,
    PatientDetail,
    Sessions,
    SessionEditor,
    Questionnaire,
}

enum class TutorialHighlight {
    AddPatient,
    TutorialPatient,
    SessionsEntry,
    AddSession,
    LatestSession,
    FillQuestionnaire,
    RecordNotes,
    AiSummary,
}

data class GettingStartedProgress(
    val hasPatient: Boolean = false,
    val hasSession: Boolean = false,
    val hasQuestionnaire: Boolean = false,
    val hasSessionNotes: Boolean = false,
    val hasAISummary: Boolean = false,
    val focusPatientId: DatabaseId? = null,
) {
    val completedCount: Int
        get() = listOf(hasPatient, hasSession, hasQuestionnaire, hasSessionNotes, hasAISummary)
            .count { it }

    val isComplete: Boolean
        get() = completedCount == GettingStartedStep.entries.size

    fun isComplete(step: GettingStartedStep): Boolean = when (step) {
        GettingStartedStep.CreatePatient -> hasPatient
        GettingStartedStep.CreateSession -> hasSession
        GettingStartedStep.FillQuestionnaire -> hasQuestionnaire
        GettingStartedStep.RecordSessionSummary -> hasSessionNotes
        GettingStartedStep.CreateAISummary -> hasAISummary
    }

    val currentStepNumber: Int
        get() {
            val current = currentStep ?: return GettingStartedStep.entries.size
            return GettingStartedStep.entries.indexOf(current) + 1
        }

    val currentStep: GettingStartedStep?
        get() = GettingStartedStep.entries.firstOrNull { !isComplete(it) }

    companion object {
        val empty = GettingStartedProgress()

        private fun tourScore(
            patient: Patient,
            questionnairesForPatient: (Patient) -> List<CompletedQuestionnaire>?,
        ): Int {
            var score = 1
            if (patient.sessions.isNotEmpty()) score = 2
            val records = questionnairesForPatient(patient)
            if (!records.isNullOrEmpty()) score = 3
            if (patient.sessions.any { it.notes.trim().isNotEmpty() }) score = 4
            if (patient.sessions.any { it.structuredNotes != null }) score = 5
            return score
        }

        fun focusTutorialPatient(
            patients: List<Patient>,
            questionnairesForPatient: (Patient) -> List<CompletedQuestionnaire>?,
        ): Patient? {
            val tutorial = patients.filter { DemoData.isTutorialPatientId(it.id) }
            if (tutorial.isEmpty()) return null
            return tutorial.maxWithOrNull { a, b ->
                val scoreA = tourScore(a, questionnairesForPatient)
                val scoreB = tourScore(b, questionnairesForPatient)
                when {
                    scoreA != scoreB -> scoreA.compareTo(scoreB)
                    else -> {
                        val indexA = patients.indexOfFirst { it.id.queryValue == a.id.queryValue }
                        val indexB = patients.indexOfFirst { it.id.queryValue == b.id.queryValue }
                        indexA.compareTo(indexB)
                    }
                }
            }
        }

        fun evaluate(
            patients: List<Patient>,
            questionnairesForPatient: (Patient) -> List<CompletedQuestionnaire>?,
        ): GettingStartedProgress {
            val focus = focusTutorialPatient(patients, questionnairesForPatient) ?: return empty
            val records = questionnairesForPatient(focus)
            return GettingStartedProgress(
                hasPatient = true,
                hasSession = focus.sessions.isNotEmpty(),
                hasQuestionnaire = !records.isNullOrEmpty(),
                hasSessionNotes = focus.sessions.any { it.notes.trim().isNotEmpty() },
                hasAISummary = focus.sessions.any { it.structuredNotes != null },
                focusPatientId = focus.id,
            )
        }

        fun sessionHasSummary(session: Session): Boolean =
            session.structuredNotes != null || session.notes.trim().isNotEmpty()
    }
}

object TutorialCoach {
    fun highlight(
        step: GettingStartedStep?,
        placement: TutorialCoachPlacement,
        progress: GettingStartedProgress,
        viewingPatientId: DatabaseId? = null,
    ): TutorialHighlight? {
        if (step == null) return null
        if (placement != TutorialCoachPlacement.PatientList &&
            placement != TutorialCoachPlacement.AddPatient
        ) {
            val focus = progress.focusPatientId
            if (focus != null && viewingPatientId != null &&
                viewingPatientId.queryValue != focus.queryValue
            ) {
                return null
            }
        }

        return when (step) {
            GettingStartedStep.CreatePatient -> when (placement) {
                TutorialCoachPlacement.PatientList -> TutorialHighlight.AddPatient
                else -> null
            }
            GettingStartedStep.CreateSession -> when (placement) {
                TutorialCoachPlacement.PatientList -> TutorialHighlight.TutorialPatient
                TutorialCoachPlacement.PatientDetail -> TutorialHighlight.SessionsEntry
                TutorialCoachPlacement.Sessions -> TutorialHighlight.AddSession
                else -> null
            }
            GettingStartedStep.FillQuestionnaire,
            GettingStartedStep.RecordSessionSummary,
            GettingStartedStep.CreateAISummary,
            -> when (placement) {
                TutorialCoachPlacement.PatientList -> TutorialHighlight.TutorialPatient
                TutorialCoachPlacement.PatientDetail -> TutorialHighlight.SessionsEntry
                TutorialCoachPlacement.Sessions ->
                    if (progress.hasSession) TutorialHighlight.LatestSession
                    else TutorialHighlight.AddSession
                TutorialCoachPlacement.SessionEditor -> when (step) {
                    GettingStartedStep.FillQuestionnaire -> TutorialHighlight.FillQuestionnaire
                    GettingStartedStep.RecordSessionSummary -> TutorialHighlight.RecordNotes
                    GettingStartedStep.CreateAISummary -> TutorialHighlight.AiSummary
                    else -> null
                }
                else -> null
            }
        }
    }

    @StringRes
    fun hintRes(
        step: GettingStartedStep?,
        placement: TutorialCoachPlacement,
        progress: GettingStartedProgress,
        viewingPatientId: DatabaseId? = null,
    ): Int? {
        if (step == null) return null
        if (placement != TutorialCoachPlacement.PatientList &&
            placement != TutorialCoachPlacement.AddPatient
        ) {
            val focus = progress.focusPatientId
            if (focus != null && viewingPatientId != null &&
                viewingPatientId.queryValue != focus.queryValue
            ) {
                return R.string.tutorial_coach_hint_open_patient
            }
        }

        return when (step) {
            GettingStartedStep.CreatePatient -> when (placement) {
                TutorialCoachPlacement.PatientList -> R.string.tutorial_coach_hint_add_patient
                TutorialCoachPlacement.AddPatient -> R.string.tutorial_coach_hint_fill_new_patient
                else -> R.string.tutorial_coach_hint_return_patients_add
            }
            GettingStartedStep.CreateSession -> when (placement) {
                TutorialCoachPlacement.PatientList -> R.string.tutorial_coach_hint_open_patient
                TutorialCoachPlacement.PatientDetail -> R.string.tutorial_coach_hint_open_sessions
                TutorialCoachPlacement.Sessions -> R.string.tutorial_coach_hint_add_session
                TutorialCoachPlacement.SessionEditor -> R.string.tutorial_coach_hint_save_session
                else -> R.string.tutorial_coach_hint_open_patient
            }
            GettingStartedStep.FillQuestionnaire -> when (placement) {
                TutorialCoachPlacement.PatientList -> R.string.tutorial_coach_hint_open_patient
                TutorialCoachPlacement.PatientDetail -> R.string.tutorial_coach_hint_open_sessions
                TutorialCoachPlacement.Sessions ->
                    if (progress.hasSession) R.string.tutorial_coach_hint_open_session
                    else R.string.tutorial_coach_hint_add_session
                TutorialCoachPlacement.SessionEditor -> R.string.tutorial_coach_hint_fill_questionnaire
                TutorialCoachPlacement.Questionnaire -> R.string.tutorial_coach_hint_complete_questionnaire
                else -> R.string.tutorial_coach_hint_open_patient
            }
            GettingStartedStep.RecordSessionSummary -> when (placement) {
                TutorialCoachPlacement.PatientList -> R.string.tutorial_coach_hint_open_patient
                TutorialCoachPlacement.PatientDetail -> R.string.tutorial_coach_hint_open_sessions
                TutorialCoachPlacement.Sessions ->
                    if (progress.hasSession) R.string.tutorial_coach_hint_open_session
                    else R.string.tutorial_coach_hint_add_session
                TutorialCoachPlacement.SessionEditor -> R.string.tutorial_coach_hint_record_notes
                else -> R.string.tutorial_coach_hint_open_session
            }
            GettingStartedStep.CreateAISummary -> when (placement) {
                TutorialCoachPlacement.PatientList -> R.string.tutorial_coach_hint_open_patient
                TutorialCoachPlacement.PatientDetail -> R.string.tutorial_coach_hint_open_sessions
                TutorialCoachPlacement.Sessions ->
                    if (progress.hasSession) R.string.tutorial_coach_hint_open_session
                    else R.string.tutorial_coach_hint_add_session
                TutorialCoachPlacement.SessionEditor -> R.string.tutorial_coach_hint_ai_summary
                else -> R.string.tutorial_coach_hint_open_session
            }
        }
    }
}
