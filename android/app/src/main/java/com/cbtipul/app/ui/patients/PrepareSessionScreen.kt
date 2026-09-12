package com.cbtipul.app.ui.patients

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.cbtipul.app.R
import com.cbtipul.app.model.NextSessionPreparation
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
                title = { Text(stringResource(R.string.prepare_next_session_action), color = colors.textBright) },
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
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            if (isOutdated) {
                Text(
                    stringResource(R.string.preparation_outdated_message),
                    color = colors.warning,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(colors.warningSoft)
                        .padding(12.dp),
                )
            }
            if (preparation.executiveSummary.isNotBlank()) {
                Text(stringResource(R.string.executive_summary_section), color = colors.textBright, fontWeight = FontWeight.Bold)
                ClinicalCard(accent = atmosphere) {
                    Text(preparation.executiveSummary, color = colors.textBright)
                }
            }
            if (preparation.assignmentsToCheck.isNotEmpty()) {
                Text(stringResource(R.string.assignments_to_check_section), color = colors.textBright, fontWeight = FontWeight.Bold)
                preparation.assignmentsToCheck.forEach { item ->
                    ClinicalCard(accent = atmosphere) {
                        Text(item.assignment, color = colors.textBright, fontWeight = FontWeight.SemiBold)
                        item.details?.takeIf { it.isNotBlank() }?.let { Text(it, color = colors.textBody) }
                    }
                }
            }
            if (preparation.priorityFollowUps.isNotEmpty()) {
                Text(stringResource(R.string.priority_follow_ups_section), color = colors.textBright, fontWeight = FontWeight.Bold)
                preparation.priorityFollowUps.forEach { item ->
                    ClinicalCard(accent = atmosphere) {
                        if (item.source.isNotBlank()) SourceBadge(item.source)
                        Text(item.item, color = colors.textBright, fontWeight = FontWeight.SemiBold)
                        if (item.reason.isNotBlank()) Text(item.reason, color = colors.textBody)
                    }
                }
            }
            if (preparation.recurringNats.isNotEmpty()) {
                Text(stringResource(R.string.recurring_nats_section), color = colors.textBright, fontWeight = FontWeight.Bold)
                preparation.recurringNats.forEach { item ->
                    ClinicalCard(accent = atmosphere) {
                        Text(item.thought, color = colors.textBright, fontWeight = FontWeight.SemiBold, fontStyle = androidx.compose.ui.text.font.FontStyle.Italic)
                        if (item.situations.isNotEmpty()) Text(item.situations.joinToString(), color = colors.textBody)
                        if (item.cognitivePatterns.isNotEmpty()) {
                            item.cognitivePatterns.forEach { pattern ->
                                Text(pattern.pattern, color = colors.textBody)
                            }
                        }
                    }
                }
            }
            if (preparation.cbtCycles.isNotEmpty()) {
                Text(stringResource(R.string.maintenance_cycles_section), color = colors.textBright, fontWeight = FontWeight.Bold)
                Text(stringResource(R.string.maintenance_cycles_subtitle), color = colors.textBody)
                preparation.cbtCycles.forEach {
                    ClinicalCard(accent = atmosphere) { CycleLines(it) }
                }
            }
            if (preparation.questionnaireInsights.isNotEmpty()) {
                Text(stringResource(R.string.questionnaire_insights_section), color = colors.textBright, fontWeight = FontWeight.Bold)
                preparation.questionnaireInsights.forEach { item ->
                    ClinicalCard(accent = atmosphere) {
                        Text(item.observation, color = colors.textBright, fontWeight = FontWeight.SemiBold)
                        if (item.clinicalRelevance.isNotBlank()) Text(item.clinicalRelevance, color = colors.textBody)
                    }
                }
            }
            preparation.treatmentFocus?.let { focus ->
                Text(stringResource(R.string.treatment_focus_section), color = colors.textBright, fontWeight = FontWeight.Bold)
                Text(stringResource(R.string.treatment_focus_subtitle), color = colors.textBody)
                ClinicalCard(accent = atmosphere) {
                    Text(focus.focus, color = colors.textBright, fontWeight = FontWeight.SemiBold)
                    if (focus.rationale.isNotBlank()) Text(focus.rationale, color = colors.textBody)
                }
            }
            if (preparation.suggestedQuestions.isNotEmpty()) {
                Text(stringResource(R.string.suggested_questions_section), color = colors.textBright, fontWeight = FontWeight.Bold)
                preparation.suggestedQuestions.forEach { item ->
                    ClinicalCard(accent = atmosphere) {
                        Text(item.question, color = colors.textBright, fontWeight = FontWeight.Medium)
                        if (item.purpose.isNotBlank()) Text(item.purpose, color = colors.textBody)
                    }
                }
            }
            preparation.coreBeliefHypothesis?.let { belief ->
                Text(stringResource(R.string.possible_core_belief_section), color = colors.textBright, fontWeight = FontWeight.Bold)
                Text(stringResource(R.string.core_belief_subtitle), color = colors.textBody)
                ClinicalCard(accent = atmosphere) {
                    Text(belief.belief, color = colors.textBright, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}
