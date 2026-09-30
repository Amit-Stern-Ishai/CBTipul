package com.cbtipul.app.ui.diary

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AddCircleOutline
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.RemoveCircleOutline
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import com.cbtipul.app.R
import com.cbtipul.app.data.ThinkingError
import com.cbtipul.app.ui.theme.Theme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun DiaryThinkingErrorPicker(selection: List<ThinkingError>, onChange: (List<ThinkingError>) -> Unit) {
    var showingPicker by remember { mutableStateOf(false) }
    var explaining by remember { mutableStateOf<ThinkingError?>(null) }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        selection.forEach { error ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(error.title), Modifier.weight(1f), color = Theme.colors.textBright)
                IconButton(onClick = { onChange(selection - error) }) {
                    Icon(Icons.Outlined.RemoveCircleOutline, stringResource(R.string.diary_remove_thinking_error, stringResource(error.title)), tint = Theme.colors.textBody)
                }
            }
        }
        OutlinedButton(onClick = { showingPicker = true }) {
            Icon(if (selection.isEmpty()) Icons.Outlined.AddCircleOutline else Icons.Outlined.Tune, null)
            Spacer(Modifier.width(8.dp))
            Text(stringResource(if (selection.isEmpty()) R.string.diary_choose_thinking_errors else R.string.diary_edit_thinking_errors))
        }
    }
    if (showingPicker) {
        ModalBottomSheet(onDismissRequest = { showingPicker = false; explaining = null },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = Theme.colors.surface) {
            CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(stringResource(R.string.diary_choose_thinking_errors), Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
                        TextButton(onClick = { showingPicker = false }) { Text(stringResource(R.string.done)) }
                    }
                    Text(stringResource(R.string.diary_thinking_choose), style = MaterialTheme.typography.bodySmall, color = Theme.colors.textBody)
                    LazyColumn(Modifier.weight(1f, fill = false), contentPadding = PaddingValues(vertical = 16.dp)) {
                        items(ThinkingError.entries, key = { it.name }) { error ->
                            val selected = error in selection
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Row(Modifier.weight(1f).heightIn(min = 48.dp).toggleable(value = selected, role = Role.Checkbox,
                                    onValueChange = { onChange(if (selected) selection - error else selection + error) }), verticalAlignment = Alignment.CenterVertically) {
                                    Checkbox(selected, onCheckedChange = null)
                                    Text(stringResource(error.title), Modifier.weight(1f).padding(start = 8.dp), color = Theme.colors.textBright, textAlign = TextAlign.Start)
                                }
                                IconButton(onClick = { explaining = error }) {
                                    Icon(Icons.Outlined.Info, stringResource(R.string.diary_thinking_about, stringResource(error.title)), tint = Theme.colors.gold)
                                }
                            }
                            HorizontalDivider()
                        }
                    }
                }
            }
        }
    }
    explaining?.let { error ->
        AlertDialog(onDismissRequest = { explaining = null }, title = { Text(stringResource(error.title)) },
            text = { Text(stringResource(error.explanation)) },
            confirmButton = { TextButton(onClick = { explaining = null }) { Text(stringResource(R.string.ok)) } })
    }
}
