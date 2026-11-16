package com.cbtipul.app.ui.patients

import android.content.Intent
import androidx.compose.ui.platform.LocalContext
import androidx.compose.runtime.*
import androidx.compose.material3.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.cbtipul.app.CbTipulApp
import com.cbtipul.app.R
import com.cbtipul.app.auth.AuthSession
import com.cbtipul.app.data.EdgePayload
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

internal object EmailInvitationShare {
    const val text = "הוזמנת להשתמש ב־CBTipul. פתחו את האפליקציה והירשמו או התחברו עם כתובת המייל שמסרתם למטפל/ת.\n\nhttps://cbtipul.com/"
    fun intent() = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, text)
    }
}

/** Dialog-local only. Editing keeps the address and clears only its previous result. */
internal class EmailInvitationFormState {
    var email by mutableStateOf(""); private set
    var saving by mutableStateOf(false); private set
    var message by mutableStateOf<Int?>(null); private set
    var confirmed by mutableStateOf(false); private set
    var pendingStatus by mutableStateOf<String?>(null); private set
    val canCorrect get() = pendingStatus in setOf("pending", "waiting_for_sign_in", "waiting_for_confirmation")
    var loading by mutableStateOf(true); private set
    var loadFailed by mutableStateOf(false); private set
    val canShare get() = confirmed && canCorrect && !loading && !loadFailed && !saving
    suspend fun load(isCurrent: () -> Boolean, fetch: suspend () -> String) {
        loading = true; loadFailed = false
        try {
            val status = fetch()
            if (!isCurrent()) return
            when (status) {
                "pending" -> { pendingStatus = "pending"; confirmed = true; message = emailInvitationResult("pending") }
                "connected" -> { pendingStatus = "already_connected"; confirmed = true; message = emailInvitationResult("already_connected") }
                "no_invitation" -> { pendingStatus = null; confirmed = false; message = null }
                else -> error("invalid_invitation_status")
            }
        } catch (error: CancellationException) { throw error }
        catch (error: Exception) { if (isCurrent()) loadFailed = true }
        finally { loading = false }
    }
    fun correct() { if (!saving && canCorrect) { email = ""; message = null; confirmed = false } }
    fun edit(value: String) { if (!saving) { email = value; message = null; confirmed = false } }
    suspend fun submit(isCurrent: () -> Boolean, save: suspend (String) -> String) {
        if (saving || confirmed || !isCurrent()) return
        if (email.trim().isEmpty()) { message = R.string.email_invitation_invalid; return }
        saving = true; message = null
        try {
            val status = save(email.trim())
            if (!isCurrent()) return
            message = emailInvitationResult(status)
            confirmed = status in setOf("waiting_for_sign_in", "waiting_for_confirmation", "already_connected")
            if (confirmed) pendingStatus = status
        } catch (error: CancellationException) { throw error }
        catch (error: Exception) {
            if (isCurrent()) message = emailInvitationFailure(EdgePayload.httpStatus(error), EdgePayload.codeAndMessage(EdgePayload.responseBody(error)).first,
                generateSequence(error as Throwable?) { it.cause }.any { it is java.io.IOException || it is io.ktor.client.plugins.HttpRequestTimeoutException })
        } finally { saving = false }
    }
}

