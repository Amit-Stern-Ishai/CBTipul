package com.cbtipul.app.ui.auth

import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.foundation.BorderStroke
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.unit.constrainHeight
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.activity.compose.BackHandler
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.material3.OutlinedButton
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.KeyboardArrowRight
import androidx.compose.material.icons.outlined.RadioButtonUnchecked
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Link
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.HorizontalDivider
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
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.focus.FocusDirection
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.foundation.layout.widthIn
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
    // UI intent only. Never creates or changes the authenticated account role.
    var entryStage by rememberSaveable { mutableStateOf("choose") }
    val backToRoles = {
        entryStage = "choose"
        onPasswordChange("")
        onConfirmPasswordChange("")
    }
    BackHandler(enabled = entryStage != "choose") {
        if (!state.isWorking) backToRoles()
    }
    val colors = Theme.colors
    Box(Modifier.themedScreen(colors.gold), contentAlignment = Alignment.TopCenter) {
    if (entryStage == "choose") {
        Layout(
            modifier = Modifier.widthIn(max = 520.dp).fillMaxSize().editorScroll()
                .padding(horizontal = 20.dp, vertical = 16.dp),
            content = {
            Column(
                Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Image(painterResource(R.drawable.splash_icon), contentDescription = null,
                    modifier = Modifier.size(88.dp).clip(RoundedCornerShape(26.dp)))
                Text(stringResource(R.string.app_title), color = colors.textBright,
                    style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
            }
            Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Text(stringResource(R.string.auth_role_title), style = MaterialTheme.typography.headlineSmall,
                    color = colors.textBright, fontWeight = FontWeight.Bold)
                Text(stringResource(R.string.auth_role_explanation), color = colors.textBody)
                RoleChoice(R.string.auth_role_therapist, R.string.auth_role_therapist_detail, patient = false) { entryStage = "therapist" }
                RoleChoice(R.string.auth_role_patient, R.string.auth_role_patient_detail, patient = true) { entryStage = "patient" }
            }
            },
        ) { measurables, constraints ->
            val childConstraints = constraints.copy(minHeight = 0)
            val header = measurables[0].measure(childConstraints)
            val choices = measurables[1].measure(childConstraints)
            val gap = 32.dp.roundToPx()
            val height = constraints.constrainHeight(header.height + gap + choices.height)
            // Center the decision block in the entire safe viewport. The brand sits
            // just above it; compact screens scroll without overlap or clipped text.
            val choicesY = maxOf(header.height + gap, (height - choices.height) / 2)
            layout(constraints.maxWidth, height) {
                header.placeRelative(0, choicesY - gap - header.height)
                choices.placeRelative(0, choicesY)
            }
        }
    } else {
    Column(
        modifier = Modifier
            .widthIn(max = 520.dp)
            .fillMaxSize()
            .dismissKeyboardOnTap()
            .editorScroll()
            .padding(horizontal = 20.dp, vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        AuthBrandHeader()
        if (entryStage != "choose") {
            TextButton(onClick = backToRoles, enabled = !state.isWorking,
                modifier = Modifier.align(Alignment.Start)) {
                Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = null,
                    modifier = Modifier.padding(end = 8.dp))
                Text(stringResource(R.string.auth_change_role))
            }
        }
        if (entryStage == "therapist" && state.verificationEmail == null) {
            Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(stringResource(R.string.auth_therapist_only), color = colors.textBright,
                    style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                Text(stringResource(if (state.mode == AuthMode.SignIn) R.string.auth_welcome_sign_in
                    else R.string.auth_welcome_sign_up), color = colors.textBody,
                    style = MaterialTheme.typography.bodyMedium)
            }
        }
        if (entryStage == "patient") {
            Column(Modifier.fillMaxWidth().background(colors.surface, RoundedCornerShape(16.dp)).padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp)) {
                Icon(Icons.Outlined.Link, contentDescription = null, tint = colors.gold, modifier = Modifier.size(32.dp))
                Text(stringResource(R.string.auth_patient_link_title), style = MaterialTheme.typography.headlineSmall,
                    color = colors.textBright, fontWeight = FontWeight.Bold)
                Text(stringResource(R.string.auth_patient_link_body), color = colors.textBright)
                HorizontalDivider()
                Text(stringResource(R.string.auth_patient_no_link), color = colors.textBody)
            }
        } else if (state.verificationEmail != null) {
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
    }
        BusyOverlay(state.isWorking)
    }
}

@Composable
private fun AuthBrandHeader() {
    val colors = Theme.colors
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Image(painterResource(R.drawable.splash_icon), contentDescription = null,
                modifier = Modifier.size(52.dp).clip(RoundedCornerShape(14.dp)))
            Text(stringResource(R.string.app_title), color = colors.textBright,
                style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold,
                modifier = Modifier.weight(1f))
        }
 }

