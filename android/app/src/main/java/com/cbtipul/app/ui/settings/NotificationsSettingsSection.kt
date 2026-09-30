package com.cbtipul.app.ui.settings

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.StringRes
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.cbtipul.app.CbTipulApp
import com.cbtipul.app.R
import com.cbtipul.app.push.OsNotificationAuthorization
import com.cbtipul.app.push.PushDeliveryPolicy
import com.cbtipul.app.ui.patients.MessageOverlay
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.Theme
import kotlinx.coroutines.launch

@Composable
internal fun NotificationsSettingsSection(@StringRes explanationRes: Int) {
    val app = LocalContext.current.applicationContext as CbTipulApp
    val colors = Theme.colors
    val scope = rememberCoroutineScope()
    val lifecycleOwner = LocalLifecycleOwner.current
    var preferenceOn by remember { mutableStateOf(true) }
    var osStatus by remember { mutableStateOf(OsNotificationAuthorization.Allowed) }
    var busy by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    val osAllowed = osStatus == OsNotificationAuthorization.Allowed
    val osDenied = osStatus == OsNotificationAuthorization.Denied
    val effectiveOn = PushDeliveryPolicy.toggleShowsOn(preferenceOn, osAllowed)
    val disableFailed = stringResource(R.string.settings_notifications_disable_failed)
    val enableFailed = stringResource(R.string.settings_notifications_enable_failed)
    val permissionDenied = stringResource(R.string.settings_notifications_permission_denied)

    suspend fun refresh() {
        preferenceOn = app.preferences.isNotificationsEnabledByUser()
        osStatus = app.pushManager.osAuthorization()
    }

    LaunchedEffect(Unit) { refresh() }

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                scope.launch { refresh() }
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        scope.launch {
            if (granted) {
                try {
                    app.pushManager.enableNotificationsAfterOsAllowed()
                } catch (_: Exception) {
                    errorMessage = enableFailed
                }
            } else {
                errorMessage = permissionDenied
            }
            busy = false
            refresh()
        }
    }

    Text(
        stringResource(R.string.settings_notifications_section_title),
        color = colors.textBright,
        fontWeight = FontWeight.SemiBold,
    )
    GroupedListCard(accent = colors.gold) {
        Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    stringResource(R.string.settings_notifications_receive_title),
                    color = colors.textBright,
                    modifier = Modifier.weight(1f).padding(end = 12.dp),
                )
                Switch(
                    checked = effectiveOn,
                    enabled = !busy,
                    onCheckedChange = { wantOn ->
                        if (busy) return@Switch
                        busy = true
                        scope.launch {
                            try {
                                if (!wantOn) {
                                    app.pushManager.disableNotifications()
                                } else if (preferenceOn && !osAllowed) {
                                    app.pushManager.openSystemNotificationSettings()
                                } else {
                                    when (PushDeliveryPolicy.actionForTurningOn(app.pushManager.osAuthorization())) {
                                        PushDeliveryPolicy.TurnOnAction.RemainOffAndOfferSettings -> {
                                            errorMessage = permissionDenied
                                            app.pushManager.openSystemNotificationSettings()
                                        }
                                        PushDeliveryPolicy.TurnOnAction.RequestPermission -> {
                                            if (Build.VERSION.SDK_INT >= 33) {
                                                app.pushManager.markOsPermissionAsked()
                                                permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                                                return@launch
                                            }
                                            app.pushManager.enableNotificationsAfterOsAllowed()
                                        }
                                        PushDeliveryPolicy.TurnOnAction.PersistOnAndRegister -> {
                                            app.pushManager.enableNotificationsAfterOsAllowed()
                                        }
                                    }
                                }
                            } catch (_: Exception) {
                                errorMessage = if (wantOn) enableFailed else disableFailed
                            } finally {
                                busy = false
                                refresh()
                            }
                        }
                    },
                    colors = SwitchDefaults.colors(
                        checkedTrackColor = colors.gold,
                    ),
                )
            }
            Text(
                stringResource(explanationRes),
                color = colors.textBody,
                fontSize = 13.sp,
                modifier = Modifier.padding(top = 4.dp, bottom = 4.dp),
            )
            if (osDenied) {
                TextButton(onClick = { app.pushManager.openSystemNotificationSettings() }) {
                    Text(
                        stringResource(R.string.settings_notifications_open_system_settings),
                        color = colors.gold,
                    )
                }
            }
        }
    }

    MessageOverlay(
        visible = errorMessage != null,
        title = stringResource(R.string.settings_notifications_receive_title),
        message = errorMessage.orEmpty(),
        onDismiss = { errorMessage = null },
    )
}
