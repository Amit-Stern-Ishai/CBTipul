package com.cbtipul.app.ui

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.cbtipul.app.R
import com.cbtipul.app.data.AppVersionDecision
import com.cbtipul.app.data.AppVersionManager
import com.cbtipul.app.ui.theme.Theme
import kotlinx.coroutines.launch

@Composable
fun AppVersionGate(manager: AppVersionManager, content: @Composable () -> Unit) {
    val state by manager.state.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { scope.launch { manager.check() } }
    when {
        state.checkingInitially -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        state.decision == AppVersionDecision.Required -> {
            BackHandler { /* Required update has no route into the app. */ }
            AppUpdateNotice(manager, required = true)
        }
        else -> content()
    }
}

@Composable
fun AppUpdateNotice(manager: AppVersionManager, required: Boolean) {
    val state by manager.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    var storeFailed by remember(state.policy?.storeUrl) { mutableStateOf(false) }
    Surface(color = Theme.colors.base) {
        Column(
            (if (required) Modifier.fillMaxSize() else Modifier.fillMaxWidth().heightIn(max = 260.dp))
                .verticalScroll(rememberScrollState()).padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
        ) {
            Text(stringResource(if (required) R.string.update_required_title else R.string.update_optional_title),
                style = MaterialTheme.typography.headlineSmall, color = Theme.colors.textBright)
            Text(stringResource(if (required) R.string.update_required_body else R.string.update_optional_body), color = Theme.colors.textBody)
            if (storeFailed) Text(stringResource(R.string.update_store_failed), color = Theme.colors.error)
            Button(onClick = {
                state.policy?.storeUrl?.let { url ->
                    storeFailed = runCatching {
                        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    }.isFailure
                }
            }, colors = ButtonDefaults.buttonColors(containerColor = Theme.colors.accentFill, contentColor = Theme.colors.textOnAccent)) {
                Text(stringResource(if (required) R.string.update_required_action else R.string.update_optional_action))
            }
            if (!required) TextButton(onClick = manager::dismissOptional) { Text(stringResource(R.string.update_later_action)) }
        }
    }
}
