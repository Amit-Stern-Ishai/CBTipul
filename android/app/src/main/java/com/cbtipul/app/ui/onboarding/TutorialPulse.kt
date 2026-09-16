package com.cbtipul.app.ui.onboarding

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import com.cbtipul.app.ui.theme.Theme

enum class TutorialPulseStyle {
    Card,
    Toolbar,
}

fun Modifier.tutorialPulse(
    isActive: Boolean,
    style: TutorialPulseStyle = TutorialPulseStyle.Card,
): Modifier = composed {
    if (!isActive) return@composed this
    val colors = Theme.colors
    val transition = rememberInfiniteTransition(label = "tutorialPulse")
    val flash by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(650),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "flash",
    )
    val tint by animateColorAsState(
        targetValue = if (flash > 0.5f) colors.warning else Color.Unspecified,
        label = "pulseTint",
    )
    this.drawWithContent {
        drawContent()
        if (style == TutorialPulseStyle.Card || style == TutorialPulseStyle.Toolbar) {
            val alpha = 0.25f + flash * 0.45f
            drawRect(
                color = colors.warning.copy(alpha = alpha),
                style = Stroke(width = 3f),
            )
        }
        // Keep tint available for callers that read LocalContentColor via draw; border is enough.
        @Suppress("UNUSED_VARIABLE")
        val unused = tint
    }
}

@Composable
fun tutorialPulseColor(isActive: Boolean): Color {
    if (!isActive) return Color.Unspecified
    val colors = Theme.colors
    val transition = rememberInfiniteTransition(label = "tutorialPulseColor")
    val flash by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(650),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "colorFlash",
    )
    return if (flash > 0.5f) colors.warning else colors.gold
}
