package com.cbtipul.app.ui.diary

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AddCircleOutline
import androidx.compose.material.icons.outlined.DeleteOutline
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.cbtipul.app.R
import com.cbtipul.app.data.DiaryAutomaticThoughtDraft
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.editorFocus

@Composable
internal fun DiaryThoughtRow(id: String, number: Int, title: String, text: String, focusRequest: String?,
    onTextChange: (String) -> Unit, onRemove: () -> Unit, focusVersion: Int = 0, content: @Composable ColumnScope.() -> Unit = {}) {
    val focus = remember(id) { FocusRequester() }
    var confirmingRemoval by remember { mutableStateOf(false) }
    Surface(color = Theme.colors.elevated, shape = MaterialTheme.shapes.medium) {
        Column(Modifier.fillMaxWidth().padding(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.diary_thought_number, title, number), Modifier.weight(1f), style = MaterialTheme.typography.titleSmall)
                IconButton(onClick = { if (text.isBlank()) onRemove() else confirmingRemoval = true }) {
                    Icon(Icons.Outlined.DeleteOutline, stringResource(R.string.diary_remove_thought_number, title, number), tint = Theme.colors.textBody)
                }
            }
            OutlinedTextField(value = text, onValueChange = onTextChange, minLines = 2, maxLines = 6,
                label = { Text(title) }, modifier = Modifier.fillMaxWidth().focusRequester(focus).editorFocus(), readOnly = !com.cbtipul.app.ui.entitlementCanWrite())
            content()
        }
    }
    LaunchedEffect(focusVersion) { if (focusRequest == id) focus.requestFocus() }
    if (confirmingRemoval) AlertDialog(onDismissRequest = { confirmingRemoval = false },
        title = { Text(stringResource(R.string.diary_remove_thought_confirm)) },
        confirmButton = { TextButton(onClick = { confirmingRemoval = false; onRemove() }) { Text(stringResource(R.string.diary_remove_thought_action), color = Theme.colors.error) } },
        dismissButton = { TextButton(onClick = { confirmingRemoval = false }) { Text(stringResource(R.string.cancel)) } })
}

@Composable
internal fun DiaryThoughtsEditor(rows: List<DiaryAutomaticThoughtDraft>, title: String, addTitle: String, onChange: (List<DiaryAutomaticThoughtDraft>) -> Unit) {
    var focusRequest by remember { mutableStateOf<String?>(null) }
    var focusVersion by remember { mutableIntStateOf(0) }
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        rows.forEachIndexed { index, row -> key(row.id) {
            DiaryThoughtRow(row.id, index + 1, title, row.text, focusRequest,
                onTextChange = { value -> onChange(rows.map { if (it.id == row.id) it.copy(text = value) else it }) },
                onRemove = { onChange(rows.filterNot { it.id == row.id }) }, focusVersion = focusVersion)
        } }
        if (rows.none { it.text.isBlank() }) OutlinedButton(onClick = {
            val unfinished = rows.firstOrNull { it.text.isBlank() }
            if (unfinished != null) focusRequest = unfinished.id
            else {
                val row = DiaryAutomaticThoughtDraft()
                onChange(rows + row)
                focusRequest = row.id
            }
            focusVersion++
        }) {
            Icon(Icons.Outlined.AddCircleOutline, null)
            Spacer(Modifier.width(8.dp))
            Text(addTitle)
        }
    }
}
