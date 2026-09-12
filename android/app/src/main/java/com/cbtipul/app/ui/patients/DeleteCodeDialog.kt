package com.cbtipul.app.ui.patients

import androidx.compose.material3.AlertDialog
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.res.stringResource
import com.cbtipul.app.R
import com.cbtipul.app.ui.theme.Theme

@Composable
fun DeleteCodeDialog(
    visible: Boolean,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    if (!visible) return
    var code by remember { mutableStateOf(randomCode()) }
    var input by remember { mutableStateOf("") }
    var mismatch by remember { mutableStateOf(false) }
    LaunchedEffect(visible) {
        if (visible) {
            code = randomCode()
            input = ""
            mismatch = false
        }
    }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.delete_code_title)) },
        text = {
            androidx.compose.foundation.layout.Column {
                Text(stringResource(R.string.delete_code_message, code))
                OutlinedTextField(
                    value = input,
                    onValueChange = { input = it.uppercase() },
                    placeholder = { Text(stringResource(R.string.delete_code_placeholder)) },
                    singleLine = true,
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    if (input.trim().equals(code, ignoreCase = true)) {
                        onConfirm()
                    } else {
                        mismatch = true
                    }
                },
            ) {
                Text(stringResource(R.string.delete_code_confirm_action), color = Theme.colors.error)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) }
        },
    )
    if (mismatch) {
        AlertDialog(
            onDismissRequest = { mismatch = false },
            title = { Text(stringResource(R.string.delete_code_mismatch_title)) },
            text = { Text(stringResource(R.string.delete_code_mismatch_message)) },
            confirmButton = {
                TextButton(onClick = { mismatch = false }) { Text(stringResource(R.string.ok)) }
            },
        )
    }
}

private fun randomCode(): String {
    val chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    return (1..8).map { chars.random() }.joinToString("")
}
