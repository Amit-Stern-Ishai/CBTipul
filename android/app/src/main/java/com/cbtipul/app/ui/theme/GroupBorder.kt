package com.cbtipul.app.ui.theme

import androidx.compose.foundation.background
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp

enum class GroupRowPosition {
    Only, First, Middle, Last;

    companion object {
        fun at(index: Int, of: Int): GroupRowPosition = when {
            of <= 1 -> Only
            index == 0 -> First
            index == of - 1 -> Last
            else -> Middle
        }
    }
}

@Composable
fun Modifier.groupBordered(position: GroupRowPosition, accent: Color): Modifier {
    val surface = Theme.colors.surface
    val outline = accent.copy(alpha = 0.35f)
    return this
        .background(surface)
        .drawWithCache {
            val stroke = 1.dp.toPx()
            val radius = 26.dp.toPx()
            val path = groupBorderPath(position, size, radius, stroke)
            onDrawWithContent {
                drawContent()
                drawPath(path, color = outline, style = Stroke(width = stroke, cap = StrokeCap.Butt))
            }
        }
}

private fun groupBorderPath(
    position: GroupRowPosition,
    size: Size,
    radius: Float,
    stroke: Float,
): Path {
    val inset = stroke / 2f
    val minX = inset
    val maxX = size.width - inset
    val minY = if (position == GroupRowPosition.First || position == GroupRowPosition.Only) inset else 0f
    val maxY = if (position == GroupRowPosition.Last || position == GroupRowPosition.Only) {
        size.height - inset
    } else {
        size.height
    }
    val path = Path()
    when (position) {
        GroupRowPosition.Only -> {
            path.addRoundRect(
                RoundRect(
                    rect = Rect(minX, minY, maxX, maxY),
                    cornerRadius = CornerRadius(radius, radius),
                ),
            )
        }
        GroupRowPosition.First -> {
            path.moveTo(minX, maxY)
            path.lineTo(minX, minY + radius)
            path.quadraticTo(minX, minY, minX + radius, minY)
            path.lineTo(maxX - radius, minY)
            path.quadraticTo(maxX, minY, maxX, minY + radius)
            path.lineTo(maxX, maxY)
        }
        GroupRowPosition.Middle -> {
            path.moveTo(minX, minY)
            path.lineTo(minX, maxY)
            path.moveTo(maxX, minY)
            path.lineTo(maxX, maxY)
        }
        GroupRowPosition.Last -> {
            path.moveTo(minX, minY)
            path.lineTo(minX, maxY - radius)
            path.quadraticTo(minX, maxY, minX + radius, maxY)
            path.lineTo(maxX - radius, maxY)
            path.quadraticTo(maxX, maxY, maxX, maxY - radius)
            path.lineTo(maxX, minY)
        }
    }
    return path
}