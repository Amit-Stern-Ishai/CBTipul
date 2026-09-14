package com.cbtipul.app.ui.patients

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ExpandLess
import androidx.compose.material.icons.outlined.ExpandMore
import androidx.compose.material.icons.outlined.FormatQuote
import androidx.compose.material.icons.outlined.Lightbulb
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
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
        verticalArrangement = Arrangement.spacedBy(8.dp),
        content = content,
    )
}

@Composable
fun HypothesisBadge(labelRes: Int = R.string.hypothesis_badge) {
    val colors = Theme.colors
    Row(
        modifier = Modifier
            .background(colors.warning.copy(alpha = 0.12f), RoundedCornerShape(50))
            .padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Icon(
            Icons.Outlined.Lightbulb,
            contentDescription = null,
            tint = colors.warning,
            modifier = Modifier.size(14.dp),
        )
        Text(
            stringResource(labelRes),
            color = colors.warning,
            fontWeight = FontWeight.SemiBold,
            fontSize = 12.sp,
        )
    }
}

@Composable
fun EvidenceDisclosure(evidence: String) {
    if (evidence.isBlank()) return
    val colors = Theme.colors
    var open by remember { mutableStateOf(false) }
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { open = !open }
                .padding(vertical = 2.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(
                stringResource(R.string.evidence_label),
                color = colors.textBody,
                fontWeight = FontWeight.SemiBold,
                fontSize = 12.sp,
                modifier = Modifier.weight(1f),
            )
            Icon(
                if (open) Icons.Outlined.ExpandLess else Icons.Outlined.ExpandMore,
                contentDescription = null,
                tint = colors.textBody,
                modifier = Modifier.size(18.dp),
            )
        }
        AnimatedVisibility(visible = open) {
            Text(
                evidence,
                color = colors.textBody,
                fontSize = 14.sp,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
    }
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
    Row(
        modifier = Modifier
            .background(tint.copy(alpha = 0.12f), RoundedCornerShape(50))
            .padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Icon(
            if (reported) Icons.Outlined.FormatQuote else Icons.Outlined.Lightbulb,
            contentDescription = null,
            tint = tint,
            modifier = Modifier.size(14.dp),
        )
        Text(
            label,
            color = tint,
            fontWeight = FontWeight.SemiBold,
            fontSize = 12.sp,
        )
    }
}

fun confidenceCaption(raw: String, high: String, medium: String, low: String): String? {
    if (raw.isBlank()) return null
    val lowered = raw.lowercase()
    return when {
        lowered.contains("high") || lowered.contains("גבוה") -> high
        lowered.contains("med") || lowered.contains("בינוני") -> medium
        lowered.contains("low") || lowered.contains("נמוך") -> low
        else -> raw
    }
}
