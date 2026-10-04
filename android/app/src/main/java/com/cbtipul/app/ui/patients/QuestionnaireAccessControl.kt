package com.cbtipul.app.ui.patients

import com.cbtipul.app.ui.entitlementCreateControl
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Book
import androidx.compose.material.icons.outlined.RemoveCircleOutline
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
    PatientToolAccessControl(patient, repository, isDemo, PatientAssignmentType.Questionnaire, parentBusy)
}

@Composable
internal fun PatientToolAccessControl(patient: Patient, repository: PatientAssignmentRepository?, isDemo: Boolean,
    type: PatientAssignmentType, parentBusy: Boolean = false, onBusyChanged: (Boolean) -> Unit = {}) {
    val title = stringResource(when (type) {
        PatientAssignmentType.Questionnaire -> R.string.access_questionnaires_title
        PatientAssignmentType.DiaryOne -> R.string.diary_one_title
        PatientAssignmentType.DiaryTwo -> R.string.diary_two_title
        PatientAssignmentType.DiaryThree -> R.string.diary_three_title
    })
    val detail = stringResource(when (type) {
        PatientAssignmentType.Questionnaire -> R.string.access_questionnaires_description
        PatientAssignmentType.DiaryOne -> R.string.patient_diary_one_description
        PatientAssignmentType.DiaryTwo -> R.string.patient_diary_two_description
        PatientAssignmentType.DiaryThree -> R.string.patient_diary_three_description
    })
    var generation by remember { mutableIntStateOf(0) }
    val id = PatientAssignmentRepository.uuidOrNull(patient.id)
    val (connection, refreshConnection) = rememberPatientConnection(patient, repository, isDemo)
    val scope = rememberCoroutineScope()
    var assignmentId by remember(id, type) { mutableStateOf(repository?.cachedOngoingAssignment(id.orEmpty(), type)?.assignmentId) }
    var loaded by remember(id, type) { mutableStateOf(repository?.cachedOngoingAssignment(id.orEmpty(), type) != null) }
    var busy by remember { mutableStateOf(false) }
    var failed by remember { mutableStateOf(false) }
    var revision by remember { mutableIntStateOf(0) }
    var confirmStop by remember { mutableStateOf(false) }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { revision++ }
    LaunchedEffect(id, type, connection, revision) {
        if (id == null || repository == null || isDemo || busy) return@LaunchedEffect
        val requestGeneration = generation
        try {
            val assignment = repository.activeOngoingAssignment(id, type)
            if (!busy && generation == requestGeneration) { assignmentId = assignment?.id; loaded = true; failed = false }
        } catch (e: CancellationException) { throw e } catch (_: Exception) { if (generation == requestGeneration) failed = true }
    }
    fun changeAccess() {
        if (busy || parentBusy || isDemo || id == null || repository == null) return
        generation++
        busy = true
        onBusyChanged(true)
        failed = false
        scope.launch {
            try {
                val current = assignmentId
                if (current != null) { repository.cancelOngoingAssignment(current); assignmentId = null }
                else assignmentId = repository.activateOngoingAssignment(id, type).id
                loaded = true
            } catch (e: CancellationException) { throw e } catch (_: Exception) { failed = true; refreshConnection() }
            finally { busy = false; onBusyChanged(false) }
        }
    }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        IconLabel(title, if (type == PatientAssignmentType.Questionnaire) Icons.Outlined.Assignment else Icons.Outlined.Book)
        Text(detail, style = MaterialTheme.typography.bodyMedium, color = Theme.colors.textBody)
        if (loaded) IconLabel(stringResource(if (assignmentId == null) R.string.access_inactive else R.string.access_active),
            if (assignmentId == null) Icons.Outlined.RemoveCircleOutline else Icons.Outlined.CheckCircle,
            color = if (assignmentId == null) Theme.colors.textBody else Theme.colors.success)
        when {
            isDemo -> Text(stringResource(R.string.questionnaire_demo_sending_unavailable))
            !loaded -> if (!failed) CircularProgressIndicator()
            assignmentId != null -> TextButton(onClick = { confirmStop = true }, enabled = !busy && !parentBusy) {
                Text(stringResource(R.string.access_stop), color = Theme.colors.error)
            }
            connection == ConnectionUi.Connected -> Button(onClick = ::changeAccess, enabled = !busy && !parentBusy, modifier = Modifier.entitlementCreateControl()) {
                Text(stringResource(R.string.access_activate))
            }
            else -> Text(stringResource(R.string.patient_not_connected_body), color = Theme.colors.textBody)
        }
        if (busy) CircularProgressIndicator()
        if (failed) {
            Text(stringResource(R.string.access_error), color = Theme.colors.error)
            TextButton(onClick = { revision++; refreshConnection() }, enabled = !busy) { Text(stringResource(R.string.retry)) }
        }
    }
    if (confirmStop) AlertDialog(onDismissRequest = { confirmStop = false },
        title = { Text(title + " — " + stringResource(R.string.access_stop)) },
        text = { Text(stringResource(R.string.access_stop_explanation)) },
        confirmButton = { TextButton(onClick = { confirmStop = false; changeAccess() }) { Text(stringResource(R.string.access_stop)) } },
        dismissButton = { TextButton(onClick = { confirmStop = false }) { Text(stringResource(R.string.cancel)) } })
}
