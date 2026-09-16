package com.cbtipul.app.ui.onboarding

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.themedScreen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WelcomeOnboardingScreen(
    onStartDemoTour: () -> Unit,
    onSkip: () -> Unit,
    allowsSkip: Boolean = true,
) {
    val colors = Theme.colors
    var showInfo by remember { mutableStateOf(false) }
    Column(
        modifier = Modifier
            .fillMaxSize()
            .themedScreen(colors.gold)
            .padding(horizontal = 24.dp, vertical = 28.dp),
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Spacer(Modifier.height(24.dp))
            Text(
                stringResource(R.string.welcome_title),
                color = colors.textBright,
                fontWeight = FontWeight.Bold,
                fontSize = 28.sp,
            )
            Text(
                stringResource(R.string.welcome_body),
                color = colors.textBody,
                fontSize = 16.sp,
            )
        }
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Button(
                onClick = onStartDemoTour,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(
                    containerColor = colors.gold,
                    contentColor = colors.textOnAccent,
                ),
            ) {
                Text(
                    stringResource(R.string.welcome_primary_action),
                    fontWeight = FontWeight.SemiBold,
                )
            }
            if (allowsSkip) {
                TextButton(
                    onClick = onSkip,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(
                        stringResource(R.string.welcome_secondary_action),
                        color = colors.textBody,
                        fontWeight = FontWeight.Medium,
                    )
                }
            }
            TextButton(onClick = { showInfo = true }, modifier = Modifier.fillMaxWidth()) {
                Text(
                    stringResource(R.string.welcome_info_link),
                    color = colors.gold,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
    }

    if (showInfo) {
        val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        val context = LocalContext.current
        ModalBottomSheet(
            onDismissRequest = { showInfo = false },
            sheetState = sheetState,
            containerColor = colors.surface,
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Text(
                    stringResource(R.string.welcome_info_link),
                    color = colors.textBright,
                    fontWeight = FontWeight.Bold,
                    fontSize = 18.sp,
                )
                Text(
                    stringResource(R.string.welcome_info_body),
                    color = colors.textBright,
                )
                TextButton(
                    onClick = {
                        context.startActivity(
                            Intent(Intent.ACTION_VIEW, Uri.parse("https://cbtipul.com/privacy")),
                        )
                    },
                ) {
                    Text(stringResource(R.string.privacy_policy_title), color = colors.gold)
                }
                TextButton(onClick = { showInfo = false }) {
                    Text(stringResource(R.string.welcome_info_done_action), color = colors.gold)
                }
                Spacer(Modifier.height(12.dp))
            }
        }
    }
}
