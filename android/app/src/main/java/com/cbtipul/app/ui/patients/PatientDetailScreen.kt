package com.cbtipul.app.ui.patients

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.AutoFixHigh
import androidx.compose.material.icons.outlined.DateRange
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.EditNote
import androidx.compose.material.icons.outlined.ShowChart
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.cbtipul.app.R
import com.cbtipul.app.model.CombinedMoodQuestionnaire
import com.cbtipul.app.model.Patient
import com.cbtipul.app.model.PatientStatus
import com.cbtipul.app.model.SessionType
import com.cbtipul.app.ui.theme.BusyOverlay
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.GroupedListDivider
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.dismissKeyboardOnTap
import com.cbtipul.app.ui.theme.themedScreen
import java.io.File

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PatientDetailScreen(
    patient: Patient?,
    unnamed: String,
    onBack: () -> Unit,
    onRename: (String, String) -> Unit,
    lastQuestionnaire: CombinedMoodQuestionnaire?,
    previousQuestionnaire: CombinedMoodQuestionnaire?,
    lastSessionType: SessionType?,
    onStatusChange: (PatientStatus) -> Unit,
    onSaveGoal: (String) -> Unit,
    isSavingGoal: Boolean,
    onOpenSessions: () -> Unit,
    onOpenQuestionnaires: () -> Unit,
    onOpenChat: () -> Unit,
    isPreparing: Boolean,
    savedPreparationDate: String?,
    isPreparationOutdated: Boolean,
    prepareError: String?,
    onPrepare: () -> Unit,
    onOpenLastPreparation: () -> Unit,
    onOpenFormulation: () -> Unit,
    notesError: String?,
    isSavingNotes: Boolean,
    isTranscribing: Boolean,
    isAnonymizingTranscription: Boolean,
    onSaveNotes: (String, Boolean) -> Unit,
    onTranscribe: (File, String, (String) -> Unit, () -> Unit) -> Unit,
    onDelete: () -> Unit,
) {
    val colors = Theme.colors
    if (patient == null) {
        BoxMissing(onBack)
        return
    }
    var showRename by remember { mutableStateOf(false) }
    var showGoal by remember { mutableStateOf(false) }
    var goalDraft by remember { mutableStateOf("") }
    var showDeleteConfirm by remember { mutableStateOf(false) }
    var showDeleteCode by remember { mutableStateOf(false) }
    var statusExpanded by remember { mutableStateOf(false) }
    val name = patient.displayName(unnamed)
    val treatmentGoal = patient.formulation?.treatmentGoal.orEmpty()
    val busy = isSavingNotes || isSavingGoal || isTranscribing || isAnonymizingTranscription
    val context = LocalContext.current
    var recorderTick by remember { mutableIntStateOf(0) }
    val recorder = remember {
        VoiceNoteRecorder(context.applicationContext).also { it.onChange = { recorderTick++ } }
    }
    DisposableEffect(recorder) {
        onDispose { recorder.release() }
    }
    val permissionDenied = stringResource(R.string.mic_permission_denied)
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) {
            recorder.startRecording()
        } else {
            recorder.errorMessage = permissionDenied
            recorderTick++
        }
    }
    @Suppress("UNUSED_VARIABLE")
    val observed = recorderTick
    var notes by remember(patient.id.queryValue, patient.notes) { mutableStateOf(patient.notes) }
    var showDiscard by remember { mutableStateOf(false) }
    val hasUnsavedChanges = notes != patient.notes || recorder.recordingFile != null

    fun requestBack() {
        if (busy) return
        if (hasUnsavedChanges) showDiscard = true else onBack()
    }

    BackHandler(enabled = !busy) { requestBack() }

    fun transcribePending() {
        val file = recorder.recordingFile ?: return
        onTranscribe(file, notes, { notes = it }, { recorder.discard() })
    }

    fun startMic() {
        val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        if (granted) recorder.startRecording() else permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
    }

    Box(Modifier.fillMaxSize()) {
    Scaffold(
        modifier = Modifier
            .themedScreen(PatientAvatarColor.background(patient.id))
            .dismissKeyboardOnTap(),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(name, color = colors.textBright) },
                navigationIcon = {
                    IconButton(onClick = { requestBack() }) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = stringResource(R.string.back), tint = colors.gold)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                InitialsAvatar(name = name, patientId = patient.id, size = 64.dp)
                val chipColor = PatientAvatarColor.background(patient.id)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        name,
                        color = colors.textBright,
                        fontWeight = FontWeight.Bold,
                        fontSize = 22.sp,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.weight(1f, fill = false),
                    )
                    Icon(
                        Icons.Outlined.Edit,
                        contentDescription = stringResource(R.string.edit_patient_name_action),
                        tint = chipColor,
                        modifier = Modifier
                            .padding(start = 6.dp)
                            .size(36.dp)
                            .clickable { showRename = true }
                            .padding(6.dp),
                    )
                }
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(chipColor.copy(alpha = 0.12f), RoundedCornerShape(12.dp))
                        .padding(start = 12.dp, end = 4.dp, top = 4.dp, bottom = 4.dp),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        if (treatmentGoal.isEmpty()) {
                            stringResource(R.string.no_treatment_goal_placeholder)
                        } else {
                            treatmentGoal
                        },
                        color = if (treatmentGoal.isEmpty()) colors.textBody else colors.textBright,
                        fontWeight = FontWeight.SemiBold,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.weight(1f, fill = false),
                    )
                    Icon(
                        Icons.Outlined.Edit,
                        contentDescription = stringResource(R.string.edit_treatment_goal_action),
                        tint = chipColor,
                        modifier = Modifier
                            .size(36.dp)
                            .clickable {
                                goalDraft = treatmentGoal
                                showGoal = true
                            }
                            .padding(6.dp),
                    )
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (lastQuestionnaire != null) {
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        GAD7ScoreCapsule(lastQuestionnaire, previousQuestionnaire)
                        PHQ9ScoreCapsule(lastQuestionnaire, previousQuestionnaire)
                    }
                }
                lastSessionType?.let {
                    Text(stringResource(it.labelRes()), color = colors.textBody, fontWeight = FontWeight.SemiBold)
                }
                Text(
                    if (patient.sessionsUpToTodayCount == 1) {
                        stringResource(R.string.sessions_count_one)
                    } else {
                        stringResource(R.string.sessions_count_other, patient.sessionsUpToTodayCount)
                    },
                    color = colors.textBody,
                    fontWeight = FontWeight.SemiBold,
                )
            }

            val accent = PatientAvatarColor.background(patient.id)
            GroupedListCard(accent = accent) {
            ExposedDropdownMenuBox(
                expanded = statusExpanded,
                onExpandedChange = { statusExpanded = it },
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
            ) {
                OutlinedTextField(
                    value = stringResource(
                        if (patient.status == PatientStatus.Active) {
                            R.string.patient_status_active
                        } else {
                            R.string.patient_status_inactive
                        },
                    ),
                    onValueChange = {},
                    readOnly = true,
                    label = { Text(stringResource(R.string.status_label)) },
                    modifier = Modifier.fillMaxWidth().menuAnchor(),
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = statusExpanded) },
                    enabled = !busy,
                )
                ExposedDropdownMenu(expanded = statusExpanded, onDismissRequest = { statusExpanded = false }) {
                    PatientStatus.entries.forEach { option ->
                        DropdownMenuItem(
                            text = {
                                Text(
                                    stringResource(
                                        if (option == PatientStatus.Active) {
                                            R.string.patient_status_active
                                        } else {
                                            R.string.patient_status_inactive
                                        },
                                    ),
                                )
                            },
                            onClick = {
                                onStatusChange(option)
                                statusExpanded = false
                            },
                        )
                    }
                }
            }
            GroupedListDivider(startInset = 56.dp)
            IconChipRow(
                icon = Icons.Outlined.DateRange,
                title = stringResource(R.string.sessions_title),
                onClick = onOpenSessions,
            )
            GroupedListDivider(startInset = 56.dp)
            IconChipRow(
                icon = Icons.Outlined.ShowChart,
                title = stringResource(R.string.view_questionnaires_action),
                onClick = onOpenQuestionnaires,
            )
            GroupedListDivider(startInset = 56.dp)
            IconChipRow(
                icon = Icons.Outlined.AutoAwesome,
                title = stringResource(R.string.ai_action),
                onClick = onOpenChat,
            )
            GroupedListDivider(startInset = 56.dp)
            IconChipRow(
                icon = Icons.Outlined.EditNote,
                title = stringResource(R.string.my_formulation_title),
                onClick = onOpenFormulation,
            )
            GroupedListDivider(startInset = 56.dp)
            IconChipRow(
                icon = Icons.Outlined.AutoFixHigh,
                title = stringResource(R.string.prepare_next_session_action),
                enabled = !isPreparing,
                trailing = {
                    if (isPreparing) CircularProgressIndicator(Modifier.size(18.dp), color = colors.gold, strokeWidth = 2.dp)
                },
                onClick = onPrepare,
            )
            if (savedPreparationDate != null) {
                GroupedListDivider(startInset = 56.dp)
                IconChipRow(
                    icon = Icons.Outlined.Description,
                    title = stringResource(R.string.last_preparation_action),
                    trailing = {
                        Column(horizontalAlignment = Alignment.End) {
                            Text(savedPreparationDate, color = colors.textBody, fontSize = 12.sp)
                            if (isPreparationOutdated) {
                                Text(stringResource(R.string.outdated_badge), color = colors.warning, fontSize = 11.sp)
                            }
                        }
                    },
                    onClick = onOpenLastPreparation,
                )
            }
            }

            Text(stringResource(R.string.notes_section), color = colors.textBright, fontWeight = FontWeight.SemiBold)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.Bottom,
            ) {
                OutlinedTextField(
                    value = notes,
                    onValueChange = { notes = it },
                    modifier = Modifier.weight(1f),
                    minLines = 3,
                    placeholder = { Text(stringResource(R.string.optional_notes_placeholder)) },
                    enabled = !busy,
                )
                if (recorder.isRecording) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(formatDuration(recorder.durationSeconds), color = colors.error, fontWeight = FontWeight.SemiBold)
                        IconButton(onClick = {
                            recorder.stopRecording()
                            transcribePending()
                        }) {
                            Icon(Icons.Filled.Stop, contentDescription = stringResource(R.string.recording_label), tint = colors.error)
                        }
                    }
                } else {
                    IconButton(onClick = { startMic() }, enabled = !busy) {
                        Icon(Icons.Filled.Mic, contentDescription = stringResource(R.string.record_voice_note_action), tint = colors.gold)
                    }
                }
            }

            val pending = recorder.recordingFile != null && !isTranscribing && !isAnonymizingTranscription
            if (pending) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    TextButton(onClick = { recorder.togglePlayback() }) {
                        Icon(
                            if (recorder.isPlaying) Icons.Filled.Stop else Icons.Filled.PlayArrow,
                            contentDescription = null,
                            tint = colors.gold,
                        )
                        Text(
                            stringResource(if (recorder.isPlaying) R.string.stop_playback_action else R.string.play_recording_action),
                            color = colors.gold,
                        )
                    }
                    TextButton(onClick = { transcribePending() }) {
                        Text(stringResource(R.string.transcribe_action), color = colors.gold, fontWeight = FontWeight.SemiBold)
                    }
                    IconButton(onClick = { recorder.discard() }) {
                        Icon(Icons.Filled.Delete, contentDescription = stringResource(R.string.discard_recording_action), tint = colors.error)
                    }
                }
            }

            if (isTranscribing || isAnonymizingTranscription) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    CircularProgressIndicator(Modifier.size(18.dp), color = colors.gold, strokeWidth = 2.dp)
                    Text(
                        stringResource(
                            if (isTranscribing) R.string.transcribing_label else R.string.anonymizing_status_label,
                        ),
                        color = colors.textBody,
                    )
                }
            }
            recorder.errorMessage?.let { Text(it, color = colors.error) }

            Button(
                onClick = { onSaveNotes(notes, false) },
                enabled = !busy,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = colors.gold, contentColor = colors.textOnAccent),
            ) {
                if (isSavingNotes) CircularProgressIndicator(Modifier.size(18.dp), color = colors.textOnAccent, strokeWidth = 2.dp)
                else Text(stringResource(R.string.save_changes_action))
            }
            notesError?.let { Text(it, color = colors.error) }
            prepareError?.let { Text(it, color = colors.error) }
            Spacer(Modifier.height(12.dp))
            Button(
                onClick = { showDeleteConfirm = true },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = colors.error, contentColor = colors.textBright),
            ) {
                Text(stringResource(R.string.delete_patient_action))
            }
        }
    }
        BusyOverlay(
            isBusy = isSavingNotes || isAnonymizingTranscription,
            label = if (isAnonymizingTranscription) stringResource(R.string.anonymizing_status_label) else null,
        )
    }

    if (showRename) {
        RenameDialog(
            initialFirst = patient.firstName,
            initialLast = patient.lastName,
            onDismiss = { showRename = false },
            onSave = { first, last ->
                onRename(first, last)
                showRename = false
            },
        )
    }
    if (showGoal) {
        AlertDialog(
            onDismissRequest = { showGoal = false },
            title = { Text(stringResource(R.string.edit_treatment_goal_action)) },
            text = {
                OutlinedTextField(
                    value = goalDraft,
                    onValueChange = { goalDraft = it },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 2,
                    placeholder = { Text(stringResource(R.string.no_treatment_goal_placeholder)) },
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    onSaveGoal(goalDraft.trim())
                    showGoal = false
                }) { Text(stringResource(R.string.save)) }
            },
            dismissButton = {
                TextButton(onClick = { showGoal = false }) { Text(stringResource(R.string.cancel)) }
            },
        )
    }
    if (showDeleteConfirm) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm = false },
            title = { Text(stringResource(R.string.delete_patient_confirm_title)) },
            text = { Text(stringResource(R.string.delete_patient_confirm_message)) },
            confirmButton = {
                TextButton(onClick = {
                    showDeleteConfirm = false
                    showDeleteCode = true
                }) { Text(stringResource(R.string.delete_patient_action), color = colors.error) }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirm = false }) { Text(stringResource(R.string.cancel)) }
            },
        )
    }
    DeleteCodeDialog(
        visible = showDeleteCode,
        onConfirm = {
            showDeleteCode = false
            onDelete()
        },
        onDismiss = { showDeleteCode = false },
    )
    DiscardChangesDialog(
        visible = showDiscard,
        canSave = true,
        onSave = {
            showDiscard = false
            onSaveNotes(notes, true)
        },
        onDiscard = {
            showDiscard = false
            recorder.discard()
            notes = patient.notes
            onBack()
        },
        onKeepEditing = { showDiscard = false },
    )
}

