package com.cbtipul.app.ui.patient

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.ui.theme.Theme

@Composable
internal fun PatientToolStatus(active: Boolean) {
    val color = if (active) Theme.colors.success else Theme.colors.textBody
    Row(Modifier.background(color.copy(alpha = .12f), RoundedCornerShape(8.dp)).padding(horizontal = 8.dp, vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Icon(if (active) Icons.Outlined.CheckCircle else Icons.Outlined.Lock, contentDescription = null,
            tint = color, modifier = Modifier.size(16.dp))
        Text(stringResource(if (active) R.string.patient_tool_enabled else R.string.patient_history_only),
            color = color, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
    }
}
