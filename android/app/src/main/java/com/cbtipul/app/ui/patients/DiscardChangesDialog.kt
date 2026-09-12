package com.cbtipul.app.ui.patients

import androidx.compose.foundation.layout.Column
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import com.cbtipul.app.R
import com.cbtipul.app.ui.theme.Theme

@Composable
fun AnalysisLeaveDialog(
    visible: Boolean,
    onSave: () -> Unit,
    onDiscard: () -> Unit,
    onKeepViewing: () -> Unit,
) {
    if (!visible) return
    val colors = Theme.colors
    AlertDialog(
        onDismissRequest = onKeepViewing,
        title = { Text(stringResource(R.string.save_summary_prompt)) },
        confirmButton = {
            Column {
                TextButton(onClick = onSave) {
                    Text(stringResource(R.string.save_changes_action), color = colors.gold)
                }
                TextButton(onClick = onDiscard) {
                    Text(stringResource(R.string.dont_save_action), color = colors.error)
                }
                TextButton(onClick = onKeepViewing) {
                    Text(stringResource(R.string.keep_viewing_action), color = colors.gold)
                }
            }
        },
    )
}

@Composable
fun DiscardChangesDialog(
    visible: Boolean,
    canSave: Boolean,
    onSave: () -> Unit,
    onDiscard: () -> Unit,
    onKeepEditing: () -> Unit,
) {
    if (!visible) return
    val colors = Theme.colors
    AlertDialog(
        onDismissRequest = onKeepEditing,
        title = { Text(stringResource(R.string.discard_changes_title)) },
        confirmButton = {
            Column {
                if (canSave) {
                    TextButton(onClick = onSave) {
                        Text(stringResource(R.string.save_changes_action), color = colors.gold)
                    }
                }
                TextButton(onClick = onDiscard) {
                    Text(stringResource(R.string.discard_changes_action), color = colors.error)
                }
                TextButton(onClick = onKeepEditing) {
                    Text(stringResource(R.string.keep_editing_action), color = colors.gold)
                }
            }
        },
    )
}
