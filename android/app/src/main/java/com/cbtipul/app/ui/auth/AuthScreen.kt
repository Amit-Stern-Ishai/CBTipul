package com.cbtipul.app.ui.auth

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Email
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.MarkEmailUnread
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.auth.AuthMode
import com.cbtipul.app.auth.AuthUiState
import com.cbtipul.app.auth.PasswordRule
import com.cbtipul.app.ui.theme.BusyOverlay
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.dismissKeyboardOnTap
import com.cbtipul.app.ui.theme.themedScreen

@Composable
fun AuthScreen(
    state: AuthUiState,
    callbackError: String?,
    onEmailChange: (String) -> Unit,
    onPasswordChange: (String) -> Unit,
    onConfirmPasswordChange: (String) -> Unit,
    onModeChange: (AuthMode) -> Unit,
    onSubmit: () -> Unit,
    onForgotPassword: () -> Unit,
    onResend: () -> Unit,
    onBackToSignIn: () -> Unit,
) {
    val colors = Theme.colors
    Box(Modifier.fillMaxSize()) {
    Column(
        modifier = Modifier
            .themedScreen(colors.gold)
            .dismissKeyboardOnTap()
            .verticalScroll(rememberScrollState())
            .padding(24.dp)
            .padding(top = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(28.dp),
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Image(
                painter = painterResource(R.drawable.splash_icon),
                contentDescription = null,
                modifier = Modifier
                    .size(88.dp)
                    .clip(RoundedCornerShape(26.dp)),
            )
            Text(
                text = stringResource(R.string.app_title),
                color = colors.textBright,
                fontSize = 34.sp,
                fontWeight = FontWeight.Bold,
            )
            if (state.verificationEmail == null) {
                Text(
                    text = stringResource(
                        if (state.mode == AuthMode.SignIn) {
                            R.string.auth_welcome_sign_in
                        } else {
                            R.string.auth_welcome_sign_up
                        },
                    ),
                    color = colors.textBody,
                    fontSize = 14.sp,
                    textAlign = TextAlign.Center,
                )
            }
        }

        if (state.verificationEmail != null) {
            VerificationCard(
                state = state,
                onResend = onResend,
                onBackToSignIn = onBackToSignIn,
            )
        } else {
            AuthCard(
                state = state,
                callbackError = callbackError,
                onEmailChange = onEmailChange,
                onPasswordChange = onPasswordChange,
                onConfirmPasswordChange = onConfirmPasswordChange,
                onModeChange = onModeChange,
                onSubmit = onSubmit,
                onForgotPassword = onForgotPassword,
            )
        }
    }
        BusyOverlay(state.isWorking)
    }
}

@Composable
private fun AuthCard(
    state: AuthUiState,
    callbackError: String?,
    onEmailChange: (String) -> Unit,
    onPasswordChange: (String) -> Unit,
    onConfirmPasswordChange: (String) -> Unit,
    onModeChange: (AuthMode) -> Unit,
    onSubmit: () -> Unit,
    onForgotPassword: () -> Unit,
) {
    val colors = Theme.colors
    val canSubmit = state.email.isNotBlank() &&
        state.password.isNotEmpty() &&
        !state.isWorking &&
        (state.mode == AuthMode.SignIn ||
            (PasswordRule.allSatisfied(state.password) && state.password == state.confirmPassword))

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(28.dp))
            .background(colors.surface)
            .border(1.dp, colors.gold.copy(alpha = 0.35f), RoundedCornerShape(28.dp))
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
            AuthMode.entries.forEachIndexed { index, mode ->
                SegmentedButton(
                    selected = state.mode == mode,
                    onClick = { onModeChange(mode) },
                    shape = SegmentedButtonDefaults.itemShape(index, AuthMode.entries.size),
                    colors = SegmentedButtonDefaults.colors(
                        activeContainerColor = colors.gold,
                        activeContentColor = colors.textOnAccent,
                        inactiveContainerColor = colors.elevated,
                        inactiveContentColor = colors.textBright,
                    ),
                    label = {
                        Text(
                            stringResource(
                                if (mode == AuthMode.SignIn) {
                                    R.string.auth_mode_sign_in
                                } else {
                                    R.string.auth_mode_sign_up
                                },
                            ),
                        )
                    },
                )
            }
        }

        AuthField(
            value = state.email,
            onValueChange = onEmailChange,
            placeholder = stringResource(R.string.email_placeholder),
            leading = { Icon(Icons.Outlined.Email, contentDescription = null, tint = colors.textBody) },
            keyboardType = KeyboardType.Email,
        )
        AuthField(
            value = state.password,
            onValueChange = onPasswordChange,
            placeholder = stringResource(R.string.password_placeholder),
            leading = { Icon(Icons.Outlined.Lock, contentDescription = null, tint = colors.textBody) },
            isPassword = true,
        )
        if (state.mode == AuthMode.SignUp) {
            AuthField(
                value = state.confirmPassword,
                onValueChange = onConfirmPasswordChange,
                placeholder = stringResource(R.string.confirm_password_placeholder),
                leading = { Icon(Icons.Outlined.Lock, contentDescription = null, tint = colors.textBody) },
                isPassword = true,
            )
            PasswordRulesChecklist(password = state.password)
            if (state.confirmPassword.isNotEmpty() &&
                state.confirmPassword.length >= state.password.length &&
                state.password != state.confirmPassword
            ) {
                Text(stringResource(R.string.passwords_dont_match_error), color = colors.error, fontSize = 13.sp)
            }
        }

        state.errorMessage?.let { Text(it, color = colors.error, fontSize = 13.sp) }
        callbackError?.let { Text(it, color = colors.error, fontSize = 13.sp) }
        state.infoMessage?.let { Text(it, color = colors.success, fontSize = 13.sp) }

        Button(
            onClick = onSubmit,
            enabled = canSubmit,
            modifier = Modifier.fillMaxWidth().height(48.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = colors.gold,
                contentColor = colors.textOnAccent,
                disabledContainerColor = colors.goldDim,
            ),
            shape = RoundedCornerShape(14.dp),
        ) {
            if (state.isWorking) {
                CircularProgressIndicator(modifier = Modifier.size(22.dp), color = colors.textOnAccent, strokeWidth = 2.dp)
            } else {
                Text(
                    stringResource(
                        if (state.mode == AuthMode.SignIn) R.string.auth_mode_sign_in else R.string.auth_mode_sign_up,
                    ),
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }

        if (state.mode == AuthMode.SignIn) {
            TextButton(onClick = onForgotPassword, enabled = !state.isWorking, modifier = Modifier.align(Alignment.CenterHorizontally)) {
                Text(stringResource(R.string.forgot_password_action), color = colors.gold)
            }
        }
    }
}

