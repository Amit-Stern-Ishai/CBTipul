package com.cbtipul.app.ui.diary

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.RemoveCircleOutline
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.cbtipul.app.R
import com.cbtipul.app.data.*
import com.cbtipul.app.ui.patients.NotesField
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.Theme
import kotlin.math.roundToInt

@Composable
fun DiaryThreeDraftFields(draft: DiaryThreeEntryDraft, attempted: Boolean, error: Int? = null, step: Int? = null, onChange: (DiaryThreeEntryDraft) -> Unit) {
    var pickingFeelings by rememberSaveable { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        if (step == null || step == 1) {
            DiaryThreeSection(stringResource(R.string.diary_three_situation_title)) {
                NotesField(draft.situation, { onChange(draft.copy(situation = it)) }, stringResource(R.string.diary_one_event_question))
            }
        }
        if (step == null || step == 2) {
            DiaryThreeSection(stringResource(R.string.diary_one_thought_title)) {
                if (step == null) Text(stringResource(R.string.diary_entry_thought_hint), color = Theme.colors.textBody)
                draft.automaticThoughts.forEach { row -> key(row.id) {
                    Row(verticalAlignment = Alignment.Top) {
                        NotesField(row.text, { text -> onChange(draft.copy(automaticThoughts = draft.automaticThoughts.map { if (it.id == row.id) it.copy(text = text) else it })) }, stringResource(R.string.diary_one_thought_singular), Modifier.weight(1f))
                        if (draft.automaticThoughts.size > 1) RemoveDiaryThreeRow(R.string.diary_one_remove_thought) {
                            onChange(draft.copy(automaticThoughts = draft.automaticThoughts.filterNot { it.id == row.id }))
                        }
                    }
                    DiaryThreePercentage(stringResource(R.string.diary_three_belief_before), row.beliefBefore) { value ->
                        onChange(draft.copy(automaticThoughts = draft.automaticThoughts.map { if (it.id == row.id) it.copy(beliefBefore = value) else it }))
                    }
                    HorizontalDivider()
                } }
                TextButton(onClick = { onChange(draft.copy(automaticThoughts = draft.automaticThoughts + DiaryThreeAutomaticThoughtDraft())) }) { Text(stringResource(R.string.diary_one_add_thought)) }
            }
        }
        if (step == null || step == 3) {
            DiaryThreeSection(stringResource(R.string.diary_three_feelings_before)) {
                if (draft.feelings.isEmpty()) Text(stringResource(R.string.diary_entry_feelings_hint), color = Theme.colors.textBody)
                draft.feelings.forEach { row -> key(row.id) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(row.name, Modifier.weight(1f), fontWeight = FontWeight.SemiBold)
                        RemoveDiaryThreeRow(R.string.diary_three_remove_feeling) { onChange(draft.copy(feelings = draft.feelings.filterNot { it.id == row.id })) }
                    }
                    DiaryThreePercentage(stringResource(R.string.diary_three_intensity_before), row.intensityBefore) { value ->
                        onChange(draft.copy(feelings = draft.feelings.map { if (it.id == row.id) it.copy(intensityBefore = value) else it }))
                    }
                    HorizontalDivider()
                } }
                TextButton(onClick = { pickingFeelings = true }) { Text(stringResource(R.string.diary_feeling_pick_title)) }
            }
        }
        if (step == null || step == 4) {
            DiaryThreeSection(stringResource(R.string.diary_thinking_errors_title)) {
                DiaryThinkingErrorPicker(draft.thinkingErrors) { onChange(draft.copy(thinkingErrors = it)) }
            }
        }
        if (step == null || step == 5) {
            DiaryThreeSection(stringResource(R.string.diary_alternative_thoughts_title)) {
                if (step == null) Text(stringResource(R.string.diary_entry_alternative_hint), color = Theme.colors.textBody)
                draft.alternativeThoughts.forEach { row -> key(row.id) {
                    Row(verticalAlignment = Alignment.Top) {
                        NotesField(row.text, { text -> onChange(draft.copy(alternativeThoughts = draft.alternativeThoughts.map { if (it.id == row.id) it.copy(text = text) else it })) }, stringResource(R.string.diary_alternative_thought_title), Modifier.weight(1f))
                        if (draft.alternativeThoughts.size > 1) RemoveDiaryThreeRow(R.string.diary_one_remove_thought) { onChange(draft.copy(alternativeThoughts = draft.alternativeThoughts.filterNot { it.id == row.id })) }
                    }
                    DiaryThreePercentage(stringResource(R.string.diary_three_belief), row.belief) { value ->
                        onChange(draft.copy(alternativeThoughts = draft.alternativeThoughts.map { if (it.id == row.id) it.copy(belief = value) else it }))
                    }
                    HorizontalDivider()
                } }
                TextButton(onClick = { onChange(draft.copy(alternativeThoughts = draft.alternativeThoughts + DiaryThreeAlternativeThoughtDraft())) }) { Text(stringResource(R.string.diary_one_add_thought)) }
            }
        }
        if (step == null || step == 6) {
            DiaryThreeSection(stringResource(R.string.diary_three_thoughts_after)) {
                draft.automaticThoughts.forEach { row -> key(row.id) {
                    Text(row.text.ifBlank { stringResource(R.string.diary_one_thought_singular) })
                    if (step != null) Text(stringResource(R.string.diary_three_belief_before) + ": ${row.beliefBefore}%", color = Theme.colors.textBody)
                    DiaryThreePercentage(stringResource(if (step == null) R.string.diary_three_belief_after else R.string.patient_diary_three_belief_now), row.beliefAfter) { value ->
                        onChange(draft.copy(automaticThoughts = draft.automaticThoughts.map { if (it.id == row.id) it.copy(beliefAfter = value) else it }))
                    }
                    HorizontalDivider()
                } }
            }
        }
        if (step == null || step == 7) {
            DiaryThreeSection(stringResource(R.string.diary_three_feelings_after)) {
                draft.feelings.forEach { row -> key(row.id) {
                    Text(row.name, fontWeight = FontWeight.SemiBold)
                    if (step != null) Text(stringResource(R.string.diary_three_intensity_before) + ": ${row.intensityBefore}%", color = Theme.colors.textBody)
                    DiaryThreePercentage(stringResource(if (step == null) R.string.diary_three_intensity_after else R.string.patient_diary_three_intensity_now), row.intensityAfter) { value ->
                        onChange(draft.copy(feelings = draft.feelings.map { if (it.id == row.id) it.copy(intensityAfter = value) else it }))
                    }
                    HorizontalDivider()
                } }
            }
        }
        if (attempted) draft.validationError()?.let { Text(stringResource(it), color = Theme.colors.error) }
        error?.let { Text(stringResource(it), color = Theme.colors.error) }
    }
    if (pickingFeelings) DiaryFeelingPickerSheet(draft.feelings.map { it.name }.toSet(), onPick = { name ->
        if (draft.feelings.none { it.name == name }) onChange(draft.copy(feelings = draft.feelings + DiaryThreeFeelingDraft(name = name)))
        pickingFeelings = false
    }, onDismiss = { pickingFeelings = false })
}

