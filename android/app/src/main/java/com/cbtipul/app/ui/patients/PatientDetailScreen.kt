package com.cbtipul.app.ui.patients

import androidx.compose.material.icons.automirrored.outlined.Notes
import androidx.compose.material.icons.automirrored.outlined.LibraryBooks
import androidx.compose.material.icons.outlined.FindInPage
import androidx.compose.material.icons.outlined.Assignment
import androidx.compose.material.icons.outlined.Book
import androidx.compose.material.icons.filled.StopCircle
import com.cbtipul.app.ui.theme.IconLabel
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.material3.MaterialTheme
import androidx.compose.material.icons.automirrored.outlined.KeyboardArrowRight
import com.cbtipul.app.ui.theme.editorScroll
import com.cbtipul.app.ui.theme.editorFocus
import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.outlined.KeyboardArrowDown
import androidx.compose.material.icons.automirrored.outlined.ShowChart
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
import androidx.compose.material.icons.outlined.MailOutline
import androidx.compose.material.icons.outlined.MenuBook
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.cbtipul.app.R
import com.cbtipul.app.data.DemoData
import com.cbtipul.app.data.PatientAssignmentException
import com.cbtipul.app.data.PatientAssignmentRepository
import com.cbtipul.app.model.CombinedMoodQuestionnaire
import com.cbtipul.app.model.Patient
import com.cbtipul.app.model.PatientStatus
import com.cbtipul.app.model.SessionType
import com.cbtipul.app.ui.theme.BusyOverlay
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.GroupedListDivider
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.dismissKeyboardOnTap
import com.cbtipul.app.ui.onboarding.TutorialHighlight
import com.cbtipul.app.ui.onboarding.tutorialPulse
import com.cbtipul.app.ui.theme.themedScreen
import java.io.File
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
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
    onOpenGraphs: () -> Unit = {},
    onOpenDiaryOne: () -> Unit = {},
    onOpenDiaryTwo: () -> Unit = {},
    onOpenDiaryThree: () -> Unit = {},
    onInvitePatient: () -> Unit = {},
    isCreatingInvitation: Boolean = false,
    onSendMessage: () -> Unit = {},
    onOpenMessages: () -> Unit = {},
    assignmentRepository: PatientAssignmentRepository? = null,
    isDemo: Boolean = false,
    onOpenChat: () -> Unit,
    isPreparing: Boolean,
    savedPreparationDate: String?,
    isPreparationOutdated: Boolean,
    prepareError: String?,
    onPrepare: () -> Unit,
    onOpenLastPreparation: () -> Unit,
    notesError: String?,
    isSavingNotes: Boolean,
    isSavingStatus: Boolean = false,
    isTranscribing: Boolean,
    isAnonymizingTranscription: Boolean,
    onSaveNotes: (String, Boolean) -> Unit,
    onTranscribe: (File, String, (String) -> Unit, () -> Unit) -> Unit,
    onDelete: () -> Unit,
    gettingStarted: com.cbtipul.app.ui.onboarding.GettingStartedRouter? = null,
) {
    val colors = Theme.colors

    LaunchedEffect(patient?.id?.queryValue) {
        gettingStarted?.setPlacement(
            com.cbtipul.app.ui.onboarding.TutorialCoachPlacement.PatientDetail,
            viewingPatientId = patient?.id,
        )
    }

    if (patient == null) {
        BoxMissing(onBack)
        return
    }
    var showNotes by remember { mutableStateOf(false) }
    var diariesExpanded by remember { mutableStateOf(false) }
    val diariesArrowRotation by animateFloatAsState(
        targetValue = if (diariesExpanded) 180f else 0f,
        animationSpec = tween(180),
        label = "diariesExpansion",
    )
    var closeNotesAfterSave by remember { mutableStateOf(false) }
    var showRename by remember { mutableStateOf(false) }
    var showGoal by remember { mutableStateOf(false) }
    var goalDraft by remember { mutableStateOf("") }
    var showDeleteConfirm by remember { mutableStateOf(false) }
    var showDeleteCode by remember { mutableStateOf(false) }
    var overflow by remember { mutableStateOf(false) }
    var statusExpanded by remember { mutableStateOf(false) }
    val name = patient.displayName(unnamed)
    val treatmentGoal = patient.formulation?.treatmentGoal.orEmpty()
    val processing = isSavingNotes || isSavingStatus || isSavingGoal || isTranscribing || isAnonymizingTranscription
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
    val busy = processing || requestingRecording || recorder.isRecording
    var notes by remember(patient.id.queryValue, patient.notes) { mutableStateOf(patient.notes) }
    var showDiscard by remember { mutableStateOf(false) }
    val hasUnsavedChanges = notes != patient.notes || recorder.recordingFile != null
    LaunchedEffect(isSavingNotes, patient.notes) {
        if (closeNotesAfterSave && !isSavingNotes) {
            if (notesError == null && notes == patient.notes) showNotes = false
            closeNotesAfterSave = false
        }
    }
    val scope = rememberCoroutineScope()
    var isSendingQuestionnaire by remember { mutableStateOf(false) }
    var sendFeedbackTitle by remember { mutableStateOf<String?>(null) }
    var sendFeedbackMessage by remember { mutableStateOf<String?>(null) }
    val sendQuestionnaireTitle = stringResource(R.string.send_questionnaire_to_patient)
    val questionnaireSent = stringResource(R.string.questionnaire_sent_to_patient)
    val questionnaireSendError = stringResource(R.string.questionnaire_assignment_send_error)
    val notConnectedTitle = stringResource(R.string.patient_not_connected_title)
    val notConnectedBody = stringResource(R.string.patient_not_connected_body)
    val invalidPatient = stringResource(R.string.patient_invitation_invalid_patient)

    fun requestBack() {
        if (busy) return
        if (hasUnsavedChanges) showDiscard = true else if (showNotes) showNotes = false else onBack()
    }

    BackHandler(enabled = true) { requestBack() }

    fun transcribePending() {
        val file = recorder.recordingFile ?: return
        onTranscribe(file, notes, { notes = it }, { recorder.discard() })
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
            .themedScreen(PatientAvatarColor.background(patient.id))
            .dismissKeyboardOnTap(),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(if (showNotes) stringResource(R.string.patient_notes_title) else name, color = colors.textBright) },
                navigationIcon = {
                    IconButton(onClick = { requestBack() }) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = stringResource(R.string.back), tint = colors.gold)
                    }
                },
                actions = {
                    if (showNotes) TextButton(
                        onClick = { onSaveNotes(notes, false) },
                        enabled = !busy && hasUnsavedChanges && recorder.recordingFile == null,
                    ) {
                        Text(
                            stringResource(R.string.save),
                            color = if (!busy && hasUnsavedChanges) colors.gold else colors.textFaint,
                        )
                    }
                    IconButton(onClick = { overflow = true }, enabled = !busy) {
                        Icon(Icons.Filled.MoreVert, contentDescription = null, tint = colors.gold)
                    }
                    DropdownMenu(expanded = overflow, onDismissRequest = { overflow = false }) {
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.delete_patient_action), color = colors.error) },
                            onClick = {
                                overflow = false
                                showDeleteConfirm = true
                            },
                        )
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
                .imePadding()
                .editorScroll()
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            val accent = PatientAvatarColor.background(patient.id)
            if (!showNotes) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                    Spacer(Modifier.size(48.dp))
                    Text(name, color = colors.textBright, fontWeight = FontWeight.Bold, fontSize = 26.sp,
                        textAlign = TextAlign.Center, modifier = Modifier.weight(1f, fill = false))
                    IconButton(onClick = { showRename = true }, enabled = !busy, modifier = Modifier.size(48.dp)) {
                        Icon(Icons.Outlined.Edit, contentDescription = stringResource(R.string.edit_patient_name_action), tint = colors.gold)
                    }
                }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                    Spacer(Modifier.size(48.dp))
                    Text(treatmentGoal.ifEmpty { stringResource(R.string.no_treatment_goal_placeholder) },
                        color = colors.textBody, textAlign = TextAlign.Center, modifier = Modifier.weight(1f, fill = false))
                    IconButton(onClick = { goalDraft = treatmentGoal; showGoal = true }, enabled = !busy, modifier = Modifier.size(48.dp)) {
                        Icon(Icons.Outlined.Edit, contentDescription = stringResource(R.string.edit_treatment_goal_action), tint = colors.gold)
                    }
                }
            }

            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                TextButton(onClick = { statusExpanded = true }, enabled = !busy) {
                    Text(stringResource(if (patient.status == PatientStatus.Active) R.string.patient_status_active else R.string.patient_status_inactive))
                }
                DropdownMenu(expanded = statusExpanded, onDismissRequest = { statusExpanded = false }) {
                    PatientStatus.entries.forEach { status ->
                        DropdownMenuItem(text = { Text(stringResource(if (status == PatientStatus.Active) R.string.patient_status_active else R.string.patient_status_inactive)) },
                            onClick = { statusExpanded = false; onStatusChange(status) })
                    }
                }
            }
            PatientConnectionActions(patient, name, assignmentRepository, isDemo, busy || isCreatingInvitation, onInvitePatient, onSendMessage)
            Text(stringResource(R.string.patient_records_title), color = colors.textBody)
            GroupedListCard(accent = accent) {
                IconChipRow(Icons.Outlined.DateRange, stringResource(R.string.sessions_title), detail = stringResource(R.string.patient_sessions_description), onClick = onOpenSessions)
                GroupedListDivider()
                IconChipRow(Icons.AutoMirrored.Outlined.LibraryBooks, stringResource(R.string.patient_diaries_title),
                    trailing = { Icon(Icons.Outlined.KeyboardArrowDown, contentDescription = null, tint = colors.gold, modifier = Modifier.rotate(diariesArrowRotation)) },
                    onClick = { diariesExpanded = !diariesExpanded })
                AnimatedVisibility(
                    visible = diariesExpanded,
                    enter = expandVertically(tween(180), expandFrom = Alignment.Top) + fadeIn(tween(180)),
                    exit = shrinkVertically(tween(180), shrinkTowards = Alignment.Top) + fadeOut(tween(120)),
                ) {
                    Column {
                        IconChipRow(Icons.Outlined.Book, stringResource(R.string.diary_one_title),
                            detail = stringResource(R.string.patient_diary_one_description), onClick = onOpenDiaryOne)
                        IconChipRow(Icons.Outlined.Book, stringResource(R.string.diary_two_title),
                            detail = stringResource(R.string.patient_diary_two_description), onClick = onOpenDiaryTwo)
                        IconChipRow(Icons.Outlined.Book, stringResource(R.string.diary_three_title),
                            detail = stringResource(R.string.patient_diary_three_description), onClick = onOpenDiaryThree)
                    }
                }
                GroupedListDivider()
                IconChipRow(Icons.Outlined.Assignment, stringResource(R.string.questionnaire_history_title), detail = stringResource(R.string.patient_questionnaires_description), onClick = onOpenQuestionnaires)
                GroupedListDivider()
                IconChipRow(Icons.AutoMirrored.Outlined.ShowChart, stringResource(R.string.graphs_and_trends_title), detail = stringResource(R.string.patient_graphs_description), onClick = onOpenGraphs)
                GroupedListDivider()
                IconChipRow(Icons.Outlined.MailOutline, stringResource(R.string.messages_title), onClick = onOpenMessages)
                GroupedListDivider()
                IconChipRow(Icons.AutoMirrored.Outlined.Notes, stringResource(R.string.patient_notes_title), detail = stringResource(R.string.patient_notes_description), onClick = { showNotes = true })
            }
            Text(stringResource(R.string.additional_assistance_title), color = colors.textBody)
            GroupedListCard(accent = accent) {
                IconChipRow(Icons.Outlined.AutoAwesome, stringResource(R.string.patient_ai_assistance_title), onClick = onOpenChat)
                GroupedListDivider()
                IconChipRow(Icons.Outlined.AutoFixHigh, stringResource(R.string.prepare_next_session_action), enabled = !isPreparing,
                    trailing = { if (isPreparing) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp) }, onClick = onPrepare)
                if (savedPreparationDate != null) {
                    GroupedListDivider()
                    IconChipRow(Icons.Outlined.FindInPage, stringResource(R.string.last_preparation_action), trailing = {
                        Column(horizontalAlignment = Alignment.End) {
                            Text(savedPreparationDate, color = colors.textBody, fontSize = 12.sp)
                            if (isPreparationOutdated) Text(stringResource(R.string.outdated_badge), color = colors.warning, fontSize = 11.sp)
                        }
                    }, onClick = onOpenLastPreparation)
                }
            }
            prepareError?.let { Text(it, color = colors.error) }
            }
            if (showNotes) {
            Text(stringResource(R.string.notes_section), color = colors.textBright, fontWeight = FontWeight.SemiBold)
            GroupedListCard(
                accent = accent,
            ) {
                val pending = recorder.recordingFile != null && !isTranscribing && !isAnonymizingTranscription
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(start = 16.dp, top = 14.dp, end = 8.dp, bottom = 14.dp),
                ) {
                    NotesField(
                        value = notes,
                        onValueChange = { notes = it },
                        placeholder = stringResource(R.string.patient_notes_field_placeholder),
                        modifier = Modifier.fillMaxWidth(),
                        enabled = !busy,
                    )
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
                        TextButton(onClick = { startMic() }, enabled = !busy && recorder.recordingFile == null) {
                            IconLabel(stringResource(R.string.record_patient_notes_action), Icons.Filled.Mic, color = colors.gold)
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
            }

            notesError?.let { Text(it, color = colors.error) }
            }
        }
    }
        BusyOverlay(
            isBusy = isSavingNotes || isSavingStatus || isAnonymizingTranscription,
            label = if (isAnonymizingTranscription) stringResource(R.string.anonymizing_status_label) else null,
        )
        if (showGoal) {
            EditGoalOverlay(
                value = goalDraft,
                onValueChange = { goalDraft = it },
                onDismiss = { showGoal = false },
                onSave = {
                    onSaveGoal(goalDraft.trim())
                    showGoal = false
                },
            )
        }
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
    if (showDeleteConfirm) {
        ConfirmDeleteOverlay(
            visible = true,
            title = stringResource(R.string.delete_patient_confirm_title),
            message = stringResource(R.string.delete_patient_confirm_message),
            confirmLabel = stringResource(R.string.delete_patient_action),
            onConfirm = {
                showDeleteConfirm = false
                showDeleteCode = true
            },
            onDismiss = { showDeleteConfirm = false },
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
        canSave = !busy && recorder.recordingFile == null,
        onSave = {
            showDiscard = false
            closeNotesAfterSave = true
            onSaveNotes(notes, false)
        },
        onDiscard = {
            showDiscard = false
            recorder.discard()
            notes = patient.notes
            showNotes = false
        },
        onKeepEditing = { showDiscard = false },
    )
    MessageOverlay(
        visible = sendFeedbackTitle != null,
        title = sendFeedbackTitle.orEmpty(),
        message = sendFeedbackMessage.orEmpty(),
        onDismiss = {
            sendFeedbackTitle = null
            sendFeedbackMessage = null
        },
    )
}

