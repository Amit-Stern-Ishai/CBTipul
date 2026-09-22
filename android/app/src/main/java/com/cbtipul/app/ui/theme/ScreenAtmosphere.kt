package com.cbtipul.app.ui.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

@Composable
fun Modifier.patientAtmosphere(accent: Color?): Modifier {
    val color = accent ?: Theme.colors.gold
    return drawBehind {
        val radius = 420.dp.toPx()
        drawRect(
            brush = Brush.radialGradient(
                colorStops = arrayOf(
                    0f to color.copy(alpha = 0.12f),
                    0.55f to color.copy(alpha = 0.05f),
                    1f to Color.Transparent,
                ),
                center = Offset(size.width * 0.85f, size.height * 0.05f),
                radius = radius,
            ),
        )
    }
}

@Composable
fun Modifier.themedScreen(accent: Color?): Modifier {
    val colors = Theme.colors
    return fillMaxSize().background(colors.base).patientAtmosphere(accent ?: colors.gold)
}
