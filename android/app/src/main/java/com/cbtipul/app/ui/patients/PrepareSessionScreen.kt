package com.cbtipul.app.ui.patients

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.outlined.GpsFixed
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.model.CBTCycle
import com.cbtipul.app.model.CoreBeliefHypothesis
import com.cbtipul.app.model.NextSessionPreparation
import com.cbtipul.app.model.RecurringNAT
import com.cbtipul.app.model.TreatmentFocus
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.themedScreen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PrepareSessionScreen(
    preparation: NextSessionPreparation?,
    atmosphere: Color?,
    isOutdated: Boolean,
    onBack: () -> Unit,
) {
    val colors = Theme.colors
    Scaffold(
        modifier = Modifier.themedScreen(atmosphere),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.session_preparation_title), color = colors.textBright) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = stringResource(R.string.back), tint = colors.gold)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
    ) { padding ->
        if (preparation == null) {
            Column(Modifier.fillMaxSize().padding(padding).padding(24.dp)) {
                Text(stringResource(R.string.empty_ai_response_error), color = colors.textBright)
                TextButton(onClick = onBack) { Text(stringResource(R.string.back), color = colors.gold) }
            }
            return@Scaffold
        }
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(28.dp),
        ) {
            if (isOutdated) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(colors.warning.copy(alpha = 0.12f), RoundedCornerShape(10.dp))
                        .padding(12.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Outlined.Schedule, contentDescription = null, tint = colors.warning, modifier = Modifier.size(18.dp))
                    Text(
                        stringResource(R.string.preparation_outdated_message),
                        color = colors.warning,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 13.sp,
                    )
                }
            }

            if (preparation.executiveSummary.isNotBlank()) {
                ClinicalCard(accent = atmosphere) {
                    Text(preparation.executiveSummary, color = colors.textBright, lineHeight = 22.sp)
                }
            }

            PrepSection(stringResource(R.string.assignments_to_check_section), preparation.assignmentsToCheck.isNotEmpty()) {
                preparation.assignmentsToCheck.forEach { item ->
                    ClinicalCard(accent = atmosphere) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = colors.textBody, modifier = Modifier.size(20.dp))
                            Column(verticalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.weight(1f)) {
                                Text(item.assignment, color = colors.textBright, fontWeight = FontWeight.SemiBold)
                                item.details?.takeIf { it.isNotBlank() }?.let {
                                    Text(it, color = colors.textBody, fontSize = 14.sp)
                                }
                            }
                        }
                    }
                }
            }

            PrepSection(stringResource(R.string.priority_follow_ups_section), preparation.priorityFollowUps.isNotEmpty()) {
                preparation.priorityFollowUps.forEach { item ->
                    ClinicalCard(accent = atmosphere) {
                        Text(item.item, color = colors.textBright, fontWeight = FontWeight.SemiBold)
                        if (item.reason.isNotBlank()) {
                            Text(item.reason, color = colors.textBody, fontSize = 14.sp)
                        }
                        if (item.source.isNotBlank()) {
                            Text(
                                stringResource(R.string.source_line, item.source),
                                color = colors.textBody,
                                fontSize = 12.sp,
                            )
                        }
                    }
                }
            }

            PrepSection(stringResource(R.string.recurring_nats_section), preparation.recurringNats.isNotEmpty()) {
                preparation.recurringNats.forEach { item ->
                    NatCard(item, atmosphere)
                }
            }

            PrepSection(
                stringResource(R.string.maintenance_cycles_section),
                preparation.cbtCycles.isNotEmpty(),
                subtitle = stringResource(R.string.maintenance_cycles_subtitle),
            ) {
                preparation.cbtCycles.forEach { cycle ->
                    MaintenanceCycleCard(cycle, atmosphere)
                }
            }

            PrepSection(stringResource(R.string.questionnaire_insights_section), preparation.questionnaireInsights.isNotEmpty()) {
                preparation.questionnaireInsights.forEach { item ->
                    ClinicalCard(accent = atmosphere) {
                        Text(item.observation, color = colors.textBright, fontWeight = FontWeight.SemiBold)
                        if (item.clinicalRelevance.isNotBlank()) {
                            Text(item.clinicalRelevance, color = colors.textBody, fontSize = 14.sp)
                        }
                        EvidenceDisclosure(item.evidence)
                    }
                }
            }

            preparation.treatmentFocus?.let { TreatmentFocusSection(it) }

            PrepSection(stringResource(R.string.suggested_questions_section), preparation.suggestedQuestions.isNotEmpty()) {
                preparation.suggestedQuestions.forEach { item ->
                    ClinicalCard(accent = atmosphere) {
                        Text(
                            item.question,
                            color = colors.textBright,
                            fontWeight = FontWeight.Medium,
                            fontStyle = FontStyle.Italic,
                        )
                        if (item.purpose.isNotBlank()) {
                            Text(item.purpose, color = colors.textBody, fontSize = 14.sp)
                        }
                    }
                }
            }

            preparation.coreBeliefHypothesis?.let { CoreBeliefSection(it, atmosphere) }

            Text(
                stringResource(R.string.ai_disclaimer),
                color = colors.textBody,
                fontSize = 13.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
private fun PrepSection(
    title: String,
    visible: Boolean,
    subtitle: String? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    if (!visible) return
    val colors = Theme.colors
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, color = colors.textBright, fontWeight = FontWeight.Bold, fontSize = 20.sp)
            subtitle?.let { Text(it, color = colors.textBody, fontSize = 12.sp) }
        }
        content()
    }
}