@Composable
private fun BoxMissing(onBack: () -> Unit) {
    NotificationTargetScreen(onBack = onBack)
}

@Composable
private fun IconChipRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    enabled: Boolean = true,
    detail: String? = null,
    trailing: @Composable () -> Unit = { Icon(Icons.AutoMirrored.Outlined.KeyboardArrowRight, contentDescription = null, tint = Theme.colors.textFaint) },
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = Theme.colors
    Row(
        modifier = modifier.then(Modifier)
            .fillMaxWidth()
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .background(colors.goldGhost, RoundedCornerShape(11.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = colors.gold, modifier = Modifier.size(18.dp))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, color = colors.textBright, fontWeight = FontWeight.SemiBold)
            detail?.let { Text(it, color = colors.textBody, style = MaterialTheme.typography.bodyMedium) }
        }
        trailing()
    }
}

@Composable
private fun EditGoalOverlay(
    value: String,
    onValueChange: (String) -> Unit,
    onDismiss: () -> Unit,
    onSave: () -> Unit,
) {
    val colors = Theme.colors
    BackHandler(onBack = onDismiss)
    Box(Modifier.fillMaxSize().imePadding()) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.5f))
                .clickable(onClick = onDismiss),
        )
        Surface(
            modifier = Modifier
                .align(Alignment.Center)
                .padding(24.dp)
                .fillMaxWidth(),
            shape = RoundedCornerShape(28.dp),
            color = colors.elevated,
        ) {
            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()).padding(24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Text(
                    stringResource(R.string.edit_treatment_goal_action),
                    color = colors.textBright,
                    fontWeight = FontWeight.SemiBold,
                )
                OutlinedTextField(
                    value = value,
                    onValueChange = onValueChange,
                    modifier = Modifier.editorFocus().fillMaxWidth(),
                    minLines = 2,
                    textStyle = TextStyle(
                        color = colors.textBright,
                        textDirection = TextDirection.Rtl,
                        textAlign = TextAlign.Right,
                    ),
                    placeholder = {
                        Text(
                            stringResource(R.string.no_treatment_goal_placeholder),
                            modifier = Modifier.fillMaxWidth(),
                            textAlign = TextAlign.Right,
                        )
                    },
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    TextButton(onClick = onSave) { Text(stringResource(R.string.save)) }
                    TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) }
                }
            }
        }
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
    AppDialogOverlay(onDismiss = onDismiss) {
        Text(
            stringResource(R.string.edit_patient_name_title),
            color = Theme.colors.textBright,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Right,
        )
        OutlinedTextField(
            value = first,
            onValueChange = { first = it },
            modifier = Modifier.editorFocus().fillMaxWidth(),
            textStyle = TextStyle(
                color = Theme.colors.textBright,
                textDirection = TextDirection.Rtl,
                textAlign = TextAlign.Right,
            ),
            placeholder = {
                Text(
                    stringResource(R.string.first_name_placeholder),
                    modifier = Modifier.fillMaxWidth(),
                    textAlign = TextAlign.Right,
                )
            },
        )
        OutlinedTextField(
            value = last,
            onValueChange = { last = it },
            modifier = Modifier.editorFocus().fillMaxWidth(),
            textStyle = TextStyle(
                color = Theme.colors.textBright,
                textDirection = TextDirection.Rtl,
                textAlign = TextAlign.Right,
            ),
            placeholder = {
                Text(
                    stringResource(R.string.last_name_placeholder),
                    modifier = Modifier.fillMaxWidth(),
                    textAlign = TextAlign.Right,
                )
            },
        )
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            TextButton(
                onClick = { onSave(first.trim(), last.trim()) },
                enabled = first.trim().isNotEmpty() || last.trim().isNotEmpty(),
            ) { Text(stringResource(R.string.save), color = Theme.colors.gold) }
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel), color = Theme.colors.gold) }
        }
    }
}

private fun formatDuration(seconds: Double): String {
    val total = seconds.toInt().coerceAtLeast(0)
    return "%d:%02d".format(total / 60, total % 60)
}
