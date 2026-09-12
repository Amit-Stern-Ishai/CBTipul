package com.cbtipul.app.ui.patients

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.cbtipul.app.R
import com.cbtipul.app.model.CBTCycle
import com.cbtipul.app.model.FormulationSupervision
import com.cbtipul.app.model.LongitudinalCaseReviewResponse
import com.cbtipul.app.model.LongitudinalFinding
import com.cbtipul.app.model.Patient
import com.cbtipul.app.model.PatientFormulation
import com.cbtipul.app.model.SupervisionPoint
import com.cbtipul.app.model.WhatAmIMissingResponse
import com.cbtipul.app.ui.theme.Theme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FormulationScreen(
    patient: Patient?,
    isSaving: Boolean,
    isAiBusy: Boolean,
    errorMessage: String?,
    onBack: () -> Unit,
    onSave: (PatientFormulation) -> Unit,
    onChallenge: () -> Unit,
    onMissing: () -> Unit,
    onLongitudinal: () -> Unit,
) {
    val colors = Theme.colors
    if (patient == null) {
        Column(Modifier.fillMaxSize().padding(24.dp)) {
            Text(stringResource(R.string.unnamed_patient), color = colors.textBright)
            TextButton(onClick = onBack) { Text(stringResource(R.string.back), color = colors.gold) }
        }
        return
    }
    var draft by remember(patient.id.queryValue) { mutableStateOf(patient.formulation ?: PatientFormulation()) }
    val busy = isSaving || isAiBusy
    Scaffold(
        containerColor = colors.base,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.my_formulation_title), color = colors.textBright) },
                navigationIcon = {
                    IconButton(onClick = onBack, enabled = !busy) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = stringResource(R.string.back), tint = colors.gold)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = colors.base),
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text(stringResource(R.string.treatment_goal_section), color = colors.textBright, fontWeight = FontWeight.SemiBold)
            OutlinedTextField(
                value = draft.treatmentGoal.orEmpty(),
                onValueChange = { draft = draft.copy(treatmentGoal = it.ifBlank { null }) },
                modifier = Modifier.fillMaxWidth(),
                enabled = !busy,
                minLines = 2,
            )
            Text(stringResource(R.string.core_belief_section), color = colors.textBright, fontWeight = FontWeight.SemiBold)
            OutlinedTextField(
                value = draft.coreBelief.orEmpty(),
                onValueChange = { draft = draft.copy(coreBelief = it.ifBlank { null }) },
                modifier = Modifier.fillMaxWidth(),
                enabled = !busy,
                placeholder = { Text(stringResource(R.string.no_core_belief_placeholder)) },
                minLines = 2,
            )
            Text(stringResource(R.string.key_automatic_thoughts_section), color = colors.textBright, fontWeight = FontWeight.SemiBold)
            draft.keyAutomaticThoughts.forEachIndexed { index, item ->
                OutlinedTextField(
                    value = item,
                    onValueChange = {
                        draft = draft.copy(keyAutomaticThoughts = draft.keyAutomaticThoughts.toMutableList().also { list -> list[index] = it })
                    },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !busy,
                )
            }
            TextButton(onClick = { draft = draft.copy(keyAutomaticThoughts = draft.keyAutomaticThoughts + "") }, enabled = !busy) {
                Text(stringResource(R.string.add_thought_action), color = colors.gold)
            }
            Text(stringResource(R.string.maintaining_behaviors_section), color = colors.textBright, fontWeight = FontWeight.SemiBold)
            draft.maintainingBehaviors.forEachIndexed { index, item ->
                OutlinedTextField(
                    value = item,
                    onValueChange = {
                        draft = draft.copy(maintainingBehaviors = draft.maintainingBehaviors.toMutableList().also { list -> list[index] = it })
                    },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !busy,
                )
            }
            TextButton(onClick = { draft = draft.copy(maintainingBehaviors = draft.maintainingBehaviors + "") }, enabled = !busy) {
                Text(stringResource(R.string.add_behavior_action), color = colors.gold)
            }
            Text(stringResource(R.string.key_cbt_cycle_section), color = colors.textBright, fontWeight = FontWeight.SemiBold)
            val cycle = draft.keyCBTCycle
            if (cycle == null) {
                Text(stringResource(R.string.no_key_cbt_cycle_label), color = colors.textBody)
                TextButton(onClick = { draft = draft.copy(keyCBTCycle = CBTCycle()) }, enabled = !busy) {
                    Text(stringResource(R.string.add_cbt_cycle_action), color = colors.gold)
                }
            } else {
                OutlinedTextField(cycle.triggerSituation.orEmpty(), { draft = draft.copy(keyCBTCycle = cycle.copy(triggerSituation = it.ifBlank { null })) }, Modifier.fillMaxWidth(), enabled = !busy, label = { Text(stringResource(R.string.situation_label)) })
                OutlinedTextField(cycle.automaticThought.orEmpty(), { draft = draft.copy(keyCBTCycle = cycle.copy(automaticThought = it.ifBlank { null })) }, Modifier.fillMaxWidth(), enabled = !busy, label = { Text(stringResource(R.string.automatic_thought_label)) })
                OutlinedTextField(cycle.emotion.orEmpty(), { draft = draft.copy(keyCBTCycle = cycle.copy(emotion = it.ifBlank { null })) }, Modifier.fillMaxWidth(), enabled = !busy, label = { Text(stringResource(R.string.emotion_label)) })
                OutlinedTextField(cycle.behavior.orEmpty(), { draft = draft.copy(keyCBTCycle = cycle.copy(behavior = it.ifBlank { null })) }, Modifier.fillMaxWidth(), enabled = !busy, label = { Text(stringResource(R.string.behavior_label)) })
                OutlinedTextField(cycle.shortTermConsequence.orEmpty(), { draft = draft.copy(keyCBTCycle = cycle.copy(shortTermConsequence = it.ifBlank { null })) }, Modifier.fillMaxWidth(), enabled = !busy, label = { Text(stringResource(R.string.short_term_consequence_label)) })
                OutlinedTextField(cycle.longTermConsequence.orEmpty(), { draft = draft.copy(keyCBTCycle = cycle.copy(longTermConsequence = it.ifBlank { null })) }, Modifier.fillMaxWidth(), enabled = !busy, label = { Text(stringResource(R.string.long_term_consequence_label)) })
                TextButton(onClick = { draft = draft.copy(keyCBTCycle = null) }, enabled = !busy) {
                    Text(stringResource(R.string.remove_cycle_action), color = colors.error)
                }
            }
            Text(stringResource(R.string.therapist_hypothesis_section), color = colors.textBright, fontWeight = FontWeight.SemiBold)
            OutlinedTextField(
                value = draft.therapistHypothesis.orEmpty(),
                onValueChange = { draft = draft.copy(therapistHypothesis = it.ifBlank { null }) },
                modifier = Modifier.fillMaxWidth(),
                enabled = !busy,
                placeholder = { Text(stringResource(R.string.therapist_hypothesis_placeholder)) },
                minLines = 3,
            )
            errorMessage?.let { Text(it, color = colors.error) }
            if (busy) CircularProgressIndicator(color = colors.gold)
            Button(
                onClick = { onSave(draft) },
                enabled = !busy,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = colors.gold, contentColor = colors.textOnAccent),
            ) { Text(stringResource(R.string.save_changes_action)) }
            Text(stringResource(R.string.ai_supervision_section), color = colors.textBright, fontWeight = FontWeight.SemiBold)
            Text(stringResource(R.string.ai_supervision_footer), color = colors.textBody)
            Button(onClick = onChallenge, enabled = !busy, modifier = Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = colors.gold, contentColor = colors.textOnAccent)) {
                Text(stringResource(R.string.challenge_formulation_action))
            }
            Button(onClick = onMissing, enabled = !busy, modifier = Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = colors.gold, contentColor = colors.textOnAccent)) {
                Text(stringResource(R.string.what_am_i_missing_action))
            }
            Button(onClick = onLongitudinal, enabled = !busy, modifier = Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = colors.gold, contentColor = colors.textOnAccent)) {
                Text(stringResource(R.string.longitudinal_review_action))
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FormulationSupervisionScreen(result: FormulationSupervision?, onBack: () -> Unit) {
    SupervisionScaffold(stringResource(R.string.challenge_formulation_action), onBack) {
        if (result == null) {
            Text(stringResource(R.string.empty_ai_response_error), color = Theme.colors.textBright)
            return@SupervisionScaffold
        }
        Text(stringResource(R.string.supervision_disclaimer_body), color = Theme.colors.textBody)
        PointSection(stringResource(R.string.supports_formulation_section), result.supportingEvidence)
        PointSection(stringResource(R.string.may_not_fit_section), result.challengingEvidence, stringResource(R.string.may_not_fit_subtitle))
        PointSection(stringResource(R.string.possible_blind_spots_section), result.possibleBlindSpots, stringResource(R.string.blind_spots_subtitle))
        if (result.alternativeFormulations.isNotEmpty()) {
            Text(stringResource(R.string.alternative_formulations_section), color = Theme.colors.textBright, fontWeight = FontWeight.Bold)
            Text(stringResource(R.string.alternative_formulations_subtitle), color = Theme.colors.textBody)
            result.alternativeFormulations.forEach { item ->
                Text(item.formulation, color = Theme.colors.textBright, fontWeight = FontWeight.SemiBold)
                if (item.whatItWouldExplain.isNotBlank()) Text(item.whatItWouldExplain, color = Theme.colors.textBody)
            }
        }
        if (result.questionsToExplore.isNotEmpty()) {
            Text(stringResource(R.string.questions_to_explore_section), color = Theme.colors.textBright, fontWeight = FontWeight.Bold)
            result.questionsToExplore.forEach { Text(it.question, color = Theme.colors.textBright) }
        }
        if (result.treatmentImplications.isNotEmpty()) {
            Text(stringResource(R.string.treatment_implications_section), color = Theme.colors.textBright, fontWeight = FontWeight.Bold)
            result.treatmentImplications.forEach { Text(it.implication, color = Theme.colors.textBright) }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WhatAmIMissingScreen(result: WhatAmIMissingResponse?, onBack: () -> Unit) {
    SupervisionScaffold(stringResource(R.string.what_am_i_missing_title), onBack) {
        if (result == null || result.findings.isEmpty()) {
            Text(stringResource(R.string.no_additional_patterns_message), color = Theme.colors.textBright)
            return@SupervisionScaffold
        }
        result.findings.forEach { finding ->
            Text(finding.title, color = Theme.colors.textBright, fontWeight = FontWeight.Bold)
            Text(finding.observation, color = Theme.colors.textBright)
            if (finding.whyItMightMatter.isNotBlank()) {
                Text(stringResource(R.string.why_this_might_matter_label), color = Theme.colors.textBody)
                Text(finding.whyItMightMatter, color = Theme.colors.textBody)
            }
            if (finding.questionForTherapist.isNotBlank()) {
                Text(stringResource(R.string.question_for_therapist_label), color = Theme.colors.textBody)
                Text(finding.questionForTherapist, color = Theme.colors.textBright)
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LongitudinalReviewScreen(result: LongitudinalCaseReviewResponse?, onBack: () -> Unit) {
    SupervisionScaffold(stringResource(R.string.longitudinal_case_review_title), onBack) {
        if (result == null) {
            Text(stringResource(R.string.insufficient_longitudinal_data_message), color = Theme.colors.textBright)
            return@SupervisionScaffold
        }
        if (result.overallTrajectory.isNotBlank()) Text(result.overallTrajectory, color = Theme.colors.textBright)
        FindingSection(stringResource(R.string.formulation_evolution_section), result.formulationEvolution)
        if (result.treatmentGoalProgress.isNotEmpty()) {
            Text(stringResource(R.string.treatment_goal_progress_section), color = Theme.colors.textBright, fontWeight = FontWeight.Bold)
            result.treatmentGoalProgress.forEach { Text(it.goal + " — " + it.status, color = Theme.colors.textBright) }
        }
        FindingSection(stringResource(R.string.longitudinal_review_footer), result.clinicalAttentionPoints)
        if (result.questionsForTherapist.isNotEmpty()) {
            result.questionsForTherapist.forEach { Text(it, color = Theme.colors.textBright) }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SupervisionScaffold(title: String, onBack: () -> Unit, content: @Composable () -> Unit) {
    val colors = Theme.colors
    Scaffold(
        containerColor = colors.base,
        topBar = {
            TopAppBar(
                title = { Text(title, color = colors.textBright) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = stringResource(R.string.back), tint = colors.gold)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = colors.base),
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            content()
        }
    }
}

@Composable
private fun PointSection(title: String, items: List<SupervisionPoint>, subtitle: String? = null) {
    if (items.isEmpty()) return
    Text(title, color = Theme.colors.textBright, fontWeight = FontWeight.Bold)
    subtitle?.let { Text(it, color = Theme.colors.textBody) }
    items.forEach { item ->
        Text(item.observation, color = Theme.colors.textBright, fontWeight = FontWeight.SemiBold)
        if (item.evidence.isNotBlank()) Text(item.evidence, color = Theme.colors.textBody)
    }
}

@Composable
private fun FindingSection(title: String, items: List<LongitudinalFinding>) {
    if (items.isEmpty()) return
    Text(title, color = Theme.colors.textBright, fontWeight = FontWeight.Bold)
    items.forEach { item ->
        Text(item.observation, color = Theme.colors.textBright)
        if (item.interpretation.isNotBlank()) Text(item.interpretation, color = Theme.colors.textBody)
    }
}
