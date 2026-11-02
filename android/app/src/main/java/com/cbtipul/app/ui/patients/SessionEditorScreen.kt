package com.cbtipul.app.ui.patients

import androidx.compose.material3.AlertDialog

import androidx.compose.material3.MaterialTheme

import androidx.compose.material3.Surface

import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.text.selection.SelectionContainer


import kotlinx.coroutines.flow.collectLatest

import androidx.compose.material.icons.outlined.HourglassEmpty
import androidx.compose.material.icons.automirrored.outlined.Send
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.EditNote
import androidx.compose.material.icons.filled.StopCircle
import com.cbtipul.app.ui.theme.IconLabel
import com.cbtipul.app.ui.theme.editorScroll
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
    onCheckSessions: () -> Unit = {},
    hasVersionConflict: Boolean = false,
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
    allowanceLookup: (suspend () -> com.cbtipul.app.data.SummaryAllowance)? = null,
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
    var editingSummaryText by remember { mutableStateOf(false) }
    var summarySaveRevision by remember(editorDraft) { mutableStateOf<Int?>(null) }
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
    val showSummaryTools = !isNew || editorDraft.hasSummaryDraft
    LaunchedEffect(editorDraft.saveRevision) {
        if (summarySaveRevision?.let { editorDraft.saveRevision > it } == true) {
            summarySaveRevision = null
            showingNotesEditor = false
        }
    }
    val processing = isSaving || isTranscribing || isAnonymizingTranscription || isAnalyzing
    val context = LocalContext.current
    val recoveryApp = context.applicationContext as com.cbtipul.app.CbTipulApp
    val owner = remember(editorDraft) { recoveryApp.authRepository.currentUserId() }
    val scope = rememberCoroutineScope()
    var allowanceMessage by remember { mutableStateOf<String?>(null) }
    var tokensExhausted by remember { mutableStateOf(false) }
    var allowanceRequest by remember { mutableIntStateOf(0) }
    var localError by remember { mutableStateOf<String?>(null) }
    var confirmRetry by remember { mutableStateOf(false) }
    var confirmDraftDelete by remember { mutableStateOf(false) }
    val blocksNewSummary = tokensExhausted && !editorDraft.hasSummaryDraft && editorDraft.audioName == null
    suspend fun checkAllowance(seconds: Double? = null, needsTokens: Boolean = true): Boolean {
        if (isDemo) return true
        val request = ++allowanceRequest
        return try {
            val snapshot = allowanceLookup?.invoke() ?: recoveryApp.patientRepository.summaryAllowance()
            if (owner != recoveryApp.authRepository.currentUserId() || request != allowanceRequest) return false
            tokensExhausted = snapshot.tokens.exhausted
            val low = snapshot.assess(needsTokens, seconds)
            allowanceMessage = if (low) "המכסה החודשית מתקרבת לסיום\nנותרו עד 10%. ייתכן שהמכסה תסתיים במהלך העיבוד." else null
            true
        } catch (error: Exception) {
            if (error is kotlinx.coroutines.CancellationException) throw error
            if (owner == recoveryApp.authRepository.currentUserId() && request == allowanceRequest) allowanceMessage = com.cbtipul.app.data.SummaryFailure.from(error).message
            false
        }
    }
    LaunchedEffect(editorDraft) { checkAllowance(seconds = 0.0) }
    var recorderTick by remember { mutableIntStateOf(0) }
    val recorder = remember {
        VoiceNoteRecorder(context.applicationContext, preserveOnRelease = true).also { voice ->
            voice.onChange = {
                recorderTick++
                if (owner == recoveryApp.authRepository.currentUserId() && editorDraft.audioName != null) {
                    editorDraft.audioSeconds = voice.durationSeconds
                    if (!voice.isRecording) editorDraft.persistRecovery()
                }
            }
            runCatching { editorDraft.audioFile(context)?.let { check(it.exists()); voice.restore(it, editorDraft.audioSeconds) } }
                .onFailure { localError = com.cbtipul.app.data.SummaryFailure.Kind.Local.message }
        }
    }
    DisposableEffect(recorder) {
        onDispose { recorder.release(); editorDraft.persistRecovery() }
    }
    val permissionDenied = stringResource(R.string.mic_permission_denied)
    var requestingRecording by remember { mutableStateOf(false) }
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        requestingRecording = false
        if (granted) {
            scope.launch {
                if (checkAllowance(seconds = 0.0)) runCatching { recorder.startRecording(editorDraft.beginAudio(context)) }
                    .onFailure { localError = com.cbtipul.app.data.SummaryFailure.Kind.Local.message }
            }
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
            .collectLatest { if (owner == recoveryApp.authRepository.currentUserId()) editorDraft.persistRecovery() }
    }
    DisposableEffect(editorDraft) { onDispose { editorDraft.persistRecovery() } }
    val canSave = canWrite && patient != null && !busy && !editorDraft.pendingCreation && (editorDraft.audioName == null || editorDraft.transcriptReady) && (isNew || hasUnsavedChanges)
    fun persist(leave: Boolean) {
        if (!canSave) return
        if (owner != recoveryApp.authRepository.currentUserId()) return
        if (!editorDraft.persistRecovery()) return
        onSave(currentSession(), leave)
    }

    fun saveSummary() {
        if (!canSave) return
        // markSaved is called only after a successful save, including immediate demo saves.
        summarySaveRevision = editorDraft.saveRevision
        persist(leave = isNew)
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
        onTranscribe(file, notes, currentSession(), { notes = it }, { /* Recovery owns the recording until server acknowledgement. */ })
    }

    fun startMic() {
        if (!com.cbtipul.app.data.Entitlements.allowMutation(allowLocalDemo = false)) return
        val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        requestingRecording = true
        scope.launch {
            try {
                if (!checkAllowance(seconds = 0.0)) return@launch
                if (granted) {
                    try { recorder.startRecording(editorDraft.beginAudio(context)) }
                    catch (_: Exception) { localError = com.cbtipul.app.data.SummaryFailure.Kind.Local.message }
                } else permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
            } finally { requestingRecording = false }
        }
    }

    val safeguardControls: @Composable () -> Unit = {
        Column(Modifier.fillMaxWidth().padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            allowanceMessage?.let {
                AIUsageNotice(it, title = "מכסת AI")
                TextButton(onClick = { scope.launch { checkAllowance(seconds = 0.0) } }, enabled = !busy) { Text("בדיקת מכסה מחדש") }
            }
            if (editorDraft.recoveryFailed) {
                Text(com.cbtipul.app.data.SummaryFailure.Kind.Local.message, color = colors.error)
                TextButton(onClick = { editorDraft.persistRecovery() }) { Text("שמירת הטיוטה מחדש") }
            } // Successful local draft persistence is silent.
            localError?.let { Text(it, color = colors.error) }
            if (hasVersionConflict) {
                TextButton(onClick = { if (editorDraft.persistRecovery()) onCheckSessions() }, enabled = !busy && patient != null) { Text("בדיקת המפגש המעודכן — הטיוטה נשארת במכשיר") }
            }
            if (editorDraft.pendingCreation) {
                Text(if (editorDraft.recoverySaved && !editorDraft.recoveryFailed)
                    "לא ניתן לוודא אם הסיכום נשמר. הטיוטה נשמרה במכשיר. יש לבדוק ברשימת המפגשים לפני ניסיון נוסף."
                    else "לא ניתן לוודא אם הסיכום נשמר. לא ניתן לאשר שהטיוטה נשמרה במכשיר. יש לנסות לשמור את הטיוטה שוב לפני יציאה.", color = colors.textBody)
                TextButton(onClick = onCheckSessions, enabled = !busy && patient != null) { Text("בדיקה ברשימת המפגשים") }
                TextButton(onClick = { confirmRetry = true }, enabled = !busy) { Text("בדקתי ברשימה — ניסיון שמירה נוסף") }
            }
            if (editorDraft.hasSummaryDraft || editorDraft.audioName != null) {
                Row {
                    TextButton(onClick = {
                        val clip = android.content.ClipData.newPlainText("טיוטה", notes)
                        if (android.os.Build.VERSION.SDK_INT >= 33) clip.description.extras = android.os.PersistableBundle().apply { putBoolean("android.content.extra.IS_SENSITIVE", true) }
                        (context.getSystemService(android.content.Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager).setPrimaryClip(clip)
                    }, enabled = notes.isNotBlank()) { Text("העתקת הטיוטה") }
                    TextButton(onClick = { confirmDraftDelete = true }, enabled = !busy) { Text("מחיקת הטיוטה") }
                }
                TextButton(onClick = { if (editorDraft.persistRecovery()) onBack() }, enabled = !busy) { Text("שמירת טיוטה ויציאה") }
            }
        }
        if (confirmRetry) AlertDialog(onDismissRequest = { confirmRetry = false }, title = { Text("ניסיון שמירה נוסף") },
            text = { Text("ייתכן שהשמירה הקודמת הצליחה. ניסיון נוסף עלול ליצור מפגש כפול. יש להמשיך רק לאחר בדיקה ברשימת המפגשים.") },
            confirmButton = { TextButton(onClick = {
                confirmRetry = false
                if (editorDraft.persistRecovery()) {
                    editorDraft.pendingCreation = false
                    if (editorDraft.persistRecovery()) {
                        if (!busy && patient != null && owner == recoveryApp.authRepository.currentUserId()) onSave(currentSession(), isNew)
                    } else editorDraft.pendingCreation = true
                }
            }) { Text("בדקתי — לשמור שוב") } }, dismissButton = { TextButton(onClick = { confirmRetry = false }) { Text("ביטול") } })
        if (confirmDraftDelete) AlertDialog(onDismissRequest = { confirmDraftDelete = false }, title = { Text("מחיקת הטיוטה מהמכשיר?") },
            text = { Text("הטקסט וההקלטה המקומיים יימחקו. מפגש שכבר נשמר בשרת לא יימחק.") },
            confirmButton = { TextButton(onClick = {
                if (editorDraft.clearAudio(context) && editorDraft.clearRecovery(close = true)) { recorder.discard(); onBack() }
            }) { Text("מחיקת הטיוטה") } }, dismissButton = { TextButton(onClick = { confirmDraftDelete = false }) { Text("ביטול") } })
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
            if (notes != notesAtOpen) confirmLeavingNotes = true else {
                summarySaveRevision = null
                showingNotesEditor = false
            }
        }
        BackHandler { leaveNotes() }
        run {
            val editorFocus = remember { FocusRequester() }
            LaunchedEffect(editingSummaryText) { if (canWrite && editingSummaryText) editorFocus.requestFocus() }
            Scaffold(modifier = Modifier.fillMaxSize().imePadding(), containerColor = colors.surface,
                bottomBar = {
                    Surface(color = colors.surface, tonalElevation = 3.dp) {
                        Column {
                        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(stringResource(if (notes != baselineNotes) R.string.session_summary_unsaved else R.string.session_summary_section),
                                modifier = Modifier.weight(1f), style = MaterialTheme.typography.labelMedium, color = colors.textBody)
                            if (notes != baselineNotes && canWrite) TextButton(onClick = { saveSummary() }, enabled = canSave) { Text(stringResource(R.string.save_summary_action)) }
                        }
                        if (canWrite) Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            if (recorder.isRecording) TextButton(onClick = { recorder.stopRecording(); transcribePending() }) {
                                IconLabel(stringResource(R.string.stop_and_transcribe_action), Icons.Filled.StopCircle, color = colors.error)
                                Text(formatDuration(recorder.durationSeconds), color = colors.error)
                            } else if (recorder.recordingFile != null) {
                                TextButton(onClick = { transcribePending() }, enabled = !busy) { Text(if (editorDraft.transcriptReady) "ניסיון עיבוד נוסף" else stringResource(R.string.transcribe_action)) }
                                IconButton(onClick = { recorder.togglePlayback() }, enabled = !busy) {
                                    Icon(if (recorder.isPlaying) Icons.Filled.Stop else Icons.Filled.PlayArrow, stringResource(R.string.play_recording_action))
                                }
                                IconButton(onClick = { recorder.discard(); editorDraft.clearAudio(context) }, enabled = !busy) {
                                    Icon(Icons.Filled.Delete, stringResource(R.string.discard_recording_action))
                                }
                            } else TextButton(onClick = { startMic() }, enabled = !busy) {
                                IconLabel(stringResource(R.string.record_session_notes_action), Icons.Filled.Mic)
                            }
                        }
                        recorder.errorMessage?.let { Text(it, color = colors.error, modifier = Modifier.padding(horizontal = 16.dp)) }
                        }
                    }
                },
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
                                TextButton(onClick = { saveSummary() }, enabled = canSave) {
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
                    if (!editingSummaryText && notes.isNotBlank()) {
                        Text(notes, style = MaterialTheme.typography.bodyLarge, color = colors.textBright,
                            modifier = Modifier.fillMaxWidth().clickable(enabled = canWrite && !busy && !blocksNewSummary) { editingSummaryText = true }.padding(24.dp))
                    } else BasicTextField(value = notes, onValueChange = { notes = it },
                        textStyle = TextStyle(color = colors.textBright, fontSize = 18.sp, lineHeight = 28.sp, textAlign = TextAlign.Start),
                        cursorBrush = SolidColor(colors.gold),
                        modifier = Modifier.fillMaxWidth().heightIn(min = 96.dp)
                            .padding(horizontal = 24.dp, vertical = 20.dp)
                            .focusRequester(editorFocus),
                        decorationBox = { input ->
                            Box(Modifier.fillMaxWidth()) {
                                if (notes.isEmpty()) Text(stringResource(R.string.session_summary_field_placeholder),
                                    color = colors.textFaint, fontSize = 18.sp, lineHeight = 28.sp)
                                input()
                            }
                        }, readOnly = !canWrite || busy || blocksNewSummary)
                    if (!isSaving && notes != baselineNotes) Text(stringResource(R.string.session_summary_unsaved),
                        color = colors.textBody, fontSize = 12.sp,
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 8.dp))
                    if (isSaving) Text(stringResource(R.string.session_saving), color = colors.textBody,
                        fontSize = 12.sp, modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 12.dp))
                    safeguardControls()
                    errorMessage?.let { AIUsageNotice(it, Modifier.padding(horizontal = 24.dp, vertical = 8.dp)) }
                }
            }
        }
        BusyOverlay(isBusy = isSaving)
        DiscardChangesDialog(
            visible = confirmLeavingNotes,
            canSave = canSave,
            onSave = { confirmLeavingNotes = false; saveSummary() },
            onDiscard = {
                notes = notesAtOpen
                confirmLeavingNotes = false
                summarySaveRevision = null
                showingNotesEditor = false
            },
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
                        IconButton(onClick = { overflow = true }, enabled = canWrite && !busy && !blocksNewSummary) {
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
                if (hasUnsavedChanges && !busy) TextButton(onClick = { if (editorDraft.persistRecovery()) onBack() }) { Text(stringResource(R.string.keep_draft_and_leave)) }
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
                    hasUnsavedChanges -> R.string.session_not_saved
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
                if (canWrite && !busy && structuredNotes != baselineStructured) Text(
                    stringResource(R.string.session_ai_save_help), color = colors.textBody, fontSize = 12.sp,
                    textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
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
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            safeguardControls()
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
            } else Surface(color = (atmosphere ?: colors.gold).copy(alpha = .14f), shape = MaterialTheme.shapes.large) {
                Text(displayName, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold,
                    color = colors.textBright, modifier = Modifier.fillMaxWidth().padding(16.dp))
            }
            if (isNew) Text(stringResource(R.string.session_creation_help), color = colors.textBody, fontSize = 14.sp)
            Text(stringResource(R.string.session_date_title), color = colors.textBright)
            TextButton(onClick = { showDatePicker = true }, enabled = canWrite && !busy && !blocksNewSummary) { Text(hebrewDate(date), color = colors.gold) }
            ExposedDropdownMenuBox(typeExpanded, onExpandedChange = { if (canWrite && !busy) typeExpanded = it }) {
                OutlinedTextField(value = type?.let { stringResource(it.labelRes()) } ?: stringResource(R.string.session_type_none),
                    onValueChange = {}, readOnly = true, singleLine = true,
                    label = { Text(stringResource(R.string.session_type_label)) },
                    modifier = Modifier.fillMaxWidth().menuAnchor(), enabled = canWrite && !busy,
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(typeExpanded) })
                ExposedDropdownMenu(typeExpanded, onDismissRequest = { typeExpanded = false }) {
                    DropdownMenuItem(text = { Text(stringResource(R.string.session_type_none)) }, onClick = { type = null; typeExpanded = false })
                    SessionType.entries.forEach { option ->
                        DropdownMenuItem(text = { Text(stringResource(option.labelRes())) }, onClick = { type = option; typeExpanded = false })
                    }
                }
            }
            val accent = atmosphere ?: colors.gold
            if (showSummaryTools) {
                Text(stringResource(R.string.ui_session_summary), color = colors.textBright,
                    fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Start)
                GroupedListCard(accent = accent) {
                    val pending = recorder.recordingFile != null && !busy
                    Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            if (hasText) notes else stringResource(R.string.session_summary_field_placeholder),
                            color = if (hasText) colors.textBright else colors.textBody,
                            maxLines = 6, overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(enabled = !busy && (hasText || canWrite)) {
                                editingSummaryText = !hasText; showingNotesEditor = true
                            },
                        )
                        TextButton(onClick = { editingSummaryText = !hasText; showingNotesEditor = true }, enabled = !busy && (hasText || canWrite)) {
                            IconLabel(stringResource(when {
                                !canWrite && hasText -> R.string.session_open_summary
                                hasText -> R.string.session_read_notes
                                else -> R.string.session_write_notes
                            }), Icons.Outlined.EditNote)
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
                            TextButton(onClick = { startMic() }, enabled = canWrite && !busy && recorder.recordingFile == null && !tokensExhausted) {
                                IconLabel(stringResource(R.string.record_session_notes_action), Icons.Filled.Mic, color = colors.gold)
                            }
                        }
                    }
                    if (pending) {
                        GroupedListDivider()
                        Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(stringResource(R.string.session_pending_recording), color = colors.textBody, fontSize = 13.sp)
                            TextButton(onClick = { transcribePending() }) {
                                Text(stringResource(R.string.transcribe_action), color = colors.gold, fontWeight = FontWeight.SemiBold)
                            }
                            TextButton(onClick = { recorder.togglePlayback() }) {
                                Icon(if (recorder.isPlaying) Icons.Filled.Stop else Icons.Filled.PlayArrow,
                                    contentDescription = null, tint = colors.gold)
                                Text(stringResource(if (recorder.isPlaying) R.string.stop_playback_action else R.string.play_recording_action), color = colors.gold)
                            }
                            TextButton(onClick = { recorder.discard(); editorDraft.clearAudio(context) }) {
                                Icon(Icons.Filled.Delete, contentDescription = null, tint = colors.error)
                                Text(stringResource(R.string.discard_recording_action), color = colors.error)
                            }
                        }
                    }
                    if (isTranscribing || isAnonymizingTranscription) {
                        GroupedListDivider()
                        Row(Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                            horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                            CircularProgressIndicator(Modifier.size(18.dp), color = colors.gold, strokeWidth = 2.dp)
                            Text(stringResource(if (isTranscribing) R.string.transcribing_label else R.string.anonymizing_status_label), color = colors.textBody)
                        }
                    }
                    recorder.errorMessage?.let {
                        GroupedListDivider()
                        Text(it, color = colors.error, modifier = Modifier.padding(16.dp))
                    }
                }

                if (hasText || structuredNotes != null) {
                    Text(stringResource(R.string.session_optional_ai), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                    GroupedListCard(accent = accent) {
                        Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            structuredNotes?.let { analysis ->
                                Text(analysis.sessionSummary, color = colors.textBright, maxLines = 6,
                                    overflow = TextOverflow.Ellipsis, modifier = Modifier.fillMaxWidth())
                                TextButton(onClick = onOpenAnalysis, enabled = !busy) {
                                    IconLabel(stringResource(if (canWrite) R.string.session_view_edit_summary else R.string.session_open_summary), Icons.Outlined.EditNote)
                                }
                                GroupedListDivider()
                            }
                            Text(stringResource(R.string.session_ai_hint), color = colors.textBody, fontSize = 12.sp)
                            if (hasText) {
                                TextButton(
                                    onClick = { onAnalyze(currentSession(), { notes = it }, { structuredNotes = it }) },
                                    enabled = canWrite && !busy && recorder.recordingFile == null,
                                ) {
                                    if (isAnalyzing) {
                                        CircularProgressIndicator(Modifier.size(18.dp), color = colors.gold, strokeWidth = 2.dp)
                                        Text(stringResource(R.string.analyzing_label), color = colors.textBody, modifier = Modifier.padding(start = 8.dp))
                                    } else {
                                        IconLabel(stringResource(if (structuredNotes == null) R.string.ai_summary_action else R.string.session_regenerate), Icons.Outlined.AutoAwesome)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if (initial.databaseId != null) {
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

            errorMessage?.let { AIUsageNotice(it) }


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
            editorDraft.clearAudio(context)
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
