package com.cbtipul.app.ui.legal

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.ui.theme.Theme

@Composable
fun TermsScreen(onAgree: (() -> Unit)? = null, onBack: (() -> Unit)? = null) {
    val colors = Theme.colors
    val context = LocalContext.current
    val body = remember {
        context.resources.openRawResource(R.raw.terms).bufferedReader().use { it.readText() }
    }
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.base),
    ) {
        Text(
            text = stringResource(R.string.terms_title),
            color = colors.textBright,
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(24.dp),
        )
        Text(
            text = body,
            color = colors.textBody,
            fontSize = 14.sp,
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp),
        )
        if (onAgree != null) {
            Button(
                onClick = onAgree,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(24.dp)
                    .height(52.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = colors.gold,
                    contentColor = colors.textOnAccent,
                ),
                shape = RoundedCornerShape(14.dp),
            ) {
                Text(stringResource(R.string.terms_agree_action), fontWeight = FontWeight.SemiBold)
            }
        } else if (onBack != null) {
            Button(
                onClick = onBack,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(24.dp)
                    .height(52.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = colors.gold,
                    contentColor = colors.textOnAccent,
                ),
                shape = RoundedCornerShape(14.dp),
            ) {
                Text(stringResource(R.string.done), fontWeight = FontWeight.SemiBold)
            }
        }
    }
}
