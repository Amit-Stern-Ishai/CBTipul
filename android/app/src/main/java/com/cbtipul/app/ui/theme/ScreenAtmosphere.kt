package com.cbtipul.app.ui.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

@Composable
fun Modifier.patientAtmosphere(accent: Color?): Modifier {
    return background(Theme.colors.base)
}

@Composable
fun Modifier.themedScreen(accent: Color?): Modifier {
    val colors = Theme.colors
    return fillMaxSize().background(colors.base).patientAtmosphere(accent ?: colors.gold)
}
