package com.cbtipul.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.lifecycleScope
import com.cbtipul.app.invite.InvitationLink
import com.cbtipul.app.settings.AppAppearance
import com.cbtipul.app.settings.AppTextSize
import com.cbtipul.app.ui.RootScreen
import com.cbtipul.app.ui.theme.CbTipulTheme
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
                RootScreen()
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
