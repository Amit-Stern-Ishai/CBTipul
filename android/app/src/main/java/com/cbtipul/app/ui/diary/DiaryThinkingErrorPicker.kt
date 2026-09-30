package com.cbtipul.app.ui.diary

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import com.cbtipul.app.R
import com.cbtipul.app.data.ThinkingError
import com.cbtipul.app.ui.theme.Theme

@Composable
internal fun DiaryThinkingErrorPicker(selection: List<ThinkingError>, onChange: (List<ThinkingError>) -> Unit) {
    var explaining by remember { mutableStateOf<ThinkingError?>(null) }
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(stringResource(R.string.diary_thinking_choose), style = MaterialTheme.typography.bodySmall, color = Theme.colors.textBody)
        ThinkingError.entries.forEach { error ->
            val selected = error in selection
            Row(verticalAlignment = Alignment.CenterVertically) {
                Row(Modifier.weight(1f).heightIn(min = 48.dp).toggleable(value = selected, role = Role.Checkbox,
                    onValueChange = { onChange(if (selected) selection - error else selection + error) }), verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(selected, onCheckedChange = null)
                    Text(stringResource(error.title), Modifier.weight(1f).padding(start = 8.dp), color = Theme.colors.textBright)
                }
                IconButton(onClick = { explaining = error }) {
                    Icon(Icons.Outlined.Info, stringResource(R.string.diary_thinking_about, stringResource(error.title)), tint = Theme.colors.gold)
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
