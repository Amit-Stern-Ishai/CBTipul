package com.cbtipul.app.ui.patients

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.sp
import com.cbtipul.app.ui.theme.Theme
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filter

/**
 * Multiline notes field matching iOS `NotesField`: height grows from
 * [minLines] to [maxLines], then scrolls. When text is set while unfocused,
 * the viewport jumps to the end instantly (no animation).
 */
@Composable
fun NotesField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    minLines: Int = 3,
    maxLines: Int = 8,
    enabled: Boolean = true,
    readOnly: Boolean = false,
    onFocusChanged: ((Boolean) -> Unit)? = null,
) {
    val colors = Theme.colors
    val style = TextStyle(
        color = colors.textBright,
        fontSize = 16.sp,
        lineHeight = 22.sp,
    )
    val density = LocalDensity.current
    val minHeight = with(density) { (style.lineHeight * minLines).toDp() }
    val maxHeight = with(density) { (style.lineHeight * maxLines).toDp() }
    val scrollState = rememberScrollState()
    var focused by remember { mutableStateOf(false) }

    // Idle fields show the latest notes (end of text). Instant — no animation.
    LaunchedEffect(value, focused) {
        if (focused) return@LaunchedEffect
        snapshotFlow { scrollState.maxValue }
            .distinctUntilChanged()
            .filter { it > 0 }
            .collect { max ->
                scrollState.scrollTo(max)
            }
    }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = minHeight, max = maxHeight),
    ) {
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = minHeight)
                .verticalScroll(scrollState)
                .onFocusChanged { focus ->
                    focused = focus.isFocused
                    onFocusChanged?.invoke(focus.isFocused)
                },
            enabled = enabled,
            readOnly = readOnly,
            textStyle = style,
            cursorBrush = SolidColor(colors.gold),
            decorationBox = { inner ->
                Box(Modifier.fillMaxWidth()) {
                    if (value.isEmpty() && placeholder.isNotEmpty()) {
                        Text(placeholder, color = colors.textFaint, style = style)
                    }
                    inner()
                }
            },
        )
    }
}
