package com.cbtipul.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.lifecycleScope
import com.cbtipul.app.settings.AppAppearance
import com.cbtipul.app.settings.AppTextSize
import com.cbtipul.app.ui.RootScreen
import com.cbtipul.app.ui.theme.CbTipulTheme
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        handleAuthIntent(intent)
        val preferences = (application as CbTipulApp).preferences
        setContent {
            val textSize by preferences.textSize.collectAsStateWithLifecycle(
                initialValue = AppTextSize.Standard,
            )
            CbTipulTheme(appearance = AppAppearance.Dark, textSize = textSize) {
                RootScreen()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAuthIntent(intent)
    }

    private fun handleAuthIntent(intent: Intent?) {
        val app = application as CbTipulApp
        val message = getString(R.string.verification_failed_error)
        lifecycleScope.launch {
            app.authRepository.handleAuthIntent(intent, message)
        }
    }
}
