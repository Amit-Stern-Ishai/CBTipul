package com.cbtipul.app.ui.patients

import kotlinx.coroutines.flow.collectLatest

import androidx.compose.material.icons.outlined.HourglassEmpty
import androidx.compose.material.icons.automirrored.outlined.Send
import androidx.compose.material.icons.outlined.FindInPage
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.EditNote
import androidx.compose.material.icons.filled.StopCircle
import com.cbtipul.app.ui.theme.IconLabel
import com.cbtipul.app.ui.theme.editorScroll
import androidx.compose.foundation.layout.imePadding
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.material3.HorizontalDivider
import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material3.DropdownMenu
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.Description
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
import androidx.compose.runtime.rememberCoroutineScope
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
import com.cbtipul.app.data.DemoData
import com.cbtipul.app.data.PatientAssignmentException
import com.cbtipul.app.data.PatientAssignmentRepository
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
import com.cbtipul.app.ui.onboarding.TutorialHighlight
import com.cbtipul.app.ui.onboarding.tutorialPulse
import com.cbtipul.app.ui.theme.themedScreen
import kotlinx.coroutines.launch
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
    gettingStarted: com.cbtipul.app.ui.onboarding.GettingStartedRouter? = null,
    viewingPatientId: com.cbtipul.app.model.DatabaseId? = null,
    assignmentRepository: PatientAssignmentRepository? = null,
    isDemo: Boolean = false,
    availablePatients: List<Patient> = emptyList(),
    choosePatient: Boolean = false,
    onSelectPatient: (Patient) -> Unit = {},
    editorDraft: SessionEditorDraft,
    onRefreshQuestionnaire: () -> Unit = {},
    questionnaireLoading: Boolean = false,
    questionnaireLoadError: String? = null,
) {
    val colors = Theme.colors

    LaunchedEffect(patient?.id?.queryValue, viewingPatientId?.queryValue) {
        gettingStarted?.setPlacement(
            com.cbtipul.app.ui.onboarding.TutorialCoachPlacement.SessionEditor,
            viewingPatientId = viewingPatientId ?: patient?.id,
        )
    }

    if (session == null && !isNew) {
        Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.Center) {
            Text(stringResource(R.string.session_not_saved_error), color = colors.textBright)
            TextButton(onClick = onBack) { Text(stringResource(R.string.back), color = colors.gold) }
        }
        return
    }
    val initial = editorDraft.initial
    var date by editorDraft::date
    var notes by editorDraft::notes
    var type by editorDraft::type
    var structuredNotes by editorDraft::structuredNotes
    var showingNotesEditor by remember { mutableStateOf(false) }
    var showingSummaryMenu by remember { mutableStateOf(false) }
    var showDatePicker by remember { mutableStateOf(false) }
    var typeExpanded by remember { mutableStateOf(false) }
    var showDelete by remember { mutableStateOf(false) }
    var showDeleteCode by remember { mutableStateOf(false) }
    var showDiscard by remember { mutableStateOf(false) }
    var showAllFollowUps by remember { mutableStateOf(false) }
    var overflow by remember { mutableStateOf(false) }
    var baselineDate by editorDraft::baselineDate
    var baselineNotes by editorDraft::baselineNotes
    var baselineType by editorDraft::baselineType
    var baselineStructured by editorDraft::baselineStructured
    val hasText = notes.trim().isNotEmpty()
    val processing = isSaving || isTranscribing || isAnonymizingTranscription || isAnalyzing
    val context = LocalContext.current
    var recorderTick by remember { mutableIntStateOf(0) }
    val recorder = remember {
        VoiceNoteRecorder(context.applicationContext).also { it.onChange = { recorderTick++ } }
    }
    DisposableEffect(recorder) {
        onDispose { recorder.release() }
    }
    val permissionDenied = stringResource(R.string.mic_permission_denied)
    var requestingRecording by remember { mutableStateOf(false) }
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        requestingRecording = false
        if (granted) {
            recorder.startRecording()
        } else {
            recorder.errorMessage = permissionDenied
            recorderTick++
        }
    }
    @Suppress("UNUSED_VARIABLE")
    val observed = recorderTick
    val canWrite = com.cbtipul.app.ui.entitlementCanWrite()
    val busy = processing || requestingRecording || recorder.isRecording

    fun currentSession() = initial.copy(date = date, notes = notes, type = type, structuredNotes = structuredNotes)

    val hasUnsavedChanges = date != baselineDate || notes != baselineNotes || type != baselineType ||
        structuredNotes != baselineStructured || recorder.recordingFile != null

    LaunchedEffect(editorDraft) {
        androidx.compose.runtime.snapshotFlow { listOf(date, notes, type, structuredNotes, editorDraft.selectedPatientId) }
            .collectLatest { kotlinx.coroutines.delay(350); editorDraft.persistRecovery() }
    }
    DisposableEffect(editorDraft) { onDispose { editorDraft.persistRecovery() } }
    val canSave = canWrite && patient != null && !busy && recorder.recordingFile == null && (isNew || hasUnsavedChanges)
    fun persist(leave: Boolean) {
        if (!canSave) return
        onSave(currentSession(), leave)
    }

    fun requestBack() {
        if (busy) return
        if (hasUnsavedChanges) showDiscard = true else onBack()
    }

    BackHandler(enabled = true) { requestBack() }

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
        if (!com.cbtipul.app.data.Entitlements.allowMutation(allowLocalDemo = false)) return
        val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        if (granted) recorder.startRecording() else {
            requestingRecording = true
            permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
        }
    }

    if (showingNotesEditor) {
        // Use the activity's already-safe viewport; a separate dialog window
        // does not share its keyboard inset handling.
        var notesAtOpen by remember { mutableStateOf(notes) }
        var confirmLeavingNotes by remember { mutableStateOf(false) }
        var observedBaseline by remember { mutableStateOf(baselineNotes) }
        LaunchedEffect(baselineNotes) {
            if (baselineNotes != observedBaseline) {
                notesAtOpen = baselineNotes
                observedBaseline = baselineNotes
            }
        }
        fun leaveNotes() {
            if (busy) return
            if (notes != notesAtOpen) confirmLeavingNotes = true else showingNotesEditor = false
        }
        BackHandler { leaveNotes() }
        run {
            val editorFocus = remember { FocusRequester() }
            LaunchedEffect(Unit) { if (canWrite) editorFocus.requestFocus() }
            Scaffold(modifier = Modifier.fillMaxSize().dismissKeyboardOnTap(), containerColor = colors.surface,
                topBar = {
                    TopAppBar(title = { Text(stringResource(R.string.session_summary_section), color = colors.textBright) },
                        colors = TopAppBarDefaults.topAppBarColors(containerColor = colors.surface),
                        navigationIcon = {
                            IconButton(onClick = { leaveNotes() }, enabled = !busy) {
                                Icon(Icons.AutoMirrored.Outlined.ArrowBack, stringResource(R.string.back), tint = colors.gold)
                            }
                        },
                        actions = {
                            if ((hasUnsavedChanges || isNew) && canWrite) {
                                TextButton(onClick = { persist(leave = isNew) }, enabled = canSave) {
                                    Text(stringResource(R.string.save_summary_action), fontWeight = FontWeight.SemiBold)
                                }
                            } else {
                                TextButton(onClick = { leaveNotes() }, enabled = !busy) {
                                    Text(stringResource(R.string.close_action), color = colors.gold, fontWeight = FontWeight.SemiBold)
                                }
                            }
                        })
                }) { padding ->
                Column(Modifier.fillMaxSize().padding(padding).editorScroll()) {
                    Row(Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text(displayName, color = colors.textBody, fontSize = 14.sp,
                            fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f))
                        Text(hebrewDate(date), color = colors.textBody, fontSize = 12.sp)
                    }
                    HorizontalDivider(color = colors.borderFaint)
                    BasicTextField(value = notes, onValueChange = { notes = it },
                        textStyle = TextStyle(color = colors.textBright, fontSize = 18.sp, lineHeight = 28.sp, textAlign = TextAlign.Start),
                        cursorBrush = SolidColor(colors.gold),
                        modifier = Modifier.fillMaxWidth().heightIn(min = 240.dp)
                            .padding(horizontal = 24.dp, vertical = 20.dp)
                            .focusRequester(editorFocus),
                        decorationBox = { input ->
                            Box(Modifier.fillMaxWidth()) {
                                if (notes.isEmpty()) Text(stringResource(R.string.session_summary_field_placeholder),
                                    color = colors.textFaint, fontSize = 18.sp, lineHeight = 28.sp)
                                input()
                            }
                        }, readOnly = !canWrite || busy)
                    if (isSaving) Text(stringResource(R.string.session_saving), color = colors.textBody,
                        fontSize = 12.sp, modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 12.dp))
                    errorMessage?.let { Text(it, color = colors.error, modifier = Modifier.padding(horizontal = 24.dp, vertical = 8.dp)) }
                }
            }
        }
        BusyOverlay(isBusy = isSaving)
        DiscardChangesDialog(
            visible = confirmLeavingNotes,
            canSave = canSave,
            onSave = { confirmLeavingNotes = false; persist(leave = isNew) },
            onDiscard = { notes = notesAtOpen; confirmLeavingNotes = false; showingNotesEditor = false },
            onKeepEditing = { confirmLeavingNotes = false },
        )
        return
    }

    Box(Modifier.fillMaxSize()) {
    Scaffold(
        modifier = Modifier
            .themedScreen(atmosphere)
            .dismissKeyboardOnTap(),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        if (isNew) {
                            stringResource(R.string.new_session_title)
                        } else {
                            stringResource(R.string.session_editor_title, sessionNumber?.let { " $it" } ?: "")
                        },
                        color = colors.textBright,
                    )
                },
                navigationIcon = {
                    IconButton(onClick = { requestBack() }, enabled = !busy) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = stringResource(R.string.back), tint = colors.gold)
                    }
                },
                actions = {
                    if (!isNew) {
                        IconButton(onClick = { overflow = true }, enabled = canWrite && !busy) {
                            Icon(Icons.Filled.MoreVert, contentDescription = null, tint = colors.gold)
                        }
                        DropdownMenu(expanded = overflow, onDismissRequest = { overflow = false }) {
                            DropdownMenuItem(
                                text = { Text(stringResource(R.string.delete_session_action), color = colors.error) },
                                onClick = {
                                    overflow = false
                                    showDelete = true
                                },
                            )
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
        bottomBar = {
            Column(Modifier.fillMaxWidth().padding(16.dp)) {
                if (editorDraft.recoveryFailed) Text(stringResource(R.string.draft_save_failed), color = colors.error)
                if (hasUnsavedChanges && !busy && recorder.recordingFile == null) TextButton(onClick = { if (editorDraft.persistRecovery()) onBack() }) { Text(stringResource(R.string.keep_draft_and_leave)) }
                val status = when {
                    recorder.isRecording -> R.string.session_recording_in_progress
                    isTranscribing -> R.string.transcribing_label
                    isAnonymizingTranscription -> R.string.anonymizing_status_label
                    isSaving -> R.string.session_saving
                    isAnalyzing -> R.string.analyzing_label
                    busy -> R.string.session_processing
                    recorder.recordingFile != null -> R.string.session_recording_needs_transcription
                    patient == null -> R.string.session_choose_patient_help
                    isNew -> R.string.session_not_created
                    else -> null
                }
                if (status != null) IconLabel(
                    stringResource(status),
                    icon = when {
                        recorder.isRecording -> Icons.Filled.Mic
                        busy -> Icons.Outlined.HourglassEmpty
                        else -> Icons.Outlined.EditNote
                    },
                    color = if (recorder.isRecording) colors.error else colors.textBody,
                    fontSize = 12.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
                Button(onClick = { persist(leave = isNew) }, enabled = canSave, modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = colors.accentFill, contentColor = colors.textOnAccent)) {
                    Text(stringResource(R.string.save_session_action), modifier = Modifier.padding(6.dp))
                }
            }
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .editorScroll()
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            if (choosePatient) {
                var expanded by remember { mutableStateOf(false) }
                ExposedDropdownMenuBox(expanded, onExpandedChange = { if (!busy) expanded = it }) {
                    OutlinedTextField(value = patient?.displayName(unnamed) ?: stringResource(R.string.session_choose_patient_placeholder),
                        onValueChange = {}, readOnly = true, label = { Text(stringResource(R.string.choose_patient_for_session)) },
                        modifier = Modifier.fillMaxWidth().menuAnchor(), enabled = canWrite && !busy,
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) })
                    ExposedDropdownMenu(expanded, onDismissRequest = { expanded = false }) {
                        availablePatients.sortedWith(compareBy<Patient> { it.status != com.cbtipul.app.model.PatientStatus.Active }.thenBy { it.displayName(unnamed) }).forEach { option ->
                            DropdownMenuItem(text = { Text(option.displayName(unnamed)) }, onClick = { expanded = false; onSelectPatient(option) })
                        }
                    }
                }
                if (patient == null) Text(stringResource(R.string.session_choose_patient_help), color = colors.textBody)
            } else Text(displayName, fontSize = 22.sp, fontWeight = FontWeight.Bold, color = colors.textBright, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
            Text(stringResource(R.string.session_date_title), color = colors.textBright)
            TextButton(onClick = { showDatePicker = true }, enabled = canWrite && !busy) { Text(hebrewDate(date), color = colors.gold) }
            ExposedDropdownMenuBox(typeExpanded, onExpandedChange = { if (canWrite && !busy) typeExpanded = it }) {
                OutlinedTextField(value = type?.let { stringResource(it.labelRes()) } ?: stringResource(R.string.session_type_none),
                    onValueChange = {}, readOnly = true, label = { Text(stringResource(R.string.session_type_label)) },
                    modifier = Modifier.fillMaxWidth().menuAnchor(), enabled = canWrite && !busy,
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(typeExpanded) })
                ExposedDropdownMenu(typeExpanded, onDismissRequest = { typeExpanded = false }) {
                    DropdownMenuItem(text = { Text(stringResource(R.string.session_type_none)) }, onClick = { type = null; typeExpanded = false })
                    SessionType.entries.forEach { option ->
                        DropdownMenuItem(text = { Text(stringResource(option.labelRes())) }, onClick = { type = option; typeExpanded = false })
                    }
                }
            }
            Text(stringResource(R.string.session_summary_section), color = colors.textBright, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Start)
            val accent = atmosphere ?: colors.gold
            GroupedListCard(accent = accent) {
                val pending = recorder.recordingFile != null && !busy
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                ) {
                    Column(Modifier.fillMaxWidth().clickable(enabled = !busy) { showingNotesEditor = true }) {
                        Text(notes.ifEmpty { stringResource(R.string.session_summary_field_placeholder) },
                            color = if (notes.isEmpty()) colors.textBody else colors.textBright,
                            maxLines = 6, overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.fillMaxWidth()
                                .background(colors.base, RoundedCornerShape(12.dp))
                                .border(1.dp, colors.borderFaint, RoundedCornerShape(12.dp))
                                .padding(16.dp).heightIn(min = 88.dp))
                        TextButton(onClick = { showingNotesEditor = true }, enabled = !busy) {
                            IconLabel(stringResource(if (notes.isEmpty()) R.string.session_write_notes else R.string.session_read_notes), Icons.Outlined.EditNote)
                        }
                    }
                    GroupedListDivider()
                    if (recorder.isRecording) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(formatDuration(recorder.durationSeconds), color = colors.error, fontWeight = FontWeight.SemiBold)
                            TextButton(onClick = {
                                recorder.stopRecording()
                                transcribePending()
                            }) {
                                IconLabel(stringResource(R.string.stop_and_transcribe_action), Icons.Filled.StopCircle, color = colors.error)
                            }
                        }
                    } else {
                        TextButton(onClick = { startMic() }, enabled = canWrite && !busy && recorder.recordingFile == null) {
                            IconLabel(stringResource(R.string.record_session_notes_action), Icons.Filled.Mic, color = colors.gold)
                        }
                    }
                }
                if (pending) {
                    GroupedListDivider()
                    Column(
                        modifier = Modifier.fillMaxWidth().padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Text(stringResource(R.string.session_pending_recording), color = colors.textBody, fontSize = 13.sp)
                        TextButton(onClick = { transcribePending() }) {
                            Text(stringResource(R.string.transcribe_action), color = colors.gold, fontWeight = FontWeight.SemiBold)
                        }
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
                        TextButton(onClick = { recorder.discard() }) {
                            Icon(Icons.Filled.Delete, contentDescription = null, tint = colors.error)
                            Text(stringResource(R.string.discard_recording_action), color = colors.error)
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
                if (editorDraft.canGenerateAnalysis) {
                    GroupedListDivider()
                    Row(Modifier.fillMaxWidth().clickable(enabled = canWrite && !busy && recorder.recordingFile == null) {
                        onAnalyze(currentSession(), { notes = it }, { structuredNotes = it })
                    }.padding(16.dp), verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        if (isAnalyzing) {
                            CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                            Text(stringResource(R.string.analyzing_label), color = colors.textBody)
                        } else {
                            Icon(Icons.Outlined.AutoAwesome, contentDescription = null, tint = colors.gold)
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Text(stringResource(R.string.ai_summary_action), color = colors.gold, fontWeight = FontWeight.SemiBold)
                                Text(stringResource(R.string.session_ai_hint), color = colors.textBody, fontSize = 12.sp)
                            }
                        }
                    }
                }
                recorder.errorMessage?.let {
                    GroupedListDivider()
                    Text(it, color = colors.error, modifier = Modifier.padding(16.dp))
                }
            }
            structuredNotes?.let { analysis ->
                Text(stringResource(R.string.structured_summary_section), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                GroupedListCard(accent = accent) {
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
                    Text(analysis.sessionSummary, color = colors.textBright, maxLines = 6,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f).clickable(enabled = !busy, onClick = onOpenAnalysis).padding(16.dp))
                    Box {
                        IconButton(onClick = { showingSummaryMenu = true }, enabled = canWrite && !busy) {
                            Icon(Icons.Filled.MoreVert, contentDescription = stringResource(R.string.session_regenerate))
                        }
                        DropdownMenu(expanded = showingSummaryMenu, onDismissRequest = { showingSummaryMenu = false }) {
                            DropdownMenuItem(text = { Text(stringResource(R.string.session_regenerate)) },
                                enabled = canWrite && !busy && hasText && recorder.recordingFile == null,
                                onClick = { showingSummaryMenu = false; onAnalyze(currentSession(), { notes = it }, { structuredNotes = it }) })
                        }
                    }
                    }
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
                            Icon(Icons.Outlined.FindInPage, contentDescription = null, tint = colors.gold, modifier = Modifier.size(16.dp))
                        }
                        Text(
                            stringResource(R.string.session_view_edit_summary),
                            color = colors.gold,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                }
            }

            if (initial.databaseId != null) {
                Text(stringResource(R.string.questionnaire_local_entry_help), color = colors.textBody)
                Text(stringResource(R.string.questionnaire_section_title), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                if (questionnaireLoadError != null) {
                    Text(questionnaireLoadError, color = colors.error)
                    TextButton(onClick = onRefreshQuestionnaire, enabled = !questionnaireLoading) { Text(stringResource(R.string.questionnaire_refresh_action)) }
                }
                GroupedListCard(accent = accent) {
                    if (questionnaireLoading && questionnaire == null) {
                        CircularProgressIndicator(Modifier.padding(16.dp))
                    } else if (questionnaire != null) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable(enabled = !busy, onClick = onOpenQuestionnaire)
                                .padding(horizontal = 16.dp, vertical = 12.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            IconLabel(
                                hebrewDate(questionnaire.answeredDate), Icons.Outlined.CheckCircle,
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
                                .tutorialPulse(gettingStarted?.shouldPulse(TutorialHighlight.FillQuestionnaire) == true)
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
                                Icon(Icons.Outlined.EditNote, contentDescription = null, tint = colors.gold, modifier = Modifier.size(16.dp))
                            }
                            Text(
                                stringResource(R.string.fill_questionnaire_here_action),
                                color = colors.textBright,
                                fontWeight = FontWeight.SemiBold,
                            )
                        }
                    }
                }
            }

            if (initial.databaseId != null && patient != null && assignmentRepository != null) {
                GroupedListCard(accent = accent) {
                    Column(Modifier.padding(16.dp)) {
                        QuestionnaireAccessControl(patient, assignmentRepository, isDemo, busy)
                    }
                }
            }

            errorMessage?.let { Text(it, color = colors.error) }


        }
    }
        BusyOverlay(
            isBusy = isSaving || isAnonymizingTranscription,
            label = if (isAnonymizingTranscription || (isSaving && hasText)) {
                stringResource(R.string.anonymizing_status_label)
            } else null,
        )
        ConfirmDeleteOverlay(
            visible = showDelete,
            title = stringResource(R.string.delete_session_confirm_title),
            message = stringResource(R.string.delete_session_confirm_message),
            confirmLabel = stringResource(R.string.delete_session_action),
            onConfirm = {
                showDelete = false
                showDeleteCode = true
            },
            onDismiss = { showDelete = false },
        )
        DeleteCodeDialog(
            visible = showDeleteCode,
            onConfirm = {
                showDeleteCode = false
                onDelete(initial.copy(date = date, notes = notes, type = type))
            },
            onDismiss = { showDeleteCode = false },
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
        canSave = canSave,
        onSave = {
            showDiscard = false
            persist(leave = true)
        },
        onDiscard = {
            if (!editorDraft.clearRecovery(close = true)) return@DiscardChangesDialog
            showDiscard = false
            recorder.discard()
            date = baselineDate
            notes = baselineNotes
            type = baselineType
            structuredNotes = baselineStructured
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
                        enabled = canWrite && !busy,
                        onMarkDiscussed = { onMarkFollowUpDiscussed(previousSession, index) },
                    )
                }
                TextButton(onClick = { showAllFollowUps = false }) {
                    Text(stringResource(R.string.close_action), color = colors.gold)
                }
            }
        }
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
