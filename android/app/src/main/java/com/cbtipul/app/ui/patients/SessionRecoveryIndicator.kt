package com.cbtipul.app.ui.patients

import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import com.cbtipul.app.CbTipulApp
import com.cbtipul.app.data.DeviceFormDraftStore

@Composable
fun rememberSessionRecovery(target: String): Boolean {
    val app = LocalContext.current.applicationContext as CbTipulApp
    val account = app.authRepository.currentUserId()
    var exists by remember(account, target) { mutableStateOf(false) }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) {
        exists = account?.let { runCatching { app.formDrafts.read(DeviceFormDraftStore.key(it, if (app.patientRepository.isDemoMode.value) "demo-session" else "therapist-session", target)) != null }.getOrDefault(false) } ?: false
    }
    return exists
}