@Composable private fun RemoveDiaryThreeRow(label: Int, onClick: () -> Unit) {
    IconButton(onClick = onClick) { Icon(Icons.Outlined.RemoveCircleOutline, stringResource(label)) }
}
@Composable
private fun DiaryThreePercentage(label: String, value: Int?, onChange: (Int) -> Unit) {
    DiaryFeelingIntensityControl(intensity = value, title = label, onIntensityChange = onChange)
}

@Composable
fun DiaryThreeEntryContent(entry: DiaryThreeEntry) {
    DiaryThreeSection(stringResource(R.string.diary_three_situation_title)) { Text(entry.situation) }
    DiaryThreeSection(stringResource(R.string.diary_one_thought_title)) {
        entry.automaticThoughts.forEach {
            Text(it.text)
            DiaryThreeComparison(it.beliefBefore, it.beliefAfter, R.string.diary_three_belief_before, R.string.diary_three_belief_after)
        }
    }
    DiaryThreeSection(stringResource(R.string.diary_two_feelings_title)) {
        entry.feelings.forEach {
            Text(it.name, fontWeight = FontWeight.SemiBold)
            DiaryThreeComparison(it.intensityBefore, it.intensityAfter, R.string.diary_three_intensity_before, R.string.diary_three_intensity_after)
        }
    }
    DiaryThreeSection(stringResource(R.string.diary_thinking_errors_title)) { entry.thinkingErrors.forEach { Text(stringResource(it.title)) } }
    DiaryThreeSection(stringResource(R.string.diary_alternative_thoughts_title)) {
        entry.alternativeThoughts.forEach { Text(it.text); Text(stringResource(R.string.diary_three_belief) + ": ${it.belief}%", color = Theme.colors.textBody) }
    }
}
@Composable
private fun DiaryThreeComparison(before: Int, after: Int, beforeLabel: Int, afterLabel: Int) {
    Surface(color = Theme.colors.elevated, shape = MaterialTheme.shapes.medium) {
        Row(Modifier.fillMaxWidth().padding(12.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            listOf(beforeLabel to before, afterLabel to after).forEach { (label, value) ->
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(stringResource(label), style = MaterialTheme.typography.labelMedium, color = Theme.colors.textBody)
                    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
                        Text("$value%", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    }
                }
            }
        }
    }
}
@Composable
private fun DiaryThreeSection(title: String, content: @Composable ColumnScope.() -> Unit) {
    GroupedListCard(accent = Theme.colors.gold) {
        Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(title, fontWeight = FontWeight.SemiBold)
            content()
        }
    }
}
