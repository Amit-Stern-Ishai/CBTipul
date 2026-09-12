package com.cbtipul.app.ui.patients

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
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
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.cbtipul.app.R
import com.cbtipul.app.model.CompletedQuestionnaire
import com.cbtipul.app.model.Session
import com.cbtipul.app.model.SessionType
import com.cbtipul.app.ui.theme.Theme
import java.io.File
import java.text.DateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SessionEditorScreen(
    session: Session?,
    isNew: Boolean,
    isSaving: Boolean,
    isTranscribing: Boolean,
    isAnonymizingTranscription: Boolean,
    isAnalyzing: Boolean,
    errorMessage: String?,
    onBack: () -> Unit,
    onSave: (Session) -> Unit,
    onDelete: (Session) -> Unit,
    onTranscribe: (File, String, Session, (String) -> Unit, () -> Unit) -> Unit,
    onAnalyze: (Session, (String) -> Unit, (com.cbtipul.app.model.CBTSessionAnalysis) -> Unit) -> Unit,
    onOpenAnalysis: () -> Unit,
    questionnaire: CompletedQuestionnaire?,
    previousQuestionnaire: CompletedQuestionnaire?,
    onOpenQuestionnaire: () -> Unit,
) {
    val colors = Theme.colors
    if (session == null && !isNew) {
        Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.Center) {
            Text(stringResource(R.string.session_not_saved_error), color = colors.textBright)
            TextButton(onClick = onBack) { Text(stringResource(R.string.back), color = colors.gold) }
        }
        return
    }
    val initial = session ?: Session()
    var date by remember(initial.id) { mutableStateOf(initial.date) }
    var notes by remember(initial.id) { mutableStateOf(initial.notes) }
    var type by remember(initial.id) { mutableStateOf(initial.type) }
    var structuredNotes by remember(initial.id) { mutableStateOf(initial.structuredNotes) }
    var showDatePicker by remember { mutableStateOf(false) }
    var typeExpanded by remember { mutableStateOf(false) }
    var showDelete by remember { mutableStateOf(false) }
    val dateFormat = remember { DateFormat.getDateInstance(DateFormat.MEDIUM, Locale("iw")) }
    val hasText = notes.trim().isNotEmpty()
    val busy = isSaving || isTranscribing || isAnonymizingTranscription || isAnalyzing
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

    fun currentSession() = initial.copy(date = date, notes = notes, type = type, structuredNotes = structuredNotes)

    fun transcribePending() {
        val file = recorder.recordingFile ?: return
        onTranscribe(file, notes, currentSession(), { notes = it }, { recorder.discard() })
    }

    fun startMic() {
        val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        if (granted) recorder.startRecording() else permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
    }

    Scaffold(
        containerColor = colors.base,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        if (isNew) stringResource(R.string.new_session_title)
                        else stringResource(R.string.session_editor_title, ""),
                        color = colors.textBright,
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack, enabled = !busy) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = stringResource(R.string.back), tint = colors.gold)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = colors.base),
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
            Text(stringResource(R.string.session_date_title), color = colors.textBright, fontWeight = FontWeight.SemiBold)
            TextButton(onClick = { showDatePicker = true }, enabled = !busy) {
                Text(dateFormat.format(date), color = colors.gold)
            }

            Text(stringResource(R.string.session_type_label), color = colors.textBright, fontWeight = FontWeight.SemiBold)
            ExposedDropdownMenuBox(expanded = typeExpanded, onExpandedChange = { if (!busy) typeExpanded = it }) {
                OutlinedTextField(
                    value = type?.let { stringResource(it.labelRes()) } ?: stringResource(R.string.session_type_none),
                    onValueChange = {},
                    readOnly = true,
                    modifier = Modifier.fillMaxWidth().menuAnchor(),
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = typeExpanded) },
                )
                ExposedDropdownMenu(expanded = typeExpanded, onDismissRequest = { typeExpanded = false }) {
                    DropdownMenuItem(
                        text = { Text(stringResource(R.string.session_type_none)) },
                        onClick = {
                            type = null
                            typeExpanded = false
                        },
                    )
                    SessionType.entries.forEach { option ->
                        DropdownMenuItem(
                            text = { Text(stringResource(option.labelRes())) },
                            onClick = {
                                type = option
                                typeExpanded = false
                            },
                        )
                    }
                }
            }

            Text(stringResource(R.string.notes_section_title), color = colors.textBright, fontWeight = FontWeight.SemiBold)
            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = notes,
                    onValueChange = { notes = it },
                    modifier = Modifier.weight(1f).height(180.dp),
                    placeholder = { Text(stringResource(R.string.notes_field_placeholder), color = colors.textFaint) },
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

            if (isTranscribing || isAnonymizingTranscription || isAnalyzing) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    CircularProgressIndicator(Modifier.size(18.dp), color = colors.gold, strokeWidth = 2.dp)
                    Text(
                        stringResource(
                            when {
                                isTranscribing -> R.string.transcribing_label
                                isAnonymizingTranscription -> R.string.anonymizing_status_label
                                else -> R.string.ai_thinking_label
                            },
                        ),
                        color = colors.textBody,
                    )
                }
            }

            recorder.errorMessage?.let { Text(it, color = colors.error) }

            Button(
                onClick = {
                    onAnalyze(currentSession(), { notes = it }, { structuredNotes = it })
                },
                enabled = !busy && hasText,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = colors.gold, contentColor = colors.textOnAccent),
            ) {
                Text(stringResource(R.string.ai_summary_action))
            }

            structuredNotes?.let { analysis ->
                Text(stringResource(R.string.structured_summary_section), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                Text(analysis.sessionSummary, color = colors.textBody)
                TextButton(onClick = onOpenAnalysis, enabled = !busy) {
                    Text(stringResource(R.string.show_structured_summary_action), color = colors.gold)
                }
            }

            if (initial.databaseId != null) {
                Text(stringResource(R.string.questionnaire_section_title), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                if (questionnaire != null) {
                    Column(
                        modifier = Modifier.fillMaxWidth().clickable { onOpenQuestionnaire() },
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            GAD7ScoreCapsule(questionnaire.questionnaire, previousQuestionnaire?.questionnaire)
                            PHQ9ScoreCapsule(questionnaire.questionnaire, previousQuestionnaire?.questionnaire)
                        }
                    }
                } else {
                    TextButton(onClick = onOpenQuestionnaire, enabled = !busy) {
                        Text(stringResource(R.string.add_questionnaire_action), color = colors.gold)
                    }
                }
            }

            errorMessage?.let { Text(it, color = colors.error) }
            if (isSaving) {
                Text(
                    if (hasText) stringResource(R.string.anonymizing_status_label)
                    else stringResource(R.string.save),
                    color = colors.textBody,
                )
            }

            Button(
                onClick = {
                    onSave(initial.copy(date = date, notes = notes, type = type, structuredNotes = structuredNotes))
                },
                enabled = !busy,
                modifier = Modifier.fillMaxWidth().height(48.dp),
                colors = ButtonDefaults.buttonColors(containerColor = colors.gold, contentColor = colors.textOnAccent),
            ) {
                if (isSaving) CircularProgressIndicator(Modifier.size(22.dp), color = colors.textOnAccent, strokeWidth = 2.dp)
                else Text(stringResource(if (isNew) R.string.add_session_action else R.string.save_changes_action), fontWeight = FontWeight.SemiBold)
            }

            if (!isNew) {
                Button(
                    onClick = { showDelete = true },
                    enabled = !busy,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = colors.error, contentColor = colors.textBright),
                ) {
                    Text(stringResource(R.string.delete_session_action))
                }
            }
        }
    }

    if (showDatePicker) {
        val pickerState = rememberDatePickerState(initialSelectedDateMillis = date.time)
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    pickerState.selectedDateMillis?.let { date = Date(it) }
                    showDatePicker = false
                }) { Text(stringResource(R.string.save), color = colors.gold) }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) {
                    Text(stringResource(R.string.cancel), color = colors.gold)
                }
            },
        ) {
            DatePicker(state = pickerState)
        }
    }

    if (showDelete) {
        AlertDialog(
            onDismissRequest = { showDelete = false },
            title = { Text(stringResource(R.string.delete_session_confirm_title)) },
            text = { Text(stringResource(R.string.delete_session_confirm_message)) },
            confirmButton = {
                TextButton(onClick = {
                    showDelete = false
                    onDelete(initial.copy(date = date, notes = notes, type = type))
                }) { Text(stringResource(R.string.delete_session_action), color = colors.error) }
            },
            dismissButton = {
                TextButton(onClick = { showDelete = false }) { Text(stringResource(R.string.cancel)) }
            },
        )
    }
}

private fun formatDuration(seconds: Double): String {
    val total = seconds.toInt().coerceAtLeast(0)
    return "%d:%02d".format(total / 60, total % 60)
}
