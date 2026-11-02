package com.cbtipul.app.ui.patients

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.cbtipul.app.ui.theme.Theme

/** Only curated messages; presentation never determines error classification. */
@Composable
fun AIUsageNotice(message: String, modifier: Modifier = Modifier, title: String = "הפעולה לא הושלמה") {
    val colors = Theme.colors
    val parts = message.split('\n', limit = 2)
    Surface(modifier.fillMaxWidth().semantics(mergeDescendants = true) { liveRegion = LiveRegionMode.Polite },
        shape = RoundedCornerShape(12.dp), color = colors.surface,
        border = BorderStroke(1.dp, colors.borderDefault)) {
        Row(Modifier.padding(14.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Icon(Icons.Outlined.Info, contentDescription = null, tint = colors.gold, modifier = Modifier.size(22.dp))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                Text(if (parts.size > 1) parts[0] else title, style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold, color = colors.textBright)
                Text(if (parts.size > 1) parts[1] else message, style = MaterialTheme.typography.bodyMedium, color = colors.textBody)
            }
        }
    }
}
