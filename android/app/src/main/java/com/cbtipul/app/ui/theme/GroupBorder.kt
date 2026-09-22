package com.cbtipul.app.ui.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

private val GroupCornerRadius = 12.dp

@Composable
fun Modifier.groupedListCard(accent: Color? = null): Modifier {
    val shape = RoundedCornerShape(GroupCornerRadius)
    val outline = (accent ?: Theme.colors.gold).copy(alpha = 0.35f)
    return this
        .clip(shape)
        .background(Theme.colors.surface)
        .border(1.dp, outline, shape)
}

@Composable
fun GroupedListCard(
    accent: Color? = null,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier
            .fillMaxWidth()
            .groupedListCard(accent),
        content = content,
    )
}

@Composable
fun GroupedListDivider(startInset: Dp = 16.dp) {
    HorizontalDivider(
        modifier = Modifier.padding(start = startInset),
        color = Theme.colors.borderFaint,
    )
}
