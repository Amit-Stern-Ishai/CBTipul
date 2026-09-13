package com.cbtipul.app.ui.patients

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.outlined.EditNote
import androidx.compose.material.icons.outlined.History
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringArrayResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.model.CombinedMoodQuestionnaire
import com.cbtipul.app.model.CompletedQuestionnaire
import com.cbtipul.app.model.Session
import com.cbtipul.app.ui.theme.BusyOverlay
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.GroupedListDivider
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.dismissKeyboardOnTap
import com.cbtipul.app.ui.theme.hebrewDate
import com.cbtipul.app.ui.theme.themedScreen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuestionnaireScreen(
    session: Session?,
    existing: CombinedMoodQuestionnaire?,
    previous: CompletedQuestionnaire?,
    atmosphere: Color?,
    isSaving: Boolean,
    errorMessage: String?,
    onBack: () -> Unit,
    onSave: (CombinedMoodQuestionnaire) -> Unit,
    onDelete: () -> Unit,
) {
    val colors = Theme.colors
    if (session?.databaseId == null) {
        Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.Center) {
            Text(stringResource(R.string.session_not_saved_error), color = colors.textBright)
            TextButton(onClick = onBack) { Text(stringResource(R.string.back), color = colors.gold) }
        }
        return
    }
    val isExisting = existing != null
    var draft by remember { mutableStateOf(existing ?: CombinedMoodQuestionnaire()) }
    var isEditing by remember { mutableStateOf(!isExisting) }
    var showIncomplete by remember { mutableStateOf(false) }
    var showDeleteConfirm by remember { mutableStateOf(false) }
    var showDeleteCode by remember { mutableStateOf(false) }
    var menu by remember { mutableStateOf(false) }
    var showDiscard by remember { mutableStateOf(false) }
    val initial = remember { existing ?: CombinedMoodQuestionnaire() }
    val hasUnsavedChanges = isEditing && draft != initial
    val gad7 = stringArrayResource(R.array.gad7_questions)
    val phq9 = stringArrayResource(R.array.phq9_questions)
    val answers = stringArrayResource(R.array.answer_descriptions)
    val interference = stringArrayResource(R.array.phq9_interference_options)
    val accent = atmosphere ?: colors.gold
    val editable = isEditing && !isSaving

    fun requestBack() {
        if (isSaving) return
        if (hasUnsavedChanges) showDiscard = true else onBack()
    }

    BackHandler(enabled = !isSaving) { requestBack() }

    Box(Modifier.fillMaxSize()) {
    Scaffold(
        modifier = Modifier
            .themedScreen(atmosphere)
            .dismissKeyboardOnTap(),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(stringResource(R.string.questionnaire_section_title), color = colors.textBright)
                        Text(hebrewDate(session.date), color = colors.textBody, fontSize = 13.sp)
                    }
                },
                navigationIcon = {
                    IconButton(onClick = { requestBack() }, enabled = !isSaving) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = stringResource(R.string.back), tint = colors.gold)
                    }
                },
                actions = {
                    if (isEditing) {
                        TextButton(
                            onClick = {
                                if (draft.isComplete) onSave(draft) else showIncomplete = true
                            },
                            enabled = !isSaving,
                        ) { Text(stringResource(R.string.save), color = colors.gold) }
                    }
                    if (!isEditing || isExisting) {
                        IconButton(onClick = { menu = true }, enabled = !isSaving) {
                            Icon(Icons.Filled.MoreVert, contentDescription = null, tint = colors.gold)
                        }
                        DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                            if (!isEditing) {
                                DropdownMenuItem(
                                    text = { Text(stringResource(R.string.edit_questionnaire_action)) },
                                    onClick = {
                                        menu = false
                                        isEditing = true
                                    },
                                )
                            }
                            if (isExisting) {
                                DropdownMenuItem(
                                    text = { Text(stringResource(R.string.delete_questionnaire_action), color = colors.error) },
                                    onClick = {
                                        menu = false
                                        showDeleteConfirm = true
                                    },
                                )
                            }
                        }
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
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            Text(stringResource(R.string.gad7_title), color = colors.textBright, fontWeight = FontWeight.SemiBold)
            GroupedListCard(accent = accent) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(stringResource(R.string.answer_key_title), color = colors.textBright, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                    answers.forEach { Text(it, color = colors.textBody, fontSize = 13.sp) }
                    previous?.let {
                        Text(
                            stringResource(R.string.previous_answer_legend, hebrewDate(it.answeredDate)),
                            color = colors.warning,
                            fontSize = 13.sp,
                        )
                    }
                }
                GroupedListDivider()
                Text(
                    aiMarkdown(stringResource(R.string.gad7_main_question)),
                    color = colors.textBright,
                    modifier = Modifier.padding(16.dp),
                )
                gad7.forEachIndexed { index, question ->
                    GroupedListDivider()
                    QuestionBlock(
                        text = question,
                        selection = draft.gad7Answers.getOrNull(index),
                        note = draft.gad7Notes.getOrNull(index).orEmpty(),
                        previousAnswer = previous?.questionnaire?.gad7Answers?.getOrNull(index),
                        accent = accent,
                        editable = editable,
                        onSelect = { value ->
                            draft = draft.copy(gad7Answers = draft.gad7Answers.toMutableList().also { it[index] = value })
                        },
                        onNote = { value ->
                            draft = draft.copy(gad7Notes = draft.gad7Notes.toMutableList().also { it[index] = value })
                        },
                    )
                }
                GroupedListDivider()
                ScoreBlock(
                    score = draft.gad7Score,
                    classification = gad7SeverityLabel(draft.gad7Severity),
                    previousScore = previous?.questionnaire?.gad7Score,
                    previousDate = previous?.answeredDate,
                )
            }

            Text(stringResource(R.string.phq9_title), color = colors.textBright, fontWeight = FontWeight.SemiBold)
            GroupedListCard(accent = accent) {
                Text(
                    aiMarkdown(stringResource(R.string.phq9_main_question)),
                    color = colors.textBright,
                    modifier = Modifier.padding(16.dp),
                )
                phq9.forEachIndexed { index, question ->
                    GroupedListDivider()
                    QuestionBlock(
                        text = question,
                        selection = draft.phq9Answers.getOrNull(index),
                        note = draft.phq9Notes.getOrNull(index).orEmpty(),
                        previousAnswer = previous?.questionnaire?.phq9Answers?.getOrNull(index),
                        accent = accent,
                        editable = editable,
                        onSelect = { value ->
                            draft = draft.copy(phq9Answers = draft.phq9Answers.toMutableList().also { it[index] = value })
                        },
                        onNote = { value ->
                            draft = draft.copy(phq9Notes = draft.phq9Notes.toMutableList().also { it[index] = value })
                        },
                    )
                }
                GroupedListDivider()
                InterferenceBlock(
                    options = interference,
                    selection = draft.interferenceLevel,
                    note = draft.interferenceNote,
                    previousSelection = previous?.questionnaire?.interferenceLevel,
                    editable = editable,
                    onSelect = { draft = draft.copy(interferenceLevel = it) },
                    onNote = { draft = draft.copy(interferenceNote = it) },
                )
                GroupedListDivider()
                ScoreBlock(
                    score = draft.phq9Score,
                    classification = phq9SeverityLabel(draft.phq9Severity),
                    previousScore = previous?.questionnaire?.phq9Score,
                    previousDate = previous?.answeredDate,
                )
                GroupedListDivider()
                Text(
                    phq9Suggestion(draft.phq9Severity),
                    color = colors.textBody,
                    fontSize = 13.sp,
                    modifier = Modifier.padding(16.dp),
                )
            }

            errorMessage?.let { Text(it, color = colors.error) }
        }
    }
        BusyOverlay(
            isBusy = isSaving,
            label = stringResource(R.string.anonymizing_status_label),
        )
    }

    if (showIncomplete) {
        AlertDialog(
            onDismissRequest = { showIncomplete = false },
            title = { Text(stringResource(R.string.questionnaire_incomplete_title)) },
            text = { Text(stringResource(R.string.questionnaire_incomplete_message)) },
            confirmButton = {
                TextButton(onClick = { showIncomplete = false }) { Text(stringResource(R.string.ok)) }
            },
        )
    }
    if (showDeleteConfirm) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm = false },
            title = { Text(stringResource(R.string.delete_questionnaire_confirm_title)) },
            text = { Text(stringResource(R.string.delete_questionnaire_confirm_message)) },
            confirmButton = {
                TextButton(onClick = {
                    showDeleteConfirm = false
                    showDeleteCode = true
                }) { Text(stringResource(R.string.delete_questionnaire_action), color = colors.error) }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirm = false }) { Text(stringResource(R.string.cancel)) }
            },
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
        canSave = draft.isComplete,
        onSave = {
            showDiscard = false
            if (draft.isComplete) onSave(draft) else showIncomplete = true
        },
        onDiscard = {
            showDiscard = false
            draft = initial
            onBack()
        },
        onKeepEditing = { showDiscard = false },
    )
}

