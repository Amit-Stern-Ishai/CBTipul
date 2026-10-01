package com.cbtipul.app.ui

import android.Manifest
import android.app.Activity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.cbtipul.app.CbTipulApp
import com.cbtipul.app.R
import com.cbtipul.app.auth.AuthSession
import com.cbtipul.app.auth.AuthViewModel
import com.cbtipul.app.debug.InviteDebugLog
import com.cbtipul.app.data.AnonymousPatientDestination
import com.cbtipul.app.data.AppRootDestination
import com.cbtipul.app.data.AppRootRouting
import com.cbtipul.app.data.PatientDiaryOneSubmitError
import com.cbtipul.app.ui.auth.AuthScreen
import com.cbtipul.app.ui.auth.NewPasswordSheet
import com.cbtipul.app.ui.invite.InvitationFlowScreen
import com.cbtipul.app.ui.legal.AiConsentDialog
import com.cbtipul.app.ui.legal.TermsScreen
import com.cbtipul.app.ui.onboarding.WelcomeOnboardingScreen
import com.cbtipul.app.ui.onboarding.AppIntroductionScreen
import com.cbtipul.app.ui.patient.PatientActivationIncompleteScreen
import com.cbtipul.app.ui.patient.PatientContextRetryScreen
import com.cbtipul.app.ui.patient.PatientModeScreen
import com.cbtipul.app.ui.patient.PatientSettingsScreen
import com.cbtipul.app.ui.patients.MessageOverlay
import com.cbtipul.app.ui.patients.PatientListViewModel
import com.cbtipul.app.ui.settings.SettingsScreen
import com.cbtipul.app.ui.therapist.TherapistRootScreen
import com.cbtipul.app.settings.AppAppearance
import com.cbtipul.app.settings.AppTextSize
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.themedScreen
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.launch

