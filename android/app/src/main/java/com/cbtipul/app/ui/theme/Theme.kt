package com.cbtipul.app.ui.theme

import android.app.Activity
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.material3.Typography
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material3.LocalContentColor
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

private val LocalCbTipulColors = staticCompositionLocalOf { cbTipulColors(dark = false) }

object Theme {
    val colors: CbTipulColors
        @Composable
        @ReadOnlyComposable
        get() = LocalCbTipulColors.current
}

@Composable
fun CbTipulTheme(
    appearance: AppAppearance = AppAppearance.Light,
    textSize: AppTextSize = AppTextSize.System,
    content: @Composable () -> Unit,
) {
    val dark = false
    val colors = cbTipulColors(dark)
    val scheme = lightColorScheme(
            primary = colors.gold,
            onPrimary = Color.White,
            secondary = colors.goldVivid,
            onSecondary = colors.textOnAccent,
            tertiary = Color(0xFF365D70),
            onTertiary = Color.White,
            tertiaryContainer = Color(0xFFE8F1F5),
            onTertiaryContainer = Color(0xFF365D70),
            surfaceTint = Color.Transparent,
            inverseSurface = colors.textBright,
            inverseOnSurface = Color.White,
            inversePrimary = Color(0xFFE5EFF9),
            surfaceBright = colors.surface,
            surfaceDim = colors.elevated,
            surfaceContainerLow = colors.base,
            surfaceContainerLowest = colors.surface,
            onError = Color.White,
            errorContainer = Color(0xFFF7E7E9),
            onErrorContainer = colors.error,
            scrim = Color(0xFF00244E),
            background = colors.base,
            onBackground = colors.textBright,
            surface = colors.surface,
            onSurface = colors.textBright,
            surfaceVariant = colors.elevated,
            onSurfaceVariant = colors.textBody,
            error = colors.error,
            outline = colors.borderDefault,
            outlineVariant = colors.borderFaint,
            primaryContainer = colors.goldGhost,
            onPrimaryContainer = colors.gold,
            secondaryContainer = colors.elevated,
            onSecondaryContainer = colors.textBright,
            surfaceContainer = colors.surface,
            surfaceContainerHigh = colors.elevated,
            surfaceContainerHighest = colors.hover,
        )
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
        LocalContentColor provides colors.textBright,
        LocalLayoutDirection provides LayoutDirection.Rtl,
        LocalDensity provides Density(
            density = density.density,
            fontScale = textSize.resolvedScale(density.fontScale),
        ),
    ) {
        val defaults = Typography()
        MaterialTheme(
            colorScheme = scheme,
            typography = defaults.copy(
                titleLarge = defaults.titleLarge.copy(fontWeight = FontWeight.SemiBold, lineHeight = 28.sp),
                titleMedium = defaults.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                bodyLarge = defaults.bodyLarge.copy(lineHeight = 23.sp),
                bodyMedium = defaults.bodyMedium.copy(lineHeight = 20.sp),
                labelLarge = defaults.labelLarge.copy(fontWeight = FontWeight.SemiBold),
            ),
            shapes = Shapes(
                extraSmall = RoundedCornerShape(8.dp),
                small = RoundedCornerShape(12.dp),
                medium = RoundedCornerShape(14.dp),
                large = RoundedCornerShape(16.dp),
                extraLarge = RoundedCornerShape(22.dp),
            ),
            content = content,
        )
    }
}