@Composable
private fun VerificationCard(
    state: AuthUiState,
    onResend: () -> Unit,
    onBackToSignIn: () -> Unit,
) {
    val colors = Theme.colors
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(28.dp))
            .background(colors.surface)
            .border(1.dp, colors.gold.copy(alpha = 0.35f), RoundedCornerShape(28.dp))
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Icon(
            Icons.Outlined.MarkEmailUnread,
            contentDescription = null,
            tint = colors.gold,
            modifier = Modifier
                .size(76.dp)
                .background(colors.goldGhost, CircleShape)
                .padding(20.dp),
        )
        Text(stringResource(R.string.verify_email_title), color = colors.textBright, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        Text(
            stringResource(R.string.verify_email_message, state.verificationEmail.orEmpty()),
            color = colors.textBody,
            textAlign = TextAlign.Center,
        )
        state.errorMessage?.let { Text(it, color = colors.error, fontSize = 13.sp) }
        state.infoMessage?.let { Text(it, color = colors.success, fontSize = 13.sp) }
        Button(
            onClick = onResend,
            enabled = !state.isWorking && !state.isResendBlocked,
            modifier = Modifier.fillMaxWidth().height(48.dp),
            colors = ButtonDefaults.buttonColors(containerColor = colors.gold, contentColor = colors.textOnAccent),
            shape = RoundedCornerShape(14.dp),
        ) {
            if (state.isWorking) {
                CircularProgressIndicator(modifier = Modifier.size(22.dp), color = colors.textOnAccent, strokeWidth = 2.dp)
            } else {
                Text(stringResource(R.string.resend_verification_action), fontWeight = FontWeight.SemiBold)
            }
        }
        TextButton(onClick = onBackToSignIn, enabled = !state.isWorking) {
            Text(stringResource(R.string.back_to_sign_in_action), color = colors.gold)
        }
    }
}

@Composable
private fun AuthField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    leading: @Composable () -> Unit,
    keyboardType: KeyboardType = KeyboardType.Text,
    isPassword: Boolean = false,
) {
    val colors = Theme.colors
    TextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = { Text(placeholder, color = colors.textFaint) },
        leadingIcon = leading,
        singleLine = true,
        visualTransformation = if (isPassword) PasswordVisualTransformation() else androidx.compose.ui.text.input.VisualTransformation.None,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .border(1.dp, colors.gold.copy(alpha = 0.35f), RoundedCornerShape(14.dp)),
        colors = TextFieldDefaults.colors(
            focusedContainerColor = colors.elevated,
            unfocusedContainerColor = colors.elevated,
            focusedTextColor = colors.textBright,
            unfocusedTextColor = colors.textBright,
            cursorColor = colors.gold,
            focusedIndicatorColor = androidx.compose.ui.graphics.Color.Transparent,
            unfocusedIndicatorColor = androidx.compose.ui.graphics.Color.Transparent,
        ),
    )
}

@Composable
fun PasswordRulesChecklist(password: String) {
    val colors = Theme.colors
    Column(verticalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
        PasswordRule.entries.forEach { rule ->
            val met = rule.isMet(password)
            val title = stringResource(
                when (rule) {
                    PasswordRule.MinLength -> R.string.password_rule_min_length
                    PasswordRule.Uppercase -> R.string.password_rule_uppercase
                    PasswordRule.Lowercase -> R.string.password_rule_lowercase
                    PasswordRule.Digit -> R.string.password_rule_digit
                    PasswordRule.Special -> R.string.password_rule_special
                },
            )
            Text(
                text = title,
                color = if (met) colors.success else colors.error,
                fontSize = 13.sp,
            )
        }
    }
}