@Composable
fun RootScreen() {
    val app = LocalContext.current.applicationContext as CbTipulApp
    val authViewModel: AuthViewModel = viewModel(
        factory = AuthViewModel.Factory(app.authRepository, app.preferences, app.patientRepository),
    )
    val session by authViewModel.session.collectAsStateWithLifecycle()
    val signedIn = session as? AuthSession.SignedIn
    val isAnonymous = signedIn?.isAnonymous == true
    val isTherapist = signedIn != null && !isAnonymous
    val therapistIdentity = signedIn?.email?.takeUnless { it.isBlank() } ?: signedIn?.userId
    val invitationPhase by app.invitationFlow.phase.collectAsStateWithLifecycle()
    val invitationActive = invitationPhase !is com.cbtipul.app.data.InvitationPhase.Idle
    val appContext by app.appContext.current.collectAsStateWithLifecycle()
    val contextLoading by app.appContext.isLoading.collectAsStateWithLifecycle()
    val rootDestination = AppRootRouting.destination(
        invitationActive = invitationActive,
        hasSession = signedIn != null,
        isAnonymous = isAnonymous,
    )
    val anonymousDestination = AppRootRouting.anonymousDestination(
        context = appContext,
        isLoading = contextLoading || session is AuthSession.Loading,
    )
    LaunchedEffect(rootDestination, anonymousDestination, signedIn != null, isAnonymous) {
        InviteDebugLog.d("session exists: ${signedIn != null}")
        InviteDebugLog.d("isAnonymous: $isAnonymous")
        InviteDebugLog.d("root destination selected: ${rootDestination.name.lowercase()}")
        if (rootDestination == AppRootDestination.AnonymousPatient) {
            InviteDebugLog.d("anonymous destination: ${anonymousDestination.name.lowercase()}")
            appContext?.let {
                InviteDebugLog.d("get-app-context role: ${it.role.name.lowercase()}")
                InviteDebugLog.d("activation: ${it.activation?.name?.lowercase() ?: "null"}")
            }
        }
    }
    LaunchedEffect(signedIn?.userId, isAnonymous, invitationActive, session) {
        if (session is AuthSession.Loading) return@LaunchedEffect
        if (isAnonymous && !invitationActive) {
            runCatching { app.appContext.getCurrentAppContext() }
        } else if (signedIn == null && !invitationActive) {
            app.appContext.clear()
        }
    }
    val listSession by authViewModel.listSession.collectAsStateWithLifecycle()
    val recovering by authViewModel.isRecoveringPassword.collectAsStateWithLifecycle()
    val callbackError by authViewModel.callbackError.collectAsStateWithLifecycle()
    val ui by authViewModel.ui.collectAsStateWithLifecycle()
    val termsAccepted = remember(therapistIdentity) { mutableStateOf<Boolean?>(null) }
    LaunchedEffect(therapistIdentity) {
        val identity = therapistIdentity
        if (identity == null) {
            termsAccepted.value = null
            return@LaunchedEffect
        }
        app.preferences.hasAcceptedTerms(identity).collect { termsAccepted.value = it }
    }
    val consentPrompt by app.aiConsentStore.promptVisible.collectAsStateWithLifecycle()
    val textSize by app.preferences.textSize.collectAsStateWithLifecycle(AppTextSize.Standard)
    val appearance by app.preferences.appearance.collectAsStateWithLifecycle(AppAppearance.Dark)
    val consentAcceptedFlow = remember(therapistIdentity) {
        therapistIdentity?.let { app.preferences.hasAcceptedAiConsent(it) } ?: flowOf(false)
    }
    val aiConsentAccepted by consentAcceptedFlow.collectAsStateWithLifecycle(initialValue = false)
    val onboardingHydrated by app.onboardingStore.isHydrated.collectAsStateWithLifecycle()
    val onboardingIdentity by app.onboardingStore.hydratedIdentity.collectAsStateWithLifecycle()
    val shouldShowIntroduction by app.onboardingStore.shouldShowIntroduction.collectAsStateWithLifecycle()
    var reviewIntroduction by rememberSaveable(therapistIdentity) { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    LaunchedEffect(therapistIdentity, isTherapist) {
        app.onboardingStore.setActiveUser(therapistIdentity.takeIf { isTherapist })
    }
    LaunchedEffect(therapistIdentity) {
        app.aiConsentStore.setActiveUser(therapistIdentity)
    }
    var showSettings by remember { mutableStateOf(false) }
    var showPatientSettings by remember { mutableStateOf(false) }
    var showWelcome by remember { mutableStateOf(false) }
    var patientsViewModel by remember { mutableStateOf<PatientListViewModel?>(null) }
    var isDeletingAccount by remember { mutableStateOf(false) }
    var deleteAccountError by remember { mutableStateOf<String?>(null) }
    var isLeavingPatientMode by remember { mutableStateOf(false) }
    var leavePatientError by remember { mutableStateOf<String?>(null) }
    var therapistDisplayName by remember { mutableStateOf<String?>(null) }
    var therapistDisplayNameLoadFailed by remember { mutableStateOf(false) }

    LaunchedEffect(signedIn?.userId, isAnonymous) {
        if (signedIn == null || isAnonymous) return@LaunchedEffect
        therapistDisplayNameLoadFailed = false
        try {
            therapistDisplayName = app.therapistProfiles.getCurrentProfile()?.displayName
        } catch (_: Exception) {
            therapistDisplayNameLoadFailed = true
        }
    }

    val wantsDemoConsent by app.onboardingStore.wantsDemoConsent.collectAsStateWithLifecycle()
    LaunchedEffect(wantsDemoConsent) {
        if (!wantsDemoConsent) return@LaunchedEffect
        app.onboardingStore.clearDemoConsentRequest()
        // Present above Settings (same as iOS fullScreenCover), then drop Settings under it.
        showWelcome = true
        showSettings = false
    }
    LaunchedEffect(therapistIdentity) {
        if (therapistIdentity == null) {
            showWelcome = false
            patientsViewModel = null
        }
    }

    val notConfigured = stringResource(R.string.supabase_not_configured_error)
    val emailNotConfirmed = stringResource(R.string.email_not_confirmed_error)
    val tooManyRequests = stringResource(R.string.too_many_requests_error)
    val passwordsDontMatch = stringResource(R.string.passwords_dont_match_error)
    val enterEmailFirst = stringResource(R.string.enter_email_first_message)
    val resetSent = stringResource(R.string.password_reset_sent_message)
    val resentMessage = stringResource(R.string.verification_resent_message)
    val diarySubmitFallback = stringResource(R.string.patient_diary_one_submit_error)
    val diaryThoughtsInvalid = stringResource(R.string.diary_one_validation_thought)
    val leaveFailed = stringResource(R.string.patient_leave_mode_failed)
    val activity = androidx.activity.compose.LocalActivity.current
    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted -> app.pushManager.onNotificationPermissionResult(granted) }
    val pushRegistrationContext = when {
        recovering || invitationActive -> null
        isTherapist &&
            termsAccepted.value == true &&
            onboardingHydrated && onboardingIdentity == therapistIdentity &&
            !shouldShowIntroduction && !reviewIntroduction && !showWelcome -> signedIn?.userId?.let { "therapist-$it" }
        rootDestination == AppRootDestination.AnonymousPatient &&
            anonymousDestination == AnonymousPatientDestination.PatientMode ->
            signedIn?.userId?.let { "patient-$it" }
        else -> null
    }
    LaunchedEffect(pushRegistrationContext) {
        if (pushRegistrationContext == null) return@LaunchedEffect
        val host = activity ?: return@LaunchedEffect
        app.pushManager.startAfterEnteringAuthenticatedMode(host) {
            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    val versionState by app.appVersion.state.collectAsStateWithLifecycle()
    androidx.compose.foundation.layout.Column(Modifier.fillMaxSize()) {
    Box(modifier = Modifier.weight(1f)) {
        when {
            recovering && !invitationActive -> {
                NewPasswordSheet(
                    state = ui,
                    onPasswordChange = authViewModel::updateNewPassword,
                    onConfirmChange = authViewModel::updateNewPasswordConfirm,
                    onSave = {
                        authViewModel.saveNewPassword(
                            notConfigured,
                            emailNotConfirmed,
                            tooManyRequests,
                            passwordsDontMatch,
                        )
                    },
                    onCancel = authViewModel::cancelRecovery,
                )
            }
            session is AuthSession.Loading && !invitationActive -> {
                Box(
                    modifier = Modifier.fillMaxSize().themedScreen(Theme.colors.gold),
                    contentAlignment = Alignment.Center,
                ) {
                    CircularProgressIndicator(color = Theme.colors.gold)
                }
            }
            rootDestination == AppRootDestination.Invitation -> {
                InvitationFlowScreen(app.invitationFlow)
            }
            rootDestination == AppRootDestination.AnonymousPatient -> {
                when (anonymousDestination) {
                    AnonymousPatientDestination.PatientMode -> {
                        val pending by app.pendingDestinations.pending.collectAsStateWithLifecycle()
                        PatientModeScreen(
                        diaryTwo = app.patientDiaryTwo,
                        diaryThree = app.patientDiaryThree,
                        patientId = appContext?.patientId.orEmpty(),
                        loadAssignments = {
                            app.assignments.patientAssignments(appContext?.patientId)
                        },
                        loadQuestionnaireHistory = { app.patientQuestionnaires.history(appContext?.patientId.orEmpty()) },
                        submitQuestionnaire = { assignmentId, gad7, phq9, interference ->
                            app.assignments.submitPatientQuestionnaire(
                                assignmentId,
                                gad7,
                                phq9,
                                interference,
                            )
                        },
                        submitDiaryOne = { event, automaticThoughts, feelings, behaviour, physicalSymptoms ->
                            try {
                                app.patientDiaryOne.submitEntry(
                                    event,
                                    automaticThoughts,
                                    feelings,
                                    behaviour,
                                    physicalSymptoms,
                                    fallbackMessage = diarySubmitFallback,
                                    invalidThoughtsMessage = diaryThoughtsInvalid,
                                )
                            } catch (error: PatientDiaryOneSubmitError.AccessDenied) {
                                runCatching { app.appContext.getCurrentAppContext() }
                                throw error
                            }
                        },
                        loadDiaryOneHistory = {
                            val patientId = appContext?.patientId
                            if (patientId.isNullOrBlank()) {
                                emptyList()
                            } else {
                                app.patientDiaryOne.loadPatientCreatedEntries(patientId)
                            }
                        },
                        loadMessages = {
                            val patientId = appContext?.patientId
                            if (patientId == null) emptyList() else app.messages.messages(patientId)
                        },
                        loadMessage = { id -> app.messages.message(id) },
                        markMessageRead = { id -> app.messages.markRead(id) },
                        pendingDestination = pending,
                        onConsumePending = { app.pendingDestinations.consume() },
                        onOpenSettings = { showPatientSettings = true },
                    )
                    }
                    AnonymousPatientDestination.Incomplete -> PatientActivationIncompleteScreen(
                        onRetry = { scope.launch { runCatching { app.appContext.getCurrentAppContext() } } },
                        onLeaveToTherapistSignIn = {
                            isLeavingPatientMode = true
                            leavePatientError = null
                            scope.launch {
                                try {
                                    app.authRepository.signOutPatientMode()
                                    app.appContext.clear()
                                } catch (_: Exception) {
                                    leavePatientError = leaveFailed
                                } finally {
                                    isLeavingPatientMode = false
                                }
                            }
                        },
                        isLeaving = isLeavingPatientMode,
                    )
                    AnonymousPatientDestination.Loading -> {
                        Box(
                            modifier = Modifier.fillMaxSize().themedScreen(Theme.colors.gold),
                            contentAlignment = Alignment.Center,
                        ) {
                            CircularProgressIndicator(color = Theme.colors.gold)
                        }
                    }
                    AnonymousPatientDestination.Retry -> PatientContextRetryScreen(
                        onRetry = { scope.launch { runCatching { app.appContext.getCurrentAppContext() } } },
                        onLeaveToTherapistSignIn = {
                            isLeavingPatientMode = true
                            leavePatientError = null
                            scope.launch {
                                try {
                                    app.authRepository.signOutPatientMode()
                                    app.appContext.clear()
                                } catch (_: Exception) {
                                    leavePatientError = leaveFailed
                                } finally {
                                    isLeavingPatientMode = false
                                }
                            }
                        },
                        isLeaving = isLeavingPatientMode,
                    )
                }
            }
            isTherapist && termsAccepted.value == null -> {
                Box(
                    modifier = Modifier.fillMaxSize().themedScreen(Theme.colors.gold),
                    contentAlignment = Alignment.Center,
                ) {
                    CircularProgressIndicator(color = Theme.colors.gold)
                }
            }
            isTherapist && termsAccepted.value == false -> {
                TermsScreen(
                    onAgree = {
                        val identity = therapistIdentity ?: return@TermsScreen
                        scope.launch { authViewModel.acceptTerms(identity) }
                    },
                )
            }
            isTherapist && termsAccepted.value == true -> {
                val listVm: PatientListViewModel = viewModel(
                    key = "$therapistIdentity-$listSession",
                    factory = PatientListViewModel.Factory(app.patientRepository, app.onboardingStore),
                )
                SideEffect { patientsViewModel = listVm }

                when {
                    !onboardingHydrated || onboardingIdentity != therapistIdentity -> {
                        Box(
                            modifier = Modifier.fillMaxSize().themedScreen(Theme.colors.gold),
                            contentAlignment = Alignment.Center,
                        ) {
                            CircularProgressIndicator(color = Theme.colors.gold)
                        }
                    }
                    shouldShowIntroduction -> {
                        AppIntroductionScreen(
                            onTrySample = {
                                scope.launch {
                                    listVm.startDemoTour().join()
                                    app.onboardingStore.completeIntroduction()
                                }
                            },
                            onContinue = { scope.launch { app.onboardingStore.completeIntroduction() } },
                        )
                    }
                    else -> {
                        TherapistRootScreen(
                            viewModel = listVm,
                            onCloseSettingsOverlay = { showSettings = false },
                            settingsContent = {
                                val isDemoMode by listVm.isDemoMode.collectAsStateWithLifecycle()
                                SettingsScreen(
                                    isDemoMode = isDemoMode,
                                    onExitDemoMode = { listVm.exitDemoMode() },
                                    email = signedIn?.email,
                                    textSize = textSize,
                                    appearance = appearance,
                                    onAppearance = { value -> scope.launch { app.preferences.setAppearance(value) } },
                                    aiConsentAccepted = aiConsentAccepted,
                                    displayName = therapistDisplayName,
                                    displayNameLoadFailed = therapistDisplayNameLoadFailed,
                                    isDeleting = isDeletingAccount,
                                    deleteError = deleteAccountError,
                                    onTextSize = { value -> scope.launch { app.preferences.setTextSize(value) } },
                                    onSignOut = {
                                        authViewModel.signOut()
                                        showSettings = false
                                    },
                                    onLoadDisplayName = {
                                        try {
                                            val loaded = app.therapistProfiles.getCurrentProfile()?.displayName
                                            therapistDisplayName = loaded
                                            therapistDisplayNameLoadFailed = false
                                            loaded
                                        } catch (_: Exception) {
                                            therapistDisplayNameLoadFailed = true
                                            throw IllegalStateException("display_name_load_failed")
                                        }
                                    },
                                    onSaveDisplayName = { name ->
                                        therapistDisplayName = app.therapistProfiles.saveDisplayName(name).displayName
                                        therapistDisplayNameLoadFailed = false
                                    },
                                    onDeleteAccount = {
                                        isDeletingAccount = true
                                        deleteAccountError = null
                                        authViewModel.deleteAccount(
                                            notConfigured,
                                            emailNotConfirmed,
                                            tooManyRequests,
                                            onSuccess = {
                                                isDeletingAccount = false
                                                showSettings = false
                                            },
                                            onError = { message ->
                                                isDeletingAccount = false
                                                deleteAccountError = message
                                            },
                                        )
                                    },
                                    onClearDeleteError = { deleteAccountError = null },
                                    onGettingStartedGuide = {
                                        app.onboardingStore.requestDemoConsent()
                                    },
                                    onReviewIntroduction = { reviewIntroduction = true },
                                    onDone = {},
                                    showCloseButton = false,
                                )
                            },
                        )
                    }
                }
            }
            else -> {
                AuthScreen(
                    state = ui,
                    callbackError = callbackError,
                    onEmailChange = authViewModel::updateEmail,
                    onPasswordChange = authViewModel::updatePassword,
                    onConfirmPasswordChange = authViewModel::updateConfirmPassword,
                    onModeChange = authViewModel::setMode,
                    onSubmit = {
                        authViewModel.submit(notConfigured, emailNotConfirmed, tooManyRequests, passwordsDontMatch)
                    },
                    onForgotPassword = {
                        authViewModel.forgotPassword(
                            notConfigured,
                            emailNotConfirmed,
                            tooManyRequests,
                            enterEmailFirst,
                            resetSent,
                        )
                    },
                    onResend = {
                        authViewModel.resendVerification(
                            notConfigured,
                            emailNotConfirmed,
                            tooManyRequests,
                            resentMessage,
                        )
                    },
                    onBackToSignIn = authViewModel::backToSignIn,
                )
            }
        }

        if (consentPrompt && !recovering && !isAnonymous) {
            AiConsentDialog(
                onAccept = { scope.launch { app.aiConsentStore.accept() } },
                onDecline = { scope.launch { app.aiConsentStore.decline() } },
            )
        }

        if (leavePatientError != null && !showPatientSettings) {
            MessageOverlay(
                visible = true,
                title = leaveFailed,
                message = leavePatientError.orEmpty(),
                onDismiss = { leavePatientError = null },
            )
        }

        if (showPatientSettings) {
            PatientSettingsScreen(
                textSize = textSize,
                appearance = appearance,
                onTextSize = { value -> scope.launch { app.preferences.setTextSize(value) } },
                onAppearance = { value -> scope.launch { app.preferences.setAppearance(value) } },
                isLeaving = isLeavingPatientMode,
                leaveError = leavePatientError,
                onLeavePatientMode = {
                    isLeavingPatientMode = true
                    leavePatientError = null
                    scope.launch {
                        try {
                            app.authRepository.signOutPatientMode()
                            app.appContext.clear()
                            showPatientSettings = false
                        } catch (_: Exception) {
                            leavePatientError = leaveFailed
                        } finally {
                            isLeavingPatientMode = false
                        }
                    }
                },
                onClearLeaveError = { leavePatientError = null },
                onDone = { showPatientSettings = false },
            )
        }

        if (showSettings) {
            val demoModeFlow = remember(patientsViewModel) { patientsViewModel?.isDemoMode ?: flowOf(false) }
            val isDemoMode by demoModeFlow.collectAsStateWithLifecycle(initialValue = false)
            SettingsScreen(
                isDemoMode = isDemoMode,
                onExitDemoMode = { patientsViewModel?.exitDemoMode() },
                email = signedIn?.email,
                textSize = textSize,
                appearance = appearance,
                onAppearance = { value -> scope.launch { app.preferences.setAppearance(value) } },
                aiConsentAccepted = aiConsentAccepted,
                displayName = therapistDisplayName,
                displayNameLoadFailed = therapistDisplayNameLoadFailed,
                isDeleting = isDeletingAccount,
                deleteError = deleteAccountError,
                onTextSize = { value -> scope.launch { app.preferences.setTextSize(value) } },
                onSignOut = {
                    authViewModel.signOut()
                    showSettings = false
                },
                onLoadDisplayName = {
                    try {
                        val loaded = app.therapistProfiles.getCurrentProfile()?.displayName
                        therapistDisplayName = loaded
                        therapistDisplayNameLoadFailed = false
                        loaded
                    } catch (_: Exception) {
                        therapistDisplayNameLoadFailed = true
                        throw IllegalStateException("display_name_load_failed")
                    }
                },
                onSaveDisplayName = { name ->
                    therapistDisplayName = app.therapistProfiles.saveDisplayName(name).displayName
                    therapistDisplayNameLoadFailed = false
                },
                onDeleteAccount = {
                    isDeletingAccount = true
                    deleteAccountError = null
                    authViewModel.deleteAccount(
                        notConfigured,
                        emailNotConfirmed,
                        tooManyRequests,
                        onSuccess = {
                            isDeletingAccount = false
                            showSettings = false
                        },
                        onError = { message ->
                            isDeletingAccount = false
                            deleteAccountError = message
                        },
                    )
                },
                onClearDeleteError = { deleteAccountError = null },
                onGettingStartedGuide = {
                    // RootScreen presents welcome and closes Settings under it.
                    app.onboardingStore.requestDemoConsent()
                },
                onReviewIntroduction = { reviewIntroduction = true },
                onDone = { showSettings = false },
            )
        }

        if (showWelcome) {
            val vm = patientsViewModel
            WelcomeOnboardingScreen(
                onStartDemoTour = {
                    vm?.startDemoTour()
                    showWelcome = false
                },
                onSkip = { showWelcome = false },
            )
        }

        if (reviewIntroduction && isTherapist && termsAccepted.value == true && !invitationActive && !recovering) {
            AppIntroductionScreen(
                isReview = true,
                onTrySample = {
                    scope.launch {
                        patientsViewModel?.startDemoTour()?.join()
                        reviewIntroduction = false
                    }
                },
                onContinue = { reviewIntroduction = false },
            )
        }
    }
    if (versionState.optionalVisible && !invitationActive && !recovering && !consentPrompt &&
        !showSettings && !showPatientSettings && !showWelcome && !reviewIntroduction &&
        (pushRegistrationContext != null || session is AuthSession.SignedOut)) {
        AppUpdateNotice(app.appVersion, required = false)
    }
    }

}
