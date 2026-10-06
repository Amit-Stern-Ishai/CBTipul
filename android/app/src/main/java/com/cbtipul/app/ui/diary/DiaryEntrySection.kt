package com.cbtipul.app.ui.diary

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowForward
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.ExpandLess
import androidx.compose.material.icons.outlined.ExpandMore
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.cbtipul.app.R
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.Theme

@OptIn(ExperimentalFoundationApi::class)
@Composable
internal fun DiaryEntrySection(number: Int, title: String, summary: String, issue: String?,
    active: Int, onActive: (Int) -> Unit, attempted: Boolean, optional: Boolean = false,
    next: (() -> Unit)? = null, content: @Composable ColumnScope.() -> Unit) {
    var triedNext by rememberSaveable { mutableStateOf(false) }
    val expanded = active == number
    val focus = LocalFocusManager.current
    val requester = remember { BringIntoViewRequester() }
    val state = stringResource(if (expanded) R.string.diary_section_close else R.string.diary_section_open)
    LaunchedEffect(expanded) {
        if (expanded) { withFrameNanos { }; requester.bringIntoView() }
    }
    GroupedListCard(accent = Theme.colors.gold) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(Modifier.fillMaxWidth().bringIntoViewRequester(requester).heightIn(min = 48.dp)
                .semantics { stateDescription = state }
                .clickable(role = Role.Button) { focus.clearFocus(); onActive(if (expanded) 0 else number) },
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Surface(color = Theme.colors.goldGhost, shape = MaterialTheme.shapes.extraLarge) {
                    Box(Modifier.size(32.dp), contentAlignment = Alignment.Center) {
                        if (issue == null && !optional) Icon(Icons.Outlined.Check, stringResource(R.string.diary_section_complete), tint = Theme.colors.gold, modifier = Modifier.size(18.dp))
                        else Text(number.toString(), style = MaterialTheme.typography.labelLarge, color = Theme.colors.gold)
                    }
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(title, style = MaterialTheme.typography.titleSmall, color = Theme.colors.textBright)
                    if (optional) Text(stringResource(R.string.diary_one_optional_hint), style = MaterialTheme.typography.labelSmall, color = Theme.colors.textBody)
                    if (!expanded && summary.isNotBlank()) Text(summary, maxLines = 2, style = MaterialTheme.typography.bodyMedium, color = Theme.colors.textBody)
                }
                Icon(if (expanded) Icons.Outlined.ExpandLess else Icons.Outlined.ExpandMore, null, tint = Theme.colors.textBody)
            }
            if (expanded) content()
            if ((attempted || triedNext) && issue != null) Text(issue, color = Theme.colors.error, style = MaterialTheme.typography.bodySmall)
            if (expanded && next != null) OutlinedButton(onClick = {
                triedNext = true
                if (issue == null) { focus.clearFocus(); next() }
            }, modifier = Modifier.align(Alignment.End)) {
                Text(stringResource(R.string.diary_section_next))
                Spacer(Modifier.width(8.dp))
                Icon(Icons.AutoMirrored.Outlined.ArrowForward, null, Modifier.size(18.dp))
            }
        }
    }
}

@Composable
internal fun DiaryEntryProgress(completed: Int, total: Int, lastPartOptional: Boolean = false) {
    val requiredTotal = total - if (lastPartOptional) 1 else 0
    Column(Modifier.padding(vertical = 4.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(if (lastPartOptional) stringResource(R.string.diary_five_parts_optional) else stringResource(R.string.diary_entry_progress, completed, total), style = MaterialTheme.typography.labelLarge)
        LinearProgressIndicator(progress = { completed.toFloat() / requiredTotal }, modifier = Modifier.fillMaxWidth(), color = Theme.colors.gold)
        Text(stringResource(if (completed == requiredTotal) R.string.diary_ready_to_save else R.string.diary_entry_guide), style = MaterialTheme.typography.bodySmall, color = Theme.colors.textBody)
    }
}

@Composable
internal fun DiaryOriginalThoughts(thoughts: List<String>) {
    if (thoughts.isEmpty()) return
    var expanded by rememberSaveable { mutableStateOf(false) }
    Surface(color = Theme.colors.elevated, shape = MaterialTheme.shapes.medium) {
        Column(Modifier.fillMaxWidth().padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(role = Role.Button) { expanded = !expanded }, verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.diary_original_thoughts), Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
                Icon(if (expanded) Icons.Outlined.ExpandLess else Icons.Outlined.ExpandMore, null)
            }
            if (expanded) thoughts.forEach { Text(it, style = MaterialTheme.typography.bodyMedium) }
        }
    }
}

@Composable
fun PatientDiaryGuide(isDiaryTwo: Boolean = false) {
    var showExample by rememberSaveable { mutableStateOf(false) }
    GroupedListCard(accent = Theme.colors.gold) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(stringResource(if (isDiaryTwo) R.string.patient_diary_two_purpose else R.string.patient_diary_one_purpose), style = MaterialTheme.typography.titleMedium, color = Theme.colors.textBright)
            TextButton(onClick = { showExample = !showExample }) {
                Text(stringResource(R.string.patient_example_action))
                Icon(if (showExample) Icons.Outlined.ExpandLess else Icons.Outlined.ExpandMore, contentDescription = null)
            }
            if (showExample) Text(stringResource(if (isDiaryTwo) R.string.patient_diary_two_example else R.string.patient_diary_one_example), color = Theme.colors.textBody)
        }
    }
}
