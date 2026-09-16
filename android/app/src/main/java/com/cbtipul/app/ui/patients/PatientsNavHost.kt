package com.cbtipul.app.ui.patients

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.cbtipul.app.R
import com.cbtipul.app.model.CompletedQuestionnaire
import com.cbtipul.app.model.DatabaseId
import com.cbtipul.app.model.PatientFormulation
import com.cbtipul.app.model.Session
import com.cbtipul.app.ui.onboarding.DemoModeChrome
import com.cbtipul.app.ui.onboarding.DemoShowcaseIntroScreen
import com.cbtipul.app.ui.onboarding.ShowcaseRevealPhase
import com.cbtipul.app.ui.theme.hebrewDate
import java.util.Calendar
import java.util.Date

@Composable
fun PatientsNavHost(
    viewModel: PatientListViewModel,
    onOpenSettings: () -> Unit,
    onCloseSettings: (() -> Unit)? = null,
    navController: NavHostController = rememberNavController(),
) {
    val unnamed = stringResource(R.string.unnamed_patient)
    val notConfigured = stringResource(R.string.supabase_not_configured_error)
    val rejected = stringResource(R.string.update_rejected_error)
    val sessionNotSaved = stringResource(R.string.session_not_saved_error)
    val anonymizationFailed = stringResource(R.string.anonymization_failed_error)
    val invalidInput = stringResource(R.string.invalid_input_error)
    val analysisFailed = stringResource(R.string.session_analysis_failed_error)
    val emptyAi = stringResource(R.string.empty_ai_response_error)
    val transcriptionFailedTemplate = stringResource(R.string.transcription_failed)
    val couldNotReadAudioTemplate = stringResource(R.string.could_not_read_audio_file)
    val patients by viewModel.patients.collectAsStateWithLifecycle()
    val questionnaires by viewModel.questionnaires.collectAsStateWithLifecycle()
    val ui by viewModel.ui.collectAsStateWithLifecycle()
    val isDemoMode by viewModel.isDemoMode.collectAsStateWithLifecycle()
    val showcaseLoaded by viewModel.showcaseDataLoaded.collectAsStateWithLifecycle()
    val routerState by viewModel.gettingStartedState.collectAsStateWithLifecycle()
    val checklistDismissed by viewModel.onboarding.checklistDismissed.collectAsStateWithLifecycle()
    val backStackEntry by navController.currentBackStackEntryAsState()
    val atList = backStackEntry?.destination?.route == "list"

    LaunchedEffect(routerState.wantsPatientListReset) {
        if (!routerState.wantsPatientListReset) return@LaunchedEffect
        if (!viewModel.gettingStarted.consumePatientListReset()) return@LaunchedEffect
        navController.popBackStack(route = "list", inclusive = false)
        viewModel.gettingStarted.patientListDidReset(viewModel.onboarding)
    }

    LaunchedEffect(isDemoMode) {
        if (isDemoMode) {
            onCloseSettings?.invoke()
            viewModel.refreshGettingStartedProgress()
        } else {
            navController.popBackStack(route = "list", inclusive = false)
            viewModel.gettingStarted.clearHighlight()
            viewModel.refreshGettingStartedProgress()
        }
    }

    DemoModeChrome(
        isDemoMode = isDemoMode,
        checklistDismissed = checklistDismissed,
        routerState = routerState,
        showcaseLoaded = showcaseLoaded,
        onExitDemo = { viewModel.exitDemoMode() },
        onRestart = { viewModel.restartDemoTutorial() },
        onDismissCoach = { viewModel.dismissCoach() },
        onSkipToShowcase = { viewModel.skipToShowcaseData() },
    ) {
        NavHost(navController = navController, startDestination = "list") {
        composable("list") {
            PatientListScreen(
                viewModel = viewModel,
                unnamed = unnamed,
                onOpenPatient = { navController.navigate("patient/$it") },
                onOpenSettings = onOpenSettings,
                onAddPatient = { navController.navigate("add") },
            )
        }
        composable("add") {
            AddPatientScreen(
                isSaving = ui.isSavingAdd,
                errorMessage = ui.addError,
                onCancel = { if (!ui.isSavingAdd) navController.popBackStack() },
                onSave = { first, last, status ->
                    viewModel.addPatient(first, last, status, notConfigured, rejected) {
                        navController.popBackStack()
                    }
                },
                gettingStarted = viewModel.gettingStarted,
            )
        }
        composable(
            "patient/{id}",
            arguments = listOf(navArgument("id") { type = NavType.StringType }),
        ) { entry ->
            val id = entry.arguments?.getString("id").orEmpty()
            val patient = patients.find { it.id.queryValue == id } ?: viewModel.patient(id)
            LaunchedEffect(id) {
                viewModel.loadSavedPreparation(id)
                patient?.id?.let { viewModel.loadQuestionnaires(it, notConfigured, rejected) }
            }
            val savedPrep = ui.savedPreparations[id]
            val newestQuestionnaires = questionnaires[id].orEmpty().sortedByDescending { it.answeredDate.time }
            PatientDetailScreen(
                patient = patient,
                unnamed = unnamed,
                onBack = { navController.popBackStack() },
                onRename = { first, last ->
                    patient?.let { viewModel.rename(it.id, first, last) }
                },
                lastQuestionnaire = newestQuestionnaires.firstOrNull()?.questionnaire,
                previousQuestionnaire = newestQuestionnaires.getOrNull(1)?.questionnaire,
                lastSessionType = patient?.sessions?.maxByOrNull { it.date }?.type,
                onStatusChange = { status ->
                    val databaseId = patient?.id ?: return@PatientDetailScreen
                    viewModel.updatePatientStatus(
                        databaseId,
                        status,
                        notConfigured,
                        rejected,
                        sessionNotSaved,
                        anonymizationFailed,
                    )
                },
                onSaveGoal = { goal ->
                    val databaseId = patient?.id ?: return@PatientDetailScreen
                    val next = (patient.formulation ?: PatientFormulation()).copy(
                        treatmentGoal = goal.takeIf { it.isNotEmpty() },
                    )
                    viewModel.saveFormulation(
                        databaseId,
                        next,
                        notConfigured,
                        rejected,
                        sessionNotSaved,
                        anonymizationFailed,
                    ) {}
                },
                isSavingGoal = ui.isSavingFormulation,
                onOpenSessions = { navController.navigate("patient/$id/sessions") },
                onOpenQuestionnaires = { navController.navigate("patient/$id/questionnaires") },
                onOpenChat = { navController.navigate("patient/$id/chat") },
                isPreparing = ui.isPreparing,
                savedPreparationDate = savedPrep?.let { hebrewDate(Date(it.generatedAtMillis)) },
                isPreparationOutdated = patient != null && savedPrep != null &&
                    viewModel.isPreparationOutdated(patient, savedPrep.generatedAtMillis),
                prepareError = ui.sessionError,
                onPrepare = {
                    val databaseId = patient?.id ?: return@PatientDetailScreen
                    viewModel.prepareSession(
                        databaseId,
                        notConfigured,
                        rejected,
                        sessionNotSaved,
                        anonymizationFailed,
                        invalidInput,
                        analysisFailed,
                        emptyAi,
                    ) {
                        navController.navigate("patient/$id/prepare")
                    }
                },
                onOpenLastPreparation = { navController.navigate("patient/$id/prepare") },
                notesError = ui.sessionError,
                isSavingNotes = ui.isSavingNotes,
                isTranscribing = ui.isTranscribing,
                isAnonymizingTranscription = ui.isAnonymizingTranscription,
                onSaveNotes = { notes, leave ->
                    val databaseId = patient?.id ?: return@PatientDetailScreen
                    viewModel.savePatientNotes(
                        databaseId,
                        notes,
                        notConfigured,
                        rejected,
                        sessionNotSaved,
                        anonymizationFailed,
                    ) {
                        if (leave) navController.popBackStack()
                    }
                },
                onTranscribe = { file, existing, onNotes, onDone ->
                    viewModel.transcribeVoice(
                        file,
                        existing,
                        sessionForAutosave = null,
                        notConfigured,
                        rejected,
                        sessionNotSaved,
                        anonymizationFailed,
                        transcriptionFailed = { detail ->
                            String.format(transcriptionFailedTemplate, detail)
                        },
                        couldNotReadAudio = { detail ->
                            String.format(couldNotReadAudioTemplate, detail)
                        },
                        onNotes = onNotes,
                        onTranscribed = onDone,
                        patientIdForNotes = patient?.id,
                    )
                },
                onDelete = {
                    val databaseId: DatabaseId? = patient?.id
                    if (databaseId != null) {
                        viewModel.delete(databaseId, notConfigured, rejected) {
                            navController.popBackStack()
                        }
                    }
                },
                gettingStarted = viewModel.gettingStarted,
            )
        }
        composable(
            "patient/{id}/formulation",
            arguments = listOf(navArgument("id") { type = NavType.StringType }),
        ) { entry ->
            val id = entry.arguments?.getString("id").orEmpty()
            val patient = patients.find { it.id.queryValue == id } ?: viewModel.patient(id)
            val emptyHint = stringResource(R.string.add_formulation_content_hint)
            FormulationScreen(
                patient = patient,
                isSaving = ui.isSavingFormulation,
                isAiBusy = ui.isAiBusy,
                errorMessage = ui.sessionError,
                onBack = {
                    viewModel.clearSessionError()
                    navController.popBackStack()
                },
                onSave = { formulation ->
                    val databaseId = patient?.id ?: return@FormulationScreen
                    viewModel.saveFormulation(
                        databaseId,
                        formulation,
                        notConfigured,
                        rejected,
                        sessionNotSaved,
                        anonymizationFailed,
                    ) { }
                },
                onChallenge = {
                    val databaseId = patient?.id ?: return@FormulationScreen
                    viewModel.challengeFormulation(
                        databaseId, notConfigured, rejected, sessionNotSaved, anonymizationFailed,
                        emptyHint, analysisFailed, emptyAi,
                    ) { navController.navigate("patient/$id/formulation/challenge") }
                },
                onMissing = {
                    val databaseId = patient?.id ?: return@FormulationScreen
                    viewModel.whatAmIMissing(
                        databaseId, notConfigured, rejected, sessionNotSaved, anonymizationFailed,
                        invalidInput, analysisFailed, emptyAi,
                    ) { navController.navigate("patient/$id/formulation/missing") }
                },
                onLongitudinal = {
                    val databaseId = patient?.id ?: return@FormulationScreen
                    viewModel.longitudinalReview(
                        databaseId, notConfigured, rejected, sessionNotSaved, anonymizationFailed,
                        invalidInput, analysisFailed, emptyAi,
                    ) { navController.navigate("patient/$id/formulation/longitudinal") }
                },
            )
        }
        composable(
            "patient/{id}/formulation/challenge",
            arguments = listOf(navArgument("id") { type = NavType.StringType }),
        ) { entry ->
            val id = entry.arguments?.getString("id").orEmpty()
            val patient = patients.find { it.id.queryValue == id } ?: viewModel.patient(id)
            FormulationSupervisionScreen(
                result = ui.formulationSupervision,
                atmosphere = patient?.id?.let(PatientAvatarColor::background),
                onBack = { navController.popBackStack() },
            )
        }
        composable(
            "patient/{id}/formulation/missing",
            arguments = listOf(navArgument("id") { type = NavType.StringType }),
        ) { entry ->
            val id = entry.arguments?.getString("id").orEmpty()
            val patient = patients.find { it.id.queryValue == id } ?: viewModel.patient(id)
            WhatAmIMissingScreen(
                result = ui.missingReview,
                atmosphere = patient?.id?.let(PatientAvatarColor::background),
                onBack = { navController.popBackStack() },
            )
        }
        composable(
            "patient/{id}/formulation/longitudinal",
            arguments = listOf(navArgument("id") { type = NavType.StringType }),
        ) { entry ->
            val id = entry.arguments?.getString("id").orEmpty()
            val patient = patients.find { it.id.queryValue == id } ?: viewModel.patient(id)
            LongitudinalReviewScreen(
                result = ui.longitudinalReview,
                atmosphere = patient?.id?.let(PatientAvatarColor::background),
                onBack = { navController.popBackStack() },
            )
        }
        composable(
            "patient/{id}/sessions",
            arguments = listOf(navArgument("id") { type = NavType.StringType }),
        ) { entry ->
            val id = entry.arguments?.getString("id").orEmpty()
            val patient = patients.find { it.id.queryValue == id } ?: viewModel.patient(id)
            PatientSessionsScreen(
                patient = patient,
                unnamed = unnamed,
                questionnaires = questionnaires[id].orEmpty(),
                onBack = { navController.popBackStack() },
                onAdd = { navController.navigate("patient/$id/session/new") },
                onOpenSession = { session ->
                    val sessionKey = session.databaseId?.queryValue ?: session.id.toString()
                    navController.navigate("patient/$id/session/$sessionKey")
                },
                onLoadQuestionnaires = { patient?.id?.let { viewModel.loadQuestionnaires(it, notConfigured, rejected) } },
                gettingStarted = viewModel.gettingStarted,
            )
        }
        composable(
            "patient/{id}/questionnaires",
            arguments = listOf(navArgument("id") { type = NavType.StringType }),
        ) { entry ->
            val id = entry.arguments?.getString("id").orEmpty()
            val patient = patients.find { it.id.queryValue == id } ?: viewModel.patient(id)
            LaunchedEffect(id) { patient?.id?.let { viewModel.loadQuestionnaires(it, notConfigured, rejected) } }
            PatientQuestionnairesScreen(
                records = questionnaires[id].orEmpty(),
                atmosphere = patient?.id?.let(PatientAvatarColor::background),
                isLoading = ui.isLoadingQuestionnaires && questionnaires[id].isNullOrEmpty(),
                loadError = ui.questionnairesError,
                onRetry = { patient?.id?.let { viewModel.loadQuestionnaires(it, notConfigured, rejected) } },
                onBack = { navController.popBackStack() },
                onOpen = { record ->
                    val sessionKey = record.sessionId?.queryValue ?: return@PatientQuestionnairesScreen
                    navController.navigate("patient/$id/session/$sessionKey/questionnaire")
                },
            )
        }
        composable(
            "patient/{id}/session/{sessionId}",
            arguments = listOf(
                navArgument("id") { type = NavType.StringType },
                navArgument("sessionId") { type = NavType.StringType },
            ),
        ) { entry ->
            val id = entry.arguments?.getString("id").orEmpty()
            val sessionId = entry.arguments?.getString("sessionId").orEmpty()
            val isNew = sessionId == "new"
            val patient = patients.find { it.id.queryValue == id } ?: viewModel.patient(id)
            val draft = remember { Session() }
            val session: Session? = if (isNew) draft else viewModel.session(id, sessionId)
            val records = questionnaires[id].orEmpty()
            val currentQuestionnaire = session?.databaseId?.let { db ->
                records.firstOrNull { it.sessionId?.queryValue == db.queryValue }
            }
            LaunchedEffect(id) { patient?.id?.let { viewModel.loadQuestionnaires(it, notConfigured, rejected) } }
            SessionEditorScreen(
                session = session,
                patient = patient,
                unnamed = unnamed,
                isNew = isNew,
                isSaving = ui.isSavingSession,
                isTranscribing = ui.isTranscribing,
                isAnonymizingTranscription = ui.isAnonymizingTranscription,
                isAnalyzing = ui.isAnalyzing,
                errorMessage = ui.sessionError,
                onBack = {
                    viewModel.clearSessionError()
                    navController.popBackStack()
                },
                onSave = { edited, leave ->
                    val patientId = patient?.id ?: return@SessionEditorScreen
                    viewModel.saveSession(
                        patientId,
                        edited,
                        isNew,
                        leaveAfterSave = leave,
                        notConfigured,
                        rejected,
                        sessionNotSaved,
                        anonymizationFailed,
                    ) {
                        viewModel.clearSessionError()
                        navController.popBackStack()
                    }
                },
                onDelete = { edited ->
                    viewModel.deleteSession(
                        edited,
                        notConfigured,
                        rejected,
                        sessionNotSaved,
                        anonymizationFailed,
                    ) {
                        viewModel.clearSessionError()
                        navController.popBackStack()
                    }
                },
                onTranscribe = { file, existing, edited, onNotes, onDone ->
                    viewModel.transcribeVoice(
                        file,
                        existing,
                        edited,
                        notConfigured,
                        rejected,
                        sessionNotSaved,
                        anonymizationFailed,
                        transcriptionFailed = { detail ->
                            String.format(transcriptionFailedTemplate, detail)
                        },
                        couldNotReadAudio = { detail ->
                            String.format(couldNotReadAudioTemplate, detail)
                        },
                        onNotes = onNotes,
                        onTranscribed = onDone,
                    )
                },
                onAnalyze = { edited, onNotes, onAnalysis ->
                    viewModel.analyzeSession(
                        edited,
                        notConfigured,
                        rejected,
                        sessionNotSaved,
                        anonymizationFailed,
                        invalidInput,
                        analysisFailed,
                        emptyAi,
                        onNotes = onNotes,
                        onAnalysis = { analysis ->
                            onAnalysis(analysis)
                            val key = edited.databaseId?.queryValue ?: edited.id.toString()
                            navController.navigate("patient/$id/session/$key/analysis")
                        },
                    )
                },
                onOpenAnalysis = {
                    val key = session?.databaseId?.queryValue ?: session?.id?.toString() ?: return@SessionEditorScreen
                    navController.navigate("patient/$id/session/$key/analysis")
                },
                questionnaire = currentQuestionnaire,
                previousQuestionnaire = previousQuestionnaire(records, session),
                atmosphere = patient?.id?.let(PatientAvatarColor::background),
                onOpenQuestionnaire = {
                    val key = session?.databaseId?.queryValue ?: return@SessionEditorScreen
                    navController.navigate("patient/$id/session/$key/questionnaire")
                },
                onMarkFollowUpDiscussed = { source, questionIndex ->
                    viewModel.markFollowUpDiscussed(
                        source,
                        questionIndex,
                        notConfigured,
                        rejected,
                        sessionNotSaved,
                        anonymizationFailed,
                    )
                },
                gettingStarted = viewModel.gettingStarted,
                viewingPatientId = patient?.id,
            )
        }
        composable(
            "patient/{id}/session/{sessionId}/analysis",
            arguments = listOf(
                navArgument("id") { type = NavType.StringType },
                navArgument("sessionId") { type = NavType.StringType },
            ),
        ) { entry ->
            val id = entry.arguments?.getString("id").orEmpty()
            val sessionId = entry.arguments?.getString("sessionId").orEmpty()
            val session = viewModel.session(id, sessionId)
            val patient = patients.find { it.id.queryValue == id } ?: viewModel.patient(id)
            SessionAnalysisScreen(
                analysis = session?.structuredNotes ?: ui.pendingAnalysis,
                atmosphere = patient?.id?.let(PatientAvatarColor::background),
                persisted = session?.databaseId != null,
                isSaving = ui.isSavingSession,
                errorMessage = ui.sessionError,
                onBack = {
                    viewModel.clearSessionError()
                    navController.popBackStack()
                },
                onSave = { analysis ->
                    val target = session
                    if (target?.databaseId != null) {
                        viewModel.saveAnalysis(
                            target,
                            analysis,
                            notConfigured,
                            rejected,
                            sessionNotSaved,
                            anonymizationFailed,
                        ) {
                            viewModel.clearSessionError()
                            navController.popBackStack()
                        }
                    } else {
                        viewModel.clearSessionError()
                        navController.popBackStack()
                    }
                },
                onDiscard = {
                    if (session?.databaseId == null) viewModel.clearPendingAnalysis()
                    viewModel.clearSessionError()
                    navController.popBackStack()
                },
            )
        }
        composable(
            "patient/{id}/prepare",
            arguments = listOf(navArgument("id") { type = NavType.StringType }),
        ) { entry ->
            val id = entry.arguments?.getString("id").orEmpty()
            val patient = patients.find { it.id.queryValue == id } ?: viewModel.patient(id)
            LaunchedEffect(id) { viewModel.loadSavedPreparation(id) }
            val saved = ui.savedPreparations[id]
            PrepareSessionScreen(
                preparation = saved?.preparation,
                atmosphere = patient?.id?.let(PatientAvatarColor::background),
                isOutdated = patient != null && saved != null &&
                    viewModel.isPreparationOutdated(patient, saved.generatedAtMillis),
                onBack = { navController.popBackStack() },
            )
        }
        composable(
            "patient/{id}/chat",
            arguments = listOf(navArgument("id") { type = NavType.StringType }),
        ) { entry ->
            val id = entry.arguments?.getString("id").orEmpty()
            val patient = patients.find { it.id.queryValue == id } ?: viewModel.patient(id)
            LaunchedEffect(id) { patient?.id?.let { viewModel.loadQuestionnaires(it, notConfigured, rejected) } }
            PatientAIScreen(
                patient = patient,
                unnamed = unnamed,
                questionnaires = questionnaires[id].orEmpty(),
                errorMessage = ui.sessionError,
                onBack = {
                    viewModel.clearSessionError()
                    navController.popBackStack()
                },
                onSend = { system, turns, onAnswer, onDone ->
                    viewModel.sendChat(
                        system,
                        turns,
                        notConfigured,
                        rejected,
                        sessionNotSaved,
                        anonymizationFailed,
                        invalidInput,
                        analysisFailed,
                        emptyAi,
                        onAnswer,
                        onDone,
                    )
                },
            )
        }
        composable(
            "patient/{id}/session/{sessionId}/questionnaire",
            arguments = listOf(
                navArgument("id") { type = NavType.StringType },
                navArgument("sessionId") { type = NavType.StringType },
            ),
        ) { entry ->
            val id = entry.arguments?.getString("id").orEmpty()
            val sessionId = entry.arguments?.getString("sessionId").orEmpty()
            val patient = patients.find { it.id.queryValue == id } ?: viewModel.patient(id)
            val records = questionnaires[id].orEmpty()
            val session = viewModel.session(id, sessionId)
                ?: records.firstOrNull { it.sessionId?.queryValue == sessionId }?.let {
                    Session(databaseId = it.sessionId, date = it.answeredDate)
                }
            val existing = records.firstOrNull { it.sessionId?.queryValue == sessionId }?.questionnaire
            LaunchedEffect(id) { patient?.id?.let { viewModel.loadQuestionnaires(it, notConfigured, rejected) } }
            QuestionnaireScreen(
                session = session,
                existing = existing,
                previous = previousQuestionnaire(records, session),
                atmosphere = patient?.id?.let(PatientAvatarColor::background),
                isSaving = ui.isSavingQuestionnaire,
                errorMessage = ui.sessionError,
                onBack = {
                    viewModel.clearSessionError()
                    navController.popBackStack()
                },
                onSave = { filled ->
                    val patientId = patient?.id ?: return@QuestionnaireScreen
                    val target = session ?: return@QuestionnaireScreen
                    viewModel.saveQuestionnaire(
                        filled,
                        patientId,
                        target,
                        notConfigured,
                        rejected,
                        sessionNotSaved,
                        anonymizationFailed,
                    ) {
                        viewModel.clearSessionError()
                        navController.popBackStack()
                    }
                },
                onDelete = {
                    val patientId = patient?.id ?: return@QuestionnaireScreen
                    val target = session ?: return@QuestionnaireScreen
                    viewModel.deleteQuestionnaire(
                        patientId,
                        target,
                        notConfigured,
                        rejected,
                        sessionNotSaved,
                        anonymizationFailed,
                    ) {
                        viewModel.clearSessionError()
                        navController.popBackStack()
                    }
                },
                gettingStarted = viewModel.gettingStarted,
                viewingPatientId = patient?.id,
            )
        }
        }
        if (atList && routerState.showcaseRevealPhase == ShowcaseRevealPhase.Intro) {
            DemoShowcaseIntroScreen(onExplore = { viewModel.finishShowcaseIntro() })
        }
    }
}

private fun previousQuestionnaire(
    records: List<CompletedQuestionnaire>,
    session: Session?,
): CompletedQuestionnaire? {
    if (session == null) return null
    val sessionDay = Calendar.getInstance().apply {
        time = session.date
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }.time
    return records.firstOrNull { record ->
        record.sessionId?.queryValue != session.databaseId?.queryValue && record.answeredDate < sessionDay
    }
}
