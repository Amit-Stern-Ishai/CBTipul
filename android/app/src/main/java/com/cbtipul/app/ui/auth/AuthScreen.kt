package com.cbtipul.app.ui.auth

import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Row
import androidx.activity.compose.BackHandler
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.material3.OutlinedButton
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Cancel
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.outlined.WarningAmber
import com.cbtipul.app.ui.theme.IconLabel
import com.cbtipul.app.ui.theme.editorFocus
import com.cbtipul.app.ui.theme.editorScroll
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
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
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
    onGoogleSignIn: () -> Unit,
    onAppleSignIn: () -> Unit,
    onCancelGoogleSignIn: () -> Unit,
) {
    DisposableEffect(Unit) { onDispose { onCancelGoogleSignIn() } }
    val colors = Theme.colors
    Box(Modifier.fillMaxSize()) {
    Column(
        modifier = Modifier
            .themedScreen(colors.gold)
            .dismissKeyboardOnTap()
            .editorScroll()
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
                onGoogleSignIn = onGoogleSignIn,
                onAppleSignIn = onAppleSignIn,
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
    onGoogleSignIn: () -> Unit,
    onAppleSignIn: () -> Unit,
) {
    val colors = Theme.colors
    var showingEmailForm by rememberSaveable { mutableStateOf(false) }
    BackHandler(enabled = showingEmailForm) {
        if (!state.isWorking) showingEmailForm = false
    }
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
                    enabled = !state.isWorking,
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

        state.errorMessage?.let { IconLabel(it, Icons.Outlined.WarningAmber, color = colors.error, fontSize = 13.sp) }
        callbackError?.let { IconLabel(it, Icons.Outlined.WarningAmber, color = colors.error, fontSize = 13.sp) }
        state.infoMessage?.let { IconLabel(it, Icons.Filled.CheckCircle, color = colors.success, fontSize = 13.sp) }

        if (!showingEmailForm) {
            Button(
                onClick = { showingEmailForm = true },
                enabled = !state.isWorking,
                modifier = Modifier.fillMaxWidth().height(48.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = colors.accentFill,
                    contentColor = colors.textOnAccent,
                ),
                shape = RoundedCornerShape(14.dp),
            ) {
                IconLabel(
                    stringResource(if (state.mode == AuthMode.SignIn) R.string.auth_email_sign_in else R.string.auth_email_sign_up),
                    Icons.Outlined.Email,
                    color = colors.textOnAccent,
                )
            }
            OutlinedButton(
                onClick = onGoogleSignIn,
                enabled = !state.isWorking,
                modifier = Modifier.fillMaxWidth().height(48.dp),
                shape = RoundedCornerShape(12.dp),
                border = BorderStroke(1.dp, Color(0xFF747775)),
                colors = ButtonDefaults.outlinedButtonColors(
                    containerColor = Color.White,
                    contentColor = Color(0xFF1F1F1F),
                    disabledContainerColor = Color.White.copy(alpha = 0.55f),
                ),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Image(painterResource(R.drawable.google_sign_in_logo),
                        contentDescription = null, modifier = Modifier.size(18.dp))
                    Text(stringResource(R.string.auth_google_sign_in), fontWeight = FontWeight.Medium)
                }
            }
            // Use the app's actual surface, including its explicit theme setting.
            val appleFill = if (colors.surface.luminance() < 0.5f) Color.White else Color.Black
            val appleInk = if (appleFill == Color.White) Color.Black else Color.White
            androidx.compose.foundation.layout.BoxWithConstraints(Modifier.fillMaxWidth()) {
                OutlinedButton(
                    onClick = onAppleSignIn, enabled = !state.isWorking,
                    modifier = Modifier.fillMaxWidth().height(48.dp),
                    shape = RoundedCornerShape(12.dp),
                    border = null,
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = maxWidth * 0.08f, vertical = 0.dp),
                    colors = ButtonDefaults.outlinedButtonColors(
                        containerColor = appleFill, contentColor = appleInk,
                        disabledContainerColor = appleFill,
                        disabledContentColor = appleInk.copy(alpha = 0.55f),
                    ),
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        // Apple's SVG includes its own padding. Scale the entire
                        // 31×44 viewport to button height; never crop or mirror it.
                        Image(
                            painter = painterResource(
                                if (appleFill == Color.White) R.drawable.apple_sign_in_logo_black
                                else R.drawable.apple_sign_in_logo_white,
                            ),
                            contentDescription = null,
                            modifier = Modifier.size(width = (48f * 31f / 44f).dp, height = 48.dp),
                            alpha = if (state.isWorking) 0.55f else 1f,
                        )
                        Text(stringResource(R.string.auth_apple_sign_in),
                            fontWeight = FontWeight.Medium, fontSize = 16.sp, maxLines = 1)
                    }
                }
            }
            Text(stringResource(R.string.auth_existing_account_guidance),
                color = colors.textBody, fontSize = 12.sp)

        } else {
            TextButton(
                onClick = { showingEmailForm = false },
                enabled = !state.isWorking,
            ) {
                IconLabel(stringResource(R.string.auth_back_to_methods),
                    Icons.AutoMirrored.Outlined.ArrowBack, color = colors.gold)
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
                    IconLabel(stringResource(R.string.passwords_dont_match_error), Icons.Outlined.WarningAmber, color = colors.error, fontSize = 13.sp)
                }
            }

            Button(
                onClick = onSubmit,
                enabled = canSubmit,
                modifier = Modifier.fillMaxWidth().height(48.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = colors.accentFill,
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
        state.errorMessage?.let { IconLabel(it, Icons.Outlined.WarningAmber, color = colors.error, fontSize = 13.sp) }
        state.infoMessage?.let { IconLabel(it, Icons.Filled.CheckCircle, color = colors.success, fontSize = 13.sp) }
        Button(
            onClick = onResend,
            enabled = !state.isWorking && !state.isResendBlocked,
            modifier = Modifier.fillMaxWidth().height(48.dp),
            colors = ButtonDefaults.buttonColors(containerColor = colors.accentFill, contentColor = colors.textOnAccent),
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
    var passwordVisible by remember { mutableStateOf(false) }
    TextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = { Text(placeholder, color = colors.textFaint) },
        leadingIcon = leading,
        trailingIcon = if (isPassword) {
            {
                IconButton(onClick = { passwordVisible = !passwordVisible }) {
                    Icon(
                        imageVector = if (passwordVisible) Icons.Outlined.VisibilityOff else Icons.Outlined.Visibility,
                        contentDescription = stringResource(
                            if (passwordVisible) R.string.hide_password_action else R.string.show_password_action,
                        ),
                        tint = colors.gold,
                    )
                }
            }
        } else {
            null
        },
        singleLine = true,
        visualTransformation = when {
            isPassword && !passwordVisible -> PasswordVisualTransformation()
            else -> VisualTransformation.None
        },
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        modifier = Modifier.editorFocus()
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
            IconLabel(
                text = title, icon = if (met) Icons.Filled.CheckCircle else Icons.Outlined.Cancel,
                color = if (met) colors.success else colors.error,
                fontSize = 13.sp,
            )
        }
    }
}
