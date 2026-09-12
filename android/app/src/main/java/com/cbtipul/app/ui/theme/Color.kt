package com.cbtipul.app.ui.theme

import androidx.compose.ui.graphics.Color

object DarkPalette {
    val base = Color(0xFF07080F)
    val surface = Color(0xFF0D1230)
    val elevated = Color(0xFF131A3C)
    val hover = Color(0xFF1A2248)
    val surfaceWarm = Color(0xFF1A2248)
    val borderFaint = Color(0x1ACFA038)
    val borderDefault = Color(0x38CFA038)
    val borderStrong = Color(0x73CFA038)
    val textBright = Color(0xFFF2EDE0)
    val textBody = Color(0xFF8C8CA8)
    val textFaint = Color(0xFF3A3A54)
    val gold = Color(0xFFCFA038)
    val goldVivid = Color(0xFFF2C050)
    val goldDim = Color(0xFF7A5C1A)
    val goldGhost = Color(0x1FCFA038)
    val textOnAccent = Color(0xFF07080F)
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
    val base = Color(0xFFF2F2F7)
    val surface = Color(0xFFFFFFFF)
    val elevated = Color(0x1E767680)
    val hover = Color(0x33787880)
    val surfaceWarm = Color(0xFFF2F2F7)
    val borderFaint = Color(0x4A3C3C43)
    val borderDefault = Color(0x4A3C3C43)
    val borderStrong = Color(0xFFC6C6C8)
    val textBright = Color(0xFF000000)
    val textBody = Color(0x993C3C43)
    val textFaint = Color(0x4D3C3C43)
    val gold = Color(0xFF007AFF)
    val goldVivid = Color(0xFF007AFF)
    val goldDim = Color(0xFF007AFF)
    val goldGhost = Color(0x1F007AFF)
    val textOnAccent = Color.White
    val success = Color(0xFF34C759)
    val warning = Color(0xFFFF9500)
    val warningSoft = Color(0x1FFF9500)
    val error = Color(0xFFFF3B30)
    val positiveSoft = Color(0x1F34C759)
    val negativeSoft = Color(0x1FFF3B30)
    val neutral = Color(0xFF8E8E93)
    val neutralMedium = Color(0xFFAEAEB2)
    val neutralSoft = Color(0x1E767680)
    val critical = Color(0xFFFF3B30)
    val criticalSoft = Color(0x2EFF3B30)
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
