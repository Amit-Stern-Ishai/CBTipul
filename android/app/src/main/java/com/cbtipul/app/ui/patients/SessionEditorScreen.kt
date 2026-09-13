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
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material3.DropdownMenu
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.rememberModalBottomSheetState
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
import androidx.compose.runtime.LaunchedEffect
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
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.cbtipul.app.R
import com.cbtipul.app.model.CompletedQuestionnaire
import com.cbtipul.app.model.FollowUpStatus
import com.cbtipul.app.model.Patient
import com.cbtipul.app.model.Session
import com.cbtipul.app.model.SessionType
import com.cbtipul.app.ui.theme.BusyOverlay
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.GroupedListDivider
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.dismissKeyboardOnTap
import com.cbtipul.app.ui.theme.hebrewDate
import com.cbtipul.app.ui.theme.themedScreen
import java.io.File
import java.util.Date

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SessionEditorScreen(
    session: Session?,
    patient: Patient?,
    unnamed: String,
    isNew: Boolean,
    isSaving: Boolean,
    isTranscribing: Boolean,
    isAnonymizingTranscription: Boolean,
    isAnalyzing: Boolean,
    errorMessage: String?,
    onBack: () -> Unit,
    onSave: (Session, Boolean) -> Unit,
    onDelete: (Session) -> Unit,
    onTranscribe: (File, String, Session, (String) -> Unit, () -> Unit) -> Unit,
    onAnalyze: (Session, (String) -> Unit, (com.cbtipul.app.model.CBTSessionAnalysis) -> Unit) -> Unit,
    onOpenAnalysis: () -> Unit,
    questionnaire: CompletedQuestionnaire?,
    previousQuestionnaire: CompletedQuestionnaire?,
    atmosphere: Color?,
    onOpenQuestionnaire: () -> Unit,
    onMarkFollowUpDiscussed: (Session, Int) -> Unit,
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
    var showDiscard by remember { mutableStateOf(false) }
    var showAllFollowUps by remember { mutableStateOf(false) }
    var baselineDate by remember(initial.id) { mutableStateOf(initial.date) }
    var baselineNotes by remember(initial.id) { mutableStateOf(initial.notes) }
    var baselineType by remember(initial.id) { mutableStateOf(initial.type) }
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

    val hasUnsavedChanges = date != baselineDate || notes != baselineNotes || type != baselineType ||
        recorder.recordingFile != null

    fun persist(leave: Boolean) {
        baselineDate = date
        baselineNotes = notes
        baselineType = type
        onSave(currentSession(), leave)
    }

    fun requestBack() {
        if (busy) return
        if (hasUnsavedChanges) showDiscard = true else onBack()
    }

    BackHandler(enabled = !busy) { requestBack() }

    val displayName = patient?.displayName(unnamed) ?: unnamed
    val sessionNumber = remember(patient, initial.id, initial.databaseId, isNew) {
        val sorted = patient?.sessions?.sortedBy { it.date.time }.orEmpty()
        val index = sorted.indexOfFirst {
            it.id == initial.id || (it.databaseId != null && it.databaseId == initial.databaseId)
        }
        when {
            index >= 0 -> index + 1
            isNew -> sorted.size + 1
            else -> null
        }
    }
    val previousSession = remember(patient, initial.id, date) {
        patient?.sessions
            ?.filter { other ->
                other.id != initial.id &&
                    (initial.databaseId == null || other.databaseId != initial.databaseId) &&
                    !other.date.after(date)
            }
            ?.maxByOrNull { it.date.time }
    }
    val pendingFollowUps = previousSession?.structuredNotes?.followUpQuestions
        ?.mapIndexedNotNull { index, question ->
            if (question.status == FollowUpStatus.Discussed || question.status == FollowUpStatus.NotRelevant) {
                null
            } else {
                index to question
            }
        }
        .orEmpty()
    LaunchedEffect(pendingFollowUps.isEmpty()) {
        if (pendingFollowUps.isEmpty()) showAllFollowUps = false
    }

    fun transcribePending() {
        val file = recorder.recordingFile ?: return
        onTranscribe(file, notes, currentSession(), { notes = it }, { recorder.discard() })
    }

    fun startMic() {
        val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        if (granted) recorder.startRecording() else permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
    }

    Box(Modifier.fillMaxSize()) {
    Scaffold(
        modifier = Modifier
            .themedScreen(atmosphere)
            .dismissKeyboardOnTap(),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { },
                navigationIcon = {
                    IconButton(onClick = { requestBack() }, enabled = !busy) {
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
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                if (isNew) {
                    Text(stringResource(R.string.new_session_title), color = colors.textBright, fontWeight = FontWeight.Bold, fontSize = 22.sp)
                    Text(displayName, color = colors.textBody, fontWeight = FontWeight.SemiBold)
                } else {
                    Text(displayName, color = colors.textBright, fontWeight = FontWeight.Bold, fontSize = 22.sp)
                    sessionNumber?.let {
                        Text(stringResource(R.string.session_editor_title, " $it"), color = colors.textBody, fontWeight = FontWeight.SemiBold)
                    }
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(
                            type?.let { stringResource(it.labelRes()) } ?: stringResource(R.string.session_type_none),
                            color = if (type == null) colors.textFaint else colors.gold,
                            fontWeight = FontWeight.SemiBold,
                        )
                        IconButton(onClick = { if (!busy) typeExpanded = true }, modifier = Modifier.size(32.dp)) {
                            Icon(Icons.Filled.Edit, contentDescription = stringResource(R.string.session_type_label), tint = colors.gold)
                        }
                        DropdownMenu(expanded = typeExpanded, onDismissRequest = { typeExpanded = false }) {
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
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(hebrewDate(date), color = colors.textBody)
                        IconButton(onClick = { if (!busy) showDatePicker = true }, modifier = Modifier.size(32.dp)) {
                            Icon(Icons.Filled.DateRange, contentDescription = stringResource(R.string.edit_date_accessibility_label), tint = colors.gold)
                        }
                    }
                }
            }

            if (isNew) {
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
                Text(stringResource(R.string.session_date_title), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                TextButton(onClick = { showDatePicker = true }, enabled = !busy) {
                    Text(hebrewDate(date), color = colors.gold)
                }
            }

            if (pendingFollowUps.isNotEmpty()) {
                Text(stringResource(R.string.from_last_session_header), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                val first = pendingFollowUps.first()
                previousSession?.let { source ->
                    FollowUpEditorRow(
                        question = first.second.question,
                        reason = first.second.reason,
                        enabled = !busy,
                        onMarkDiscussed = { onMarkFollowUpDiscussed(source, first.first) },
                    )
                }
                if (pendingFollowUps.size > 1) {
                    TextButton(onClick = { showAllFollowUps = true }, enabled = !busy) {
                        Icon(Icons.Filled.MoreHoriz, contentDescription = null, tint = colors.gold)
                        Text(stringResource(R.string.more_follow_ups, pendingFollowUps.size - 1), color = colors.gold)
                    }
                }
            }

            Text(stringResource(R.string.session_summary_section), color = colors.textBright, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Start)
            val accent = atmosphere ?: colors.gold
            GroupedListCard(accent = accent) {
                val pending = recorder.recordingFile != null && !isTranscribing && !isAnonymizingTranscription
                Box(Modifier.fillMaxWidth()) {
                    BasicTextField(
                        value = notes,
                        onValueChange = { notes = it },
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = 160.dp)
                            .padding(start = 16.dp, top = 14.dp, end = 16.dp, bottom = 48.dp),
                        enabled = !busy,
                        textStyle = TextStyle(color = colors.textBright, fontSize = 16.sp),
                        minLines = 5,
                    )
                    if (recorder.isRecording) {
                        Row(
                            modifier = Modifier
                                .align(Alignment.BottomEnd)
                                .padding(4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(formatDuration(recorder.durationSeconds), color = colors.error, fontWeight = FontWeight.SemiBold)
                            IconButton(onClick = {
                                recorder.stopRecording()
                                transcribePending()
                            }) {
                                Icon(Icons.Filled.Stop, contentDescription = stringResource(R.string.recording_label), tint = colors.error)
                            }
                        }
                    } else {
                        IconButton(
                            onClick = { startMic() },
                            enabled = !busy,
                            modifier = Modifier.align(Alignment.BottomEnd).padding(4.dp),
                        ) {
                            Icon(Icons.Filled.Mic, contentDescription = stringResource(R.string.record_voice_note_action), tint = colors.gold)
                        }
                    }
                }
                if (pending) {
                    GroupedListDivider()
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 8.dp, vertical = 4.dp),
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
                    GroupedListDivider()
                    Row(
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        CircularProgressIndicator(Modifier.size(18.dp), color = colors.gold, strokeWidth = 2.dp)
                        Text(
                            stringResource(
                                if (isTranscribing) R.string.transcribing_label else R.string.anonymizing_status_label,
                            ),
                            color = colors.textBody,
                        )
                    }
                }
                recorder.errorMessage?.let {
                    GroupedListDivider()
                    Text(it, color = colors.error, modifier = Modifier.padding(16.dp))
                }
                GroupedListDivider()
                if (isAnalyzing) {
                    Row(
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        CircularProgressIndicator(Modifier.size(18.dp), color = colors.gold, strokeWidth = 2.dp)
                        Text(stringResource(R.string.analyzing_label), color = colors.textBody)
                    }
                } else {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable(
                                enabled = !busy && hasText,
                                onClick = {
                                    onAnalyze(currentSession(), { notes = it }, { structuredNotes = it })
                                },
                            )
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
                            Icon(Icons.Outlined.AutoAwesome, contentDescription = null, tint = colors.gold, modifier = Modifier.size(16.dp))
                        }
                        Text(
                            stringResource(R.string.ai_summary_action),
                            color = if (!busy && hasText) colors.gold else colors.textFaint,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                }
            }

            structuredNotes?.let { analysis ->
                Text(stringResource(R.string.structured_summary_section), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                GroupedListCard(accent = accent) {
                    Text(
                        analysis.sessionSummary,
                        color = colors.textBody,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
                    )
                    GroupedListDivider()
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable(enabled = !busy, onClick = onOpenAnalysis)
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
                            Icon(Icons.Outlined.Description, contentDescription = null, tint = colors.gold, modifier = Modifier.size(16.dp))
                        }
                        Text(
                            stringResource(R.string.show_structured_summary_action),
                            color = colors.gold,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                }
            }

            if (initial.databaseId != null) {
                Text(stringResource(R.string.questionnaire_section_title), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                GroupedListCard(accent = accent) {
                    if (questionnaire != null) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable(enabled = !busy, onClick = onOpenQuestionnaire)
                                .padding(horizontal = 16.dp, vertical = 12.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Text(
                                hebrewDate(questionnaire.answeredDate),
                                color = colors.textBright,
                                fontWeight = FontWeight.SemiBold,
                            )
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                GAD7ScoreCapsule(questionnaire.questionnaire, previousQuestionnaire?.questionnaire)
                                PHQ9ScoreCapsule(questionnaire.questionnaire, previousQuestionnaire?.questionnaire)
                            }
                        }
                    } else {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable(enabled = !busy, onClick = onOpenQuestionnaire)
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
                                Icon(Icons.Outlined.Add, contentDescription = null, tint = colors.gold, modifier = Modifier.size(16.dp))
                            }
                            Text(
                                stringResource(R.string.add_questionnaire_action),
                                color = colors.textBright,
                                fontWeight = FontWeight.SemiBold,
                            )
                        }
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
                onClick = { persist(leave = isNew) },
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
        BusyOverlay(
            isBusy = isSaving || isAnonymizingTranscription,
            label = if (isAnonymizingTranscription || (isSaving && hasText)) {
                stringResource(R.string.anonymizing_status_label)
            } else null,
        )
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

    DiscardChangesDialog(
        visible = showDiscard,
        canSave = true,
        onSave = {
            showDiscard = false
            persist(leave = true)
        },
        onDiscard = {
            showDiscard = false
            recorder.discard()
            date = baselineDate
            notes = baselineNotes
            type = baselineType
            onBack()
        },
        onKeepEditing = { showDiscard = false },
    )

    if (showAllFollowUps && previousSession != null) {
        ModalBottomSheet(
            onDismissRequest = { showAllFollowUps = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        ) {
            Column(Modifier.fillMaxWidth().padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(stringResource(R.string.open_questions_title), color = colors.textBright, fontWeight = FontWeight.Bold)
                pendingFollowUps.forEach { (index, question) ->
                    FollowUpEditorRow(
                        question = question.question,
                        reason = question.reason,
                        enabled = !busy,
                        onMarkDiscussed = { onMarkFollowUpDiscussed(previousSession, index) },
                    )
                }
                TextButton(onClick = { showAllFollowUps = false }) {
                    Text(stringResource(R.string.done), color = colors.gold)
                }
            }
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

@Composable
private fun FollowUpEditorRow(
    question: String,
    reason: String,
    enabled: Boolean,
    onMarkDiscussed: () -> Unit,
) {
    val colors = Theme.colors
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(question, color = colors.textBright, fontWeight = FontWeight.SemiBold)
            if (reason.isNotBlank()) Text(reason, color = colors.textBody)
        }
        IconButton(onClick = onMarkDiscussed, enabled = enabled) {
            Icon(
                Icons.Filled.CheckCircle,
                contentDescription = stringResource(R.string.mark_discussed_accessibility_label),
                tint = colors.positive,
            )
        }
    }
}

private fun formatDuration(seconds: Double): String {
    val total = seconds.toInt().coerceAtLeast(0)
    return "%d:%02d".format(total / 60, total % 60)
}
