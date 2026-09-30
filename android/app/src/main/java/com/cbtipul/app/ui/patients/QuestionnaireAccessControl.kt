package com.cbtipul.app.ui.patients

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Assignment
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import com.cbtipul.app.R
import com.cbtipul.app.data.PatientAssignmentRepository
import com.cbtipul.app.data.PatientAssignmentType
import com.cbtipul.app.model.Patient
import com.cbtipul.app.ui.theme.IconLabel
import com.cbtipul.app.ui.theme.Theme
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

@Composable
internal fun QuestionnaireAccessControl(patient: Patient, repository: PatientAssignmentRepository?, isDemo: Boolean, parentBusy: Boolean = false) {
    val id = PatientAssignmentRepository.uuidOrNull(patient.id)
    val (connection, refreshConnection) = rememberPatientConnection(patient, repository, isDemo)
    val scope = rememberCoroutineScope()
    var assignmentId by remember(id) { mutableStateOf(repository?.cachedOngoingAssignment(id.orEmpty(), PatientAssignmentType.Questionnaire)?.assignmentId) }
    var loaded by remember(id) { mutableStateOf(repository?.cachedOngoingAssignment(id.orEmpty(), PatientAssignmentType.Questionnaire) != null) }
    var busy by remember { mutableStateOf(false) }
    var failed by remember { mutableStateOf(false) }
    var revision by remember { mutableIntStateOf(0) }
    var confirmStop by remember { mutableStateOf(false) }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { revision++ }
    LaunchedEffect(id, connection, revision) {
        if (id == null || repository == null || isDemo || busy) return@LaunchedEffect
        try {
            val assignment = repository.activeOngoingAssignment(id, PatientAssignmentType.Questionnaire)
            if (!busy) { assignmentId = assignment?.id; loaded = true; failed = false }
        } catch (e: CancellationException) { throw e } catch (_: Exception) { failed = true }
    }
    fun changeAccess() {
        if (busy || id == null || repository == null) return
        busy = true
        failed = false
        scope.launch {
            try {
                val current = assignmentId
                if (current != null) { repository.cancelOngoingAssignment(current); assignmentId = null }
                else assignmentId = repository.activateOngoingAssignment(id, PatientAssignmentType.Questionnaire).id
                loaded = true
            } catch (e: CancellationException) { throw e } catch (_: Exception) { failed = true; refreshConnection() }
            finally { busy = false }
        }
    }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        IconLabel(stringResource(if (assignmentId == null) R.string.send_questionnaire_to_patient else R.string.questionnaires_active),
            if (assignmentId == null) Icons.Outlined.Assignment else Icons.Outlined.CheckCircle)
        Text(stringResource(R.string.patient_questionnaire_request_description), color = Theme.colors.textBody)
        when {
            isDemo -> Text(stringResource(R.string.questionnaire_demo_sending_unavailable))
            !loaded -> if (!failed) CircularProgressIndicator()
            assignmentId != null -> TextButton(onClick = { confirmStop = true }, enabled = !busy && !parentBusy) {
                Text(stringResource(R.string.questionnaires_stop), color = Theme.colors.error)
            }
            connection == ConnectionUi.Connected -> Button(onClick = ::changeAccess, enabled = !busy && !parentBusy) {
                Text(stringResource(R.string.send_questionnaire_to_patient))
            }
            else -> Text(stringResource(R.string.patient_not_connected_body), color = Theme.colors.textBody)
        }
        if (busy) CircularProgressIndicator()
        if (failed) {
            Text(stringResource(R.string.questionnaire_assignment_send_error), color = Theme.colors.error)
            TextButton(onClick = { revision++; refreshConnection() }, enabled = !busy) { Text(stringResource(R.string.retry)) }
        }
    }
    if (confirmStop) AlertDialog(onDismissRequest = { confirmStop = false },
        title = { Text(stringResource(R.string.questionnaires_stop)) },
        text = { Text(stringResource(R.string.questionnaires_stop_explanation)) },
        confirmButton = { TextButton(onClick = { confirmStop = false; changeAccess() }) { Text(stringResource(R.string.questionnaires_stop)) } },
        dismissButton = { TextButton(onClick = { confirmStop = false }) { Text(stringResource(R.string.cancel)) } })
}
