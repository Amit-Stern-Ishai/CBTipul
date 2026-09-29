package com.cbtipul.app.ui.patients

import androidx.compose.material.icons.automirrored.outlined.HelpOutline
import com.cbtipul.app.ui.theme.IconLabel
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.cbtipul.app.R
import com.cbtipul.app.ui.theme.Theme

/** A deep link always has a visible loading/error destination and a way back. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun NotificationTargetScreen(
    onBack: () -> Unit,
    loading: Boolean = false,
    error: String? = null,
    onRetry: (() -> Unit)? = null,
) {
    Scaffold(
        containerColor = Theme.colors.base,
        topBar = {
            TopAppBar(title = {}, navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(Icons.AutoMirrored.Outlined.ArrowBack, stringResource(R.string.back))
                }
            })
        },
    ) { padding ->
        Column(
            Modifier.fillMaxSize().padding(padding).padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (loading) CircularProgressIndicator() else {
                IconLabel(error ?: stringResource(R.string.notification_target_unavailable), Icons.AutoMirrored.Outlined.HelpOutline, color = Theme.colors.textBody)
                if (onRetry != null) TextButton(onClick = onRetry) { Text(stringResource(R.string.retry)) }
                TextButton(onClick = onBack) { Text(stringResource(R.string.back)) }
            }
        }
    }
}
