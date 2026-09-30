package com.cbtipul.app.ui.diary

import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.cbtipul.app.R
import com.cbtipul.app.data.DiaryOneEntryDraft
import com.cbtipul.app.ui.patients.NotesField
import com.cbtipul.app.ui.theme.Theme

@Composable
fun DiaryOneDraftFields(draft: DiaryOneEntryDraft, didAttemptSave: Boolean, errorMessage: String? = null, onChange: (DiaryOneEntryDraft) -> Unit) {
    var active by rememberSaveable { mutableIntStateOf(1) }
    val attempted = didAttemptSave
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
        if (draft.behaviour.isBlank()) R.string.diary_one_validation_behaviour else null,
    )
    LaunchedEffect(attempted) { if (attempted) issues.indexOfFirst { it != null }.takeIf { it >= 0 }?.let { active = it + 1 } }
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        DiaryEntryProgress(issues.count { it == null }, 5, lastPartOptional = true)
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
        DiaryEntrySection(4, stringResource(R.string.diary_one_behaviour_title), draft.behaviour, issues[3]?.let { stringResource(it) }, active, { active = it }, attempted, next = { active = 5 }) {
            NotesField(draft.behaviour, { onChange(draft.copy(behaviour = it)) }, stringResource(R.string.diary_one_behaviour_question))
        }
        DiaryEntrySection(5, stringResource(R.string.diary_one_physical_title), draft.physicalSymptoms, null, active, { active = it }, attempted, optional = true) {
            NotesField(draft.physicalSymptoms, { onChange(draft.copy(physicalSymptoms = it)) }, stringResource(R.string.diary_one_physical_question))
        }
        errorMessage?.let { Text(it, color = Theme.colors.error) }
    }
}
