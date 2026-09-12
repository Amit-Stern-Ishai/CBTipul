package com.cbtipul.app.ui.patients

import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

fun aiMarkdown(text: String): AnnotatedString = buildAnnotatedString {
    text.lineSequence().forEachIndexed { index, raw ->
        if (index > 0) append('\n')
        var line = raw
        var weight = FontWeight.Normal
        var sizeSp = 16
        when {
            line.startsWith("### ") -> {
                line = line.removePrefix("### ")
                weight = FontWeight.SemiBold
                sizeSp = 16
            }
            line.startsWith("## ") -> {
                line = line.removePrefix("## ")
                weight = FontWeight.Bold
                sizeSp = 18
            }
            line.startsWith("# ") -> {
                line = line.removePrefix("# ")
                weight = FontWeight.Bold
                sizeSp = 20
            }
            line.startsWith("- ") || line.startsWith("* ") -> {
                line = "• " + line.drop(2)
            }
        }
        val start = length
        appendInlineMarkdown(line)
        if (weight != FontWeight.Normal || sizeSp != 16) {
            addStyle(SpanStyle(fontWeight = weight, fontSize = sizeSp.sp), start, length)
        }
    }
}

private fun AnnotatedString.Builder.appendInlineMarkdown(line: String) {
    val pattern = Regex("(\\*\\*[^*]+\\*\\*|\\*[^*]+\\*|`[^`]+`)")
    var cursor = 0
    for (match in pattern.findAll(line)) {
        append(line.substring(cursor, match.range.first))
        val token = match.value
        val start = length
        when {
            token.startsWith("**") -> {
                append(token.removeSurrounding("**"))
                addStyle(SpanStyle(fontWeight = FontWeight.Bold), start, length)
            }
            token.startsWith("*") -> {
                append(token.removeSurrounding("*"))
                addStyle(SpanStyle(fontStyle = FontStyle.Italic), start, length)
            }
            else -> {
                append(token.removeSurrounding("`"))
                addStyle(SpanStyle(fontFamily = FontFamily.Monospace), start, length)
            }
        }
        cursor = match.range.last + 1
    }
    append(line.substring(cursor))
}
