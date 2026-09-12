package com.cbtipul.app.ui.theme

import android.app.Activity
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.core.view.WindowCompat
import com.cbtipul.app.settings.AppAppearance
import com.cbtipul.app.settings.AppTextSize

private val LocalCbTipulColors = staticCompositionLocalOf { cbTipulColors(dark = true) }

object Theme {
    val colors: CbTipulColors
        @Composable
        @ReadOnlyComposable
        get() = LocalCbTipulColors.current
}

@Composable
fun CbTipulTheme(
    appearance: AppAppearance = AppAppearance.Dark,
    textSize: AppTextSize = AppTextSize.Standard,
    content: @Composable () -> Unit,
) {
    val dark = appearance == AppAppearance.Dark
    val colors = cbTipulColors(dark)
    val scheme = if (dark) {
        darkColorScheme(
            primary = colors.gold,
            onPrimary = colors.textOnAccent,
            secondary = colors.goldVivid,
            background = colors.base,
            onBackground = colors.textBright,
            surface = colors.surface,
            onSurface = colors.textBright,
            surfaceVariant = colors.elevated,
            onSurfaceVariant = colors.textBody,
            error = colors.error,
            outline = colors.borderDefault,
        )
    } else {
        lightColorScheme(
            primary = colors.gold,
            onPrimary = colors.textOnAccent,
            secondary = colors.goldVivid,
            background = colors.base,
            onBackground = colors.textBright,
            surface = colors.surface,
            onSurface = colors.textBright,
            surfaceVariant = colors.elevated,
            onSurfaceVariant = colors.textBody,
            error = colors.error,
            outline = colors.borderDefault,
        )
    }
    val density = LocalDensity.current
    val view = LocalView.current
    SideEffect {
        val window = (view.context as Activity).window
        WindowCompat.getInsetsController(window, view).apply {
            isAppearanceLightStatusBars = !dark
            isAppearanceLightNavigationBars = !dark
        }
    }
    CompositionLocalProvider(
        LocalCbTipulColors provides colors,
        LocalLayoutDirection provides LayoutDirection.Rtl,
        LocalDensity provides Density(
            density = density.density,
            fontScale = density.fontScale * textSize.fontScale,
        ),
    ) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}