@Composable
private fun NatCard(item: RecurringNAT, atmosphere: Color?) {
    val colors = Theme.colors
    val high = stringResource(R.string.confidence_high)
    val medium = stringResource(R.string.confidence_medium)
    val low = stringResource(R.string.confidence_low)
    ClinicalCard(accent = atmosphere) {
        Row(verticalAlignment = Alignment.Top) {
            Text(
                item.thought,
                color = colors.textBright,
                fontWeight = FontWeight.SemiBold,
                fontStyle = FontStyle.Italic,
                modifier = Modifier.weight(1f),
            )
            HypothesisBadge()
        }
        if (item.situations.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(stringResource(R.string.situations_label), color = colors.textBody, fontSize = 12.sp)
                Text(item.situations.joinToString(" · "), color = colors.textBright, fontSize = 14.sp)
            }
        }
        EvidenceDisclosure(item.evidence)
        if (item.cognitivePatterns.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    stringResource(R.string.possible_thinking_patterns_label),
                    color = colors.textBody,
                    fontSize = 12.sp,
                )
                item.cognitivePatterns.forEach { pattern ->
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(colors.elevated, RoundedCornerShape(8.dp))
                            .padding(10.dp),
                        verticalArrangement = Arrangement.spacedBy(2.dp),
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                pattern.pattern,
                                color = colors.gold,
                                fontWeight = FontWeight.Medium,
                                fontSize = 14.sp,
                                modifier = Modifier.weight(1f),
                            )
                            confidenceCaption(pattern.confidence, high, medium, low)?.let {
                                Text(it, color = colors.textBody, fontSize = 12.sp)
                            }
                        }
                        if (pattern.evidence.isNotBlank()) {
                            Text(pattern.evidence, color = colors.textBody, fontSize = 12.sp)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun MaintenanceCycleCard(cycle: CBTCycle, atmosphere: Color?) {
    val colors = Theme.colors
    ClinicalCard(accent = atmosphere) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                stringResource(R.string.possible_maintenance_cycle_label),
                color = colors.textBody,
                fontWeight = FontWeight.SemiBold,
                fontSize = 12.sp,
                modifier = Modifier.weight(1f),
            )
            HypothesisBadge()
        }
        CycleLines(cycle, elevatedStages = true)
    }
}

@Composable
private fun TreatmentFocusSection(focus: TreatmentFocus) {
    val colors = Theme.colors
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                stringResource(R.string.treatment_focus_section),
                color = colors.textBright,
                fontWeight = FontWeight.Bold,
                fontSize = 20.sp,
            )
            Text(
                stringResource(R.string.treatment_focus_subtitle),
                color = colors.textBody,
                fontSize = 12.sp,
            )
        }
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(colors.goldGhost, RoundedCornerShape(12.dp))
                .border(1.dp, colors.gold.copy(alpha = 0.45f), RoundedCornerShape(12.dp))
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Outlined.GpsFixed, contentDescription = null, tint = colors.gold, modifier = Modifier.size(20.dp))
                Text(focus.focus, color = colors.textBright, fontWeight = FontWeight.SemiBold)
            }
            if (focus.rationale.isNotBlank()) {
                Text(focus.rationale, color = colors.textBody, fontSize = 14.sp)
            }
        }
    }
}

@Composable
private fun CoreBeliefSection(belief: CoreBeliefHypothesis, atmosphere: Color?) {
    val colors = Theme.colors
    val outline = (atmosphere ?: colors.borderDefault).copy(alpha = if (atmosphere != null) 0.35f else 1f)
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                stringResource(R.string.possible_core_belief_section),
                color = colors.textBright,
                fontWeight = FontWeight.Bold,
                fontSize = 20.sp,
            )
            Text(
                stringResource(R.string.core_belief_subtitle),
                color = colors.textBody,
                fontSize = 12.sp,
            )
        }
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(colors.surface.copy(alpha = 0.6f), RoundedCornerShape(12.dp))
                .drawBehind {
                    drawRoundRect(
                        color = outline,
                        cornerRadius = CornerRadius(12.dp.toPx()),
                        style = Stroke(
                            width = 1.dp.toPx(),
                            pathEffect = PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 4.dp.toPx())),
                        ),
                    )
                }
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Row(verticalAlignment = Alignment.Top) {
                Text(
                    belief.belief,
                    color = colors.textBright,
                    fontWeight = FontWeight.Medium,
                    fontStyle = FontStyle.Italic,
                    modifier = Modifier.weight(1f),
                )
                HypothesisBadge()
            }
            if (belief.evidence.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        stringResource(R.string.evidence_label),
                        color = colors.textBody,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 12.sp,
                    )
                    belief.evidence.forEach { line ->
                        Text(
                            stringResource(R.string.bulleted, line),
                            color = colors.textBody,
                            fontSize = 14.sp,
                        )
                    }
                }
            }
        }
    }
}
