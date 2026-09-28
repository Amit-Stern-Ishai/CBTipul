package com.cbtipul.app.ui.patients

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import com.cbtipul.app.R
import com.cbtipul.app.data.*
import com.cbtipul.app.model.Patient
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.Theme
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

internal enum class ConnectionUi { Checking, Connected, NotConnected, Unavailable, Failed }

@Composable
internal fun rememberPatientConnection(patient: Patient?, repository: PatientAssignmentRepository?, isDemo: Boolean): Pair<ConnectionUi, () -> Unit> {
    var state by remember(patient?.id, isDemo) { mutableStateOf(ConnectionUi.Checking) }
    var revision by remember { mutableIntStateOf(0) }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { revision++ }
    LaunchedEffect(patient?.id, isDemo, revision) {
        val id = patient?.id?.let(PatientAssignmentRepository::uuidOrNull)
        state = if (patient == null || isDemo || DemoData.isDemoId(patient.id) || id == null || repository == null) ConnectionUi.Unavailable else {
            state = ConnectionUi.Checking
            try { if (repository.isPatientConnected(id)) ConnectionUi.Connected else ConnectionUi.NotConnected }
            catch (e: CancellationException) { throw e }
            catch (_: Exception) { ConnectionUi.Failed }
        }
    }
    return state to { revision++ }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun PatientConnectionActions(patient: Patient, name: String, repository: PatientAssignmentRepository?, isDemo: Boolean,
    busy: Boolean, onInvite: () -> Unit, onMessage: () -> Unit) {
    val colors = Theme.colors
    val (connection, refresh) = rememberPatientConnection(patient, repository, isDemo)
    var sheet by remember { mutableStateOf<String?>(null) }
    var sending by remember { mutableStateOf(false) }
    var feedback by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val sent = stringResource(R.string.questionnaire_sent_to_patient)
    val diarySent = stringResource(R.string.patient_diary_one_activated)
    val failed = stringResource(R.string.questionnaire_assignment_send_error)
    GroupedListCard(accent = PatientAvatarColor.background(patient.id)) {
        Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            when (connection) {
                ConnectionUi.Checking -> Text(stringResource(R.string.patient_connection_checking), color = colors.textBody)
                ConnectionUi.Connected -> {
                    Text(stringResource(R.string.patient_connected_status), color = colors.textBody)
                    TextButton(onClick = { sheet = "send" }, enabled = !busy && !sending) {
                        Text(stringResource(R.string.send_to_patient_action), fontWeight = FontWeight.SemiBold)
                    }
                }
                ConnectionUi.NotConnected, ConnectionUi.Unavailable -> {
                    TextButton(onClick = { sheet = "invite" }, enabled = !busy) {
                        Text(stringResource(R.string.patient_invite_to_app_action), fontWeight = FontWeight.SemiBold)
                    }
                    Text(stringResource(if (connection == ConnectionUi.Unavailable) R.string.patient_invitation_demo_status else R.string.patient_not_connected_status), color = colors.textBody)
                }
                ConnectionUi.Failed -> {
                    Text(stringResource(R.string.patient_connection_check_error), color = colors.textBody)
                    TextButton(onClick = refresh) { Text(stringResource(R.string.retry)) }
                }
            }
            if (sending) CircularProgressIndicator()
        }
    }
    if (sheet != null) ModalBottomSheet(onDismissRequest = { if (!sending) sheet = null },
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text(name, fontWeight = FontWeight.Bold)
            if (sheet == "invite") {
                Text(stringResource(R.string.patient_connect_description))
                if (connection == ConnectionUi.NotConnected) {
                    Text(stringResource(R.string.patient_share_invitation_explanation))
                    Button(onClick = { sheet = null; onInvite() }, modifier = Modifier.fillMaxWidth()) { Text(stringResource(R.string.patient_share_invitation_action)) }
                } else Text(stringResource(R.string.patient_invitation_unavailable_explanation))
                Text(stringResource(R.string.patient_connection_optional_explanation))
            } else if (connection == ConnectionUi.Connected) {
                Text(stringResource(R.string.patient_choose_send_action), fontWeight = FontWeight.Bold)
                SendChoice(R.string.send_patient_message_action, R.string.patient_send_message_description, !sending) { sheet = null; onMessage() }
                SendChoice(R.string.send_questionnaire_to_patient, R.string.patient_questionnaire_request_description, !sending) {
                    sending = true
                    scope.launch {
                        try { repository!!.sendQuestionnaireAssignment(PatientAssignmentRepository.uuidOrNull(patient.id)!!); feedback = sent }
                        catch (e: CancellationException) { throw e }
                        catch (_: Exception) { feedback = failed; refresh() }
                        finally { sending = false; sheet = null }
                    }
                }
                SendChoice(R.string.patient_enable_diary_one_action, R.string.patient_send_diary_one_description, !sending) {
                    sending = true
                    scope.launch {
                        try { repository!!.activateOngoingAssignment(PatientAssignmentRepository.uuidOrNull(patient.id)!!, PatientAssignmentType.DiaryOne); feedback = diarySent }
                        catch (e: CancellationException) { throw e }
                        catch (_: Exception) { feedback = failed; refresh() }
                        finally { sending = false; sheet = null }
                    }
                }
                Text(stringResource(R.string.diary_two_title) + " · " + stringResource(R.string.coming_soon), color = colors.textFaint)
                Text(stringResource(R.string.diary_three_title) + " · " + stringResource(R.string.coming_soon), color = colors.textFaint)
            } else Text(stringResource(R.string.patient_not_connected_body))
            TextButton(onClick = { sheet = null }, enabled = !sending) { Text(stringResource(R.string.cancel)) }
        }
    }
    if (feedback != null) AlertDialog(onDismissRequest = { feedback = null }, text = { Text(feedback.orEmpty()) },
        confirmButton = { TextButton(onClick = { feedback = null }) { Text(stringResource(R.string.done)) } })
}

@Composable
private fun SendChoice(title: Int, description: Int, enabled: Boolean, onClick: () -> Unit) {
    OutlinedCard(onClick = onClick, enabled = enabled, modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(stringResource(title), fontWeight = FontWeight.SemiBold)
            Text(stringResource(description), style = MaterialTheme.typography.bodyMedium)
        }
    }
}
