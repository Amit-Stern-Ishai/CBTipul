package com.cbtipul.app.ui.diary

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.RemoveCircleOutline
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.cbtipul.app.R
import com.cbtipul.app.data.*
import com.cbtipul.app.ui.patients.NotesField
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.Theme

/** Shared clinical fields; patient and therapist screens own their own save/navigation behavior. */
@Composable
fun DiaryTwoDraftFields(draft: DiaryTwoEntryDraft, attempted: Boolean, error: Int? = null, onChange: (DiaryTwoEntryDraft) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        DiaryTwoCard(stringResource(R.string.diary_one_event_title)) {
            NotesField(value = draft.event, onValueChange = { onChange(draft.copy(event = it)) }, placeholder = stringResource(R.string.diary_one_event_question))
        }
        DiaryTwoThoughts(stringResource(R.string.diary_one_thought_title), stringResource(R.string.diary_one_thought_singular), draft.automaticThoughts) {
            onChange(draft.copy(automaticThoughts = it))
        }
        DiaryTwoCard(stringResource(R.string.diary_two_feelings_title)) {
            DiaryFeelingsEditor(drafts = draft.feelings, highlightIncomplete = attempted, onChange = { onChange(draft.copy(feelings = it)) })
        }
        DiaryTwoCard(stringResource(R.string.diary_thinking_errors_title)) {
            ThinkingError.entries.forEach { error ->
                val selected = error in draft.thinkingErrors
                Row(Modifier.fillMaxWidth().clickable(role = androidx.compose.ui.semantics.Role.Checkbox) {
                    onChange(draft.copy(thinkingErrors = if (selected) draft.thinkingErrors - error else draft.thinkingErrors + error))
                }.padding(vertical = 6.dp), verticalAlignment = Alignment.Top) {
                    Checkbox(checked = selected, onCheckedChange = null)
                    Column(Modifier.weight(1f).padding(start = 8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(stringResource(error.title), fontWeight = FontWeight.SemiBold)
                        Text(stringResource(error.explanation), style = MaterialTheme.typography.bodySmall, color = Theme.colors.textBody)
                    }
                }
            }
        }
        DiaryTwoThoughts(stringResource(R.string.diary_alternative_thoughts_title), stringResource(R.string.diary_alternative_thought_title), draft.alternativeThoughts) {
            onChange(draft.copy(alternativeThoughts = it))
        }
        if (attempted) draft.validationError()?.let { Text(stringResource(it), color = Theme.colors.error) }
        error?.let { Text(stringResource(it), color = Theme.colors.error) }
    }
}

@Composable
private fun DiaryTwoThoughts(title: String, placeholder: String, rows: List<DiaryAutomaticThoughtDraft>, onChange: (List<DiaryAutomaticThoughtDraft>) -> Unit) {
    DiaryTwoCard(title) {
        rows.forEach { row -> key(row.id) {
            Row(verticalAlignment = Alignment.Top) {
                NotesField(row.text, { text -> onChange(rows.map { if (it.id == row.id) it.copy(text = text) else it }) }, placeholder, Modifier.weight(1f))
                if (rows.size > 1) IconButton(onClick = { onChange(rows.filterNot { it.id == row.id }) }) {
                    Icon(Icons.Outlined.RemoveCircleOutline, stringResource(R.string.diary_one_remove_thought))
                }
            }
        } }
        TextButton(onClick = { onChange(rows + DiaryAutomaticThoughtDraft()) }) { Text(stringResource(R.string.diary_one_add_thought)) }
    }
}

@Composable
private fun DiaryTwoCard(title: String, content: @Composable ColumnScope.() -> Unit) {
    GroupedListCard(accent = Theme.colors.gold) {
        Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(title, fontWeight = FontWeight.SemiBold)
            content()
        }
    }
}
