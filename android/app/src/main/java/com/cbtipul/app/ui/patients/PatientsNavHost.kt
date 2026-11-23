package com.cbtipul.app.ui.patients

import com.cbtipul.app.ui.theme.editorScroll
import com.cbtipul.app.ui.theme.editorFocus
import androidx.compose.material.icons.outlined.EditNote
import androidx.compose.material.icons.Icons
import com.cbtipul.app.ui.theme.IconLabel
import com.cbtipul.app.ui.theme.popScreen
import com.cbtipul.app.ui.theme.AppMotion
import androidx.compose.ui.platform.LocalLayoutDirection
import android.app.Activity
import android.content.Intent
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.cbtipul.app.CbTipulApp
import com.cbtipul.app.R
import com.cbtipul.app.data.DemoData
import com.cbtipul.app.data.PatientAssignmentRepository
import com.cbtipul.app.data.PatientInvitationShare
import com.cbtipul.app.data.TherapistProfile
import com.cbtipul.app.debug.InviteDebugLog
import com.cbtipul.app.model.CompletedQuestionnaire
import com.cbtipul.app.ui.diary.TherapistDiaryTwoScreen
import com.cbtipul.app.ui.diary.TherapistDiaryThreeScreen
import com.cbtipul.app.ui.diary.TherapistDiaryOneScreen
import com.cbtipul.app.ui.messages.MessageListScreen
import com.cbtipul.app.ui.messages.PatientMessageDetailScreen
import com.cbtipul.app.ui.messages.TherapistMessageComposeScreen
import com.cbtipul.app.model.DatabaseId
import com.cbtipul.app.model.PatientFormulation
import com.cbtipul.app.model.Session
import com.cbtipul.app.ui.onboarding.DemoShowcaseIntroScreen
import com.cbtipul.app.ui.onboarding.ShowcaseRevealPhase
import com.cbtipul.app.ui.theme.hebrewDate
import kotlinx.coroutines.launch
import kotlinx.coroutines.ensureActive
import java.util.Calendar
import java.util.Date

