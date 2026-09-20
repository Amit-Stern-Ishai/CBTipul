package com.cbtipul.app.ui.invite

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.cbtipul.app.R
import com.cbtipul.app.data.ActivationFailure
import com.cbtipul.app.data.InvitationPhase
import com.cbtipul.app.data.PatientInvitationFlow
import com.cbtipul.app.data.PatientInvitationPreviewStatus
import com.cbtipul.app.debug.InviteDebugLog
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.themedScreen

@Composable
fun InvitationFlowScreen(flow: PatientInvitationFlow) {
    val phase by flow.phase.collectAsStateWithLifecycle()
    when (val current = phase) {
        InvitationPhase.Idle -> Box(Modifier.themedScreen(Theme.colors.gold))
        InvitationPhase.Loading -> InvitationLoading()
        is InvitationPhase.Preview -> InvitationPreview(
            therapistDisplayName = current.therapistDisplayName,
            onContinue = { flow.continueToConsent() },
            onClose = { flow.dismiss() },
        )
        is InvitationPhase.Unavailable -> InvitationMessage(
            title = unavailableTitle(current.status),
            body = unavailableBody(current.status),
            onClose = { flow.dismiss() },
        )
        InvitationPhase.Failed -> InvitationMessage(
            title = stringResource(R.string.invite_preview_load_failed),
            body = stringResource(R.string.invite_preview_load_failed_body),
            onClose = { flow.dismiss() },
        )
        InvitationPhase.Consent -> InvitationConsent(
            onAccept = { flow.accept() },
            onBack = { flow.returnToPreview() },
        )
        InvitationPhase.Activating -> InvitationActivating()
        is InvitationPhase.ActivationFailed -> InvitationActivationFailed(
            failure = current.failure,
            onRetry = {
                InviteDebugLog.d("Retry tapped")
                flow.accept()
            },
            onClose = { flow.dismiss() },
        )
    }
}

@Composable
private fun InvitationLoading() {
    Box(Modifier.themedScreen(Theme.colors.gold), contentAlignment = Alignment.Center) {
        CircularProgressIndicator(color = Theme.colors.gold)
    }
}

@Composable
private fun InvitationActivating() {
    val colors = Theme.colors
    Box(Modifier.themedScreen(colors.gold), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.padding(24.dp),
        ) {
            CircularProgressIndicator(color = colors.gold)
            Text(
                stringResource(R.string.patient_activation_connecting),
                color = colors.textBody,
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun InvitationPreview(
    therapistDisplayName: String,
    onContinue: () -> Unit,
    onClose: () -> Unit,
) {
    val colors = Theme.colors
    InvitationChrome(
        onBack = onClose,
        content = {
            Text(
                stringResource(R.string.invite_preview_title),
                color = colors.textBright,
                fontWeight = FontWeight.Bold,
                fontSize = 28.sp,
            )
            Text(
                stringResource(R.string.invite_preview_therapist_line, therapistDisplayName),
                color = colors.textBody,
            )
            Text(stringResource(R.string.invite_preview_explanation), color = colors.textBody)
        },
        footer = {
            GoldButton(stringResource(R.string.invite_preview_continue), onClick = onContinue)
            TextButton(onClick = onClose, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.invite_preview_close), color = colors.textBody, fontWeight = FontWeight.Medium)
            }
        },
    )
}

@Composable
private fun InvitationMessage(
    title: String,
    body: String,
    onClose: () -> Unit,
) {
    val colors = Theme.colors
    InvitationChrome(
        onBack = onClose,
        content = {
            Text(title, color = colors.textBright, fontWeight = FontWeight.Bold, fontSize = 28.sp)
            if (body.isNotEmpty()) {
                Text(body, color = colors.textBody)
            }
        },
        footer = {
            GoldButton(stringResource(R.string.invite_preview_close), onClick = onClose)
        },
    )
}

@Composable
private fun InvitationActivationFailed(
    failure: ActivationFailure,
    onRetry: () -> Unit,
    onClose: () -> Unit,
) {
    val colors = Theme.colors
    val (title, body) = activationCopy(failure)
    InvitationChrome(
        onBack = onClose,
        content = {
            Text(title, color = colors.textBright, fontWeight = FontWeight.Bold, fontSize = 28.sp)
            Text(body, color = colors.textBody)
        },
        footer = {
            GoldButton(stringResource(R.string.patient_activation_retry), onClick = onRetry)
            TextButton(onClick = onClose, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.invite_preview_close), color = colors.textBody, fontWeight = FontWeight.Medium)
            }
        },
    )
}

