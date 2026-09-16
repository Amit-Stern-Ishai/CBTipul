package com.cbtipul.app.ui.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.Science
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.cbtipul.app.R
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.themedScreen

@Composable
fun DemoShowcaseIntroScreen(
    onExplore: () -> Unit,
) {
    val colors = Theme.colors
    Dialog(
        onDismissRequest = onExplore,
        properties = DialogProperties(
            usePlatformDefaultWidth = false,
            dismissOnBackPress = true,
            dismissOnClickOutside = false,
        ),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .themedScreen(colors.gold)
                .padding(24.dp),
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(20.dp)) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Icon(Icons.Outlined.AutoAwesome, contentDescription = null, tint = colors.textBright)
                    Text(
                        stringResource(R.string.showcase_reveal_title),
                        color = colors.textBright,
                        fontWeight = FontWeight.Bold,
                        fontSize = 22.sp,
                    )
                }
                Text(
                    stringResource(R.string.showcase_reveal_body),
                    color = colors.textBody,
                    fontSize = 16.sp,
                )
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(colors.warning.copy(alpha = 0.12f))
                        .padding(14.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Outlined.Science, contentDescription = null, tint = colors.warning)
                    Text(
                        stringResource(R.string.showcase_reveal_exit_hint),
                        color = colors.textBody,
                        fontSize = 14.sp,
                    )
                }
            }
            Column {
                Spacer(Modifier.height(16.dp))
                Button(
                    onClick = onExplore,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = colors.gold,
                        contentColor = colors.textOnAccent,
                    ),
                ) {
                    Text(
                        stringResource(R.string.showcase_reveal_action),
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
        }
    }
}
