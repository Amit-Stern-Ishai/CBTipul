package com.cbtipul.app.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Alignment
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.cbtipul.app.R
import com.cbtipul.app.data.AppContextFailure
import com.cbtipul.app.data.AppContextLoadState
import com.cbtipul.app.ui.theme.Theme

@Composable
fun AccessResolutionNotice(state: AppContextLoadState, onRetry: () -> Unit) {
    val failed = state as? AppContextLoadState.Failed
    Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            if (failed == null) CircularProgressIndicator(color = Theme.colors.gold)
            Text(stringResource(if (failed == null) R.string.access_resolution_loading_title else R.string.access_resolution_failed_title), color = Theme.colors.textBright)
        }
        Text(stringResource(when (failed?.reason) {
            AppContextFailure.MissingEntitlement -> R.string.access_resolution_missing_body
            AppContextFailure.SessionInitialization -> R.string.access_resolution_session_body
            null -> R.string.access_resolution_loading_body
            else -> R.string.access_resolution_failed_body
        }), color = Theme.colors.textBody)
        if (failed != null) TextButton(onClick = onRetry) { Text(stringResource(R.string.retry), color = Theme.colors.gold) }
    }
}

@Composable
fun SessionRecoveryScreen(onRetry: suspend () -> Unit) {
    val scope = rememberCoroutineScope()
    var retrying by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally) {
        Text(stringResource(R.string.session_resolution_failed_title), color = Theme.colors.textBright)
        Text(stringResource(R.string.access_resolution_session_body), color = Theme.colors.textBody)
        if (retrying) CircularProgressIndicator(color = Theme.colors.gold)
        TextButton(enabled = !retrying, onClick = {
            retrying = true
            scope.launch { try { runCatching { onRetry() } } finally { retrying = false } }
        }) { Text(stringResource(R.string.retry), color = Theme.colors.gold) }
    }
}
