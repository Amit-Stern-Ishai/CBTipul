package com.cbtipul.app.ui.patient

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
import com.cbtipul.app.data.DiaryOneEntryDraft
import com.cbtipul.app.data.PatientDiaryOneSubmitError
import com.cbtipul.app.ui.diary.DiaryOneDraftFields
import com.cbtipul.app.ui.patients.DiscardChangesDialog
import com.cbtipul.app.ui.patients.MessageOverlay
import com.cbtipul.app.ui.theme.BusyOverlay
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.dismissKeyboardOnTap
import com.cbtipul.app.ui.theme.themedScreen
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PatientDiaryOneEntryScreen(
    onSubmit: suspend (
        event: String,
        thought: String,
        feelings: List<DiaryFeeling>,
        behaviour: String,
        physicalSymptoms: String?,
    ) -> Unit,
    onDiaryInactive: () -> Unit,
    onBack: () -> Unit,
) {
    val colors = Theme.colors
    val scope = rememberCoroutineScope()
    val initial = remember { DiaryOneEntryDraft() }
    var draft by remember { mutableStateOf(initial) }
    var didAttemptSave by remember { mutableStateOf(false) }
    var isSaving by remember { mutableStateOf(false) }
    var showValidation by remember { mutableStateOf(false) }
    var validationMessage by remember { mutableStateOf<String?>(null) }
    var showDiscard by remember { mutableStateOf(false) }
    var showInactive by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var inactiveMessage by remember { mutableStateOf<String?>(null) }
    val eventMissing = stringResource(R.string.diary_one_validation_event)
    val thoughtMissing = stringResource(R.string.diary_one_validation_thought)
    val feelingsRequired = stringResource(R.string.diary_one_validation_feelings)
    val feelingName = stringResource(R.string.diary_one_validation_feeling_name)
    val intensityGeneric = stringResource(R.string.diary_one_validation_feeling_intensity)
    val intensityNamed = stringResource(R.string.diary_one_validation_feeling_intensity_named)
    val behaviourMissing = stringResource(R.string.diary_one_validation_behaviour)
    val defaultInactive = stringResource(R.string.patient_diary_one_not_active)
    val defaultSubmitError = stringResource(R.string.patient_diary_one_submit_error)
    val hasUnsavedChanges = draft.comparableSnapshot != initial.comparableSnapshot

    fun currentValidation(): String? = draft.validationMessage(
        eventMissing = eventMissing,
        thoughtMissing = thoughtMissing,
        feelingsRequired = feelingsRequired,
        feelingName = feelingName,
        intensityFor = { name ->
            if (name.isBlank()) intensityGeneric else intensityNamed.format(name)
        },
        behaviourMissing = behaviourMissing,
    )

    fun requestBack() {
        if (isSaving) return
        if (hasUnsavedChanges) showDiscard = true else onBack()
    }

    fun submit() {
        if (isSaving) return
        didAttemptSave = true
        val message = currentValidation()
        val feelings = draft.persistedFeelings()
        if (message != null || feelings == null) {
            validationMessage = message ?: intensityGeneric
            showValidation = true
            return
        }
        isSaving = true
        errorMessage = null
        scope.launch {
            try {
                onSubmit(
                    draft.event.trim(),
                    draft.thought.trim(),
                    feelings,
                    draft.behaviour.trim(),
                    draft.physicalSymptoms.trim().ifEmpty { null },
                )
                onBack()
            } catch (error: PatientDiaryOneSubmitError.NotActive) {
                isSaving = false
                inactiveMessage = error.userMessage.ifBlank { defaultInactive }
                showInactive = true
            } catch (error: PatientDiaryOneSubmitError) {
                errorMessage = error.userMessage.ifBlank { defaultSubmitError }
                isSaving = false
            } catch (_: Exception) {
                errorMessage = defaultSubmitError
                isSaving = false
            }
        }
    }

    BackHandler(enabled = !isSaving) { requestBack() }

    Box(Modifier.fillMaxSize()) {
        Scaffold(
            modifier = Modifier
                .themedScreen(colors.gold)
                .dismissKeyboardOnTap()
                .imePadding(),
            containerColor = Color.Transparent,
            topBar = {
                TopAppBar(
                    title = { Text(stringResource(R.string.diary_one_title), color = colors.textBright) },
                    navigationIcon = {
                        IconButton(onClick = { requestBack() }, enabled = !isSaving) {
                            Icon(
                                Icons.AutoMirrored.Outlined.ArrowBack,
                                contentDescription = stringResource(R.string.back),
                                tint = colors.gold,
                            )
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                )
            },
            bottomBar = {
                Button(
                    onClick = { submit() },
                    enabled = !isSaving,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp, vertical = 16.dp)
                        .height(48.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = colors.gold,
                        contentColor = colors.textOnAccent,
                        disabledContainerColor = colors.goldDim,
                    ),
                    shape = RoundedCornerShape(14.dp),
                ) {
                    Text(stringResource(R.string.patient_diary_one_save_action), fontWeight = FontWeight.SemiBold)
                }
            },
        ) { padding ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp)
                    .padding(top = 12.dp, bottom = 28.dp),
            ) {
                DiaryOneDraftFields(
                    draft = draft,
                    didAttemptSave = didAttemptSave,
                    errorMessage = errorMessage,
                    onChange = { draft = it },
                )
            }
        }
        BusyOverlay(
            isBusy = isSaving,
            label = stringResource(R.string.patient_diary_one_submitting),
        )
    }

    MessageOverlay(
        visible = showValidation,
        title = stringResource(R.string.diary_one_validation_title),
        message = validationMessage.orEmpty(),
        onDismiss = { showValidation = false },
    )
    DiscardChangesDialog(
        visible = showDiscard,
        canSave = false,
        onSave = {},
        onDiscard = {
            showDiscard = false
            onBack()
        },
        onKeepEditing = { showDiscard = false },
    )
    if (showInactive) {
        AlertDialog(
            onDismissRequest = {},
            title = { Text(stringResource(R.string.patient_diary_one_not_active_title)) },
            text = { Text(inactiveMessage ?: defaultInactive) },
            confirmButton = {
                TextButton(
                    onClick = {
                        showInactive = false
                        onDiaryInactive()
                        onBack()
                    },
                ) {
                    Text(stringResource(R.string.ok), color = colors.gold)
                }
            },
        )
    }
}
