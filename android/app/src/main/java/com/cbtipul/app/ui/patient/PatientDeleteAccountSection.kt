package com.cbtipul.app.ui.patient

import androidx.compose.runtime.*
import androidx.compose.material3.*
import androidx.compose.foundation.layout.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.cbtipul.app.CbTipulApp
import com.cbtipul.app.ui.patients.ConfirmDeleteOverlay
import kotlinx.coroutines.launch

@Composable
fun PatientDeleteAccountSection(onDeleted: () -> Unit, onBusy: (Boolean) -> Unit) {
    val app = LocalContext.current.applicationContext as CbTipulApp
    val auth = app.authRepository
    val owner = auth.currentUserId()
    val scope = rememberCoroutineScope()
    val model = remember(owner) { PatientAccountDeletion(
        identity = { auth.currentUserId() },
        request = { auth.deletePatientAccountForDebug(checkNotNull(owner)) },
        checkSession = { auth.verifyPatientDeletionSession(checkNotNull(owner)) },
        cleanup = { auth.finishPatientDeletion(checkNotNull(owner)); check(auth.currentUserId() == null); app.appContext.clear(); onDeleted() },
    ) }
    DisposableEffect(model) { onDispose { model.invalidate(); onBusy(false) } }
    LaunchedEffect(model.busy) { onBusy(model.busy) }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        TextButton(onClick = model::ask, enabled = model.state in listOf(PatientAccountDeletion.State.Idle, PatientAccountDeletion.State.Rejected, PatientAccountDeletion.State.Retryable)) {
            Text("מחיקת חשבון", color = MaterialTheme.colorScheme.error)
        }
        if (model.busy) {
            CircularProgressIndicator()
            Text(if (model.state == PatientAccountDeletion.State.Checking) "בודק את מצב ההתחברות…" else "מוחק את החשבון…")
        }
        when (model.state) {
            PatientAccountDeletion.State.Rejected -> Text("הבקשה למחיקת החשבון נדחתה. אפשר לנסות שוב.")
            PatientAccountDeletion.State.Uncertain, PatientAccountDeletion.State.SessionUnverified -> {
                Text("לא ניתן לאשר שהחשבון נמחק. יש לבדוק את מצב ההתחברות לפני ניסיון נוסף.")
                TextButton(onClick = { scope.launch { model.recheck() } }) { Text("בדיקת מצב ההתחברות") }
            }
            PatientAccountDeletion.State.Retryable -> Text("ההתחברות אומתה. אפשר לנסות שוב למחוק את החשבון.")
            PatientAccountDeletion.State.CleanupFailed -> {
                Text("החשבון נמחק. לא ניתן להשלים את היציאה מהמכשיר.")
                TextButton(onClick = { scope.launch { model.retryCleanup() } }) { Text("השלמת היציאה") }
            }
            else -> Unit
        }
    }
    ConfirmDeleteOverlay(phrase = com.cbtipul.app.ui.patients.DeletionPhrase.Account, visible = model.state == PatientAccountDeletion.State.Confirming,
        title = "למחוק את החשבון?",
        message = "זו מחיקת החשבון, ולא רק יציאה ממנו. פרטי ההתחברות והגישה שלכם לאפליקציה יימחקו. תיק המטופל/ת והרשומות הקליניות אצל המטפל/ת יישארו. לא ניתן לבטל את המחיקה.",
        confirmLabel = "מחיקת חשבון", onConfirm = { scope.launch { model.confirm() } }, onDismiss = model::cancel)
}
