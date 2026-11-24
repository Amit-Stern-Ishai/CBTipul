package com.cbtipul.app.ui.patients

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.ui.unit.dp
import com.cbtipul.app.R
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.editorFocus
import androidx.compose.material3.*
import androidx.compose.runtime.*
import com.cbtipul.app.data.RevokePatientAccess
import kotlinx.coroutines.launch
import kotlinx.coroutines.CancellationException

@Composable
internal fun RevokePatientAccessDialog(onDismiss: () -> Unit, revoke: suspend () -> Unit) {
    var input by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var failed by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    fun submit() {
        if (busy || !RevokePatientAccess.matches(input)) return
        busy = true; failed = false
        scope.launch {
            try { revoke(); onDismiss() }
            catch (cancelled: CancellationException) { throw cancelled }
            catch (_: Exception) { failed = true }
            finally { busy = false }
        }
    }
    val colors = Theme.colors
    AppDialogOverlay(onDismiss = { if (!busy) onDismiss() }, dismissOnScrim = !busy) {
        Text(RevokePatientAccess.phrase, color = colors.textBright,
            fontWeight = FontWeight.SemiBold, modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Right)
        Text(RevokePatientAccess.explanation, color = colors.textBody,
            modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Right)
        Text("להמשך יש להקליד את הביטוי:\n${RevokePatientAccess.phrase}", color = colors.textBody,
            modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Right)
        OutlinedTextField(value = input, onValueChange = { input = it }, enabled = !busy, singleLine = true,
            modifier = Modifier.editorFocus().fillMaxWidth(),
            textStyle = TextStyle(color = colors.textBright, textDirection = TextDirection.Rtl, textAlign = TextAlign.Right),
            placeholder = { Text(stringResource(R.string.delete_code_placeholder)) })
        if (busy) CircularProgressIndicator()
        if (failed) {
            Text("לא ניתן להשלים את הפסקת הגישה. אפשר לנסות שוב.", color = colors.error)
            TextButton(onClick = ::submit, enabled = !busy && RevokePatientAccess.matches(input)) { Text("ניסיון נוסף") }
        }
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            TextButton(onClick = ::submit, enabled = !busy && RevokePatientAccess.matches(input)) {
                Text(RevokePatientAccess.phrase, color = colors.error)
            }
            TextButton(onClick = onDismiss, enabled = !busy) { Text(stringResource(R.string.cancel), color = colors.gold) }
        }
    }
}