@Composable
private fun InvitationConsent(
    onAccept: () -> Unit,
    onBack: () -> Unit,
) {
    val colors = Theme.colors
    val uriHandler = LocalUriHandler.current
    var hasAccepted by remember { mutableStateOf(false) }
    var isStarting by remember { mutableStateOf(false) }
    BackHandler(enabled = !isStarting) { onBack() }
    Column(Modifier.themedScreen(colors.gold)) {
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp)
                .padding(top = 24.dp, bottom = 16.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            Text(
                stringResource(R.string.invite_consent_title),
                color = colors.textBright,
                fontWeight = FontWeight.Bold,
                fontSize = 28.sp,
            )
            Text(stringResource(R.string.invite_consent_intro), color = colors.textBody)
            ConsentCard(
                title = stringResource(R.string.invite_consent_therapist_heading),
                body = stringResource(R.string.invite_consent_therapist_body),
            )
            ConsentCard(
                title = stringResource(R.string.invite_consent_data_heading),
                body = stringResource(R.string.invite_consent_data_body),
            )
            ConsentCard(
                title = stringResource(R.string.invite_consent_emergency_heading),
                body = stringResource(R.string.invite_consent_emergency_body),
            )
            TextButton(onClick = { uriHandler.openUri("https://cbtipul.com/privacy/") }) {
                Text(
                    stringResource(R.string.privacy_policy_title),
                    color = colors.gold,
                    fontWeight = FontWeight.SemiBold,
                )
            }
            TextButton(onClick = { uriHandler.openUri("https://cbtipul.com/terms/") }) {
                Text(
                    stringResource(R.string.terms_title),
                    color = colors.gold,
                    fontWeight = FontWeight.SemiBold,
                )
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.Top,
            ) {
                Checkbox(
                    checked = hasAccepted,
                    onCheckedChange = { hasAccepted = it },
                    enabled = !isStarting,
                    colors = CheckboxDefaults.colors(
                        checkedColor = colors.gold,
                        uncheckedColor = colors.textBody,
                    ),
                )
                Text(
                    stringResource(R.string.invite_consent_acceptance),
                    color = colors.textBright,
                    modifier = Modifier.padding(top = 12.dp),
                )
            }
        }
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(top = 12.dp, bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            GoldButton(
                text = stringResource(R.string.invite_consent_accept),
                enabled = hasAccepted && !isStarting,
                onClick = {
                    isStarting = true
                    onAccept()
                },
            )
            TextButton(
                onClick = onBack,
                enabled = !isStarting,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(stringResource(R.string.invite_consent_back), color = colors.textBody, fontWeight = FontWeight.Medium)
            }
        }
    }
}

@Composable
private fun ConsentCard(title: String, body: String) {
    val colors = Theme.colors
    GroupedListCard(accent = colors.gold) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(title, color = colors.textBright, fontWeight = FontWeight.SemiBold)
            Text(body, color = colors.textBody)
        }
    }
}

@Composable
private fun InvitationChrome(
    onBack: () -> Unit,
    content: @Composable () -> Unit,
    footer: @Composable () -> Unit,
) {
    BackHandler(onBack = onBack)
    Column(
        modifier = Modifier
            .themedScreen(Theme.colors.gold)
            .padding(horizontal = 24.dp)
            .padding(bottom = 28.dp),
    ) {
        Spacer(Modifier.height(24.dp))
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            content()
        }
        Spacer(Modifier.height(32.dp))
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            footer()
        }
    }
}

@Composable
private fun GoldButton(
    text: String,
    onClick: () -> Unit,
    enabled: Boolean = true,
) {
    val colors = Theme.colors
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.fillMaxWidth().height(48.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = colors.gold,
            contentColor = colors.textOnAccent,
            disabledContainerColor = colors.goldDim,
        ),
        shape = RoundedCornerShape(14.dp),
    ) {
        Text(text, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun unavailableTitle(status: PatientInvitationPreviewStatus): String = stringResource(
    when (status) {
        PatientInvitationPreviewStatus.Valid -> R.string.invite_preview_title
        PatientInvitationPreviewStatus.Expired -> R.string.invite_expired_title
        PatientInvitationPreviewStatus.Claimed -> R.string.invite_claimed_title
        PatientInvitationPreviewStatus.Cancelled -> R.string.invite_cancelled_title
        PatientInvitationPreviewStatus.Invalid -> R.string.invite_invalid_title
    },
)

@Composable
private fun unavailableBody(status: PatientInvitationPreviewStatus): String = when (status) {
    PatientInvitationPreviewStatus.Valid, PatientInvitationPreviewStatus.Invalid -> ""
    PatientInvitationPreviewStatus.Expired -> stringResource(R.string.invite_expired_body)
    PatientInvitationPreviewStatus.Claimed -> stringResource(R.string.invite_claimed_body)
    PatientInvitationPreviewStatus.Cancelled -> stringResource(R.string.invite_cancelled_body)
}

@Composable
private fun activationCopy(failure: ActivationFailure): Pair<String, String> = when (failure) {
    ActivationFailure.SignIn -> stringResource(R.string.patient_activation_failed_title) to
        stringResource(R.string.patient_activation_sign_in_failed)
    is ActivationFailure.Claim -> when (failure.status) {
        PatientInvitationPreviewStatus.Expired ->
            stringResource(R.string.invite_expired_title) to stringResource(R.string.invite_expired_body)
        PatientInvitationPreviewStatus.Claimed ->
            stringResource(R.string.invite_claimed_title) to stringResource(R.string.invite_claimed_body)
        PatientInvitationPreviewStatus.Cancelled ->
            stringResource(R.string.invite_cancelled_title) to stringResource(R.string.invite_cancelled_body)
        PatientInvitationPreviewStatus.Invalid ->
            stringResource(R.string.invite_invalid_title) to ""
        PatientInvitationPreviewStatus.Valid, null ->
            stringResource(R.string.patient_activation_failed_title) to
                stringResource(R.string.patient_activation_claim_failed)
    }
    ActivationFailure.Context -> stringResource(R.string.patient_activation_failed_title) to
        stringResource(R.string.patient_activation_context_failed)
}
