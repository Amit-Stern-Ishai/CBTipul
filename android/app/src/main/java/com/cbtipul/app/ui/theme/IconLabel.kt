package com.cbtipul.app.ui.theme

import androidx.compose.ui.text.style.TextAlign
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp

/** The visible label names the action; its companion icon is decorative for TalkBack. */
@Composable
fun IconLabel(
    text: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    color: Color = LocalContentColor.current,
    fontWeight: FontWeight? = null,
    fontSize: TextUnit = TextUnit.Unspecified,
    textAlign: TextAlign? = null,
) {
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(8.dp, if (textAlign == TextAlign.Center) Alignment.CenterHorizontally else Alignment.Start), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(20.dp))
        Text(text, modifier = Modifier.weight(1f, fill = false), color = color, fontWeight = fontWeight, fontSize = fontSize, textAlign = textAlign)
    }
}
