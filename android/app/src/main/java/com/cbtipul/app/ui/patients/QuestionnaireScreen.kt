package com.cbtipul.app.ui.patients

import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.outlined.EditNote
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringArrayResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.model.CombinedMoodQuestionnaire
import com.cbtipul.app.model.CompletedQuestionnaire
import com.cbtipul.app.model.Session
import com.cbtipul.app.ui.theme.Theme
import java.text.DateFormat
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuestionnaireScreen(
    session: Session?,
    existing: CombinedMoodQuestionnaire?,
    previous: CompletedQuestionnaire?,
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
    val dateFormat = remember { DateFormat.getDateInstance(DateFormat.MEDIUM, Locale("iw")) }
    val gad7 = stringArrayResource(R.array.gad7_questions)
    val phq9 = stringArrayResource(R.array.phq9_questions)
    val answers = stringArrayResource(R.array.answer_descriptions)
    val interference = stringArrayResource(R.array.phq9_interference_options)

    Scaffold(
        containerColor = colors.base,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.questionnaire_section_title), color = colors.textBright) },
                navigationIcon = {
                    IconButton(onClick = onBack, enabled = !isSaving) {
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
                colors = TopAppBarDefaults.topAppBarColors(containerColor = colors.base),
            )
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
            Text(dateFormat.format(session.date), color = colors.textBody)
            Text(stringResource(R.string.gad7_title), color = colors.textBright, fontWeight = FontWeight.SemiBold)
            Text(stringResource(R.string.answer_key_title), color = colors.textBright)
            answers.forEach { Text(it, color = colors.textBody, fontSize = 13.sp) }
            previous?.let {
                Text(
                    stringResource(R.string.previous_answer_legend, dateFormat.format(it.answeredDate)),
                    color = colors.warning,
                    fontSize = 13.sp,
                )
            }
            Text(stringResource(R.string.gad7_main_question), color = colors.textBright)
            gad7.forEachIndexed { index, question ->
                QuestionBlock(
                    text = question,
                    selection = draft.gad7Answers.getOrNull(index),
                    note = draft.gad7Notes.getOrNull(index).orEmpty(),
                    previousAnswer = previous?.questionnaire?.gad7Answers?.getOrNull(index),
                    editable = isEditing && !isSaving,
                    onSelect = { value ->
                        draft = draft.copy(gad7Answers = draft.gad7Answers.toMutableList().also { it[index] = value })
                    },
                    onNote = { value ->
                        draft = draft.copy(gad7Notes = draft.gad7Notes.toMutableList().also { it[index] = value })
                    },
                )
            }
            Text(stringResource(R.string.total_score_line, draft.gad7Score), color = colors.textBright, fontWeight = FontWeight.SemiBold)
            Text(gad7SeverityLabel(draft.gad7Severity), color = colors.textBody)
            previous?.let {
                Text(stringResource(R.string.previous_score_line, dateFormat.format(it.answeredDate), it.questionnaire.gad7Score), color = colors.warning, fontSize = 13.sp)
            }

            Text(stringResource(R.string.phq9_title), color = colors.textBright, fontWeight = FontWeight.SemiBold)
            Text(stringResource(R.string.phq9_main_question), color = colors.textBright)
            phq9.forEachIndexed { index, question ->
                QuestionBlock(
                    text = question,
                    selection = draft.phq9Answers.getOrNull(index),
                    note = draft.phq9Notes.getOrNull(index).orEmpty(),
                    previousAnswer = previous?.questionnaire?.phq9Answers?.getOrNull(index),
                    editable = isEditing && !isSaving,
                    onSelect = { value ->
                        draft = draft.copy(phq9Answers = draft.phq9Answers.toMutableList().also { it[index] = value })
                    },
                    onNote = { value ->
                        draft = draft.copy(phq9Notes = draft.phq9Notes.toMutableList().also { it[index] = value })
                    },
                )
            }
            Text(stringResource(R.string.phq9_interference_question).replace("**", ""), color = colors.textBright)
            interference.forEachIndexed { index, option ->
                val selected = draft.interferenceLevel == index
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(enabled = isEditing && !isSaving) { draft = draft.copy(interferenceLevel = index) }
                        .padding(vertical = 6.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(
                        option + if (previous?.questionnaire?.interferenceLevel == index) " ⏱" else "",
                        color = if (selected) colors.gold else colors.textBody,
                    )
                }
            }
            NoteButton(
                note = draft.interferenceNote,
                editable = isEditing && !isSaving,
                onNote = { draft = draft.copy(interferenceNote = it) },
            )
            Text(stringResource(R.string.total_score_line, draft.phq9Score), color = colors.textBright, fontWeight = FontWeight.SemiBold)
            Text(phq9SeverityLabel(draft.phq9Severity), color = colors.textBody)
            Text(phq9Suggestion(draft.phq9Severity), color = colors.textBody, fontSize = 13.sp)
            previous?.let {
                Text(stringResource(R.string.previous_score_line, dateFormat.format(it.answeredDate), it.questionnaire.phq9Score), color = colors.warning, fontSize = 13.sp)
            }

            errorMessage?.let { Text(it, color = colors.error) }
            if (isSaving) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    CircularProgressIndicator(color = colors.gold)
                    Text(stringResource(R.string.anonymizing_status_label), color = colors.textBody)
                }
            }
        }
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
}

@Composable
private fun QuestionBlock(
    text: String,
    selection: Int?,
    note: String,
    previousAnswer: Int?,
    editable: Boolean,
    onSelect: (Int) -> Unit,
    onNote: (String) -> Unit,
) {
    val colors = Theme.colors
    Column(verticalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(vertical = 8.dp)) {
        Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
            Text(text, color = colors.textBright, modifier = Modifier.weight(1f))
            NoteButton(note = note, editable = editable, onNote = onNote)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            (0..3).forEach { value ->
                val selected = selection == value
                FilterChip(
                    selected = selected,
                    onClick = { if (editable) onSelect(value) },
                    enabled = editable,
                    label = { Text(value.toString()) },
                    modifier = if (previousAnswer == value) {
                        Modifier.border(1.dp, colors.warning, CircleShape)
                    } else {
                        Modifier
                    },
                )
            }
        }
        if (note.isNotBlank()) Text(note, color = colors.textBody, fontSize = 13.sp)
    }
}

@Composable
private fun NoteButton(note: String, editable: Boolean, onNote: (String) -> Unit) {
    if (!editable && note.isBlank()) return
    var show by remember { mutableStateOf(false) }
    IconButton(onClick = { if (editable) show = true }) {
        Icon(
            if (note.isBlank()) Icons.Outlined.EditNote else Icons.Filled.Edit,
            contentDescription = stringResource(R.string.notes_field_placeholder),
            tint = Theme.colors.gold,
        )
    }
    if (show) {
        var value by remember { mutableStateOf(note) }
        AlertDialog(
            onDismissRequest = { show = false },
            title = { Text(stringResource(R.string.notes_field_placeholder)) },
            text = { OutlinedTextField(value = value, onValueChange = { value = it }) },
            confirmButton = {
                TextButton(onClick = {
                    onNote(value)
                    show = false
                }) { Text(stringResource(R.string.save)) }
            },
            dismissButton = {
                TextButton(onClick = { show = false }) { Text(stringResource(R.string.cancel)) }
            },
        )
    }
}
