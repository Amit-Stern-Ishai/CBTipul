package com.cbtipul.app.ui.patients

import androidx.compose.foundation.layout.imePadding
import com.cbtipul.app.ui.theme.editorScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import com.cbtipul.app.ui.theme.editorFocus
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

enum class DeletionPhrase(val text: String) {
    Patient("מחיקת מטופל"), Account("מחיקת חשבון"), Session("מחיקת פגישה"), Questionnaire("מחיקת שאלוני מצב הרוח");
    fun matches(input: String) = input.trim() == text
}

@Composable
fun ConfirmDeleteOverlay(
    visible: Boolean,
    title: String,
    message: String,
    confirmLabel: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
    phrase: DeletionPhrase? = null,
) {
    if (!visible) return
    var input by remember(phrase) { mutableStateOf("") }
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
        if (phrase != null) {
            Text(stringResource(R.string.delete_code_message, phrase.text), color = colors.textBody)
            OutlinedTextField(value = input, onValueChange = { input = it }, singleLine = true,
                modifier = Modifier.editorFocus().fillMaxWidth(),
                textStyle = TextStyle(color = colors.textBright, textDirection = TextDirection.Rtl, textAlign = TextAlign.Right),
                placeholder = { Text(stringResource(R.string.delete_code_placeholder)) })
        }
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            TextButton(onClick = { if (phrase == null || phrase.matches(input)) onConfirm() }, enabled = phrase == null || phrase.matches(input)) {
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
    phrase: DeletionPhrase,
    visible: Boolean,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    if (!visible) return
    val colors = Theme.colors
    var input by remember(phrase) { mutableStateOf("") }
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
            stringResource(R.string.delete_code_message, phrase.text),
            color = colors.textBody,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Right,
        )
        OutlinedTextField(
            value = input,
            onValueChange = { input = it },
            modifier = Modifier.editorFocus().fillMaxWidth(),
            singleLine = true,
            textStyle = TextStyle(
                color = colors.textBright,
                textDirection = TextDirection.Rtl,
                textAlign = TextAlign.Right,
                fontSize = 16.sp,
            ),
            placeholder = { Text(stringResource(R.string.delete_code_placeholder)) },
        )
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            TextButton(
                enabled = phrase.matches(input),
                onClick = {
                    if (phrase.matches(input)) {
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
    Box(Modifier.fillMaxSize().imePadding()) {
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
                modifier = Modifier.editorScroll().padding(24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
                content = content,
            )
        }
    }
}
