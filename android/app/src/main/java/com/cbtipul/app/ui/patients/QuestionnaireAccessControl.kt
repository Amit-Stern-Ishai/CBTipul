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
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.contentDescription
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
internal fun QuestionnaireAccessControl(patient: Patient, repository: PatientAssignmentRepository?, isDemo: Boolean, parentBusy: Boolean = false, compact: Boolean = false) {
    PatientToolAccessControl(patient, repository, isDemo, PatientAssignmentType.Questionnaire, parentBusy, compact = compact)
}

@Composable
internal fun PatientToolAccessControl(patient: Patient, repository: PatientAssignmentRepository?, isDemo: Boolean,
    type: PatientAssignmentType, parentBusy: Boolean = false, onBusyChanged: (Boolean) -> Unit = {}, compact: Boolean = false, reviewEnabled: Boolean? = null, listRow: Boolean = false) {
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
    val review = com.cbtipul.app.BuildConfig.DEBUG && reviewEnabled != null
    val (connection, refreshConnection) = if (review) ConnectionUi.Connected to {} else rememberPatientConnection(patient, repository, isDemo)
    val scope = rememberCoroutineScope()
    var assignmentId by remember(id, type) { mutableStateOf(if (review && reviewEnabled == true) "synthetic-assignment" else repository?.cachedOngoingAssignment(id.orEmpty(), type)?.assignmentId) }
    var loaded by remember(id, type) { mutableStateOf(review || repository?.cachedOngoingAssignment(id.orEmpty(), type) != null) }
    var busy by remember { mutableStateOf(false) }
    var failed by remember { mutableStateOf(false) }
    var revision by remember { mutableIntStateOf(0) }
    var confirmStop by remember { mutableStateOf(false) }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { revision++ }
    LaunchedEffect(id, type, connection, revision) {
        if (review || id == null || repository == null || isDemo || busy) return@LaunchedEffect
        val requestGeneration = generation
        try {
            val assignment = repository.activeOngoingAssignment(id, type)
            if (!busy && generation == requestGeneration) { assignmentId = assignment?.id; loaded = true; failed = false }
        } catch (e: CancellationException) { throw e } catch (_: Exception) { if (generation == requestGeneration) failed = true }
    }
    fun changeAccess() {
        if (review) { assignmentId = if (assignmentId == null) "synthetic-assignment" else null; return }
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
    if (listRow) {
        val rowTitle = stringResource(when (type) {
            PatientAssignmentType.Questionnaire -> R.string.activity_questionnaires
            PatientAssignmentType.DiaryOne -> R.string.activity_diary_one
            PatientAssignmentType.DiaryTwo -> R.string.activity_diary_two
            PatientAssignmentType.DiaryThree -> R.string.activity_diary_three
        })
        val active = assignmentId != null
        val stopLabel = stringResource(R.string.access_stop)
        val enableLabel = stringResource(R.string.activity_enable)
        val loadingLabel = stringResource(R.string.activity_loading)
        @Composable fun labels() {
            Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(rowTitle, style = MaterialTheme.typography.bodyLarge, fontWeight = androidx.compose.ui.text.font.FontWeight.Medium, color = Theme.colors.textBright)
                if (loaded) Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Icon(if (active) Icons.Outlined.CheckCircle else Icons.Outlined.RemoveCircleOutline, null,
                        modifier = Modifier.size(16.dp), tint = if (active) Theme.colors.success else Theme.colors.textBody)
                    Text(stringResource(if (type == PatientAssignmentType.Questionnaire) {
                        if (active) R.string.activity_active_plural else R.string.activity_inactive_plural
                    } else { if (active) R.string.activity_active else R.string.access_inactive }),
                        style = MaterialTheme.typography.bodySmall, color = if (active) Theme.colors.success else Theme.colors.textBody)
                }
            }
        }
        @Composable fun action() {
            when {
                isDemo -> Text(stringResource(R.string.questionnaire_demo_sending_unavailable), style = MaterialTheme.typography.bodySmall)
                busy || (!loaded && !failed) -> Box(Modifier.size(48.dp).semantics { contentDescription = loadingLabel }, contentAlignment = androidx.compose.ui.Alignment.Center) { CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp) }
                failed -> TextButton(onClick = { revision++; refreshConnection() }, enabled = !parentBusy) { Text(stringResource(R.string.retry)) }
                active -> TextButton(onClick = { confirmStop = true }, enabled = !parentBusy, modifier = Modifier.heightIn(min = 48.dp).semantics { contentDescription = "$stopLabel — $rowTitle" }) { Text(stringResource(R.string.access_stop), color = Theme.colors.error) }
                connection == ConnectionUi.Connected -> OutlinedButton(onClick = ::changeAccess, enabled = !parentBusy,
                    modifier = Modifier.heightIn(min = 48.dp).semantics { contentDescription = "$enableLabel — $rowTitle" }.entitlementCreateControl(), contentPadding = PaddingValues(horizontal = 14.dp),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = Theme.colors.gold)) { Text(stringResource(R.string.activity_enable)) }
                else -> Text(stringResource(R.string.patient_not_connected_body), style = MaterialTheme.typography.bodySmall, color = Theme.colors.textBody)
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            if (androidx.compose.ui.platform.LocalDensity.current.fontScale >= 1.4f) {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) { labels(); action() }
            } else Row(Modifier.fillMaxWidth().heightIn(min = 56.dp), verticalAlignment = androidx.compose.ui.Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Column(Modifier.weight(1f)) { labels() }
                action()
            }
            if (failed) Text(stringResource(R.string.access_error), style = MaterialTheme.typography.bodySmall, color = Theme.colors.error)
        }
    } else {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (!compact) {
            IconLabel(title, if (type == PatientAssignmentType.Questionnaire) Icons.Outlined.Assignment else Icons.Outlined.Book)
            Text(detail, style = MaterialTheme.typography.bodyMedium, color = Theme.colors.textBody)
        }
        if (loaded && (!compact || assignmentId != null)) IconLabel(stringResource(if (assignmentId == null) R.string.access_inactive else R.string.access_active),
            if (assignmentId == null) Icons.Outlined.RemoveCircleOutline else Icons.Outlined.CheckCircle,
            color = if (assignmentId == null) Theme.colors.textBody else Theme.colors.success)
        when {
            isDemo -> Text(stringResource(R.string.questionnaire_demo_sending_unavailable))
            !loaded -> if (!failed) CircularProgressIndicator()
            assignmentId != null -> TextButton(onClick = { confirmStop = true }, enabled = !busy && !parentBusy) {
                Text(stringResource(R.string.access_stop), color = Theme.colors.error)
            }
            connection == ConnectionUi.Connected -> Button(onClick = ::changeAccess, enabled = !busy && !parentBusy,
                modifier = Modifier.fillMaxWidth().entitlementCreateControl(),
                colors = ButtonDefaults.buttonColors(containerColor = Theme.colors.accentFill, contentColor = Theme.colors.textOnAccent)) {
                Text(stringResource(R.string.access_activate))
            }
            else -> Text(if (compact) "המטופל/ת עדיין לא מחובר/ת" else stringResource(R.string.patient_not_connected_body), color = Theme.colors.textBody)
        }
        if (busy) CircularProgressIndicator()
        if (failed) {
            Text(stringResource(R.string.access_error), color = Theme.colors.error)
            TextButton(onClick = { revision++; refreshConnection() }, enabled = !busy) { Text(stringResource(R.string.retry)) }
        }
    }
    }
    if (confirmStop) AlertDialog(onDismissRequest = { confirmStop = false },
        title = { Text(title + " — " + stringResource(R.string.access_stop)) },
        text = { Text(stringResource(R.string.access_stop_explanation)) },
        confirmButton = { TextButton(onClick = { confirmStop = false; changeAccess() }) { Text(stringResource(R.string.access_stop)) } },
        dismissButton = { TextButton(onClick = { confirmStop = false }) { Text(stringResource(R.string.cancel)) } })
}
