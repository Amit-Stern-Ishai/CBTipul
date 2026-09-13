package com.cbtipul.app.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
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
import com.cbtipul.app.ui.auth.AuthScreen
import com.cbtipul.app.ui.auth.NewPasswordSheet
import com.cbtipul.app.ui.legal.AiConsentDialog
import com.cbtipul.app.ui.legal.TermsScreen
import com.cbtipul.app.ui.patients.PatientListViewModel
import com.cbtipul.app.ui.patients.PatientsNavHost
import com.cbtipul.app.ui.settings.SettingsScreen
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
    val email = (session as? AuthSession.SignedIn)?.email
    val listSession by authViewModel.listSession.collectAsStateWithLifecycle()
    val recovering by authViewModel.isRecoveringPassword.collectAsStateWithLifecycle()
    val callbackError by authViewModel.callbackError.collectAsStateWithLifecycle()
    val ui by authViewModel.ui.collectAsStateWithLifecycle()
    val termsAccepted = remember(email) { mutableStateOf<Boolean?>(null) }
    LaunchedEffect(email) {
        val signedIn = email
        if (signedIn == null) {
            termsAccepted.value = null
            return@LaunchedEffect
        }
        app.preferences.hasAcceptedTerms(signedIn).collect { termsAccepted.value = it }
    }
    val consentPrompt by app.aiConsentStore.promptVisible.collectAsStateWithLifecycle()
    val appearance by app.preferences.appearance.collectAsStateWithLifecycle(AppAppearance.Dark)
    val textSize by app.preferences.textSize.collectAsStateWithLifecycle(AppTextSize.Standard)
    val consentAcceptedFlow = remember(email) {
        email?.let { app.preferences.hasAcceptedAiConsent(it) } ?: flowOf(false)
    }
    val aiConsentAccepted by consentAcceptedFlow.collectAsStateWithLifecycle(initialValue = false)
    val scope = rememberCoroutineScope()
    LaunchedEffect(email) {
        app.aiConsentStore.setActiveUser(email)
    }
    var showSettings by remember { mutableStateOf(false) }
    var isDeletingAccount by remember { mutableStateOf(false) }
    var deleteAccountError by remember { mutableStateOf<String?>(null) }

    val notConfigured = stringResource(R.string.supabase_not_configured_error)
    val emailNotConfirmed = stringResource(R.string.email_not_confirmed_error)
    val tooManyRequests = stringResource(R.string.too_many_requests_error)
    val passwordsDontMatch = stringResource(R.string.passwords_dont_match_error)
    val enterEmailFirst = stringResource(R.string.enter_email_first_message)
    val resetSent = stringResource(R.string.password_reset_sent_message)
    val resentMessage = stringResource(R.string.verification_resent_message)

    Box(modifier = Modifier.fillMaxSize()) {
        when {
            session is AuthSession.Loading || (email != null && termsAccepted.value == null) -> {
                Box(
                    modifier = Modifier.fillMaxSize().themedScreen(Theme.colors.gold),
                    contentAlignment = Alignment.Center,
                ) {
                    CircularProgressIndicator(color = Theme.colors.gold)
                }
            }
            email != null && termsAccepted.value == true -> {
                val patientsViewModel: PatientListViewModel = viewModel(
                    key = "$email-$listSession",
                    factory = PatientListViewModel.Factory(app.patientRepository),
                )
                PatientsNavHost(
                    viewModel = patientsViewModel,
                    onOpenSettings = { showSettings = true },
                )
            }
            email != null && termsAccepted.value == false -> {
                TermsScreen(
                    onAgree = {
                        val signedIn = email ?: return@TermsScreen
                        scope.launch { authViewModel.acceptTerms(signedIn) }
                    },
                )
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

        if (recovering) {
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

        if (consentPrompt) {
            AiConsentDialog(
                onAccept = { scope.launch { app.aiConsentStore.accept() } },
                onDecline = { scope.launch { app.aiConsentStore.decline() } },
            )
        }

        if (showSettings) {
            SettingsScreen(
                email = email,
                appearance = appearance,
                textSize = textSize,
                aiConsentAccepted = aiConsentAccepted,
                isDeleting = isDeletingAccount,
                deleteError = deleteAccountError,
                onAppearance = { value -> scope.launch { app.preferences.setAppearance(value) } },
                onTextSize = { value -> scope.launch { app.preferences.setTextSize(value) } },
                onSignOut = {
                    authViewModel.signOut()
                    showSettings = false
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
                onDone = { showSettings = false },
            )
        }
    }
}
