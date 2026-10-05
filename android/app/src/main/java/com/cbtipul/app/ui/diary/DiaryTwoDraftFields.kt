package com.cbtipul.app.ui.diary

import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.cbtipul.app.R
import com.cbtipul.app.data.DiaryTwoEntryDraft
import com.cbtipul.app.ui.patients.NotesField
import com.cbtipul.app.ui.theme.Theme

@Composable
fun DiaryTwoDraftFields(draft: DiaryTwoEntryDraft, attempted: Boolean, error: Int? = null, initialSection: Int = 1, editRequest: Int = 0, onChange: (DiaryTwoEntryDraft) -> Unit) {
    var active by rememberSaveable { mutableIntStateOf(1) }
    LaunchedEffect(initialSection, editRequest) { if (editRequest > 0) { active = 0; withFrameNanos { }; active = initialSection } }
    val feelingIssue = when {
        draft.feelings.isEmpty() -> R.string.diary_one_validation_feelings
        draft.feelings.any { it.name.isBlank() || it.intensity == null || it.intensity !in 0..100 } -> R.string.diary_one_validation_feeling_intensity
        draft.feelings.map { it.name.trim() }.distinct().size != draft.feelings.size -> R.string.diary_feeling_already_selected
        else -> null
    }
    val issues = listOf(
        if (draft.event.isBlank()) R.string.diary_one_validation_event else null,
        if (draft.persistedAutomaticThoughts.isEmpty()) R.string.diary_one_validation_thought else null,
        feelingIssue,
        if (draft.thinkingErrors.isEmpty()) R.string.diary_two_validation_errors else null,
        if (draft.persistedAlternativeThoughts.isEmpty()) R.string.diary_two_validation_alternatives else null,
    )
    LaunchedEffect(attempted) { if (attempted) issues.indexOfFirst { it != null }.takeIf { it >= 0 }?.let { active = it + 1 } }
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        DiaryEntryProgress(issues.count { it == null }, issues.size)
        DiaryEntrySection(1, stringResource(R.string.diary_one_event_title), draft.event, issues[0]?.let { stringResource(it) }, active, { active = it }, attempted, next = { active = 2 }) {
            NotesField(draft.event, { onChange(draft.copy(event = it)) }, stringResource(R.string.diary_one_event_question))
        }
        DiaryEntrySection(2, stringResource(R.string.diary_one_thought_title), draft.persistedAutomaticThoughts.joinToString(" · "), issues[1]?.let { stringResource(it) }, active, { active = it }, attempted, next = { active = 3 }) {
            Text(stringResource(R.string.diary_entry_thought_hint), color = Theme.colors.textBody)
            DiaryThoughtsEditor(draft.automaticThoughts, stringResource(R.string.diary_one_thought_singular), stringResource(R.string.diary_one_add_thought)) { onChange(draft.copy(automaticThoughts = it)) }
        }
        DiaryEntrySection(3, stringResource(R.string.diary_feelings_title), draft.feelings.joinToString(" · ") { it.name }, issues[2]?.let { stringResource(it) }, active, { active = it }, attempted, next = { active = 4 }) {
            DiaryFeelingsEditor(draft.feelings, attempted) { onChange(draft.copy(feelings = it)) }
        }
        DiaryEntrySection(4, stringResource(R.string.diary_thinking_errors_title), draft.thinkingErrors.map { stringResource(it.title) }.joinToString(" · "), issues[3]?.let { stringResource(it) }, active, { active = it }, attempted, next = { active = 5 }) {
            DiaryOriginalThoughts(draft.persistedAutomaticThoughts)
            DiaryThinkingErrorPicker(draft.thinkingErrors) { onChange(draft.copy(thinkingErrors = it)) }
        }
        DiaryEntrySection(5, stringResource(R.string.diary_alternative_thoughts_title), draft.persistedAlternativeThoughts.joinToString(" · "), issues[4]?.let { stringResource(it) }, active, { active = it }, attempted) {
            Text(stringResource(R.string.diary_entry_alternative_hint), color = Theme.colors.textBody)
            DiaryOriginalThoughts(draft.persistedAutomaticThoughts)
            DiaryThoughtsEditor(draft.alternativeThoughts, stringResource(R.string.diary_alternative_thought_title), stringResource(R.string.diary_add_alternative_thought)) { onChange(draft.copy(alternativeThoughts = it)) }
        }
        error?.let { Text(stringResource(it), color = Theme.colors.error) }
    }
}
