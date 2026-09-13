package com.cbtipul.app.ui.patients

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
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
    AppDialogOverlay(onDismiss = onKeepViewing) {
        Text(
            stringResource(R.string.save_summary_prompt),
            color = colors.textBright,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Right,
        )
        TextButton(onClick = onSave, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.save_changes_action), color = colors.gold)
        }
        TextButton(onClick = onDiscard, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.dont_save_action), color = colors.error)
        }
        TextButton(onClick = onKeepViewing, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.keep_viewing_action), color = colors.gold)
        }
    }
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
    AppDialogOverlay(onDismiss = onKeepEditing) {
        Text(
            stringResource(R.string.discard_changes_title),
            color = colors.textBright,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Right,
        )
        if (canSave) {
            TextButton(onClick = onSave, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.save_changes_action), color = colors.gold)
            }
        }
        TextButton(onClick = onDiscard, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.discard_changes_action), color = colors.error)
        }
        TextButton(onClick = onKeepEditing, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.keep_editing_action), color = colors.gold)
        }
    }
}
