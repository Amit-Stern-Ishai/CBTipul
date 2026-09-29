package com.cbtipul.app.ui.theme

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp

/** Extra scroll space lets the last editor move comfortably above the keyboard. */
@Composable
fun Modifier.editorScroll(state: ScrollState = rememberScrollState()): Modifier {
    val keyboardOpen = WindowInsets.ime.getBottom(LocalDensity.current) > 0
    return verticalScroll(state).padding(bottom = if (keyboardOpen) 96.dp else 0.dp)
}

/** Request room for the field and its context, rather than just its bottom cursor. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun Modifier.editorFocus(): Modifier {
    val requester = remember { BringIntoViewRequester() }
    val density = LocalDensity.current
    val keyboardBottom = WindowInsets.ime.getBottom(density)
    val clearance = with(density) { 80.dp.toPx() }
    var focused by remember { mutableStateOf(false) }
    var size by remember { mutableStateOf(IntSize.Zero) }
    LaunchedEffect(focused, keyboardBottom, size) {
        if (focused && keyboardBottom > 0 && size.height > 0) {
            requester.bringIntoView(Rect(0f, 0f, size.width.toFloat(), size.height + clearance))
        }
    }
    return bringIntoViewRequester(requester)
        .onSizeChanged { size = it }
        .onFocusChanged { focused = it.hasFocus }
}