@Composable
internal fun EmailInvitationDialog(app: CbTipulApp, patientId: String, onDismiss: () -> Unit) {
    val owner = remember(patientId) { app.authRepository.currentUserId() }
    val session by app.authRepository.session.collectAsStateWithLifecycle(initialValue = AuthSession.Loading)
    LaunchedEffect(session) { if (owner != app.authRepository.currentUserId()) onDismiss() }
    val form = remember(patientId, owner) { EmailInvitationFormState() }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val shareLabel = stringResource(R.string.email_invitation_share)
    val keyboard = LocalSoftwareKeyboardController.current
    LaunchedEffect(patientId, owner) {
        form.load({ owner == app.authRepository.currentUserId() }) { app.invitations.emailInvitationStatus(patientId) }
    }
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
        AlertDialog(onDismissRequest = { if (!form.saving) onDismiss() },
            title = { Text(stringResource(R.string.invite_patient_action)) },
            text = { Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                if (form.loading) LinearProgressIndicator(Modifier.fillMaxWidth())
                else if (form.loadFailed) {
                    Text(stringResource(R.string.email_invitation_status_failed))
                    TextButton(onClick = { scope.launch {
                        form.load({ owner == app.authRepository.currentUserId() }) { app.invitations.emailInvitationStatus(patientId) }
                    } }) { Text(stringResource(R.string.retry)) }
                }
                if (!form.loading && !form.loadFailed) {
                if (!form.confirmed) form.pendingStatus?.let { Text(stringResource(emailInvitationResult(it))) }
                if (form.canShare) OutlinedButton(onClick = {
                    context.startActivity(Intent.createChooser(EmailInvitationShare.intent(), shareLabel))
                }) { Text(shareLabel) }
                if (form.confirmed && form.canCorrect) TextButton(onClick = form::correct) {
                    Text(stringResource(R.string.email_invitation_correct))
                }
                if (!form.confirmed) OutlinedTextField(value = form.email, onValueChange = form::edit,
                    label = { Text(stringResource(R.string.email_invitation_email)) },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                    singleLine = true, enabled = !form.saving, modifier = Modifier.fillMaxWidth())
                if (form.saving) {
                    LinearProgressIndicator(Modifier.fillMaxWidth())
                    Text(stringResource(R.string.email_invitation_saving), Modifier.semantics { liveRegion = LiveRegionMode.Polite })
                }
                form.message?.let { message ->
                    Surface(color = if (form.confirmed) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.errorContainer,
                        shape = MaterialTheme.shapes.medium, modifier = Modifier.fillMaxWidth().semantics { liveRegion = LiveRegionMode.Polite }) {
                        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(stringResource(message), style = MaterialTheme.typography.titleMedium)
                            if (form.confirmed && message != R.string.email_invitation_connected)
                                Text(stringResource(R.string.email_invitation_pending_explanation), style = MaterialTheme.typography.bodyMedium)
                        }
                    }
                }
                }
            } },
            confirmButton = {
                if (!form.loading && !form.loadFailed) {
                if (form.confirmed) Button(onClick = onDismiss) { Text(stringResource(R.string.email_invitation_close)) }
                else Button(enabled = !form.saving && form.email.isNotBlank(), onClick = {
                    keyboard?.hide()
                    scope.launch { form.submit({ owner == app.authRepository.currentUserId() }) { app.invitations.saveEmailInvitation(patientId, it) } }
                }) { Text(stringResource(if (form.saving) R.string.email_invitation_saving else R.string.invite_patient_action)) }
                }
            },
            dismissButton = { if (!form.confirmed) TextButton(enabled = !form.saving, onClick = onDismiss) { Text(stringResource(R.string.cancel)) } })
    }
}
internal fun emailInvitationResult(status: String): Int = when(status) {
    "pending" -> R.string.email_invitation_pending
    "waiting_for_sign_in" -> R.string.email_invitation_waiting_sign_in
    "waiting_for_confirmation" -> R.string.email_invitation_waiting_confirmation
    "already_connected" -> R.string.email_invitation_connected
    "email_unavailable" -> R.string.email_invitation_unavailable
    else -> R.string.email_invitation_failed
}
internal fun emailInvitationFailure(status: Int?, code: String, network: Boolean): Int = when {
    status == 409 && code == "patient_profile_already_connected" -> R.string.email_invitation_profile_connected
    code == "email_unavailable" -> R.string.email_invitation_unavailable
    status == 401 -> R.string.email_invitation_auth_failed
    status == 403 -> R.string.email_invitation_forbidden
    status == 400 || status == 422 -> R.string.email_invitation_invalid
    network -> R.string.email_invitation_network_failed
    else -> R.string.email_invitation_failed
}
