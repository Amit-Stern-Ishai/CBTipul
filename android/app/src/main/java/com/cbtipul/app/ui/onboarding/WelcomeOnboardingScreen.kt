package com.cbtipul.app.ui.onboarding

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.themedScreen

/** Optional sample-data introduction opened from Settings, never a first-run gate. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WelcomeOnboardingScreen(onStartDemoTour: () -> Unit, onSkip: () -> Unit, allowsSkip: Boolean = true) {
    BackHandler { if (allowsSkip) onSkip() }
    val colors = Theme.colors
    Scaffold(modifier = Modifier.themedScreen(colors.gold), containerColor = colors.base,
        topBar = { TopAppBar(title = {}, navigationIcon = {
            if (allowsSkip) TextButton(onClick = onSkip) { Text(stringResource(R.string.cancel)) }
        }) },
        bottomBar = { Button(onClick = onStartDemoTour, modifier = Modifier.fillMaxWidth().navigationBarsPadding().padding(24.dp),
            colors = ButtonDefaults.buttonColors(containerColor = colors.accentFill, contentColor = colors.textOnAccent)) {
            Text(stringResource(R.string.sample_data_start_action), modifier = Modifier.padding(8.dp), fontWeight = FontWeight.Bold)
        } },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp)) {
            Text(stringResource(R.string.getting_started_guide_settings_title), color = colors.textBright, fontSize = 28.sp, fontWeight = FontWeight.Bold)
            Text(stringResource(R.string.getting_started_guide_settings_subtitle), color = colors.textBody)
            listOf(R.string.sample_data_explore_title to R.string.sample_data_explore_body,
                R.string.sample_data_separate_title to R.string.sample_data_separate_body,
                R.string.sample_data_return_title to R.string.sample_data_return_body).forEach { (title, body) ->
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(stringResource(title), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                    Text(stringResource(body), color = colors.textBody)
                }
            }
        }
    }
}
