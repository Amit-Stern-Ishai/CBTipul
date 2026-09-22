package com.cbtipul.app.ui.diary

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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.cbtipul.app.R
import com.cbtipul.app.data.DemoData
import com.cbtipul.app.data.DiaryFeeling
import com.cbtipul.app.data.DiaryOneEntry
import com.cbtipul.app.data.DiaryOneRepository
import com.cbtipul.app.data.PatientAssignmentException
import com.cbtipul.app.data.PatientAssignmentRepository
import com.cbtipul.app.data.PatientAssignmentType
import com.cbtipul.app.model.DatabaseId
import com.cbtipul.app.ui.patients.ConfirmDeleteOverlay
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.GroupedListDivider
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.hebrewDate
import com.cbtipul.app.ui.theme.themedScreen
import kotlinx.coroutines.launch

private enum class DiaryLoadState { Loading, Loaded, Failed }

private enum class PatientModeStatus { Loading, NotConnected, Inactive, Active, Failed }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TherapistDiaryOneScreen(
    patientId: DatabaseId,
    patientName: String,
    atmosphere: Color?,
    diary: DiaryOneRepository,
    assignments: PatientAssignmentRepository,
    isDemo: Boolean = false,
    onBack: () -> Unit,
) {
    val colors = Theme.colors
    val accent = atmosphere ?: colors.gold
    val scope = rememberCoroutineScope()
    val entriesMap by diary.entries.collectAsStateWithLifecycle()
    val entries = entriesMap[patientId.queryValue].orEmpty()
    var loadState by remember { mutableStateOf(DiaryLoadState.Loading) }
    var patientModeStatus by remember { mutableStateOf(PatientModeStatus.Loading) }
    var activeAssignmentId by remember { mutableStateOf<String?>(null) }
    var isUpdatingAssignment by remember { mutableStateOf(false) }
    var assignmentError by remember { mutableStateOf<String?>(null) }
    var showStopConfirm by remember { mutableStateOf(false) }
    var editor by remember { mutableStateOf<DiaryOneEntry?>(null) }
    var isCreating by remember { mutableStateOf(false) }
    var isSaving by remember { mutableStateOf(false) }
    var editorError by remember { mutableStateOf<String?>(null) }
    val saveFailed = stringResource(R.string.diary_one_save_failed)
    val deleteFailed = stringResource(R.string.diary_one_delete_failed)
    val activateFailed = stringResource(R.string.diary_patient_mode_activate_failed)
    val stopFailed = stringResource(R.string.diary_patient_mode_stop_failed)
    val connectionError = stringResource(R.string.patient_connection_check_error)

    suspend fun loadEntries() {
        if (entries.isEmpty()) loadState = DiaryLoadState.Loading
        loadState = try {
            diary.loadEntries(patientId)
            DiaryLoadState.Loaded
        } catch (_: Exception) {
            DiaryLoadState.Failed
        }
    }

    suspend fun loadPatientMode(showLoading: Boolean = true) {
        if (showLoading) {
            patientModeStatus = PatientModeStatus.Loading
            assignmentError = null
            activeAssignmentId = null
        }
        val patientUuid = PatientAssignmentRepository.uuidOrNull(patientId)
        if (patientUuid == null) {
            patientModeStatus = PatientModeStatus.Failed
            assignmentError = connectionError
            return
        }
        if (isDemo || DemoData.isDemoId(patientId)) {
            patientModeStatus = PatientModeStatus.NotConnected
            return
        }
        try {
            if (!assignments.isPatientConnected(patientUuid)) {
                patientModeStatus = PatientModeStatus.NotConnected
                return
            }
            val active = assignments.activeOngoingAssignment(patientUuid, PatientAssignmentType.DiaryOne)
            if (active != null) {
                activeAssignmentId = active.id
                patientModeStatus = PatientModeStatus.Active
            } else {
                patientModeStatus = PatientModeStatus.Inactive
            }
        } catch (_: Exception) {
            patientModeStatus = PatientModeStatus.Failed
            assignmentError = connectionError
        }
    }

    LaunchedEffect(patientId.queryValue) {
        loadEntries()
        loadPatientMode()
    }

    if (isCreating || editor != null) {
        val existing = editor
        DiaryOneEditorScreen(
            modeCreate = isCreating,
            existing = existing,
            patientName = patientName,
            atmosphere = atmosphere,
            onBack = {
                isCreating = false
                editor = null
                editorError = null
            },
            onSave = { event, thought, feelings, behaviour, physicalSymptoms ->
                scope.launch {
                    isSaving = true
                    editorError = null
                    try {
                        if (existing != null) {
                            diary.updateEntry(
                                id = existing.id,
                                patientId = patientId,
                                event = event,
                                thought = thought,
                                feelings = feelings,
                                behaviour = behaviour,
                                physicalSymptoms = physicalSymptoms,
                            )
                        } else {
                            diary.createEntry(
                                patientId = patientId,
                                event = event,
                                thought = thought,
                                feelings = feelings,
                                behaviour = behaviour,
                                physicalSymptoms = physicalSymptoms,
                            )
                        }
                        isCreating = false
                        editor = null
                    } catch (_: Exception) {
                        editorError = saveFailed
                    }
                    isSaving = false
                }
            },
            onDelete = if (existing != null) {
                {
                    scope.launch {
                        isSaving = true
                        editorError = null
                        try {
                            diary.deleteEntry(existing.id, patientId)
                            isCreating = false
                            editor = null
                        } catch (_: Exception) {
                            editorError = deleteFailed
                        }
                        isSaving = false
                    }
                }
            } else {
                null
            },
            isSaving = isSaving,
            error = editorError,
        )
        return
    }

    Scaffold(
        modifier = Modifier.themedScreen(atmosphere),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(stringResource(R.string.diary_one_title), color = colors.textBright)
                        if (patientName.isNotBlank()) {
                            Text(patientName, color = colors.textBody, fontSize = 13.sp)
                        }
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.AutoMirrored.Outlined.ArrowBack,
                            contentDescription = stringResource(R.string.back),
                            tint = colors.gold,
                        )
                    }
                },
                actions = {
                    IconButton(onClick = {
                        editorError = null
                        editor = null
                        isCreating = true
                    }) {
                        Icon(
                            Icons.Outlined.Add,
                            contentDescription = stringResource(R.string.diary_one_add_entry),
                            tint = colors.gold,
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
                .padding(padding),
        ) {
        PullToRefreshBox(
            isRefreshing = loadState == DiaryLoadState.Loading && entries.isNotEmpty(),
            onRefresh = {
                scope.launch {
                    loadEntries()
                    loadPatientMode()
                }
            },
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
        ) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                item {
                    GroupedListCard(accent = accent) {
                        PatientModeControl(
                            status = patientModeStatus,
                            assignmentError = assignmentError,
                            isUpdating = isUpdatingAssignment,
                            onActivate = {
                                scope.launch {
                                    if (isUpdatingAssignment || patientModeStatus != PatientModeStatus.Inactive) return@launch
                                    val patientUuid = PatientAssignmentRepository.uuidOrNull(patientId)
                                    if (patientUuid == null) {
                                        assignmentError = activateFailed
                                        return@launch
                                    }
                                    isUpdatingAssignment = true
                                    assignmentError = null
                                    try {
                                        val active = assignments.activateOngoingAssignment(
                                            patientUuid,
                                            PatientAssignmentType.DiaryOne,
                                        )
                                        activeAssignmentId = active.id
                                        loadPatientMode(showLoading = false)
                                    } catch (_: PatientAssignmentException.PatientNotConnected) {
                                        patientModeStatus = PatientModeStatus.NotConnected
                                    } catch (_: Exception) {
                                        assignmentError = activateFailed
                                        loadPatientMode(showLoading = false)
                                    }
                                    isUpdatingAssignment = false
                                }
                            },
                            onStop = { showStopConfirm = true },
                            onRetry = { scope.launch { loadPatientMode() } },
                        )
                    }
                }
                if (loadState == DiaryLoadState.Loading && entries.isEmpty()) {
                    item {
                        Box(
                            Modifier.fillMaxWidth().padding(vertical = 24.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            CircularProgressIndicator(color = colors.gold)
                        }
                    }
                } else if (loadState == DiaryLoadState.Failed) {
                    item {
                        GroupedListCard(accent = accent) {
                            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                Text(stringResource(R.string.diary_one_load_failed), color = colors.error, fontSize = 13.sp)
                                TextButton(onClick = { scope.launch { loadEntries() } }) {
                                    Text(stringResource(R.string.retry_action), color = colors.gold)
                                }
                            }
                        }
                    }
                }
                if (entries.isNotEmpty()) {
                    item {
                        GroupedListCard(accent = accent) {
                            entries.forEachIndexed { index, entry ->
                                DiaryEntrySummary(
                                    entry = entry,
                                    onClick = {
                                        editorError = null
                                        isCreating = false
                                        editor = entry
                                    },
                                )
                                if (index < entries.lastIndex) GroupedListDivider()
                            }
                        }
                    }
                } else if (loadState == DiaryLoadState.Loaded) {
                    item {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 24.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            Text(
                                stringResource(R.string.diary_one_empty_title),
                                color = colors.textBright,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 20.sp,
                                textAlign = TextAlign.Center,
                            )
                            Text(
                                stringResource(R.string.diary_one_empty_body),
                                color = colors.textBody,
                                fontSize = 14.sp,
                                textAlign = TextAlign.Center,
                            )
                        }
                    }
                }
                item { Spacer(Modifier.height(24.dp)) }
            }
        }
        Button(
            onClick = {
                editorError = null
                editor = null
                isCreating = true
            },
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(top = 8.dp, bottom = 12.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = colors.gold,
                contentColor = colors.textOnAccent,
            ),
        ) {
            Text(
                stringResource(
                    if (entries.isEmpty()) R.string.empty_diary_one_primary_action
                    else R.string.diary_one_add_entry,
                ),
            )
        }
        }
    }

    ConfirmDeleteOverlay(
        visible = showStopConfirm,
        title = stringResource(R.string.diary_patient_mode_stop_title),
        message = stringResource(R.string.diary_patient_mode_stop_message),
        confirmLabel = stringResource(R.string.diary_patient_mode_stop_confirm),
        onConfirm = {
            showStopConfirm = false
            val assignmentId = activeAssignmentId ?: return@ConfirmDeleteOverlay
            scope.launch {
                if (isUpdatingAssignment) return@launch
                isUpdatingAssignment = true
                assignmentError = null
                try {
                    assignments.cancelOngoingAssignment(assignmentId)
                    loadPatientMode(showLoading = false)
                } catch (_: Exception) {
                    assignmentError = stopFailed
                    loadPatientMode(showLoading = false)
                }
                isUpdatingAssignment = false
            }
        },
        onDismiss = { showStopConfirm = false },
    )
}

