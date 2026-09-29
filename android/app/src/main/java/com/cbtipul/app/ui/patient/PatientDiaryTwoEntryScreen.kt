package com.cbtipul.app.ui.patient

import com.cbtipul.app.ui.theme.editorScroll
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.cbtipul.app.R
import com.cbtipul.app.data.DiaryFeeling
import com.cbtipul.app.data.DiaryTwoEntryDraft
import com.cbtipul.app.data.PatientDiaryTwoSubmitError
import com.cbtipul.app.data.PatientDiaryTwoAccess
import androidx.compose.runtime.LaunchedEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.createSavedStateHandle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import androidx.compose.foundation.layout.navigationBarsPadding
import com.cbtipul.app.ui.diary.DiaryTwoDraftFields
import com.cbtipul.app.ui.patients.DiscardChangesDialog
import com.cbtipul.app.ui.patients.MessageOverlay
import com.cbtipul.app.ui.theme.BusyOverlay
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.dismissKeyboardOnTap
import com.cbtipul.app.ui.theme.themedScreen
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PatientDiaryTwoEntryScreen(
    patientId: String,
    service: PatientDiaryTwoAccess,
    onSubmitted: () -> Unit,
    onDiaryInactive: () -> Unit,
    onBack: () -> Unit,
) {
    val colors = Theme.colors
    val vm: PatientDiaryTwoViewModel = viewModel(key = "patient-diary-two-form-$patientId", factory = viewModelFactory {
        initializer { PatientDiaryTwoViewModel(patientId, service, createSavedStateHandle()) }
    })
    val state by vm.state.collectAsStateWithLifecycle()
    val initial = remember { DiaryTwoEntryDraft() }
    val savedDraft = com.cbtipul.app.ui.forms.rememberDeviceFormDraft("diary-two", patientId, DiaryTwoEntryDraft.serializer(), initial)
    val draft = savedDraft.value
    var attempted by remember { mutableStateOf(false) }
    var leaving by remember { mutableStateOf(false) }
    var cleanupError by remember { mutableStateOf(false) }
    var showValidation by remember { mutableStateOf(false) }
    val didSubmit = state.submittedId != null
    fun finish() {
        if (savedDraft.clear()) onSubmitted() else cleanupError = true
    }
    LaunchedEffect(state.submittedId) { if (state.submittedId != null) finish() }
    fun requestBack() {
        if (state.submitting) return
        if (didSubmit) finish()
        else if (draft.event.isNotBlank() || draft.persistedAutomaticThoughts.isNotEmpty() || draft.feelings.isNotEmpty() || draft.thinkingErrors.isNotEmpty() || draft.persistedAlternativeThoughts.isNotEmpty()) leaving = true
        else onBack()
    }
    BackHandler { requestBack() }
    if (leaving) com.cbtipul.app.ui.forms.DraftLeaveDialog(
        onKeep = { leaving = false; if (savedDraft.persist()) onBack() },
        onDiscard = { leaving = false; if (savedDraft.clear()) onBack() },
        onCancel = { leaving = false },
    )
    Box(Modifier.fillMaxSize()) {
        Scaffold(
            modifier = Modifier.themedScreen(colors.gold).dismissKeyboardOnTap().imePadding(),
            containerColor = Color.Transparent,
            topBar = { TopAppBar(
                title = { Text(stringResource(R.string.diary_two_title), color = colors.textBright) },
                navigationIcon = { IconButton(onClick = ::requestBack, enabled = !state.submitting) {
                    Icon(Icons.AutoMirrored.Outlined.ArrowBack, stringResource(R.string.back), tint = colors.gold)
                } }, colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            ) },
            bottomBar = {
                Button(onClick = { attempted = true; if (didSubmit) finish() else if (draft.validationError() != null) showValidation = true else vm.submit(draft) },
                    enabled = !state.submitting,
                    modifier = Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 20.dp, vertical = 16.dp).height(48.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = colors.accentFill, contentColor = colors.textOnAccent),
                ) { Text(stringResource(if (didSubmit) R.string.done else R.string.patient_diary_one_save_action)) }
            },
        ) { padding ->
            Column(Modifier.fillMaxSize().padding(padding).editorScroll().padding(20.dp)) {
                com.cbtipul.app.ui.forms.DraftStatus(savedDraft.failed, savedDraft.hasSaved)
                DiaryTwoDraftFields(draft, attempted, state.error?.messageRes) {
                    if (!state.submitting && !didSubmit) savedDraft.value = it
                }
                if (cleanupError) Text(stringResource(R.string.submitted_draft_cleanup), color = colors.error)
            }
        }
        BusyOverlay(isBusy = state.submitting, label = stringResource(R.string.patient_diary_one_submitting))
    }
    MessageOverlay(visible = showValidation,
        title = stringResource(R.string.diary_one_validation_title),
        message = stringResource(draft.validationError() ?: R.string.diary_one_validation_event),
        onDismiss = { showValidation = false })
    if (state.error?.kind == PatientDiaryTwoSubmitError.Kind.NotActive) {
        AlertDialog(onDismissRequest = {},
            title = { Text(stringResource(R.string.patient_diary_one_not_active_title)) },
            text = { Text(stringResource(R.string.patient_diary_two_not_active)) },
            confirmButton = { TextButton(onClick = { savedDraft.clear(); onDiaryInactive() }) { Text(stringResource(R.string.ok)) } },
        )
    }
}