@Composable
fun PatientsNavHost(
    viewModel: PatientListViewModel,
    onOpenSettings: (() -> Unit)? = null,
    discoveryActive: Boolean = true,
    onCloseSettings: (() -> Unit)? = null,
    navController: NavHostController = rememberNavController(),
    rootContent: (@Composable () -> Unit)? = null,
) {
    val unnamed = stringResource(R.string.unnamed_patient)
    val context = LocalContext.current
    val app = context.applicationContext as CbTipulApp
    val inviteScope = rememberCoroutineScope()
    var isCreatingInvitation by remember { mutableStateOf(false) }
    var emailInvitePatient by remember { mutableStateOf<String?>(null) }
    emailInvitePatient?.let { id -> EmailInvitationDialog(app, id) { emailInvitePatient = null } }
    var invitationError by remember { mutableStateOf<String?>(null) }
    var showDisplayNamePrompt by remember { mutableStateOf(false) }
    var pendingInvitePatientId by remember { mutableStateOf<String?>(null) }
    var displayNameDraft by remember { mutableStateOf("") }
    var displayNameError by remember { mutableStateOf<String?>(null) }
    var isSavingDisplayName by remember { mutableStateOf(false) }
    val invalidInvite = stringResource(R.string.patient_invitation_invalid_patient)
    val inviteFailed = stringResource(R.string.patient_invitation_failed_title)
    val emptyDisplayName = stringResource(R.string.therapist_display_name_empty)
    val displayNameSaveError = stringResource(R.string.therapist_display_name_save_error)
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
    val routerState by viewModel.gettingStartedState.collectAsStateWithLifecycle()
    val backStackEntry by navController.currentBackStackEntryAsState()
    androidx.compose.runtime.DisposableEffect(backStackEntry?.id) {
        onDispose { app.aiConsentStore.cancelPending() }
    }
    val discoveryAccount = app.authRepository.currentUserId()
    androidx.compose.runtime.SideEffect { app.preferences.discovery.enterContext(if (discoveryActive) "$discoveryAccount/${backStackEntry?.id}" else null) }
    val milestoneIdentity by com.cbtipul.app.data.Entitlements.state.collectAsStateWithLifecycle()
    val handledCreations = remember(discoveryAccount) { mutableSetOf<String>() }
    val aiPrompt by app.aiConsentStore.promptVisible.collectAsStateWithLifecycle()
    var sessionDiscoveryBlocked by remember(discoveryAccount) { mutableStateOf(false) }
    val entitlementPrompt by com.cbtipul.app.data.Entitlements.explanationVisible.collectAsStateWithLifecycle()
    val discoveryQueue by app.preferences.discovery.pending.collectAsStateWithLifecycle()
    val discoveryOpportunity by app.preferences.discovery.opportunities.collectAsStateWithLifecycle()
    var displayedDiscovery by remember(discoveryAccount) { mutableStateOf<com.cbtipul.app.data.DiscoveryIntent?>(null) }
    var discoveryInvite by remember(discoveryAccount) { mutableStateOf(false) }
    val lifecycleOwner = androidx.lifecycle.compose.LocalLifecycleOwner.current
    var resumed by remember { mutableStateOf(false) }
    androidx.compose.runtime.DisposableEffect(lifecycleOwner) {
        val observer = androidx.lifecycle.LifecycleEventObserver { _, _ -> resumed = lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED) }
        lifecycleOwner.lifecycle.addObserver(observer)
        resumed = lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }
    fun requestMilestone(patient: String, kind: com.cbtipul.app.data.PatientMilestone, standalone: Boolean, session: String? = null) {
        val owner = discoveryAccount ?: return
        if (!isDemoMode && owner == app.authRepository.currentUserId() && milestoneIdentity.role == com.cbtipul.app.data.AppRole.Therapist &&
            patients.firstOrNull { it.id.queryValue == patient }?.let { !DemoData.isDemoId(it.id) } == true) {
            inviteScope.launch { app.preferences.enqueueDiscovery(owner, kind.name, patient, standalone, session) }
        }
    }
    val discoverySafe = discoveryActive && resumed && !isDemoMode && milestoneIdentity.role == com.cbtipul.app.data.AppRole.Therapist &&
        !ui.isSavingSession && ui.sessionError == null && invitationError == null && !sessionDiscoveryBlocked && !entitlementPrompt &&
        !aiPrompt && !showDisplayNamePrompt && !isCreatingInvitation && emailInvitePatient == null && backStackEntry?.destination?.route != "add" && backStackEntry?.arguments?.getString("connection").isNullOrBlank()
    LaunchedEffect(backStackEntry?.id) {
        displayedDiscovery?.takeIf { it.reminder && it.context != "$discoveryAccount/${backStackEntry?.id}" }?.let { displayedDiscovery = null }
    }
    LaunchedEffect(discoverySafe) {
        val pending = displayedDiscovery
        if (!discoverySafe && pending != null) displayedDiscovery = null
    }
    LaunchedEffect(discoveryAccount, discoveryQueue, discoveryOpportunity, backStackEntry?.id, discoverySafe, displayedDiscovery, patients, ui.hasLoaded, ui.loadError) {
        val owner = discoveryAccount ?: return@LaunchedEffect
        if (!discoverySafe || displayedDiscovery != null) return@LaunchedEffect
            for (pending in discoveryQueue.filter { it.account.equals(owner, true) && it.feature != "voice" }) {
                try {
                    if (!app.preferences.discovery.valid(pending)) { app.preferences.discovery.remove(pending); continue }
                    val patient = patients.firstOrNull { it.id.queryValue == pending.patient }
                    if (patient == null) {
                        if (ui.hasLoaded && !ui.isLoading && ui.loadError == null) app.preferences.discovery.remove(pending)
                        continue
                    }
                    if (pending.feature == "invite" && pending.reminder) {
                        val status = kotlinx.coroutines.withTimeout(15_000) { app.invitations.emailInvitationStatus(pending.patient) }
                        if (status != "no_invitation") { app.preferences.discovery.remove(pending); continue }
                    }
                    val invite = kotlinx.coroutines.withTimeout(15_000) {
                        com.cbtipul.app.data.DiscoveryRules.resolve(pending,
                            firstEntry = {
                                val count = if (pending.feature == "DiaryOne") app.diaryOne.loadEntries(patient.id).size else app.diaryTwo.loadEntries(patient.id).size
                                count == 1
                            }, sessionExists = { patient.sessions.any { it.id.toString() == pending.session } },
                            connected = { app.assignments.isPatientConnected(pending.patient) },
                            enabled = { app.assignments.activeOngoingAssignment(pending.patient, it.assignment) != null })
                    }
                    if (invite == null) { app.preferences.discovery.remove(pending); continue }
                    kotlinx.coroutines.currentCoroutineContext().ensureActive()
                    if (owner != app.authRepository.currentUserId()) return@LaunchedEffect
                    if (!app.preferences.discovery.valid(pending)) continue
                    discoveryInvite = invite; displayedDiscovery = pending
                    return@LaunchedEffect
                } catch (_: kotlinx.coroutines.TimeoutCancellationException) { /* Keep for the next safe retry. */ }
                catch (cancelled: kotlinx.coroutines.CancellationException) { throw cancelled }
                catch (_: Exception) { /* Keep the intent, try other eligible types, retry at a safe opportunity. */ }
            }
    }
    val atList = backStackEntry?.destination?.route == "list"

    LaunchedEffect(routerState.wantsPatientListReset) {
        if (rootContent != null) return@LaunchedEffect
        if (!routerState.wantsPatientListReset) return@LaunchedEffect
        if (!viewModel.gettingStarted.consumePatientListReset()) return@LaunchedEffect
        navController.popBackStack(route = "list", inclusive = false)
        viewModel.gettingStarted.patientListDidReset(viewModel.onboarding)
    }

    LaunchedEffect(isDemoMode) {
        if (rootContent != null) return@LaunchedEffect
        navController.popBackStack(route = "list", inclusive = false)
        if (isDemoMode) {
            onCloseSettings?.invoke()
            viewModel.refreshGettingStartedProgress()
        } else {
            viewModel.gettingStarted.clearHighlight()
            viewModel.refreshGettingStartedProgress()
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
    Column(modifier = Modifier.fillMaxSize()) {
        if (discoverySafe) displayedDiscovery?.let { pending ->
            if (pending.account.equals(discoveryAccount, true)) {
                val invite = discoveryInvite
                val isWeb = pending.feature == "web"
                FeatureDiscoveryCard(
                    title = if (isWeb) DiscoveryCopy.webTitle else if (invite) DiscoveryCopy.inviteTitle else stringResource(R.string.discovery_activities_title),
                    body = if (isWeb) DiscoveryCopy.webBody else if (invite) DiscoveryCopy.inviteBody else stringResource(when (pending.feature) {
                        "DiaryOne" -> R.string.discovery_diary_one_body
                        "DiaryTwo" -> R.string.discovery_diary_two_body
                        else -> R.string.discovery_questionnaires_body
                    }), web = isWeb,
                    invite = if (isWeb) null else ({
                        displayedDiscovery = null
                        if (pending.account.equals(app.authRepository.currentUserId(), true)) navController.openPatientConnection(pending.patient, invite)
                    }),
                    actionLabel = stringResource(if (invite) R.string.discovery_invite_action else R.string.discovery_activities_action),
                    onPresented = { if (pending.account.equals(app.authRepository.currentUserId(), true)) app.preferences.discovery.presented(pending) },
                    onSuppress = if (isWeb) ({ app.preferences.discovery.suppress(pending.account, "web"); displayedDiscovery = null }) else null,
                    onDismiss = { displayedDiscovery = null },
                )
            }
        }
            val navigationDirection = LocalLayoutDirection.current
            NavHost(
                modifier = Modifier.weight(1f),
                navController = navController,
                startDestination = "list",
                enterTransition = { AppMotion.enter(navigationDirection) },
                exitTransition = { AppMotion.exit(navigationDirection) },
                popEnterTransition = { AppMotion.enter(navigationDirection, back = true) },
                popExitTransition = { AppMotion.exit(navigationDirection, back = true) },
            ) {
        composable("list") {
            if (rootContent != null) rootContent() else PatientListScreen(
                viewModel = viewModel,
                unnamed = unnamed,
                onOpenPatient = { navController.navigate("patient/$it") },
                onOpenSettings = null,
                onOpenWorkspaces = { navController.navigate("web-workspaces") },
                onAddPatient = { if (com.cbtipul.app.data.Entitlements.allowMutation()) navController.navigate("add") },
            )
        }
        composable("web-workspaces") {
            com.cbtipul.app.ui.workspaces.WebWorkspaceInboxScreen(
                onBack = { navController.popScreen() }, onOpen = { navController.navigate("web-workspaces/$it") })
        }
        composable("web-workspaces/{workspaceId}", arguments = listOf(navArgument("workspaceId") { type = NavType.StringType })) { entry ->
            com.cbtipul.app.ui.workspaces.WebWorkspacePreviewScreen(entry.arguments!!.getString("workspaceId")!!) { navController.popScreen() }
        }
        composable("add") {
            AddPatientScreen(
                isSaving = ui.isSavingAdd, errorMessage = ui.addError,
                onCancel = { if (!ui.isSavingAdd) navController.popScreen() },
                onSave = { first, last, status ->
                    val owner = app.authRepository.currentUserId()
                    viewModel.addPatient(first, last, status, notConfigured, rejected) { created ->
                        if (owner == app.authRepository.currentUserId()) {
                            if (created != null && !isDemoMode && owner != null && milestoneIdentity.role == com.cbtipul.app.data.AppRole.Therapist) {
                                inviteScope.launch { app.preferences.enqueueDiscovery(owner, "invite", created.id.queryValue, initialOnly = true) }
                            }
                            navController.popScreen()
                        }
                    }
                }, gettingStarted = viewModel.gettingStarted,
            )
        }
        composable(
            "patient/{id}?connection={connection}",
            arguments = listOf(navArgument("id") { type = NavType.StringType },
                navArgument("connection") { type = NavType.StringType; nullable = true; defaultValue = null }),
        ) { entry ->
            val id = entry.arguments?.getString("id").orEmpty()
            val patient = patients.find { it.id.queryValue == id } ?: viewModel.patient(id)
            LaunchedEffect(id, discoveryAccount) {
                if (!isDemoMode && milestoneIdentity.role == com.cbtipul.app.data.AppRole.Therapist) {
                    discoveryAccount?.let { app.preferences.enqueueDiscovery(it, "invite", id, reminderOnly = true) }
                }
                viewModel.loadSavedPreparation(id)
                patient?.id?.let { viewModel.loadQuestionnaires(it, notConfigured, rejected) }
            }
            val savedPrep = ui.savedPreparations[id]
            val newestQuestionnaires = questionnaires[id].orEmpty().sortedByDescending { it.answeredDate.time }
            PatientDetailScreen(
                patient = patient,
                initialConnectionSheet = entry.arguments?.getString("connection"),
                onDiscoveryBlocked = { sessionDiscoveryBlocked = it },
                unnamed = unnamed,
                onBack = { navController.popScreen() },
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
                onOpenLatestSession = {
                    patient?.let { com.cbtipul.app.data.patientJourney(it.sessions).lastOrNull()?.sessions?.lastOrNull() }?.let { latest ->
                        navController.navigate("patient/$id/session/${latest.databaseId?.queryValue ?: latest.id}")
                    }
                },
                onNewSession = { if (com.cbtipul.app.data.Entitlements.allowMutation()) navController.navigate("patient/$id/session/new") },
                onOpenQuestionnaires = { navController.navigate("patient/$id/questionnaires") },
                onOpenGraphs = { navController.navigate("patient/$id/questionnaires?graphs=true") },
                onOpenRecent = { navController.navigate(it) },
                onOpenDiaryOne = { navController.navigate("patient/$id/diary-one") },
                onOpenDiaryThree = { navController.navigate("patient/$id/diary-three") },
                onOpenDiaryTwo = { navController.navigate("patient/$id/diary-two") },
                onSendMessage = { if (com.cbtipul.app.data.Entitlements.allowMutation()) navController.navigate("patient/$id/message-compose") },
                onOpenMessages = { navController.navigate("patient/$id/messages") },
                assignmentRepository = app.assignments,
                isDemo = isDemoMode || patient?.id?.let { DemoData.isDemoId(it) } == true,
                onInvitePatient = {
                    inviteScope.launch {
                        createAndShareInvitation(
                            app = app,
                            context = context,
                            patientId = patient?.id,
                            invalidInvite = invalidInvite,
                            inviteFailed = inviteFailed,
                            isCreating = { isCreatingInvitation },
                            setCreating = { isCreatingInvitation = it },
                            setError = { invitationError = it },
                            onEmailInvite = { emailInvitePatient = it },
                            onNeedDisplayName = { uuid ->
                                pendingInvitePatientId = uuid
                                displayNameDraft = ""
                                displayNameError = null
                                showDisplayNamePrompt = true
                            },
                        )
                    }
                },
                isCreatingInvitation = isCreatingInvitation,
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
                isSavingStatus = ui.isSavingStatus,
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
                        if (leave) navController.popScreen()
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
                            navController.popScreen()
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
                    navController.popScreen()
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
                onBack = { navController.popScreen() },
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
                onBack = { navController.popScreen() },
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
                onBack = { navController.popScreen() },
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
                onOpenPatient = {
                    navController.navigate("patient/$id") { launchSingleTop = true }
                },
                onBack = { navController.popScreen() },
                onAdd = { if (com.cbtipul.app.data.Entitlements.allowMutation()) navController.navigate("patient/$id/session/new") },
                onOpenSession = { session ->
                    val sessionKey = session.databaseId?.queryValue ?: session.id.toString()
                    navController.navigate("patient/$id/session/$sessionKey")
                },
                onLoadQuestionnaires = { patient?.id?.let { viewModel.loadQuestionnaires(it, notConfigured, rejected) } },
                gettingStarted = viewModel.gettingStarted,
            )
        }
        composable(
            "patient/{id}/questionnaires?graphs={graphs}",
            arguments = listOf(navArgument("id") { type = NavType.StringType }, navArgument("graphs") { type = NavType.BoolType; defaultValue = false }),
        ) { entry ->
            val id = entry.arguments?.getString("id").orEmpty()
            val patient = patients.find { it.id.queryValue == id } ?: viewModel.patient(id)
            LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { patient?.id?.let { viewModel.loadQuestionnaires(it, notConfigured, rejected) } }
            PatientQuestionnairesScreen(
                graphsMode = entry.arguments?.getBoolean("graphs") == true,
                onOpenTrends = { navController.navigate("patient/$id/questionnaire-trends") },
                onAdd = { if (com.cbtipul.app.data.Entitlements.allowMutation()) navController.navigate("patient/$id/questionnaire-result/new") },
                records = questionnaires[id].orEmpty(),
                patientName = patient?.displayName(unnamed).orEmpty(),
                atmosphere = patient?.id?.let(PatientAvatarColor::background),
                isLoading = ui.isLoadingQuestionnaires && questionnaires[id].isNullOrEmpty(),
                loadError = ui.questionnairesError,
                onRetry = { patient?.id?.let { viewModel.loadQuestionnaires(it, notConfigured, rejected) } },
                onOpenPatient = {
                    navController.navigate("patient/$id") { launchSingleTop = true }
                },
                onBack = { navController.popScreen() },
                onOpen = { record ->
                    navController.navigate("patient/$id/questionnaire-result/${record.databaseId.queryValue}")
                },
            )
        }
        composable("patient/{id}/questionnaire-trends", arguments = listOf(navArgument("id") { type = NavType.StringType })) { entry ->
            val id = entry.arguments?.getString("id").orEmpty()
            QuestionnaireTrendsScreen(
                records = questionnaires[id].orEmpty(),
                patientName = viewModel.patient(id)?.displayName(unnamed).orEmpty(),
                onOpenPatient = {
                    navController.navigate("patient/$id") { launchSingleTop = true }
                },
                onBack = { navController.popScreen() },
            )
        }
        composable(
            "patient/{id}/diary-one?entry={entry}",
            arguments = listOf(
                navArgument("id") { type = NavType.StringType },
                navArgument("entry") { type = NavType.StringType; defaultValue = ""; nullable = true },
            ),
        ) { entry ->
            val id = entry.arguments?.getString("id").orEmpty()
            val focusEntryId = entry.arguments?.getString("entry")?.takeIf { it.isNotBlank() }
            val patient = patients.find { it.id.queryValue == id } ?: viewModel.patient(id)
            if (patient == null) {
                NotificationTargetScreen(onBack = { navController.popScreen() })
                return@composable
            }
            TherapistDiaryOneScreen(
                patientId = patient.id,
                patientName = patient.displayName(unnamed),
                atmosphere = PatientAvatarColor.background(patient.id),
                diary = app.diaryOne,
                onDiscoveryBlocked = { sessionDiscoveryBlocked = it },
                onCreated = { requestMilestone(id, com.cbtipul.app.data.PatientMilestone.DiaryOne, true) },
                assignments = app.assignments,
                isDemo = isDemoMode || DemoData.isDemoId(patient.id),
                focusEntryId = focusEntryId,
                returnDirectly = rootContent != null || !entry.arguments?.getString("entry").isNullOrBlank(),
                onBack = { navController.popScreen() },
            )
        }
        composable(
            "patient/{id}/diary-two?entry={entry}",
            arguments = listOf(
                navArgument("id") { type = NavType.StringType },
                navArgument("entry") { type = NavType.StringType; defaultValue = ""; nullable = true },
            ),
        ) { entry ->
            val id = entry.arguments?.getString("id").orEmpty()
            val patient = patients.find { it.id.queryValue == id } ?: viewModel.patient(id)
            if (patient == null) {
                NotificationTargetScreen(onBack = { navController.popScreen() })
                return@composable
            }
            TherapistDiaryTwoScreen(
                patientId = patient.id,
                patientName = patient.displayName(unnamed),
                atmosphere = PatientAvatarColor.background(patient.id),
                diary = app.diaryTwo,
                onDiscoveryBlocked = { sessionDiscoveryBlocked = it },
                onCreated = { requestMilestone(id, com.cbtipul.app.data.PatientMilestone.DiaryTwo, true) },
                focusEntryId = entry.arguments?.getString("entry")?.takeIf { it.isNotBlank() },
                returnDirectly = rootContent != null || !entry.arguments?.getString("entry").isNullOrBlank(),
                assignments = app.assignments,
                isDemo = isDemoMode || DemoData.isDemoId(patient.id),
                onBack = { navController.popScreen() },
            )
        }
        composable(
            "patient/{id}/diary-three?entry={entry}",
            arguments = listOf(
                navArgument("id") { type = NavType.StringType },
                navArgument("entry") { type = NavType.StringType; defaultValue = ""; nullable = true },
            ),
        ) { entry ->
            val id = entry.arguments?.getString("id").orEmpty()
            val patient = patients.find { it.id.queryValue == id } ?: viewModel.patient(id)
            if (patient == null) {
                NotificationTargetScreen(onBack = { navController.popScreen() })
                return@composable
            }
            TherapistDiaryThreeScreen(
                patientId = patient.id,
                patientName = patient.displayName(unnamed),
                atmosphere = PatientAvatarColor.background(patient.id),
                diary = app.diaryThree,
                focusEntryId = entry.arguments?.getString("entry")?.takeIf { it.isNotBlank() },
                returnDirectly = rootContent != null || !entry.arguments?.getString("entry").isNullOrBlank(),
                assignments = app.assignments,
                isDemo = isDemoMode || DemoData.isDemoId(patient.id),
                onBack = { navController.popScreen() },
            )
        }
        composable(
            "patient/{id}/session/{sessionId}",
            arguments = listOf(
                navArgument("id") { type = NavType.StringType },
                navArgument("sessionId") { type = NavType.StringType },
            ),
        ) { entry ->
            val routeId = entry.arguments?.getString("id").orEmpty()
            val sessionId = entry.arguments?.getString("sessionId").orEmpty()
            val isNew = sessionId == "new"
            val draftOwner: SessionEditorViewModel = viewModel(viewModelStoreOwner = entry)
            val draft = draftOwner.getOrCreate(if (isNew) Session() else viewModel.session(routeId, sessionId) ?: Session())
            val recoveryApp = androidx.compose.ui.platform.LocalContext.current.applicationContext as com.cbtipul.app.CbTipulApp
            val recoveryAccount = recoveryApp.authRepository.currentUserId()
            if (recoveryAccount != null) {
                draft.configureRecovery(recoveryApp.formDrafts, com.cbtipul.app.data.DeviceFormDraftStore.key(recoveryAccount, if (isDemoMode) "demo-session" else "therapist-session", "$routeId:$sessionId"))
            }
            val id = if (routeId == "_") draft.selectedPatientId.orEmpty() else routeId
            val patient = patients.find { it.id.queryValue == id } ?: viewModel.patient(id)
            val session: Session? = if (isNew) draft.initial else viewModel.session(id, sessionId)
            val records = questionnaires[id].orEmpty()
            val currentQuestionnaire = session?.databaseId?.let { db ->
                records.firstOrNull { it.sessionId?.queryValue == db.queryValue }
            }
            LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { patient?.id?.let { viewModel.loadQuestionnaires(it, notConfigured, rejected) } }
            SessionEditorScreen(
                choosePatient = routeId == "_",
                availablePatients = patients,
                onSelectPatient = { draft.selectedPatientId = it.id.queryValue },
                editorDraft = draft,
                onCheckSessions = {
                    if (draft.persistRecovery() && patient != null) {
                        viewModel.refresh()
                        navController.navigate("patient/${patient.id.queryValue}/sessions")
                    }
                },
                onRefreshQuestionnaire = { patient?.id?.let { viewModel.loadQuestionnaires(it, notConfigured, rejected) } },
                questionnaireLoading = ui.isLoadingQuestionnaires,
                questionnaireLoadError = ui.questionnairesError,
                session = session,
                patient = patient,
                unnamed = unnamed,
                isNew = isNew,
                isSaving = ui.isSavingSession,
                isTranscribing = ui.isTranscribing,
                isAnonymizingTranscription = ui.isAnonymizingTranscription,
                isAnalyzing = ui.isAnalyzing,
                errorMessage = ui.sessionError,
                hasVersionConflict = ui.sessionConflict,
                onBack = {
                    viewModel.clearSessionError()
                    navController.popScreen()
                },
                onDiscoveryBlocked = { sessionDiscoveryBlocked = it },
                onManualSave = {
                    val owner = discoveryAccount
                    if (owner != null && !isDemoMode && owner == app.authRepository.currentUserId() && milestoneIdentity.role == com.cbtipul.app.data.AppRole.Therapist) {
                        patient?.id?.queryValue?.let { id -> inviteScope.launch { app.preferences.enqueueDiscovery(owner, "web", id) } }
                    }
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
                        onSaved = { saved ->
                            if (draft.clearAudio(recoveryApp)) draft.markSaved(saved)
                            if (isNew && handledCreations.add("${patientId.queryValue}/${saved.id}")) {
                                val savedPatient = viewModel.patient(patientId.queryValue)
                                if (savedPatient != null) {
                                    val allowedContexts = setOf(app.preferences.discovery.activeContext,
                                        navController.previousBackStackEntry?.id?.let { "$discoveryAccount/$it" })
                                    inviteScope.launch {
                                    val kinds = com.cbtipul.app.data.DiscoveryRules.sessionMilestones(saved.type,
                                        savedPatient.sessions.count { it.type == saved.type }, savedPatient.sessions.size).toMutableList()
                                    com.cbtipul.app.data.PatientMilestone.entries.forEach { kind ->
                                        if (discoveryAccount != null && app.preferences.discoverySeen(discoveryAccount, kind.name) &&
                                            (kind == com.cbtipul.app.data.PatientMilestone.SecondSession ||
                                             kind == com.cbtipul.app.data.PatientMilestone.DiaryOne && saved.type == com.cbtipul.app.model.SessionType.DiaryOne ||
                                             kind == com.cbtipul.app.data.PatientMilestone.DiaryTwo && saved.type == com.cbtipul.app.model.SessionType.DiaryTwo) && kind !in kinds) kinds.add(kind)
                                    }
                                    kinds.forEach {
                                        if (discoveryAccount != null && (!app.preferences.discovery.seen(discoveryAccount, it.name) || app.preferences.discovery.activeContext in allowedContexts)) {
                                            requestMilestone(patientId.queryValue, it, false, saved.id.toString())
                                        }
                                    }
                                    }
                                }
                            }
                        },
                        recovery = draft,
                        accountActive = { recoveryAccount == recoveryApp.authRepository.currentUserId() },
                    ) {
                        viewModel.clearSessionError()
                        // A completed save is not a repeated Back tap. Only close its own editor.
                        if (navController.currentBackStackEntry == entry) {
                            app.preferences.discovery.returnAfterSave(navController.previousBackStackEntry?.id?.let { "$discoveryAccount/$it" })
                            navController.popBackStack()
                        }
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
                        draft.clearRecovery(close = true)
                        viewModel.clearSessionError()
                        navController.popScreen()
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
                        recovery = draft,
                        accountActive = { recoveryAccount == recoveryApp.authRepository.currentUserId() },
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
                            val key = edited.databaseId?.queryValue ?: edited.id.toString()
                            navController.navigate("patient/$id/session/$key/analysis")
                        },
                    )
                },
                onOpenAnalysis = {
                    viewModel.clearPendingAnalysis()
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
                assignmentRepository = app.assignments,
                isDemo = isDemoMode || patient?.id?.let { DemoData.isDemoId(it) } == true,
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
            val editorEntry = navController.previousBackStackEntry?.takeIf {
                it.destination.route == "patient/{id}/session/{sessionId}"
            }
            val editorOwner: SessionEditorViewModel? = editorEntry?.let { viewModel(viewModelStoreOwner = it) }
            val editorDraft = editorOwner?.draft?.takeIf {
                it.initial.id.toString() == sessionId || it.initial.databaseId?.queryValue == sessionId
            }
            val session = editorDraft?.snapshot() ?: viewModel.session(id, sessionId)
            val patient = patients.find { it.id.queryValue == id } ?: viewModel.patient(id)
            SessionAnalysisScreen(
                analysis = ui.pendingAnalysis ?: session?.structuredNotes,
                saveToEditorDraft = editorDraft != null,
                atmosphere = patient?.id?.let(PatientAvatarColor::background),
                persisted = ui.pendingAnalysis == null,
                isSaving = ui.isSavingSession,
                errorMessage = ui.sessionError,
                onBack = {
                    viewModel.clearSessionError()
                    navController.popScreen()
                },
                onSave = { analysis ->
                    val target = session
                    if (editorDraft != null) {
                        editorDraft.acceptAnalysis(analysis)
                        viewModel.clearPendingAnalysis()
                        viewModel.clearSessionError()
                        navController.popScreen()
                    } else if (target?.databaseId != null) {
                        viewModel.saveAnalysis(
                            target,
                            analysis,
                            notConfigured,
                            rejected,
                            sessionNotSaved,
                            anonymizationFailed,
                        ) {
                            editorDraft?.structuredNotes = analysis
                            viewModel.clearSessionError()
                            navController.popScreen()
                        }
                    } else {
                        editorDraft?.structuredNotes = analysis
                        viewModel.clearSessionError()
                        navController.popScreen()
                    }
                },
                onDiscard = {
                    viewModel.clearPendingAnalysis()
                    viewModel.clearSessionError()
                    navController.popScreen()
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
                onBack = { navController.popScreen() },
            )
        }
        composable(
            "patient/{id}/chat",
            arguments = listOf(navArgument("id") { type = NavType.StringType }),
        ) { entry ->
            val id = entry.arguments?.getString("id").orEmpty()
            val patient = patients.find { it.id.queryValue == id } ?: viewModel.patient(id)
            LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { patient?.id?.let { viewModel.loadQuestionnaires(it, notConfigured, rejected) } }
            PatientAIScreen(
                patient = patient,
                unnamed = unnamed,
                questionnaires = questionnaires[id].orEmpty(),
                errorMessage = ui.sessionError,
                onBack = {
                    viewModel.clearSessionError()
                    navController.popScreen()
                },
                onSend = { system, turns, onAnswer, onDone ->
                    viewModel.sendChat(
                        requireNotNull(patient).id,
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
            LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { patient?.id?.let { viewModel.loadQuestionnaires(it, notConfigured, rejected) } }
            QuestionnaireScreen(
                patientName = patient?.displayName(unnamed).orEmpty(),
                session = session,
                existing = existing,
                patientSubmitted = records.firstOrNull { it.sessionId?.queryValue == sessionId }?.createdBy == "patient",
                allowRecordEditing = records.firstOrNull { it.sessionId?.queryValue == sessionId }?.let { it.createdBy == "therapist" } ?: true,
                previous = previousQuestionnaire(records, session),
                history = records.filter { it.sessionId?.queryValue != sessionId && it.answeredDate <= (session?.date ?: java.util.Date()) }
                    .sortedWith(compareByDescending<CompletedQuestionnaire> { it.answeredDate }.thenBy { it.databaseId.queryValue }),
                atmosphere = patient?.id?.let(PatientAvatarColor::background),
                isSaving = ui.isSavingQuestionnaire,
                errorMessage = ui.sessionError,
                onBack = {
                    viewModel.clearSessionError()
                    navController.popScreen()
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
                        navController.popScreen()
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
                        navController.popScreen()
                    }
                },
                gettingStarted = viewModel.gettingStarted,
                viewingPatientId = patient?.id,
            )
        }
        composable(
            "patient/{id}/questionnaire-result/{moodId}",
            arguments = listOf(
                navArgument("id") { type = NavType.StringType },
                navArgument("moodId") { type = NavType.StringType },
            ),
        ) { entry ->
            val id = entry.arguments?.getString("id").orEmpty()
            val moodId = entry.arguments?.getString("moodId").orEmpty()
            val patient = patients.find { it.id.queryValue == id } ?: viewModel.patient(id)
            val records = questionnaires[id].orEmpty()
            LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { patient?.id?.let { viewModel.loadQuestionnaires(it, notConfigured, rejected) } }
            val record = records.firstOrNull { it.databaseId.matches(moodId) }
            if (moodId != "new" && record == null) {
                NotificationTargetScreen(
                    onBack = { navController.popScreen() },
                    loading = patient != null && ui.isLoadingQuestionnaires,
                    error = ui.questionnairesError,
                    onRetry = patient?.let { current ->
                        { viewModel.loadQuestionnaires(current.id, notConfigured, rejected) }
                    },
                )
                return@composable
            }
            val session = record?.sessionId?.let { sid ->
                viewModel.session(id, sid.queryValue) ?: Session(databaseId = sid, date = record.answeredDate)
            } ?: record?.let { Session(date = it.answeredDate) } ?: if (moodId == "new") remember { Session() } else null
            QuestionnaireScreen(
                patientName = patient?.displayName(unnamed).orEmpty(),
                session = session,
                existing = record?.questionnaire,
                patientSubmitted = record?.createdBy == "patient",
                allowRecordEditing = record == null || record.createdBy == "therapist",
                previous = previousQuestionnaire(records, session),
                history = records.filter { it.databaseId != record?.databaseId && it.answeredDate <= (session?.date ?: java.util.Date()) }
                    .sortedWith(compareByDescending<CompletedQuestionnaire> { it.answeredDate }.thenBy { it.databaseId.queryValue }),
                atmosphere = patient?.id?.let(PatientAvatarColor::background),
                isSaving = ui.isSavingQuestionnaire,
                errorMessage = ui.sessionError,
                onBack = {
                    viewModel.clearSessionError()
                    navController.popScreen()
                },
                onSave = { filled ->
                    val patientId = patient?.id ?: return@QuestionnaireScreen
                    val target = session ?: return@QuestionnaireScreen
                    viewModel.saveQuestionnaire(
                        filled, patientId, target, notConfigured, rejected, sessionNotSaved, anonymizationFailed, recordId = record?.databaseId,
                    ) {
                        viewModel.clearSessionError()
                        navController.popScreen()
                    }
                },
                onDelete = {
                    val patientId = patient?.id ?: return@QuestionnaireScreen
                    val target = session ?: return@QuestionnaireScreen
                    viewModel.deleteQuestionnaire(
                        patientId, target, notConfigured, rejected, sessionNotSaved, anonymizationFailed, recordId = record?.databaseId,
                    ) {
                        viewModel.clearSessionError()
                        navController.popScreen()
                    }
                },
                gettingStarted = viewModel.gettingStarted,
                viewingPatientId = patient?.id,
            )
        }
        composable(
            "patient/{id}/message-compose",
            arguments = listOf(navArgument("id") { type = NavType.StringType }),
        ) { entry ->
            val id = entry.arguments?.getString("id").orEmpty()
            val patient = patients.find { it.id.queryValue == id } ?: viewModel.patient(id)
            var sending by remember { mutableStateOf(false) }
            var sendError by remember { mutableStateOf<String?>(null) }
            val failed = stringResource(R.string.send_patient_message_failed)
            val empty = stringResource(R.string.send_patient_message_empty)
            val tooLong = stringResource(R.string.send_patient_message_too_long)
            val notConnected = stringResource(R.string.patient_not_connected_title)
            TherapistMessageComposeScreen(
                recipient = patient?.displayName(unnamed).orEmpty(),
                draftTarget = id,
                isSending = sending,
                errorMessage = sendError,
                onSend = { body ->
                    val uuid = patient?.id?.let { PatientAssignmentRepository.uuidOrNull(it) }
                    if (uuid == null) {
                        sendError = notConnected
                        false
                    } else {
                        sending = true
                        sendError = null
                        try {
                            app.messages.send(uuid, body)
                            true
                        } catch (error: kotlinx.coroutines.CancellationException) { throw error
                        } catch (error: com.cbtipul.app.data.PatientMessageSendError) {
                            sendError = when (error) {
                                com.cbtipul.app.data.PatientMessageSendError.Empty -> empty
                                com.cbtipul.app.data.PatientMessageSendError.TooLong -> tooLong
                                com.cbtipul.app.data.PatientMessageSendError.PatientNotConnected -> notConnected
                                else -> failed
                            }
                            false
                        } catch (_: Exception) {
                            sendError = failed
                            false
                        } finally { sending = false }
                    }
                },
                onBack = { if (!sending) navController.popScreen() },
            )
        }
        composable(
            "patient/{id}/messages",
            arguments = listOf(navArgument("id") { type = NavType.StringType }),
        ) { entry ->
            val id = entry.arguments?.getString("id").orEmpty()
            val patient = patients.find { it.id.queryValue == id } ?: viewModel.patient(id)
            val (connection, refreshConnection) = rememberPatientConnection(patient, app.assignments, isDemoMode)
            MessageListScreen(
                title = stringResource(R.string.sent_messages_title),
                load = {
                    val uuid = patient?.id?.let { PatientAssignmentRepository.uuidOrNull(it) } ?: return@MessageListScreen emptyList()
                    app.messages.messages(uuid)
                },
                emptyText = stringResource(R.string.patient_messages_empty),
                showReadState = true,
                header = {
                    Text(patient?.displayName(unnamed).orEmpty())
                    Text(stringResource(R.string.therapist_message_delivery_explanation))
                    when (connection) {
                        ConnectionUi.Connected -> androidx.compose.material3.Button(
                            onClick = { if (com.cbtipul.app.data.Entitlements.allowMutation()) navController.navigate("patient/$id/message-compose") }, modifier = Modifier.fillMaxWidth(),
                        ) { IconLabel(stringResource(R.string.send_patient_message_action), Icons.Outlined.EditNote) }
                        ConnectionUi.Checking -> Text(stringResource(R.string.patient_connection_checking))
                        ConnectionUi.Failed -> androidx.compose.material3.TextButton(onClick = refreshConnection) { Text(stringResource(R.string.retry_action)) }
                        else -> Text(stringResource(if (isDemoMode) R.string.messages_demo_unavailable else R.string.messages_require_connection))
                    }
                },
                onBack = { navController.popScreen() },
                onOpen = { navController.navigate("patient/$id/messages/${it.id}") },
            )
        }
        composable(
            "patient/{id}/messages/{messageId}",
            arguments = listOf(
                navArgument("id") { type = NavType.StringType },
                navArgument("messageId") { type = NavType.StringType },
            ),
        ) { entry ->
            val messageId = entry.arguments?.getString("messageId").orEmpty()
            val patientId = entry.arguments?.getString("id").orEmpty()
            PatientMessageDetailScreen(
                recipient = viewModel.patient(patientId)?.displayName(unnamed).orEmpty(),
                load = { app.messages.message(messageId) },
                showNoReply = false,
                onBack = { navController.popScreen() },
            )
        }
            }
    }
        MessageOverlay(
            visible = invitationError != null,
            title = inviteFailed,
            message = invitationError.orEmpty(),
            onDismiss = { invitationError = null },
        )
        if (showDisplayNamePrompt) {
            AlertDialog(
                onDismissRequest = {
                    if (!isSavingDisplayName) {
                        showDisplayNamePrompt = false
                        pendingInvitePatientId = null
                    }
                },
                title = { Text(stringResource(R.string.therapist_display_name_prompt_title)) },
                text = {
                    Column(Modifier.editorScroll()) {
                        Text(stringResource(R.string.therapist_display_name_prompt_explanation))
                        OutlinedTextField(value = displayNameDraft,
                            onValueChange = {
                                displayNameDraft = it
                                displayNameError = null
                            },
                            modifier = Modifier.editorFocus().fillMaxWidth(),
                            enabled = !isSavingDisplayName,
                            singleLine = true,
                            label = { Text(stringResource(R.string.therapist_display_name_placeholder)) },
                            isError = displayNameError != null,
                            supportingText = displayNameError?.let { { Text(it) } }, readOnly = !com.cbtipul.app.ui.entitlementCanWrite())
                    }
                },
                confirmButton = {
                    TextButton(
                        enabled = !isSavingDisplayName,
                        onClick = {
                            inviteScope.launch {
                                val trimmed = TherapistProfile.normalized(displayNameDraft)
                                if (!TherapistProfile.isValid(trimmed)) {
                                    displayNameError = emptyDisplayName
                                    return@launch
                                }
                                isSavingDisplayName = true
                                try {
                                    app.therapistProfiles.saveDisplayName(trimmed)
                                    showDisplayNamePrompt = false
                                    val uuid = pendingInvitePatientId
                                    pendingInvitePatientId = null
                                    uuid?.let { savedId ->
                                        val patient = patients.find { it.id.queryValue == savedId }
                                            ?: viewModel.patient(savedId)
                                        createAndShareInvitation(
                                            app = app,
                                            context = context,
                                            patientId = patient?.id ?: DatabaseId.Text(savedId),
                                            invalidInvite = invalidInvite,
                                            inviteFailed = inviteFailed,
                                            isCreating = { isCreatingInvitation },
                                            setCreating = { isCreatingInvitation = it },
                                            setError = { invitationError = it },
                                            onEmailInvite = { emailInvitePatient = it },
                            onNeedDisplayName = { pending ->
                                                pendingInvitePatientId = pending
                                                showDisplayNamePrompt = true
                                            },
                                        )
                                    }
                                } catch (_: Exception) {
                                    displayNameError = displayNameSaveError
                                } finally {
                                    isSavingDisplayName = false
                                }
                            }
                        },
                    ) {
                        Text(stringResource(R.string.save))
                    }
                },
                dismissButton = {
                    TextButton(
                        enabled = !isSavingDisplayName,
                        onClick = {
                            showDisplayNamePrompt = false
                            pendingInvitePatientId = null
                        },
                    ) {
                        Text(stringResource(R.string.cancel))
                    }
                },
            )
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

private suspend fun createAndShareInvitation(
    app: CbTipulApp,
    context: android.content.Context,
    patientId: DatabaseId?,
    invalidInvite: String,
    inviteFailed: String,
    isCreating: () -> Boolean,
    setCreating: (Boolean) -> Unit,
    setError: (String?) -> Unit,
    onNeedDisplayName: (String) -> Unit,
    onEmailInvite: (String) -> Unit,
) {
    if (isCreating()) return
    setError(null)
    val uuid = patientId?.let { PatientAssignmentRepository.uuidOrNull(it) }
    if (uuid == null) {
        setError(invalidInvite)
        return
    }
    onEmailInvite(uuid)
}

/** A fresh profile entry must not restore the previous profile's closed sheet. */
internal fun NavHostController.openPatientConnection(patientId: String, invite: Boolean) {
    val route = if (invite) "patient/$patientId?connection=invite"
        else com.cbtipul.app.data.NotificationRouting.inboxRoute(com.cbtipul.app.data.AppDestination.PatientDetail(patientId))!!
    navigate(route) {
        popUpTo("patient/{id}?connection={connection}") { inclusive = true }
    }
}