@Composable
private fun PatientModeControl(
    status: PatientModeStatus,
    assignmentError: String?,
    isUpdating: Boolean,
    onActivate: () -> Unit,
    onStop: () -> Unit,
    onRetry: () -> Unit,
) {
    val colors = Theme.colors
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            stringResource(R.string.diary_patient_mode_title),
            color = colors.textBright,
            fontWeight = FontWeight.SemiBold,
            fontSize = 14.sp,
        )
        when (status) {
            PatientModeStatus.Loading -> CircularProgressIndicator(
                modifier = Modifier.size(18.dp),
                color = colors.gold,
                strokeWidth = 2.dp,
            )
            PatientModeStatus.NotConnected -> Text(
                stringResource(R.string.diary_patient_mode_not_connected),
                color = colors.textBody,
                fontSize = 13.sp,
            )
            PatientModeStatus.Inactive -> {
                Text(
                    stringResource(R.string.diary_patient_mode_inactive_body),
                    color = colors.textBody,
                    fontSize = 13.sp,
                )
                TextButton(onClick = onActivate, enabled = !isUpdating) {
                    Text(
                        stringResource(R.string.diary_patient_mode_activate),
                        color = colors.gold,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
            PatientModeStatus.Active -> {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .background(colors.success, CircleShape),
                    )
                    Text(
                        stringResource(R.string.diary_patient_mode_active),
                        color = colors.textBright,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 13.sp,
                    )
                }
                TextButton(onClick = onStop, enabled = !isUpdating) {
                    Text(stringResource(R.string.diary_patient_mode_stop), color = colors.error, fontSize = 13.sp)
                }
            }
            PatientModeStatus.Failed -> {
                Text(
                    assignmentError ?: stringResource(R.string.patient_connection_check_error),
                    color = colors.error,
                    fontSize = 13.sp,
                )
                TextButton(onClick = onRetry, enabled = !isUpdating) {
                    Text(stringResource(R.string.retry_action), color = colors.gold)
                }
            }
        }
        if (assignmentError != null && (status == PatientModeStatus.Inactive || status == PatientModeStatus.Active)) {
            Text(assignmentError, color = colors.error, fontSize = 13.sp)
        }
    }
}

@Composable
private fun DiaryEntrySummary(
    entry: DiaryOneEntry,
    onClick: () -> Unit,
) {
    val colors = Theme.colors
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(hebrewDate(entry.createdAt), color = colors.textBright, fontWeight = FontWeight.SemiBold)
        LabeledLine(stringResource(R.string.diary_one_event_title), entry.event)
        LabeledLine(stringResource(R.string.diary_one_thought_title), entry.thought)
        LabeledLine(stringResource(R.string.diary_feelings_title), feelingsPreview(entry.feelings))
    }
}

@Composable
private fun LabeledLine(title: String, value: String) {
    val colors = Theme.colors
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(title, color = colors.textBody, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
        Text(value, color = colors.textBright, maxLines = 2)
    }
}

private fun feelingsPreview(feelings: List<DiaryFeeling>): String {
    val visible = feelings.take(3).joinToString(" · ") { "${it.name} ${it.intensity}%" }
    return if (feelings.size > 3) "$visible · +${feelings.size - 3}" else visible
}
