package com.cbtipul.app.ui.legal

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.DialogProperties
import com.cbtipul.app.R
import com.cbtipul.app.ui.theme.Theme

@Composable
fun AiConsentDialog(
    onAccept: () -> Unit,
    onDecline: () -> Unit,
) {
    val colors = Theme.colors
    val context = LocalContext.current
    val body = remember {
        context.resources.openRawResource(R.raw.ai_consent).bufferedReader().use { it.readText() }
    }
    AlertDialog(
        onDismissRequest = {},
        properties = DialogProperties(dismissOnBackPress = false, dismissOnClickOutside = false),
        title = { Text(stringResource(R.string.ai_consent_title), color = colors.textBright) },
        text = {
            Column(
                modifier = Modifier
                    .heightIn(max = 360.dp)
                    .verticalScroll(rememberScrollState()),
            ) {
                Text(body, color = colors.textBody)
            }
        },
        confirmButton = {
            Button(
                onClick = onAccept,
                modifier = Modifier.fillMaxWidth().padding(bottom = 4.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = colors.gold,
                    contentColor = colors.textOnAccent,
                ),
            ) { Text(stringResource(R.string.ai_consent_accept_action)) }
        },
        dismissButton = {
            TextButton(onClick = onDecline, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.ai_consent_decline_action), color = colors.gold)
            }
        },
    )
}
