package com.cbtipul.app.ui.theme

import androidx.compose.ui.graphics.Color

object DarkPalette {
    val base = Color(0xFF0C1420)
    val surface = Color(0xFF172231)
    val elevated = Color(0xFF202E40)
    val hover = Color(0xFF29394D)
    val surfaceWarm = Color(0xFF29394D)
    val borderFaint = Color(0xFF2C394B)
    val borderDefault = Color(0xFF3B4B60)
    val borderStrong = Color(0xFF60738C)
    val textBright = Color(0xFFF3F5F8)
    val textBody = Color(0xFFB4C0D0)
    val textFaint = Color(0xFF8999AE)
    val gold = Color(0xFFE2BB76)
    val goldVivid = Color(0xFFF1D29A)
    val goldDim = Color(0xFFC49C58)
    val goldGhost = Color(0x1FE2BB76)
    val textOnAccent = Color(0xFF0C1420)
    val success = Color(0xFF42D98B)
    val warning = Color(0xFFFFC94A)
    val warningSoft = Color(0x24FFC94A)
    val error = Color(0xFFFF5C68)
    val positiveSoft = Color(0x2442D98B)
    val negativeSoft = Color(0x24FF5C68)
    val neutral = Color(0xFFA7A7BE)
    val neutralMedium = Color(0xFF77778F)
    val neutralSoft = Color(0x1AA7A7BE)
    val critical = Color(0xFFFF4055)
    val criticalSoft = Color(0x33FF4055)
}

object LightPalette {
    val base = Color(0xFFFAF7F1)
    val surface = Color(0xFFFFFFFF)
    val elevated = Color(0xFFEDE7F2)
    val hover = Color(0xFFE3D8EC)
    val surfaceWarm = Color(0xFFEDE7F2)
    val borderFaint = Color(0xFFE4DCD2)
    val borderDefault = Color(0xFFD6C9DE)
    val borderStrong = Color(0xFF96849F)
    val textBright = Color(0xFF352144)
    val textBody = Color(0xFF665A6F)
    val textFaint = Color(0xFF6C6073)
    val gold = Color(0xFF5C4476)
    val goldVivid = Color(0xFF6D508A)
    val goldDim = Color(0xFF49325F)
    val goldGhost = Color(0x1A5C4476)
    val accentFill = Color(0xFF5C4476)
    val accentFillPressed = Color(0xFF49325F)
    val textOnAccent = Color(0xFFFFFFFF)
    val success = Color(0xFF18724D)
    val warning = Color(0xFF946000)
    val warningSoft = Color(0x1F946000)
    val error = Color(0xFFBC3346)
    val positiveSoft = Color(0x1F18724D)
    val negativeSoft = Color(0x1FBC3346)
    val neutral = Color(0xFF66768B)
    val neutralMedium = Color(0xFF718095)
    val neutralSoft = Color(0xFFEDE7F2)
    val critical = Color(0xFFBC3346)
    val criticalSoft = Color(0x2EBC3346)
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
    if (dark) {
        val p = DarkPalette
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
            accentFill = p.gold,
            accentFillPressed = p.goldDim,
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

/** History stays ocean in dark mode and uses the approved paper palette in light mode. */
object QuestionnaireHistoryColors {
    fun background(paper: Boolean) = if (paper) Color(0xFFF3EEF6) else background
    fun foreground(paper: Boolean) = if (paper) Color(0xFF352144) else foreground
    fun bands(paper: Boolean) = if (paper) listOf(Color(0xFFE5DBED), Color(0xFFCFBCDE), Color(0xFFB99DCC)) else bands
    val background = Color(0xFF213143)
    val foreground = Color(0xFFF3F7FA)
    val bands = listOf(Color(0xFF263F56), Color(0xFF355C78), Color(0xFF46728F))
}