@Composable
private fun BoxMissing(onBack: () -> Unit) {
    val colors = Theme.colors
    Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.Center) {
        Text(stringResource(R.string.unnamed_patient), color = colors.textBright)
        TextButton(onClick = onBack) { Text(stringResource(R.string.back), color = colors.gold) }
    }
}

@Composable
private fun IconChipRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    enabled: Boolean = true,
    trailing: @Composable () -> Unit = {},
    onClick: () -> Unit,
) {
    val colors = Theme.colors
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .size(28.dp)
                .background(colors.goldGhost, RoundedCornerShape(7.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = colors.gold, modifier = Modifier.size(16.dp))
        }
        Text(title, color = colors.textBright, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
        trailing()
    }
}

@Composable
private fun RenameDialog(
    initialFirst: String,
    initialLast: String,
    onDismiss: () -> Unit,
    onSave: (String, String) -> Unit,
) {
    var first by remember { mutableStateOf(initialFirst) }
    var last by remember { mutableStateOf(initialLast) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.edit_patient_name_title)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(value = first, onValueChange = { first = it }, placeholder = { Text(stringResource(R.string.first_name_placeholder)) })
                OutlinedTextField(value = last, onValueChange = { last = it }, placeholder = { Text(stringResource(R.string.last_name_placeholder)) })
            }
        },
        confirmButton = {
            TextButton(
                onClick = { onSave(first.trim(), last.trim()) },
                enabled = first.trim().isNotEmpty() || last.trim().isNotEmpty(),
            ) { Text(stringResource(R.string.save)) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) }
        },
    )
}

private fun formatDuration(seconds: Double): String {
    val total = seconds.toInt().coerceAtLeast(0)
    return "%d:%02d".format(total / 60, total % 60)
}
