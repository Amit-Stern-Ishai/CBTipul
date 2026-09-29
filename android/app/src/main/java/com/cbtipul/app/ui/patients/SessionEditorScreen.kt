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

private enum class QuestionnaireAssignmentUi { Demo, Loading, NotConnected, Available, Pending, Failed }

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
    var pendingSave by editorDraft::pendingSave
    val hasText = notes.trim().isNotEmpty()
    val processing = isSaving || isTranscribing || isAnonymizingTranscription || isAnalyzing
    val context = LocalContext.current
    val assignmentScope = rememberCoroutineScope()
    var assignmentStatus by remember { mutableStateOf(QuestionnaireAssignmentUi.Loading) }
    var assignmentError by remember { mutableStateOf<String?>(null) }
    var isSendingQuestionnaire by remember { mutableStateOf(false) }
    val connectionError = stringResource(R.string.patient_connection_check_error)
    val sendError = stringResource(R.string.questionnaire_assignment_send_error)

    suspend fun loadAssignment() {
        if (isNew || questionnaire != null || assignmentRepository == null) return
        assignmentStatus = QuestionnaireAssignmentUi.Loading
        assignmentError = null
        if (questionnaireLoading) return
        if (questionnaireLoadError != null) {
            assignmentStatus = QuestionnaireAssignmentUi.Failed
            assignmentError = questionnaireLoadError
            return
        }
        if (isDemo || patient?.id?.let { DemoData.isDemoId(it) } == true) {
            assignmentStatus = QuestionnaireAssignmentUi.Demo
            return
        }
        val sessionId = initial.databaseId?.let { PatientAssignmentRepository.uuidOrNull(it) }
        val patientId = patient?.id?.let { PatientAssignmentRepository.uuidOrNull(it) }
        if (sessionId == null || patientId == null) {
            assignmentStatus = QuestionnaireAssignmentUi.Failed
            assignmentError = connectionError
            return
        }

        try {
            assignmentStatus = if (!assignmentRepository.isPatientConnected(patientId)) {
                QuestionnaireAssignmentUi.NotConnected
            } else if (assignmentRepository.openQuestionnaireAssignment(sessionId) != null) {
                QuestionnaireAssignmentUi.Pending
            } else {
                QuestionnaireAssignmentUi.Available
            }
        } catch (error: kotlinx.coroutines.CancellationException) { throw error } catch (_: Exception) {
            assignmentStatus = QuestionnaireAssignmentUi.Failed
            assignmentError = connectionError
        }
    }
    LaunchedEffect(initial.databaseId?.queryValue, questionnaire?.databaseId?.queryValue, questionnaireLoading, questionnaireLoadError) {
        loadAssignment()
    }
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
    val busy = processing || requestingRecording || recorder.isRecording || isSendingQuestionnaire

    fun currentSession() = initial.copy(date = date, notes = notes, type = type, structuredNotes = structuredNotes)

    val hasUnsavedChanges = date != baselineDate || notes != baselineNotes || type != baselineType ||
        structuredNotes != baselineStructured || recorder.recordingFile != null

    val canSave = patient != null && !busy && recorder.recordingFile == null && (isNew || hasUnsavedChanges)
    LaunchedEffect(isSaving) {
        if (!isSaving) pendingSave?.let { saved ->
            if (errorMessage == null) {
                baselineDate = saved.date; baselineNotes = saved.notes; baselineType = saved.type; baselineStructured = saved.structuredNotes
            }
            pendingSave = null
        }
    }
    fun persist(leave: Boolean) {
        if (!canSave) return
        pendingSave = currentSession()
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
        val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        if (granted) recorder.startRecording() else {
            requestingRecording = true
            permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
        }
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
                        IconButton(onClick = { overflow = true }, enabled = !busy) {
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
                    else -> R.string.session_saved
                }
                Text(
                    stringResource(status),
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
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            if (choosePatient) {
                var expanded by remember { mutableStateOf(false) }
                ExposedDropdownMenuBox(expanded, onExpandedChange = { if (!busy) expanded = it }) {
                    OutlinedTextField(value = patient?.displayName(unnamed) ?: stringResource(R.string.session_choose_patient_placeholder),
                        onValueChange = {}, readOnly = true, label = { Text(stringResource(R.string.choose_patient_for_session)) },
                        modifier = Modifier.fillMaxWidth().menuAnchor(), enabled = !busy,
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
            TextButton(onClick = { showDatePicker = true }, enabled = !busy) { Text(hebrewDate(date), color = colors.gold) }
            ExposedDropdownMenuBox(typeExpanded, onExpandedChange = { if (!busy) typeExpanded = it }) {
                OutlinedTextField(value = type?.let { stringResource(it.labelRes()) } ?: stringResource(R.string.session_type_none),
                    onValueChange = {}, readOnly = true, label = { Text(stringResource(R.string.session_type_label)) },
                    modifier = Modifier.fillMaxWidth().menuAnchor(), enabled = !busy,
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
                        .padding(start = 16.dp, top = 14.dp, end = 8.dp, bottom = 14.dp),
                ) {
                    NotesField(
                        value = notes,
                        onValueChange = { notes = it },
                        placeholder = stringResource(R.string.session_summary_field_placeholder),
                        modifier = Modifier
                            .fillMaxWidth()
                            .tutorialPulse(gettingStarted?.shouldPulse(TutorialHighlight.RecordNotes) == true),
                        enabled = !busy,
                    )
                    if (recorder.isRecording) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(formatDuration(recorder.durationSeconds), color = colors.error, fontWeight = FontWeight.SemiBold)
                            TextButton(onClick = {
                                recorder.stopRecording()
                                transcribePending()
                            }) {
                                Text(stringResource(R.string.stop_and_transcribe_action), color = colors.error)
                            }
                        }
                    } else {
                        TextButton(onClick = { startMic() }, enabled = !busy && recorder.recordingFile == null) {
                            Text(stringResource(R.string.record_session_notes_action), color = colors.gold)
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
                recorder.errorMessage?.let {
                    GroupedListDivider()
                    Text(it, color = colors.error, modifier = Modifier.padding(16.dp))
                }
            }
            Text(stringResource(R.string.session_recording_help), color = colors.textBody)
            Text(stringResource(R.string.session_optional_ai), color = colors.textBright, fontWeight = FontWeight.SemiBold)
            Text(stringResource(R.string.session_ai_help), color = colors.textBody)
            GroupedListCard(accent = accent) {
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
                            .tutorialPulse(gettingStarted?.shouldPulse(TutorialHighlight.AiSummary) == true)
                            .clickable(
                                enabled = !busy && recorder.recordingFile == null && hasText,
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
                            color = if (!busy && recorder.recordingFile == null && hasText) colors.gold else colors.textFaint,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                }
            }

            structuredNotes?.let { analysis ->
                Text(stringResource(R.string.structured_summary_section), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                GroupedListCard(accent = accent) {
                    NotesField(
                        value = analysis.sessionSummary,
                        onValueChange = {},
                        placeholder = "",
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
                        enabled = !busy,
                        readOnly = true,
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
                Text(stringResource(R.string.questionnaire_local_entry_help), color = colors.textBody)
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
                                Icon(Icons.Outlined.Add, contentDescription = null, tint = colors.gold, modifier = Modifier.size(16.dp))
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

            if (initial.databaseId != null && questionnaire == null && assignmentRepository != null) {
                GroupedListCard(accent = accent) {
                    when (assignmentStatus) {
                        QuestionnaireAssignmentUi.Demo -> Text(stringResource(R.string.questionnaire_demo_sending_unavailable), modifier = Modifier.padding(16.dp))
                        QuestionnaireAssignmentUi.Loading -> {
                            Box(Modifier.fillMaxWidth().padding(16.dp), contentAlignment = Alignment.Center) {
                                CircularProgressIndicator(Modifier.size(22.dp), color = colors.gold, strokeWidth = 2.dp)
                            }
                        }
                        QuestionnaireAssignmentUi.NotConnected -> {
                            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Text(stringResource(R.string.patient_not_connected_title), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                                Text(stringResource(R.string.patient_not_connected_body), color = colors.textBody, fontSize = 13.sp)
                            }
                        }
                        QuestionnaireAssignmentUi.Available -> {
                            Text(stringResource(R.string.patient_questionnaire_request_description), modifier = Modifier.padding(16.dp))
                            Text(
                                stringResource(R.string.send_questionnaire_to_patient),
                                color = colors.gold,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable(enabled = !isSendingQuestionnaire && !busy) {
                                        assignmentScope.launch {
                                            val sessionId = initial.databaseId?.let {
                                                PatientAssignmentRepository.uuidOrNull(it)
                                            } ?: return@launch
                                            val patientId = patient?.id?.let { PatientAssignmentRepository.uuidOrNull(it) } ?: return@launch
                                            isSendingQuestionnaire = true
                                            try {
                                                assignmentRepository.sendQuestionnaireAssignment(patientId, sessionId)
                                                assignmentStatus = QuestionnaireAssignmentUi.Pending
                                            } catch (_: PatientAssignmentException.PatientNotConnected) {
                                                assignmentStatus = QuestionnaireAssignmentUi.NotConnected
                                            } catch (_: Exception) {
                                                assignmentStatus = QuestionnaireAssignmentUi.Failed
                                                assignmentError = sendError
                                            } finally {
                                                isSendingQuestionnaire = false
                                            }
                                        }
                                    }
                                    .padding(16.dp),
                            )
                        }
                        QuestionnaireAssignmentUi.Pending -> {
                            TextButton(onClick = { onRefreshQuestionnaire() }) { Text(stringResource(R.string.questionnaire_refresh_action)) }
                            Text(
                                stringResource(R.string.questionnaire_awaiting_patient),
                                color = colors.textBody,
                                modifier = Modifier.padding(16.dp),
                            )
                        }
                        QuestionnaireAssignmentUi.Failed -> {
                            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text(assignmentError ?: sendError, color = colors.error, fontSize = 13.sp)
                                Text(
                                    stringResource(R.string.questionnaire_assignment_retry),
                                    color = colors.gold,
                                    fontWeight = FontWeight.SemiBold,
                                    modifier = Modifier.clickable(enabled = !busy) { onRefreshQuestionnaire() },
                                )
                            }
                        }
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
