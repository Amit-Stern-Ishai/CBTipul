package com.cbtipul.app.ui.patient

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.themedScreen

@Composable
fun PatientActivationIncompleteScreen(
    onRetry: () -> Unit,
    onLeaveToTherapistSignIn: () -> Unit,
    isLeaving: Boolean = false,
) {
    PatientStatusScreen(
        title = stringResource(R.string.patient_activation_incomplete_title),
        body = stringResource(R.string.patient_activation_incomplete_body),
        onRetry = onRetry,
        secondaryText = stringResource(R.string.patient_activation_therapist_sign_in),
        onSecondary = onLeaveToTherapistSignIn,
        secondaryEnabled = !isLeaving,
    )
}

@Composable
fun PatientContextRetryScreen(
    onRetry: () -> Unit,
    onLeaveToTherapistSignIn: () -> Unit,
    isLeaving: Boolean = false,
) {
    PatientStatusScreen(
        title = stringResource(R.string.patient_context_retry_title),
        body = stringResource(R.string.patient_context_retry_body),
        onRetry = onRetry,
        secondaryText = stringResource(R.string.patient_activation_therapist_sign_in),
        onSecondary = onLeaveToTherapistSignIn,
        secondaryEnabled = !isLeaving,
    )
}

@Composable
private fun PatientStatusScreen(
    title: String,
    body: String,
    onRetry: () -> Unit,
    secondaryText: String? = null,
    onSecondary: (() -> Unit)? = null,
    secondaryEnabled: Boolean = true,
) {
    val colors = Theme.colors
    Column(
        modifier = Modifier
            .themedScreen(colors.gold)
            .padding(horizontal = 24.dp)
            .padding(bottom = 28.dp),
    ) {
        Spacer(Modifier.height(24.dp))
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text(title, color = colors.textBright, fontWeight = FontWeight.Bold, fontSize = 28.sp)
            Text(body, color = colors.textBody)
        }
        Spacer(Modifier.height(32.dp))
        Button(
            onClick = onRetry,
            enabled = secondaryEnabled,
            modifier = Modifier.fillMaxWidth().height(48.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = colors.accentFill,
                contentColor = colors.textOnAccent,
            ),
            shape = RoundedCornerShape(14.dp),
        ) {
            Text(stringResource(R.string.patient_activation_retry), fontWeight = FontWeight.SemiBold)
        }
        if (secondaryText != null && onSecondary != null) {
            Spacer(Modifier.height(12.dp))
            TextButton(
                onClick = onSecondary,
                enabled = secondaryEnabled,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(secondaryText, color = colors.gold, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}