@Composable
private fun RoleChoice(title: Int, detail: Int, patient: Boolean, onClick: () -> Unit) {
    val colors = Theme.colors
    OutlinedButton(onClick = onClick, modifier = Modifier.fillMaxWidth().heightIn(min = 80.dp),
        shape = RoundedCornerShape(16.dp), border = BorderStroke(1.dp, colors.gold.copy(alpha = .45f)),
        colors = ButtonDefaults.outlinedButtonColors(containerColor = colors.surface, contentColor = colors.textBright),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(18.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(if (patient) Icons.Outlined.Link else Icons.Outlined.Person, contentDescription = null,
                tint = colors.gold, modifier = Modifier.size(28.dp))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(stringResource(title), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                Text(stringResource(detail), style = MaterialTheme.typography.bodyMedium, color = colors.textBody)
            }
            Icon(Icons.AutoMirrored.Outlined.KeyboardArrowRight, contentDescription = null,
                tint = colors.textBody, modifier = Modifier.size(20.dp))
        }
    }
}

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
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
            .clip(RoundedCornerShape(16.dp))
            .background(colors.surface)
            .border(1.dp, colors.borderDefault, RoundedCornerShape(16.dp))
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(if (showingEmailForm) 12.dp else 16.dp),
    ) {
        SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
            AuthMode.entries.forEachIndexed { index, mode ->
                SegmentedButton(
                    selected = state.mode == mode,
                    enabled = !state.isWorking,
                    onClick = { onModeChange(mode) },
                    shape = SegmentedButtonDefaults.itemShape(index, AuthMode.entries.size, RoundedCornerShape(12.dp)),
                    icon = {},
                    colors = SegmentedButtonDefaults.colors(
                        activeContainerColor = colors.accentFill,
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
                modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp),
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
                modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp),
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
                    modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp),
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
            Text(stringResource(if (state.mode == AuthMode.SignIn) R.string.auth_email_sign_in
                else R.string.auth_email_sign_up), color = colors.textBright,
                style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            AuthField(
                value = state.email,
                onValueChange = onEmailChange,
                placeholder = stringResource(R.string.email_placeholder),
                leading = { Icon(Icons.Outlined.Email, contentDescription = null, tint = colors.textBody) },
                keyboardType = KeyboardType.Email,
                enabled = !state.isWorking,
            )
            AuthField(
                value = state.password,
                onValueChange = onPasswordChange,
                placeholder = stringResource(R.string.password_placeholder),
                leading = { Icon(Icons.Outlined.Lock, contentDescription = null, tint = colors.textBody) },
                isPassword = true,
                enabled = !state.isWorking,
                imeAction = if (state.mode == AuthMode.SignIn) ImeAction.Done else ImeAction.Next,
                onDone = { if (canSubmit) onSubmit() },
            )
            if (state.mode == AuthMode.SignUp) {
                AuthField(
                    value = state.confirmPassword,
                    onValueChange = onConfirmPasswordChange,
                    placeholder = stringResource(R.string.confirm_password_placeholder),
                    leading = { Icon(Icons.Outlined.Lock, contentDescription = null, tint = colors.textBody) },
                    isPassword = true,
                    enabled = !state.isWorking,
                    imeAction = ImeAction.Done,
                    onDone = { if (canSubmit) onSubmit() },
                )
                PasswordRulesChecklist(password = state.password, neutralUnmet = true)
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
                modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = colors.accentFill,
                    contentColor = colors.textOnAccent,
                    disabledContainerColor = colors.elevated,
                    disabledContentColor = colors.textBody,
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

            FlowRow(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                if (state.mode == AuthMode.SignIn) {
                    TextButton(onClick = onForgotPassword, enabled = !state.isWorking) {
                        Text(stringResource(R.string.forgot_password_action), color = colors.gold)
                    }
                }
                TextButton(onClick = { showingEmailForm = false }, enabled = !state.isWorking) {
                    Text(stringResource(R.string.auth_other_methods), color = colors.gold)
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
            .clip(RoundedCornerShape(16.dp))
            .background(colors.surface)
            .border(1.dp, colors.borderDefault, RoundedCornerShape(16.dp))
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
            modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp),
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
    enabled: Boolean = true,
    imeAction: ImeAction = ImeAction.Next,
    onDone: () -> Unit = {},
) {
    val colors = Theme.colors
    var passwordVisible by remember { mutableStateOf(false) }
    val focusManager = LocalFocusManager.current
    OutlinedTextField(
        value = value,
        enabled = enabled,
        label = { Text(placeholder) },
        textStyle = MaterialTheme.typography.bodyLarge.copy(textDirection = TextDirection.Ltr),
        onValueChange = onValueChange,
        leadingIcon = leading,
        trailingIcon = if (isPassword) {
            {
                IconButton(onClick = { passwordVisible = !passwordVisible }, enabled = enabled) {
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
        keyboardOptions = KeyboardOptions(
            keyboardType = if (isPassword) KeyboardType.Password else keyboardType,
            autoCorrectEnabled = false, imeAction = imeAction),
        keyboardActions = KeyboardActions(
            onNext = { focusManager.moveFocus(FocusDirection.Next) },
            onDone = { onDone() }),
        modifier = Modifier.editorFocus().fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        colors = OutlinedTextFieldDefaults.colors(
            focusedContainerColor = colors.elevated,
            unfocusedContainerColor = colors.elevated,
            focusedTextColor = colors.textBright,
            unfocusedTextColor = colors.textBright,
            cursorColor = colors.gold,
            focusedBorderColor = colors.gold,
            unfocusedBorderColor = colors.borderStrong,
            focusedLabelColor = colors.gold,
            unfocusedLabelColor = colors.textBody,
        ),
    )
}

@Composable
fun PasswordRulesChecklist(password: String, neutralUnmet: Boolean = false) {
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
                text = title, icon = if (met) Icons.Filled.CheckCircle else if (neutralUnmet) Icons.Outlined.RadioButtonUnchecked else Icons.Outlined.Cancel,
                color = if (met) colors.success else if (neutralUnmet) colors.textBody else colors.error,
                fontSize = 13.sp,
            )
        }
    }
}