@Composable
private fun QuestionBlock(
    text: String,
    selection: Int?,
    note: String,
    previousAnswer: Int?,
    accent: Color,
    editable: Boolean,
    onSelect: (Int) -> Unit,
    onNote: (String) -> Unit,
) {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.Top,
        ) {
            Text(aiMarkdown(text), color = Theme.colors.textBright, modifier = Modifier.weight(1f))
            NoteButton(note = note, editable = editable, onNote = onNote)
        }
        if (note.isNotBlank()) NoteBox(note)
        AnswerScale(
            selection = selection,
            previousAnswer = previousAnswer,
            accent = accent,
            editable = editable,
            onSelect = onSelect,
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AnswerScale(
    selection: Int?,
    previousAnswer: Int?,
    accent: Color,
    editable: Boolean,
    onSelect: (Int) -> Unit,
) {
    val colors = Theme.colors
    SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
        (0..3).forEach { value ->
            val selected = selection == value
            val previous = previousAnswer == value
            SegmentedButton(
                selected = selected,
                onClick = { if (editable) onSelect(value) },
                enabled = editable,
                shape = SegmentedButtonDefaults.itemShape(index = value, count = 4),
                colors = SegmentedButtonDefaults.colors(
                    activeContainerColor = colors.accentFill,
                    activeContentColor = colors.textOnAccent,
                    inactiveContainerColor = colors.elevated,
                    inactiveContentColor = colors.textBright,
                    inactiveBorderColor = if (previous) colors.warning else accent.copy(alpha = 0.35f),
                    activeBorderColor = if (previous) colors.warning else colors.accentFill,
                ),
                border = BorderStroke(
                    width = if (previous) 2.dp else 1.dp,
                    color = if (previous) colors.warning else if (selected) colors.accentFill else accent.copy(alpha = 0.35f),
                ),
                icon = {},
            ) {
                Text("$value", fontWeight = FontWeight.Medium)
            }
        }
    }
}

