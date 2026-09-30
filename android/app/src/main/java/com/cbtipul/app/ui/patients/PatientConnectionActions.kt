package com.cbtipul.app.ui.patients

import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Book
import androidx.compose.material.icons.outlined.Assignment
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material.icons.filled.CheckCircle
import com.cbtipul.app.ui.theme.IconLabel
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.background
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.material.icons.automirrored.outlined.Send
import androidx.compose.material.icons.outlined.MenuBook
import androidx.compose.material.icons.outlined.MailOutline
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.PersonAdd
import androidx.compose.material.icons.Icons
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
    val id = patient?.id?.let(PatientAssignmentRepository::uuidOrNull)
    val available = patient != null && !isDemo && !DemoData.isDemoId(patient.id) && id != null && repository != null
    fun cachedState(): ConnectionUi? = if (available) repository?.cachedPatientConnection(id!!)?.let {
        if (it) ConnectionUi.Connected else ConnectionUi.NotConnected
    } else ConnectionUi.Unavailable
    var state by remember(id, isDemo, repository) { mutableStateOf(cachedState() ?: ConnectionUi.Checking) }
    var revision by remember { mutableIntStateOf(0) }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { revision++ }
    LaunchedEffect(id, isDemo, revision) {
        if (!available) {
            state = ConnectionUi.Unavailable
        } else {
            cachedState()?.let { state = it }
            try {
                state = if (repository!!.isPatientConnected(id!!)) ConnectionUi.Connected else ConnectionUi.NotConnected
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                // A failed refresh must not replace the last known status.
                state = cachedState() ?: ConnectionUi.Failed
            }
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
    val diarySent = stringResource(R.string.patient_diary_one_activated)
    val diaryThreeSent = stringResource(R.string.patient_diary_three_activated)
    val diaryTwoSent = stringResource(R.string.patient_diary_two_activated)
    val failed = stringResource(R.string.questionnaire_assignment_send_error)
    GroupedListCard(accent = PatientAvatarColor.background(patient.id)) {
        Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            when (connection) {
                ConnectionUi.Checking -> Text(stringResource(R.string.patient_connection_checking), color = colors.textBody)
                ConnectionUi.Connected -> {
                    IconLabel(stringResource(R.string.patient_connected_status), Icons.Filled.CheckCircle, color = colors.success)
                    OutlinedButton(onClick = { sheet = "invite" }, enabled = !busy && !sending) {
                        IconLabel(stringResource(R.string.patient_reinvite_action), Icons.Outlined.PersonAdd)
                    }
                    TextButton(onClick = { sheet = "send" }, enabled = !busy && !sending) {
                        Icon(Icons.AutoMirrored.Outlined.Send, contentDescription = null, modifier = Modifier.size(20.dp))
                        Spacer(Modifier.width(8.dp))
                        Text(stringResource(R.string.send_to_patient_action), fontWeight = FontWeight.SemiBold)
                    }
                }
                ConnectionUi.NotConnected, ConnectionUi.Unavailable -> {
                    TextButton(onClick = { sheet = "invite" }, enabled = !busy) {
                        Icon(Icons.Outlined.PersonAdd, contentDescription = null, modifier = Modifier.size(20.dp))
                        Spacer(Modifier.width(8.dp))
                        Text(stringResource(R.string.patient_invite_to_app_action), fontWeight = FontWeight.SemiBold)
                    }
                    IconLabel(stringResource(if (connection == ConnectionUi.Unavailable) R.string.patient_invitation_demo_status else R.string.patient_not_connected_status), Icons.Outlined.Lock, color = colors.textBody)
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
                val connected = connection == ConnectionUi.Connected
                Text(stringResource(if (connected) R.string.patient_reinvite_action else R.string.patient_connect_description))
                if (connection == ConnectionUi.NotConnected || connected) {
                    Text(stringResource(if (connected) R.string.patient_reinvite_explanation else R.string.patient_share_invitation_explanation))
                    Button(onClick = { sheet = null; onInvite() }, enabled = !busy && !sending, modifier = Modifier.fillMaxWidth()) { IconLabel(stringResource(R.string.patient_share_invitation_action), Icons.Outlined.Share) }
                } else Text(stringResource(R.string.patient_invitation_unavailable_explanation))
                if (!connected) Text(stringResource(R.string.patient_connection_optional_explanation))
            } else if (connection == ConnectionUi.Connected) {
                Text(stringResource(R.string.patient_choose_send_action), fontWeight = FontWeight.Bold)
                SendChoice(Icons.Outlined.MailOutline, R.string.send_patient_message_action, R.string.patient_send_message_description, !sending) { sheet = null; onMessage() }
                OutlinedCard(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp)) { QuestionnaireAccessControl(patient, repository, isDemo, busy || sending) }
                }
                SendChoice(Icons.Outlined.Book, R.string.patient_enable_diary_one_action, R.string.patient_send_diary_one_description, !sending) {
                    sending = true
                    scope.launch {
                        try { repository!!.activateOngoingAssignment(PatientAssignmentRepository.uuidOrNull(patient.id)!!, PatientAssignmentType.DiaryOne); feedback = diarySent }
                        catch (e: CancellationException) { throw e }
                        catch (_: Exception) { feedback = failed; refresh() }
                        finally { sending = false; sheet = null }
                    }
                }
                SendChoice(Icons.Outlined.Book, R.string.patient_enable_diary_two_action, R.string.patient_send_diary_two_description, !sending) {
                    sending = true
                    scope.launch {
                        try { repository!!.activateOngoingAssignment(PatientAssignmentRepository.uuidOrNull(patient.id)!!, PatientAssignmentType.DiaryTwo); feedback = diaryTwoSent }
                        catch (e: CancellationException) { throw e }
                        catch (_: Exception) { feedback = failed; refresh() }
                        finally { sending = false; sheet = null }
                    }
                }

                if (PatientAssignmentType.diaryThreeSendingEnabled) {
                    SendChoice(Icons.Outlined.Book, R.string.patient_enable_diary_three_action, R.string.patient_send_diary_three_description, !sending) {
                        sending = true
                        scope.launch {
                            try { repository!!.activateOngoingAssignment(PatientAssignmentRepository.uuidOrNull(patient.id)!!, PatientAssignmentType.DiaryThree); feedback = diaryThreeSent }
                            catch (e: CancellationException) { throw e }
                            catch (_: Exception) { feedback = failed; refresh() }
                            finally { sending = false; sheet = null }
                        }
                    }
                }
            } else Text(stringResource(R.string.patient_not_connected_body))
            TextButton(onClick = { sheet = null }, enabled = !sending) { Text(stringResource(R.string.cancel)) }
        }
    }
    if (feedback != null) AlertDialog(onDismissRequest = { feedback = null }, text = { Text(feedback.orEmpty()) },
        confirmButton = { TextButton(onClick = { feedback = null }) { Text(stringResource(R.string.done)) } })
}

@Composable
private fun SendChoice(icon: ImageVector, title: Int, description: Int, enabled: Boolean, onClick: () -> Unit) {
    OutlinedCard(onClick = onClick, enabled = enabled, modifier = Modifier.fillMaxWidth()) {
        Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.Top) {
            Box(Modifier.size(40.dp).background(Theme.colors.goldGhost, RoundedCornerShape(11.dp)), contentAlignment = Alignment.Center) {
                Icon(icon, contentDescription = null, tint = Theme.colors.gold, modifier = Modifier.size(22.dp))
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(stringResource(title), fontWeight = FontWeight.SemiBold)
                Text(stringResource(description), style = MaterialTheme.typography.bodyMedium, color = Theme.colors.textBody)
            }
        }
    }
}
