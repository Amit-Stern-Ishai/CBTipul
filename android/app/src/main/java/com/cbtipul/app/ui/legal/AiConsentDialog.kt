package com.cbtipul.app.ui.legal

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.cbtipul.app.R
import com.cbtipul.app.ui.patients.AppDialogOverlay
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
    AppDialogOverlay(
        onDismiss = {},
        dismissOnBack = false,
        dismissOnScrim = false,
    ) {
        Text(
            stringResource(R.string.ai_consent_title),
            color = colors.textBright,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Right,
        )
        Text(
            body,
            color = colors.textBody,
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(max = 360.dp)
                .verticalScroll(rememberScrollState()),
            textAlign = TextAlign.Right,
        )
        Button(
            onClick = onAccept,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(
                containerColor = colors.gold,
                contentColor = colors.textOnAccent,
            ),
        ) { Text(stringResource(R.string.ai_consent_accept_action)) }
        TextButton(onClick = onDecline, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.ai_consent_decline_action), color = colors.gold)
        }
    }
}
