package com.cbtipul.app.ui.auth

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.auth.AuthUiState
import com.cbtipul.app.auth.PasswordRule
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.patientAtmosphere

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NewPasswordSheet(
    state: AuthUiState,
    onPasswordChange: (String) -> Unit,
    onConfirmChange: (String) -> Unit,
    onSave: () -> Unit,
    onCancel: () -> Unit,
) {
    val colors = Theme.colors
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    BackHandler { onCancel() }
    ModalBottomSheet(
        onDismissRequest = onCancel,
        sheetState = sheetState,
        containerColor = colors.surface,
    ) {
        Column(modifier = Modifier.padding(24.dp).fillMaxWidth().patientAtmosphere(colors.gold)) {
            Text(stringResource(R.string.new_password_title), color = colors.textBright, fontSize = 22.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp))
            Text(stringResource(R.string.new_password_message), color = colors.textBody, fontSize = 14.sp)
            Spacer(Modifier.height(16.dp))
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
            Spacer(Modifier.height(20.dp))
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
}

@Composable
private fun PasswordField(value: String, onChange: (String) -> Unit, placeholder: String) {
    val colors = Theme.colors
    TextField(
        value = value,
        onValueChange = onChange,
        placeholder = { Text(placeholder, color = colors.textFaint) },
        singleLine = true,
        visualTransformation = PasswordVisualTransformation(),
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
