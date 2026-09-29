package com.cbtipul.app.ui.theme

import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.core.tween
import androidx.compose.ui.unit.LayoutDirection

/** Short, quiet navigation motion; Compose honors the system animator duration scale. */
object AppMotion {
    fun enter(direction: LayoutDirection, back: Boolean = false) =
        fadeIn(tween(180)) + slideInHorizontally(tween(180)) {
            val sign = if (direction == LayoutDirection.Rtl) -1 else 1
            it / 16 * sign * if (back) -1 else 1
        }

    fun exit(direction: LayoutDirection, back: Boolean = false) =
        fadeOut(tween(120)) + slideOutHorizontally(tween(180)) {
            val sign = if (direction == LayoutDirection.Rtl) -1 else 1
            -it / 16 * sign * if (back) -1 else 1
        }
}
