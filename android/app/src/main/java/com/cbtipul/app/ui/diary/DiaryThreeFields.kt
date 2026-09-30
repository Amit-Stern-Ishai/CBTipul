package com.cbtipul.app.ui.diary

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AddCircleOutline
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
    LaunchedEffect(draft.feelings) {
        if (draft.feelings.any { it.intensityBefore == null || it.intensityAfter == null }) {
            onChange(draft.copy(feelings = draft.feelings.map { it.copy(intensityBefore = it.intensityBefore ?: 80, intensityAfter = it.intensityAfter ?: 80) }))
        }
    }
    var active by rememberSaveable { mutableIntStateOf(1) }
    val staged = PatientDiaryThreeDraft(entry = draft)
    LaunchedEffect(attempted) { if (attempted && step == null) staged.firstInvalidStep?.let { active = it } }
    var pickingFeelings by rememberSaveable { mutableStateOf(false) }
    var thoughtFocusRequest by remember { mutableStateOf<String?>(null) }
    var thoughtFocusVersion by remember { mutableIntStateOf(0) }
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        if (step == null) DiaryEntryProgress((1..7).count { staged.validationError(it) == null }, 7)
        if (step == null || step == 1) {
            DiaryThreeFormSection(1, stringResource(R.string.diary_three_situation_title), draft.situation, staged.validationError(1), step, active, attempted, { active = it }) {
                NotesField(draft.situation, { onChange(draft.copy(situation = it)) }, stringResource(R.string.diary_one_event_question))
            }
        }
        if (step == null || step == 2) {
            DiaryThreeFormSection(2, stringResource(R.string.diary_one_thought_title), draft.automaticThoughts.joinToString(" · ") { it.text }, staged.validationError(2), step, active, attempted, { active = it }) {
                if (step == null) Text(stringResource(R.string.diary_entry_thought_hint), color = Theme.colors.textBody)
                draft.automaticThoughts.forEachIndexed { index, row -> key(row.id) {
                    DiaryThoughtRow(row.id, index + 1, stringResource(R.string.diary_one_thought_singular), row.text, thoughtFocusRequest,
                        onTextChange = { text -> onChange(draft.copy(automaticThoughts = draft.automaticThoughts.map { if (it.id == row.id) it.copy(text = text) else it })) },
                        onRemove = { onChange(draft.copy(automaticThoughts = draft.automaticThoughts.filterNot { it.id == row.id })) }, focusVersion = thoughtFocusVersion) {
                        DiaryThreePercentage(stringResource(R.string.diary_three_belief_before), row.beliefBefore) { value ->
                            onChange(draft.copy(automaticThoughts = draft.automaticThoughts.map { if (it.id == row.id) it.copy(beliefBefore = value) else it }))
                        }
                    }
                } }
                if (draft.automaticThoughts.none { it.text.isBlank() }) OutlinedButton(onClick = {
                    val unfinished = draft.automaticThoughts.firstOrNull { it.text.isBlank() }
                    if (unfinished != null) thoughtFocusRequest = unfinished.id
                    else {
                        val row = DiaryThreeAutomaticThoughtDraft()
                        onChange(draft.copy(automaticThoughts = draft.automaticThoughts + row))
                        thoughtFocusRequest = row.id
                    }
                    thoughtFocusVersion++
                }) {
                    Icon(Icons.Outlined.AddCircleOutline, null)
                    Spacer(Modifier.width(8.dp))
                    Text(stringResource(R.string.diary_one_add_thought))
                }
            }
        }
        if (step == null || step == 3) {
            DiaryThreeFormSection(3, stringResource(R.string.diary_three_feelings_before), draft.feelings.joinToString(" · ") { it.name }, staged.validationError(3), step, active, attempted, { active = it }) {
                if (draft.feelings.isEmpty()) Text(stringResource(R.string.diary_entry_feelings_hint), color = Theme.colors.textBody)
                draft.feelings.forEach { row -> key(row.id) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(row.name, Modifier.weight(1f), fontWeight = FontWeight.SemiBold)
                        RemoveDiaryThreeRow(R.string.diary_three_remove_feeling) { onChange(draft.copy(feelings = draft.feelings.filterNot { it.id == row.id })) }
                    }
                    DiaryThreePercentage(stringResource(R.string.diary_three_intensity_before), row.intensityBefore, requiresExplicitChoice = false) { value ->
                        onChange(draft.copy(feelings = draft.feelings.map { if (it.id == row.id) it.copy(intensityBefore = value) else it }))
                    }
                    HorizontalDivider()
                } }
                OutlinedButton(onClick = { pickingFeelings = true }) {
                    Icon(Icons.Outlined.AddCircleOutline, null)
                    Spacer(Modifier.width(8.dp))
                    Text(stringResource(R.string.diary_add_feeling))
                }
            }
        }
        if (step == null || step == 4) {
            DiaryThreeFormSection(4, stringResource(R.string.diary_thinking_errors_title), draft.thinkingErrors.map { stringResource(it.title) }.joinToString(" · "), staged.validationError(4), step, active, attempted, { active = it }) {
                DiaryOriginalThoughts(draft.automaticThoughts.map { it.text }.filter { it.isNotBlank() })
                DiaryThinkingErrorPicker(draft.thinkingErrors) { onChange(draft.copy(thinkingErrors = it)) }
            }
        }
        if (step == null || step == 5) {
            DiaryThreeFormSection(5, stringResource(R.string.diary_alternative_thoughts_title), draft.alternativeThoughts.joinToString(" · ") { it.text }, staged.validationError(5), step, active, attempted, { active = it }) {
                if (step == null) Text(stringResource(R.string.diary_entry_alternative_hint), color = Theme.colors.textBody)
                DiaryOriginalThoughts(draft.automaticThoughts.map { it.text }.filter { it.isNotBlank() })
                draft.alternativeThoughts.forEachIndexed { index, row -> key(row.id) {
                    DiaryThoughtRow(row.id, index + 1, stringResource(R.string.diary_alternative_thought_title), row.text, thoughtFocusRequest,
                        onTextChange = { text -> onChange(draft.copy(alternativeThoughts = draft.alternativeThoughts.map { if (it.id == row.id) it.copy(text = text) else it })) },
                        onRemove = { onChange(draft.copy(alternativeThoughts = draft.alternativeThoughts.filterNot { it.id == row.id })) }, focusVersion = thoughtFocusVersion) {
                        DiaryThreePercentage(stringResource(R.string.diary_three_belief), row.belief) { value ->
                            onChange(draft.copy(alternativeThoughts = draft.alternativeThoughts.map { if (it.id == row.id) it.copy(belief = value) else it }))
                        }
                    }
                } }
                if (draft.alternativeThoughts.none { it.text.isBlank() }) OutlinedButton(onClick = {
                    val unfinished = draft.alternativeThoughts.firstOrNull { it.text.isBlank() }
                    if (unfinished != null) thoughtFocusRequest = unfinished.id
                    else {
                        val row = DiaryThreeAlternativeThoughtDraft()
                        onChange(draft.copy(alternativeThoughts = draft.alternativeThoughts + row))
                        thoughtFocusRequest = row.id
                    }
                    thoughtFocusVersion++
                }) {
                    Icon(Icons.Outlined.AddCircleOutline, null)
                    Spacer(Modifier.width(8.dp))
                    Text(stringResource(R.string.diary_add_alternative_thought))
                }
            }
        }
        if (step == null || step == 6) {
            DiaryThreeFormSection(6, stringResource(R.string.diary_three_thoughts_after), "", staged.validationError(6), step, active, attempted, { active = it }) {
                draft.automaticThoughts.forEach { row -> key(row.id) {
                    Text(row.text.ifBlank { stringResource(R.string.diary_one_thought_singular) })
                    row.beliefBefore?.let { DiaryBeforeRating(R.string.diary_three_belief_before, it) }
                    DiaryThreePercentage(stringResource(if (step == null) R.string.diary_three_belief_after else R.string.patient_diary_three_belief_now), row.beliefAfter) { value ->
                        onChange(draft.copy(automaticThoughts = draft.automaticThoughts.map { if (it.id == row.id) it.copy(beliefAfter = value) else it }))
                    }
                    HorizontalDivider()
                } }
            }
        }
        if (step == null || step == 7) {
            DiaryThreeFormSection(7, stringResource(R.string.diary_three_feelings_after), "", staged.validationError(7), step, active, attempted, { active = it }) {
                draft.feelings.forEach { row -> key(row.id) {
                    Text(row.name, fontWeight = FontWeight.SemiBold)
                    row.intensityBefore?.let { DiaryBeforeRating(R.string.diary_three_intensity_before, it) }
                    DiaryThreePercentage(stringResource(if (step == null) R.string.diary_three_intensity_after else R.string.patient_diary_three_intensity_now), row.intensityAfter, requiresExplicitChoice = false) { value ->
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
private fun DiaryThreePercentage(label: String, value: Int?, requiresExplicitChoice: Boolean = true, onChange: (Int) -> Unit) {
    DiaryFeelingIntensityControl(intensity = value, title = label, requiresExplicitChoice = requiresExplicitChoice, onIntensityChange = onChange)
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

@Composable
private fun DiaryThreeFormSection(number: Int, title: String, summary: String, issue: Int?, step: Int?,
    active: Int, attempted: Boolean, onActive: (Int) -> Unit, content: @Composable ColumnScope.() -> Unit) {
    if (step != null) DiaryThreeSection(title, content)
    else DiaryEntrySection(number, title, summary, issue?.let { stringResource(it) }, active, onActive, attempted,
        next = if (number < 7) { { onActive(number + 1) } } else null, content = content)
}

@Composable
private fun DiaryBeforeRating(title: Int, value: Int) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(stringResource(title), Modifier.weight(1f), color = Theme.colors.textBody, style = MaterialTheme.typography.bodyMedium)
        CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
            Text(stringResource(R.string.diary_rating_percent, value), color = Theme.colors.textBody, style = MaterialTheme.typography.bodyMedium)
        }
    }
}
