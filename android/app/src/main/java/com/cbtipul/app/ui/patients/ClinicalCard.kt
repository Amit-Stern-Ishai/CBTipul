package com.cbtipul.app.ui.patients

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.ui.theme.Theme

@Composable
fun ClinicalCard(
    accent: Color?,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    val colors = Theme.colors
    val outline = (accent ?: Color.Transparent).copy(alpha = 0.35f)
    Column(
        modifier
            .fillMaxWidth()
            .background(colors.surface, RoundedCornerShape(12.dp))
            .border(1.dp, outline, RoundedCornerShape(12.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        content = content,
    )
}

@Composable
fun SourceBadge(source: String) {
    val colors = Theme.colors
    val lowered = source.lowercase()
    val reported = when (source) {
        "explicit_patient", "therapist_reported" -> true
        "therapist_inferred", "ai_inferred" -> false
        else -> listOf("patient", "stated", "explicit", "quote", "said", "verbatim", "אמר", "אמרה", "ציטוט", "מפורש")
            .any { lowered.contains(it) }
    }
    val label = stringResource(
        when (source) {
            "explicit_patient" -> R.string.source_explicit_patient
            "therapist_reported" -> R.string.source_therapist_reported
            "therapist_inferred" -> R.string.source_therapist_inferred
            "ai_inferred" -> R.string.source_ai_inferred
            else -> if (reported) R.string.patient_said_badge else R.string.possible_inference_badge
        },
    )
    val tint = if (reported) colors.gold else colors.warning
    Text(
        label,
        color = tint,
        fontWeight = FontWeight.SemiBold,
        fontSize = 12.sp,
        modifier = Modifier
            .background(tint.copy(alpha = 0.12f), RoundedCornerShape(50))
            .padding(horizontal = 8.dp, vertical = 4.dp),
    )
}
