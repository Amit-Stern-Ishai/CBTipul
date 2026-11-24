package com.cbtipul.app.ui.theme

import androidx.compose.ui.graphics.Color

object LightPalette {
    val base = Color(0xFFF7F8FA)
    val surface = Color(0xFFFFFFFF)
    val elevated = Color(0xFFF2F4F6)
    val hover = Color(0xFFE8EEF5)
    val surfaceWarm = Color(0xFFF2F4F6)
    val borderFaint = Color(0xFFDFE3E8)
    val borderDefault = Color(0xFFB8C2CE)
    val borderStrong = Color(0xFF728399)
    val textBright = Color(0xFF00244E)
    val textBody = Color(0xFF4B5E75)
    val textFaint = Color(0xFF4B5E75)
    val gold = Color(0xFF285A8C)
    val goldVivid = Color(0xFF235580)
    val goldDim = Color(0xFF0D3B66)
    val goldGhost = Color(0x1A285A8C)
    val accentFill = Color(0xFF285A8C)
    val accentFillPressed = Color(0xFF0D3B66)
    val textOnAccent = Color(0xFFFFFFFF)
    val success = Color(0xFF28734E)
    val warning = Color(0xFF886019)
    val warningSoft = Color(0x1F886019)
    val error = Color(0xFFB33D49)
    val positiveSoft = Color(0x1F28734E)
    val negativeSoft = Color(0x1FB33D49)
    val neutral = Color(0xFF4B5E75)
    val neutralMedium = Color(0xFF4B5E75)
    val neutralSoft = Color(0xFFF2F4F6)
    val critical = Color(0xFFB33D49)
    val criticalSoft = Color(0x2EB33D49)
}

data class CbTipulColors(
    val base: Color,
    val surface: Color,
    val elevated: Color,
    val hover: Color,
    val surfaceWarm: Color,
    val borderFaint: Color,
    val borderDefault: Color,
    val borderStrong: Color,
    val textBright: Color,
    val textBody: Color,
    val textFaint: Color,
    val gold: Color,
    val goldVivid: Color,
    val goldDim: Color,
    val goldGhost: Color,
    val accentFill: Color,
    val accentFillPressed: Color,
    val textOnAccent: Color,
    val success: Color,
    val warning: Color,
    val warningSoft: Color,
    val error: Color,
    val positive: Color,
    val positiveSoft: Color,
    val negative: Color,
    val negativeSoft: Color,
    val neutral: Color,
    val neutralMedium: Color,
    val neutralSoft: Color,
    val critical: Color,
    val criticalSoft: Color,
) {
    val isPaper get() = base == LightPalette.base
    val headerInk get() = if (isPaper) textBright else Color.White
    val brandPrimary get() = accentFill
    val brandAccent get() = gold
    val prestige get() = gold
}

fun cbTipulColors(dark: Boolean): CbTipulColors {
    val p = LightPalette
    return CbTipulColors(
        base = p.base,
        surface = p.surface,
        elevated = p.elevated,
        hover = p.hover,
        surfaceWarm = p.surfaceWarm,
        borderFaint = p.borderFaint,
        borderDefault = p.borderDefault,
        borderStrong = p.borderStrong,
        textBright = p.textBright,
        textBody = p.textBody,
        textFaint = p.textFaint,
        gold = p.gold,
        goldVivid = p.goldVivid,
        goldDim = p.goldDim,
        goldGhost = p.goldGhost,
        accentFill = p.accentFill,
        accentFillPressed = p.accentFillPressed,
        textOnAccent = p.textOnAccent,
        success = p.success,
        warning = p.warning,
        warningSoft = p.warningSoft,
        error = p.error,
        positive = p.success,
        positiveSoft = p.positiveSoft,
        negative = p.error,
        negativeSoft = p.negativeSoft,
        neutral = p.neutral,
        neutralMedium = p.neutralMedium,
        neutralSoft = p.neutralSoft,
        critical = p.critical,
        criticalSoft = p.criticalSoft,
    )
}

/** One blue history scale in every system appearance. */
object QuestionnaireHistoryColors {
    fun background(paper: Boolean) = background
    fun foreground(paper: Boolean) = foreground
    fun bands(paper: Boolean) = bands
    val background = Color(0xFFF2F4F6)
    val foreground = Color(0xFF00244E)
    val bands = listOf(Color(0xFFE8EEF5), Color(0xFFCDDFEF), Color(0xFFA5C3DE))
}
