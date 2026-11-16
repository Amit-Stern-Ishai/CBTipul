package com.cbtipul.app.ui

import androidx.compose.runtime.*
import kotlinx.coroutines.launch
import kotlinx.coroutines.CancellationException
import androidx.compose.ui.res.stringResource
import com.cbtipul.app.R
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.unit.dp
import androidx.compose.ui.text.style.TextAlign
import com.cbtipul.app.data.EmailInvitationClaim.State

@Composable
internal fun EmailClaimScreen(state: State, onRetry: (Boolean) -> Unit, onContinue: () -> Unit, onSignOut: () -> Unit, resend: suspend () -> Unit) {
    var resending by remember { mutableStateOf(false) }
    var notice by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    Surface(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().padding(28.dp), verticalArrangement = Arrangement.spacedBy(20.dp, Alignment.CenterVertically), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(when(state) {
                State.Confirmation -> "לעבור למצב מטופל/ת?"
                State.Unavailable -> "ההזמנה אינה זמינה"
                State.Verification -> "אימות כתובת האימייל"
                else -> "לא ניתן לבדוק את ההזמנה"
            }, style = MaterialTheme.typography.headlineSmall, textAlign = TextAlign.Center)
            Text(when(state) {
                State.Confirmation -> "נמצאה הזמנה ממטפל/ת. האם לעבור לחשבון המטופל/ת?"
                State.Unavailable -> "לא ניתן להשתמש בהזמנה הזו. אפשר להמשיך לחשבון הקיים."
                State.Verification -> "יש לאמת את כתובת האימייל באמצעות הקישור שנשלח אליכם, ואז לנסות שוב."
                else -> "נסו שוב כדי לבדוק אם החשבון כבר חובר."
            }, textAlign = TextAlign.Center)
            if (state != State.Unavailable) Button(onClick = { onRetry(state == State.Confirmation) }) {
                Text(if (state == State.Confirmation) "מעבר למצב מטופל/ת" else "ניסיון נוסף")
            }
            if (state == State.Confirmation || state == State.Unavailable) TextButton(onClick = onContinue) { Text("המשך לחשבון הקיים") }
            if (state == State.Verification) {
                TextButton(enabled = !resending, onClick = {
                    resending = true
                    scope.launch {
                        try { resend(); notice = "קישור האימות נשלח. בדקו את תיבת האימייל." }
                        catch (cancel: CancellationException) { throw cancel }
                        catch (_: Exception) { notice = "לא ניתן לשלוח את הקישור. נסו שוב." }
                        finally { resending = false }
                    }
                }) { Text(stringResource(R.string.resend_verification_action)) }
                notice?.let { Text(it) }
            }
            TextButton(onClick = onSignOut) { Text("יציאה מהחשבון") }
        }
    }
}
