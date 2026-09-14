package com.cbtipul.app.ui.auth

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.auth.AuthUiState
import com.cbtipul.app.auth.PasswordRule
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.dismissKeyboardOnTap
import com.cbtipul.app.ui.theme.patientAtmosphere
import com.cbtipul.app.ui.theme.themedScreen

@Composable
fun NewPasswordSheet(
    state: AuthUiState,
    onPasswordChange: (String) -> Unit,
    onConfirmChange: (String) -> Unit,
    onSave: () -> Unit,
    onCancel: () -> Unit,
) {
    val colors = Theme.colors
    BackHandler { onCancel() }
    Column(
        modifier = Modifier
            .fillMaxSize()
            .themedScreen(colors.gold)
            .dismissKeyboardOnTap()
            .verticalScroll(rememberScrollState())
            .padding(24.dp)
            .patientAtmosphere(colors.gold),
    ) {
        Text(
            stringResource(R.string.new_password_title),
            color = colors.textBright,
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            stringResource(R.string.new_password_message),
            color = colors.textBody,
            fontSize = 14.sp,
        )
        Spacer(Modifier.height(24.dp))
        PasswordField(state.newPassword, onPasswordChange, stringResource(R.string.password_placeholder))
        Spacer(Modifier.height(12.dp))
        PasswordField(state.newPasswordConfirm, onConfirmChange, stringResource(R.string.confirm_password_placeholder))
        Spacer(Modifier.height(12.dp))
        PasswordRulesChecklist(state.newPassword)
        if (state.newPasswordConfirm.isNotEmpty() &&
            state.newPasswordConfirm.length >= state.newPassword.length &&
            state.newPassword != state.newPasswordConfirm
        ) {
            Spacer(Modifier.height(8.dp))
            Text(stringResource(R.string.passwords_dont_match_error), color = colors.error, fontSize = 13.sp)
        }
        state.newPasswordError?.let {
            Spacer(Modifier.height(8.dp))
            Text(it, color = colors.error, fontSize = 13.sp)
        }
        Spacer(Modifier.height(24.dp))
        val canSave = PasswordRule.allSatisfied(state.newPassword) &&
            state.newPassword == state.newPasswordConfirm &&
            !state.isWorking
        Button(
            onClick = onSave,
            enabled = canSave,
            modifier = Modifier.fillMaxWidth().height(48.dp),
            colors = ButtonDefaults.buttonColors(containerColor = colors.gold, contentColor = colors.textOnAccent),
        ) {
            Text(stringResource(R.string.save), fontWeight = FontWeight.SemiBold)
        }
        TextButton(onClick = onCancel, enabled = !state.isWorking, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.cancel), color = colors.gold)
        }
    }
}

@Composable
private fun PasswordField(value: String, onChange: (String) -> Unit, placeholder: String) {
    val colors = Theme.colors
    var passwordVisible by remember { mutableStateOf(false) }
    TextField(
        value = value,
        onValueChange = onChange,
        placeholder = { Text(placeholder, color = colors.textFaint) },
        trailingIcon = {
            IconButton(onClick = { passwordVisible = !passwordVisible }) {
                Icon(
                    imageVector = if (passwordVisible) Icons.Outlined.VisibilityOff else Icons.Outlined.Visibility,
                    contentDescription = stringResource(
                        if (passwordVisible) R.string.hide_password_action else R.string.show_password_action,
                    ),
                    tint = colors.gold,
                )
            }
        },
        singleLine = true,
        visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
        modifier = Modifier.fillMaxWidth(),
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
