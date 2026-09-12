package com.cbtipul.app.ui.patients

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.model.CombinedMoodQuestionnaire
import com.cbtipul.app.model.GAD7Severity
import com.cbtipul.app.model.PHQ9Severity
import com.cbtipul.app.ui.theme.Theme

@Composable
fun ScoreCapsule(
    text: String,
    color: Color,
    delta: Int? = null,
) {
    val colors = Theme.colors
    Row(
        modifier = Modifier
            .background(color.copy(alpha = 0.12f), RoundedCornerShape(50))
            .padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(text, color = color, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
        if (delta != null && delta != 0) {
            Icon(
                if (delta > 0) Icons.Filled.ArrowUpward else Icons.Filled.ArrowDownward,
                contentDescription = null,
                tint = if (delta > 0) colors.error else colors.success,
                modifier = Modifier.padding(start = 2.dp),
            )
        }
    }
}

@Composable
fun GAD7ScoreCapsule(questionnaire: CombinedMoodQuestionnaire, previous: CombinedMoodQuestionnaire? = null) {
    ScoreCapsule(
        text = stringResource(R.string.score_badge, stringResource(R.string.gad7_short_name), questionnaire.gad7Score),
        color = gad7Color(questionnaire.gad7Severity),
        delta = previous?.let { questionnaire.gad7Score - it.gad7Score },
    )
}

@Composable
fun PHQ9ScoreCapsule(questionnaire: CombinedMoodQuestionnaire, previous: CombinedMoodQuestionnaire? = null) {
    ScoreCapsule(
        text = stringResource(R.string.score_badge, stringResource(R.string.phq9_short_name), questionnaire.phq9Score),
        color = phq9Color(questionnaire.phq9Severity),
        delta = previous?.let { questionnaire.phq9Score - it.phq9Score },
    )
}

@Composable
fun gad7Color(severity: GAD7Severity) = when (severity) {
    GAD7Severity.Minimal -> Theme.colors.success
    GAD7Severity.Mild -> Theme.colors.warning
    GAD7Severity.Substantial, GAD7Severity.Extreme -> Theme.colors.error
}

@Composable
fun phq9Color(severity: PHQ9Severity) = when (severity) {
    PHQ9Severity.Minimal -> Theme.colors.success
    PHQ9Severity.Mild, PHQ9Severity.Moderate -> Theme.colors.warning
    PHQ9Severity.ModeratelySevere, PHQ9Severity.Severe -> Theme.colors.error
}

@Composable
fun gad7SeverityLabel(severity: GAD7Severity) = stringResource(
    when (severity) {
        GAD7Severity.Minimal -> R.string.gad7_severity_minimal
        GAD7Severity.Mild -> R.string.gad7_severity_mild
        GAD7Severity.Substantial -> R.string.gad7_severity_substantial
        GAD7Severity.Extreme -> R.string.gad7_severity_extreme
    },
)

@Composable
fun phq9SeverityLabel(severity: PHQ9Severity) = stringResource(
    when (severity) {
        PHQ9Severity.Minimal -> R.string.phq9_severity_minimal
        PHQ9Severity.Mild -> R.string.phq9_severity_mild
        PHQ9Severity.Moderate -> R.string.phq9_severity_moderate
        PHQ9Severity.ModeratelySevere -> R.string.phq9_severity_moderately_severe
        PHQ9Severity.Severe -> R.string.phq9_severity_severe
    },
)

@Composable
fun phq9Suggestion(severity: PHQ9Severity) = stringResource(
    when (severity) {
        PHQ9Severity.Minimal -> R.string.phq9_suggestion_minimal
        PHQ9Severity.Mild -> R.string.phq9_suggestion_mild
        PHQ9Severity.Moderate -> R.string.phq9_suggestion_moderate
        PHQ9Severity.ModeratelySevere -> R.string.phq9_suggestion_moderately_severe
        PHQ9Severity.Severe -> R.string.phq9_suggestion_severe
    },
)