@Composable
private fun InterferenceBlock(
    options: Array<String>,
    selection: Int?,
    note: String,
    previousSelection: Int?,
    editable: Boolean,
    onSelect: (Int) -> Unit,
    onNote: (String) -> Unit,
) {
    val colors = Theme.colors
    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
            Text(
                aiMarkdown(stringResource(R.string.phq9_interference_question)),
                color = colors.textBright,
                modifier = Modifier.weight(1f),
            )
            NoteButton(note = note, editable = editable, onNote = onNote)
        }
        if (note.isNotBlank()) NoteBox(note)
        options.forEachIndexed { index, option ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(enabled = editable) { onSelect(index) },
                verticalAlignment = Alignment.CenterVertically,
            ) {
                RadioButton(
                    selected = selection == index,
                    onClick = { if (editable) onSelect(index) },
                    enabled = editable,
                    colors = RadioButtonDefaults.colors(
                        selectedColor = colors.gold,
                        unselectedColor = colors.textBody,
                    ),
                )
                Text(option, color = colors.textBright, modifier = Modifier.weight(1f))
                if (previousSelection == index) {
                    Icon(
                        Icons.Outlined.History,
                        contentDescription = null,
                        tint = colors.warning,
                        modifier = Modifier.size(18.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun ScoreBlock(
    score: Int,
    classification: String,
    previousScore: Int?,
    previousDate: java.util.Date?,
) {
    val colors = Theme.colors
    Row(
        modifier = Modifier.fillMaxWidth().padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(2.dp), modifier = Modifier.weight(1f)) {
            Text(stringResource(R.string.total_score_line, score), color = colors.textBright, fontWeight = FontWeight.SemiBold)
            if (previousScore != null && previousDate != null) {
                Text(
                    stringResource(R.string.previous_score_line, hebrewDate(previousDate), previousScore),
                    color = colors.warning,
                    fontSize = 13.sp,
                )
            }
        }
        Text(classification, color = colors.textBody, fontSize = 14.sp)
    }
}

@Composable
private fun NoteBox(note: String) {
    Text(
        note,
        color = Theme.colors.textBody,
        fontSize = 13.sp,
        modifier = Modifier
            .fillMaxWidth()
            .background(Theme.colors.elevated, RoundedCornerShape(8.dp))
            .padding(8.dp),
    )
}

@Composable
private fun NoteButton(note: String, editable: Boolean, onNote: (String) -> Unit) {
    if (!editable && note.isBlank()) return
    var show by remember { mutableStateOf(false) }
    IconButton(onClick = { if (editable) show = true }, modifier = Modifier.size(40.dp)) {
        Icon(
            if (note.isBlank()) Icons.Outlined.EditNote else Icons.Filled.Edit,
            contentDescription = stringResource(R.string.question_note_title),
            tint = if (note.isBlank()) Theme.colors.textBody else Theme.colors.gold,
        )
    }
    if (show) {
        var value by remember { mutableStateOf(note) }
        AlertDialog(
            onDismissRequest = { show = false },
            title = { Text(stringResource(R.string.question_note_title)) },
            text = {
                OutlinedTextField(
                    value = value,
                    onValueChange = { value = it },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 4,
                    placeholder = { Text(stringResource(R.string.notes_field_placeholder)) },
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    onNote(value.trim())
                    show = false
                }) { Text(stringResource(R.string.save)) }
            },
            dismissButton = {
                TextButton(onClick = { show = false }) { Text(stringResource(R.string.cancel)) }
            },
        )
    }
}
