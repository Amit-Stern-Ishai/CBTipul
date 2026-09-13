package com.cbtipul.app.ui.patients

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.ui.theme.Theme

@Composable
fun ConfirmDeleteOverlay(
    visible: Boolean,
    title: String,
    message: String,
    confirmLabel: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    if (!visible) return
    val colors = Theme.colors
    AppDialogOverlay(onDismiss = onDismiss) {
        Text(
            title,
            color = colors.textBright,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Right,
        )
        Text(
            message,
            color = colors.textBody,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Right,
        )
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            TextButton(onClick = onConfirm) {
                Text(confirmLabel, color = colors.error)
            }
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.cancel), color = colors.gold)
            }
        }
    }
}

@Composable
fun DeleteCodeDialog(
    visible: Boolean,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    if (!visible) return
    val colors = Theme.colors
    var code by remember { mutableStateOf(randomCode()) }
    var input by remember { mutableStateOf("") }
    var mismatch by remember { mutableStateOf(false) }
    AppDialogOverlay(onDismiss = onDismiss) {
        Text(
            stringResource(R.string.delete_code_title),
            color = colors.textBright,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Right,
        )
        Text(
            stringResource(R.string.delete_code_message, code),
            color = colors.textBody,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Right,
        )
        OutlinedTextField(
            value = input,
            onValueChange = { input = it.uppercase() },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            textStyle = TextStyle(
                color = colors.textBright,
                textDirection = TextDirection.Ltr,
                textAlign = TextAlign.Left,
                fontSize = 16.sp,
            ),
            placeholder = { Text(stringResource(R.string.delete_code_placeholder)) },
        )
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            TextButton(
                onClick = {
                    if (input.trim().equals(code, ignoreCase = true)) {
                        onConfirm()
                    } else {
                        mismatch = true
                    }
                },
            ) {
                Text(stringResource(R.string.delete_code_confirm_action), color = colors.error)
            }
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.cancel), color = colors.gold)
            }
        }
    }
    if (mismatch) {
        AppDialogOverlay(onDismiss = { mismatch = false }) {
            Text(
                stringResource(R.string.delete_code_mismatch_title),
                color = colors.textBright,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Right,
            )
            Text(
                stringResource(R.string.delete_code_mismatch_message),
                color = colors.textBody,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Right,
            )
            Row(modifier = Modifier.fillMaxWidth()) {
                TextButton(onClick = { mismatch = false }) {
                    Text(stringResource(R.string.ok), color = colors.gold)
                }
            }
        }
    }
}

@Composable
fun MessageOverlay(
    visible: Boolean,
    title: String,
    message: String,
    onDismiss: () -> Unit,
) {
    if (!visible) return
    val colors = Theme.colors
    AppDialogOverlay(onDismiss = onDismiss) {
        Text(
            title,
            color = colors.textBright,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Right,
        )
        Text(
            message,
            color = colors.textBody,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Right,
        )
        Row(modifier = Modifier.fillMaxWidth()) {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.ok), color = colors.gold)
            }
        }
    }
}

@Composable
fun AppDialogOverlay(
    onDismiss: () -> Unit,
    dismissOnBack: Boolean = true,
    dismissOnScrim: Boolean = true,
    content: @Composable ColumnScope.() -> Unit,
) {
    val colors = Theme.colors
    BackHandler(enabled = dismissOnBack, onBack = onDismiss)
    Box(Modifier.fillMaxSize()) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.5f))
                .then(if (dismissOnScrim) Modifier.clickable(onClick = onDismiss) else Modifier),
        )
        Surface(
            modifier = Modifier
                .align(Alignment.Center)
                .padding(24.dp)
                .fillMaxWidth(),
            shape = RoundedCornerShape(28.dp),
            color = colors.elevated,
        ) {
            Column(
                modifier = Modifier.padding(24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
                content = content,
            )
        }
    }
}

private fun randomCode(): String {
    val chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    return (1..8).map { chars.random() }.joinToString("")
}
