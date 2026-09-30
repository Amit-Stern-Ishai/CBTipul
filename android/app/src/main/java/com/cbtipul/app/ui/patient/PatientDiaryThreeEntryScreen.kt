package com.cbtipul.app.ui.patient

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.createSavedStateHandle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.cbtipul.app.CbTipulApp
import com.cbtipul.app.R
import com.cbtipul.app.data.*
import com.cbtipul.app.ui.diary.DiaryThreeDraftFields
import com.cbtipul.app.ui.forms.DraftLeaveDialog
import com.cbtipul.app.ui.forms.DraftStatus
import com.cbtipul.app.ui.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PatientDiaryThreeEntryScreen(
    patientId: String,
    service: PatientDiaryThreeAccess,
    onSubmitted: () -> Unit,
    onAccessInvalidated: () -> Unit,
    onDiaryInactive: () -> Unit,
    onBack: () -> Unit,
) {
    val app = LocalContext.current.applicationContext as CbTipulApp
    val colors = Theme.colors
    val vm: PatientDiaryThreeViewModel = viewModel(key = "patient-diary-three-form-$patientId", factory = viewModelFactory {
        initializer {
            val account = app.authRepository.currentUserId()
            val key = account?.let { DeviceFormDraftStore.key(it, "patient-diary-three", patientId) }
            PatientDiaryThreeViewModel(patientId, service, createSavedStateHandle(), PatientDiaryThreeDraftPersistence(
                read = { app.formDrafts.read(requireNotNull(key)) },
                write = { app.formDrafts.write(requireNotNull(key), it) },
                clear = { app.formDrafts.clear(requireNotNull(key)) },
            ))
        }
    })
    val state by vm.state.collectAsStateWithLifecycle()
    val draft = state.draft
    var leaving by rememberSaveable { mutableStateOf(false) }
    val didSubmit = state.submittedId != null
    val unavailable = state.error?.kind in listOf(PatientDiaryThreeSubmitError.Kind.NotActive, PatientDiaryThreeSubmitError.Kind.AccessDenied)
    fun finish() { if (vm.consumeSuccessfulSubmission()) onSubmitted() }
    LaunchedEffect(state.navigationPending) { if (state.navigationPending) finish() }
    LaunchedEffect(unavailable) { if (unavailable) onAccessInvalidated() }
    fun close() {
        if (state.submitting) return
        if (didSubmit) finish() else if (draft.hasMeaningfulContent) leaving = true else onBack()
    }
    fun back() {
        if (state.submitting || unavailable) return
        if (!didSubmit && draft.currentStep > 1) vm.back() else close()
    }
    BackHandler { back() }
    if (leaving) DraftLeaveDialog(
        onKeep = { leaving = false; if (vm.persistDraft()) onBack() },
        onDiscard = { leaving = false; if (vm.clearDraft()) onBack() },
        onCancel = { leaving = false },
    )
    val scroll = rememberScrollState()
    val focus = androidx.compose.ui.platform.LocalFocusManager.current
    LaunchedEffect(draft.currentStep) { focus.clearFocus(); scroll.scrollTo(0) }
    val hints = listOf(R.string.patient_diary_three_step_1, R.string.patient_diary_three_step_2,
        R.string.patient_diary_three_step_3, R.string.patient_diary_three_step_4,
        R.string.patient_diary_three_step_5, R.string.patient_diary_three_step_6, R.string.patient_diary_three_step_7)
    Box(Modifier.fillMaxSize()) {
        Scaffold(modifier = Modifier.themedScreen(colors.gold).dismissKeyboardOnTap().imePadding(), containerColor = Color.Transparent,
            topBar = { Column {
                TopAppBar(title = { Text(stringResource(R.string.diary_three_title)) },
                navigationIcon = { IconButton(onClick = ::back, enabled = !state.submitting && !unavailable) {
                    Icon(Icons.AutoMirrored.Outlined.ArrowBack, stringResource(R.string.back))
                } },
                actions = { IconButton(onClick = ::close, enabled = !state.submitting && !unavailable) { Icon(Icons.Outlined.Close, stringResource(R.string.welcome_info_done_action)) } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent))
                Column(Modifier.padding(horizontal = 20.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(stringResource(R.string.patient_diary_three_progress, draft.currentStep), style = MaterialTheme.typography.labelLarge)
                    LinearProgressIndicator(progress = { draft.currentStep / 7f }, modifier = Modifier.fillMaxWidth())
                }
            } },
            bottomBar = {
                Row(Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 20.dp, vertical = 16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                    if (draft.currentStep > 1 && !didSubmit) TextButton(onClick = ::back, enabled = !state.submitting && !unavailable) {
                        Text(stringResource(R.string.diary_previous_step))
                    }
                    Button(onClick = { if (didSubmit) finish() else if (draft.currentStep == 7) vm.submit() else vm.next() },
                        enabled = !state.submitting && !unavailable,
                        modifier = Modifier.weight(1f).heightIn(min = 48.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = colors.accentFill, contentColor = colors.textOnAccent)) {
                        Text(stringResource(if (didSubmit) R.string.done else if (draft.currentStep == 7) R.string.patient_diary_one_save_action else R.string.introduction_next))
                    }
                }
            },
        ) { padding ->
            Column(Modifier.fillMaxSize().padding(padding).editorScroll(scroll).padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                DraftStatus(state.draftFailed, state.draftSaved)
                Text(stringResource(hints[draft.currentStep - 1]), color = colors.textBody)
                key(draft.currentStep) {
                    DiaryThreeDraftFields(draft.entry, attempted = false, step = draft.currentStep) {
                        vm.update(draft.copy(entry = it))
                    }
                }
                if (didSubmit && state.draftFailed) Text(stringResource(R.string.submitted_draft_cleanup), color = colors.error)
            }
        }
        BusyOverlay(state.submitting, stringResource(R.string.patient_diary_one_submitting))
    }
    state.error?.let { error ->
        AlertDialog(onDismissRequest = { if (!unavailable) vm.clearError() },
            title = { Text(stringResource(if (unavailable) R.string.patient_diary_one_not_active_title else R.string.diary_one_validation_title)) },
            text = { Text(stringResource(error.messageRes)) },
            confirmButton = { TextButton(onClick = { if (unavailable) { vm.clearDraft(); onDiaryInactive() } else vm.clearError() }) { Text(stringResource(R.string.ok)) } })
    }
}
