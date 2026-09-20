package com.cbtipul.app.ui.diary

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
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.data.DiaryFeeling
import com.cbtipul.app.data.DiaryOneEntry
import com.cbtipul.app.data.DiaryOneEntryDraft
import com.cbtipul.app.ui.patients.ConfirmDeleteOverlay
import com.cbtipul.app.ui.patients.DiscardChangesDialog
import com.cbtipul.app.ui.patients.MessageOverlay
import com.cbtipul.app.ui.theme.BusyOverlay
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.dismissKeyboardOnTap
import com.cbtipul.app.ui.theme.themedScreen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DiaryOneEditorScreen(
    modeCreate: Boolean,
    existing: DiaryOneEntry?,
    patientName: String,
    atmosphere: Color?,
    onBack: () -> Unit,
    onSave: (
        event: String,
        thought: String,
        feelings: List<DiaryFeeling>,
        behaviour: String,
        physicalSymptoms: String?,
    ) -> Unit,
    onDelete: (() -> Unit)? = null,
    isSaving: Boolean,
    error: String?,
) {
    val colors = Theme.colors
    val initial = remember(existing?.id, modeCreate) {
        if (!modeCreate && existing != null) DiaryOneEntryDraft.from(existing) else DiaryOneEntryDraft()
    }
    var draft by remember(existing?.id, modeCreate) { mutableStateOf(initial) }
    var didAttemptSave by remember { mutableStateOf(false) }
    var showValidation by remember { mutableStateOf(false) }
    var validationMessage by remember { mutableStateOf<String?>(null) }
    var showDiscard by remember { mutableStateOf(false) }
    var showDelete by remember { mutableStateOf(false) }
    val eventMissing = stringResource(R.string.diary_one_validation_event)
    val thoughtMissing = stringResource(R.string.diary_one_validation_thought)
    val feelingsRequired = stringResource(R.string.diary_one_validation_feelings)
    val feelingName = stringResource(R.string.diary_one_validation_feeling_name)
    val intensityGeneric = stringResource(R.string.diary_one_validation_feeling_intensity)
    val intensityNamed = stringResource(R.string.diary_one_validation_feeling_intensity_named)
    val behaviourMissing = stringResource(R.string.diary_one_validation_behaviour)
    val hasUnsavedChanges = draft.comparableSnapshot != initial.comparableSnapshot
    val canDelete = !modeCreate && existing != null && onDelete != null

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

    fun attemptSave() {
        if (isSaving) return
        didAttemptSave = true
        val message = currentValidation()
        val feelings = draft.persistedFeelings()
        if (message != null || feelings == null) {
            validationMessage = message ?: intensityGeneric
            showValidation = true
            return
        }
        onSave(
            draft.event.trim(),
            draft.thought.trim(),
            feelings,
            draft.behaviour.trim(),
            draft.physicalSymptoms.trim().ifEmpty { null },
        )
    }

    fun requestBack() {
        if (isSaving) return
        if (hasUnsavedChanges) showDiscard = true else onBack()
    }

    BackHandler(enabled = !isSaving) { requestBack() }

    Box(Modifier.fillMaxSize()) {
        Scaffold(
            modifier = Modifier
                .themedScreen(atmosphere)
                .dismissKeyboardOnTap()
                .imePadding(),
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
                        IconButton(onClick = { requestBack() }, enabled = !isSaving) {
                            Icon(
                                Icons.AutoMirrored.Outlined.ArrowBack,
                                contentDescription = stringResource(R.string.back),
                                tint = colors.gold,
                            )
                        }
                    },
                    actions = {
                        if (canDelete) {
                            IconButton(onClick = { showDelete = true }, enabled = !isSaving) {
                                Icon(
                                    Icons.Outlined.Delete,
                                    contentDescription = stringResource(R.string.diary_one_delete_action),
                                    tint = colors.error,
                                )
                            }
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                )
            },
            bottomBar = {
                Button(
                    onClick = { attemptSave() },
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
                    Text(stringResource(R.string.diary_one_save_entry), fontWeight = FontWeight.SemiBold)
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
                    errorMessage = error,
                    onChange = { draft = it },
                )
            }
        }
        BusyOverlay(isBusy = isSaving)
    }

    MessageOverlay(
        visible = showValidation,
        title = stringResource(R.string.diary_one_validation_title),
        message = validationMessage.orEmpty(),
        onDismiss = { showValidation = false },
    )
    DiscardChangesDialog(
        visible = showDiscard,
        canSave = currentValidation() == null && draft.persistedFeelings() != null,
        onSave = {
            showDiscard = false
            attemptSave()
        },
        onDiscard = {
            showDiscard = false
            draft = initial
            onBack()
        },
        onKeepEditing = { showDiscard = false },
    )
    if (canDelete) {
        ConfirmDeleteOverlay(
            visible = showDelete,
            title = stringResource(R.string.diary_one_delete_confirm_title),
            message = stringResource(R.string.diary_one_delete_confirm_message),
            confirmLabel = stringResource(R.string.diary_one_delete_action),
            onConfirm = {
                showDelete = false
                onDelete?.invoke()
            },
            onDismiss = { showDelete = false },
        )
    }
}
