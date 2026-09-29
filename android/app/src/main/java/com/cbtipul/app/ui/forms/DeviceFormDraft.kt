package com.cbtipul.app.ui.forms

import androidx.compose.material.icons.outlined.PhoneAndroid
import androidx.compose.material.icons.outlined.WarningAmber
import androidx.compose.material.icons.Icons
import com.cbtipul.app.ui.theme.IconLabel
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import androidx.compose.material3.Text
import androidx.compose.ui.res.stringResource
import com.cbtipul.app.CbTipulApp
import com.cbtipul.app.R
import com.cbtipul.app.data.DeviceFormDraftStore
import com.cbtipul.app.ui.theme.Theme
import kotlinx.serialization.KSerializer
import kotlinx.serialization.json.Json

class DeviceFormDraft<T>(private val store: DeviceFormDraftStore, private val key: String?, private val serializer: KSerializer<T>, initial: T) {
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    var failed by mutableStateOf(false)
        private set
    var hasSaved by mutableStateOf(false)
        private set
    private val state = mutableStateOf(initial)
    init {
        try {
            if (key == null) failed = true
            else store.read(key)?.let { state.value = json.decodeFromString(serializer, it); hasSaved = true }
        } catch (_: Exception) { failed = true }
    }
    var value: T
        get() = state.value
        set(value) {
            state.value = value
            persist()
        }
    fun persist(): Boolean = try {
        check(key != null)
        store.write(key, json.encodeToString(serializer, value))
        failed = false
        hasSaved = true
        true
    } catch (_: Exception) { failed = true; false }

    fun clear(): Boolean = try {
        check(key != null)
        store.clear(key)
        failed = false
        hasSaved = false
        true
    } catch (_: Exception) { failed = true; false }

}

@Composable
fun <T> rememberDeviceFormDraft(kind: String, target: String, serializer: KSerializer<T>, initial: T): DeviceFormDraft<T> {
    val app = LocalContext.current.applicationContext as CbTipulApp
    val account = app.authRepository.currentUserId()
    return remember(account, kind, target) {
        DeviceFormDraft(app.formDrafts, account?.takeIf { it.isNotBlank() }?.let { DeviceFormDraftStore.key(it, kind, target) }, serializer, initial)
    }
}

@Composable
fun DraftStatus(failed: Boolean, visible: Boolean = true) {
    if (!visible && !failed) return
    IconLabel(stringResource(if (failed) R.string.draft_save_failed else R.string.draft_saved),
        if (failed) Icons.Outlined.WarningAmber else Icons.Outlined.PhoneAndroid,
        color = if (failed) Theme.colors.error else Theme.colors.textBody)
}

@Composable
fun DraftLeaveDialog(onKeep: () -> Unit, onDiscard: () -> Unit, onCancel: () -> Unit) {
    androidx.compose.material3.AlertDialog(
        onDismissRequest = onCancel,
        title = { Text(stringResource(R.string.leave_draft_title)) },
        confirmButton = { androidx.compose.material3.TextButton(onClick = onKeep) { Text(stringResource(R.string.keep_draft_and_leave)) } },
        dismissButton = {
            androidx.compose.foundation.layout.Column {
                androidx.compose.material3.TextButton(onClick = onDiscard) { Text(stringResource(R.string.discard_draft_action)) }
                androidx.compose.material3.TextButton(onClick = onCancel) { Text(stringResource(R.string.keep_editing_action)) }
            }
        },
    )
}
