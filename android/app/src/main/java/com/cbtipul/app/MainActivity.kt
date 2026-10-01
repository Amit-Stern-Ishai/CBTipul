package com.cbtipul.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.ui.Modifier
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.lifecycleScope
import com.cbtipul.app.data.NotificationIntent
import com.cbtipul.app.invite.InvitationLink
import com.cbtipul.app.settings.AppAppearance
import com.cbtipul.app.settings.AppTextSize
import com.cbtipul.app.ui.RootScreen
import com.cbtipul.app.ui.theme.CbTipulTheme
import com.cbtipul.app.ui.theme.Theme
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        handleIncomingIntent(intent)
        val preferences = (application as CbTipulApp).preferences
        setContent {
            val textSize by preferences.textSize.collectAsStateWithLifecycle(
                initialValue = AppTextSize.Standard,
            )
            val appearance by preferences.appearance.collectAsStateWithLifecycle(
                initialValue = AppAppearance.Dark,
            )
            CbTipulTheme(appearance = appearance, textSize = textSize) {
                // Own and consume system-bar, cutout and keyboard insets once.
                // Nested Scaffolds then measure their bars inside this safe viewport.
                Box(Modifier.fillMaxSize().background(Theme.colors.base).safeDrawingPadding()) {
                    com.cbtipul.app.ui.AppVersionGate((application as CbTipulApp).appVersion) { RootScreen() }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingIntent(intent)
    }

    private fun handleIncomingIntent(intent: Intent?) {
        handleAuthIntent(intent)
        handleInvitationIntent(intent)
        handleNotificationIntent(intent)
    }

    private fun handleNotificationIntent(intent: Intent?) {
        val payload = NotificationIntent.payload(intent) ?: return
        NotificationIntent.clear(intent)
        (application as CbTipulApp).pendingDestinations.offer(payload)
    }

    private fun handleAuthIntent(intent: Intent?) {
        val app = application as CbTipulApp
        val message = getString(R.string.verification_failed_error)
        lifecycleScope.launch {
            app.authRepository.handleAuthIntent(intent, message)
        }
    }

    private fun handleInvitationIntent(intent: Intent?) {
        val token = InvitationLink.tokenFrom(intent?.data) ?: return
        val app = application as CbTipulApp
        app.applicationScope.launch {
            app.invitationFlow.start(token)
        }
    }
}
