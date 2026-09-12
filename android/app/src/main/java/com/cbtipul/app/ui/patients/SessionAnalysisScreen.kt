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
import com.cbtipul.app.model.FollowUpStatus
import com.cbtipul.app.model.CBTCycle
import com.cbtipul.app.model.CBTSessionAnalysis
import com.cbtipul.app.ui.theme.Theme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SessionAnalysisScreen(
    analysis: CBTSessionAnalysis?,
    canSave: Boolean,
    isSaving: Boolean,
    errorMessage: String?,
    onBack: () -> Unit,
    onSave: (CBTSessionAnalysis) -> Unit,
) {
    val colors = Theme.colors
    if (analysis == null) {
        Column(Modifier.fillMaxSize().padding(24.dp)) {
            Text(stringResource(R.string.session_not_saved_error), color = colors.textBright)
            TextButton(onClick = onBack) { Text(stringResource(R.string.back), color = colors.gold) }
        }
        return
    }
    var edited by remember(analysis.sessionSummary) { mutableStateOf(analysis) }
    Scaffold(
        containerColor = colors.base,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.session_summary_title), color = colors.textBright) },
                navigationIcon = {
                    IconButton(onClick = onBack, enabled = !isSaving) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = stringResource(R.string.back), tint = colors.gold)
                    }
                },
                actions = {
                    if (canSave) {
                        TextButton(onClick = { onSave(edited) }, enabled = !isSaving) {
                            Text(stringResource(R.string.done), color = colors.gold)
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = colors.base),
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            OutlinedTextField(
                value = edited.sessionSummary,
                onValueChange = { edited = edited.copy(sessionSummary = it) },
                modifier = Modifier.fillMaxWidth(),
                minLines = 4,
                placeholder = { Text(stringResource(R.string.session_summary_placeholder)) },
            )
            if (edited.keySituations.isNotEmpty()) {
                Text(stringResource(R.string.key_situations_section), color = colors.textBright, fontWeight = FontWeight.Bold)
                edited.keySituations.forEachIndexed { index, item ->
                    OutlinedTextField(
                        value = item.situation,
                        onValueChange = { value ->
                            edited = edited.copy(
                                keySituations = edited.keySituations.toMutableList().also {
                                    it[index] = item.copy(situation = value)
                                },
                            )
                        },
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text(stringResource(R.string.situation_label)) },
                    )
                    OutlinedTextField(
                        value = item.whyItMatters,
                        onValueChange = { value ->
                            edited = edited.copy(
                                keySituations = edited.keySituations.toMutableList().also {
                                    it[index] = item.copy(whyItMatters = value)
                                },
                            )
                        },
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text(stringResource(R.string.why_it_matters_label)) },
                    )
                }
            }
            if (edited.possibleNats.isNotEmpty()) {
                Text(stringResource(R.string.possible_automatic_thoughts_section), color = colors.textBright, fontWeight = FontWeight.Bold)
                edited.possibleNats.forEachIndexed { index, item ->
                    OutlinedTextField(
                        value = item.thought,
                        onValueChange = { value ->
                            edited = edited.copy(
                                possibleNats = edited.possibleNats.toMutableList().also {
                                    it[index] = item.copy(thought = value)
                                },
                            )
                        },
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text(stringResource(R.string.thought_label)) },
                    )
                    OutlinedTextField(
                        value = item.situation,
                        onValueChange = { value ->
                            edited = edited.copy(
                                possibleNats = edited.possibleNats.toMutableList().also {
                                    it[index] = item.copy(situation = value)
                                },
                            )
                        },
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text(stringResource(R.string.situation_label)) },
                    )
                    Text(item.emotion.orEmpty(), color = colors.textBody)
                    Text(item.behavior.orEmpty(), color = colors.textBody)
                }
            }
            if (edited.cbtCycles.isNotEmpty()) {
                Text(stringResource(R.string.cbt_cycle_section), color = colors.textBright, fontWeight = FontWeight.Bold)
                edited.cbtCycles.forEach { CycleLines(it) }
            }
            if (edited.therapistHypotheses.isNotEmpty()) {
                Text(stringResource(R.string.therapist_hypotheses_section), color = colors.textBright, fontWeight = FontWeight.Bold)
                edited.therapistHypotheses.forEach { item ->
                    Text(item.hypothesis, color = colors.textBright, fontWeight = FontWeight.SemiBold)
                    if (item.evidence.isNotEmpty()) Text(item.evidence, color = colors.textBody)
                }
            }
            if (edited.followUpQuestions.isNotEmpty()) {
                Text(stringResource(R.string.questions_to_revisit_section), color = colors.textBright, fontWeight = FontWeight.Bold)
                edited.followUpQuestions.forEachIndexed { index, item ->
                    OutlinedTextField(
                        value = item.question,
                        onValueChange = { value ->
                            edited = edited.copy(
                                followUpQuestions = edited.followUpQuestions.toMutableList().also {
                                    it[index] = item.copy(question = value)
                                },
                            )
                        },
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text(stringResource(R.string.question_placeholder)) },
                    )
                    OutlinedTextField(
                        value = item.reason,
                        onValueChange = { value ->
                            edited = edited.copy(
                                followUpQuestions = edited.followUpQuestions.toMutableList().also {
                                    it[index] = item.copy(reason = value)
                                },
                            )
                        },
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        FollowUpStatus.entries.forEach { status ->
                            val selected = item.status == status
                            TextButton(onClick = {
                                edited = edited.copy(
                                    followUpQuestions = edited.followUpQuestions.toMutableList().also {
                                        it[index] = item.copy(status = status)
                                    },
                                )
                            }) {
                                Text(
                                    stringResource(
                                        when (status) {
                                            FollowUpStatus.Discussed -> R.string.discussed_action
                                            FollowUpStatus.FollowUp -> R.string.follow_up_action
                                            FollowUpStatus.NotRelevant -> R.string.not_relevant_action
                                        },
                                    ),
                                    color = if (selected) colors.gold else colors.textBody,
                                    fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
                                )
                            }
                        }
                    }
                }
            }
            if (edited.assignmentsForNextWeek.isNotEmpty()) {
                Text(stringResource(R.string.assignments_for_next_week_section), color = colors.textBright, fontWeight = FontWeight.Bold)
                edited.assignmentsForNextWeek.forEach { item ->
                    Text(item.assignment, color = colors.textBright, fontWeight = FontWeight.SemiBold)
                    item.details?.takeIf { it.isNotBlank() }?.let { Text(it, color = colors.textBody) }
                }
            }
            errorMessage?.let { Text(it, color = colors.error) }
        }
    }
}

@Composable
internal fun CycleLines(cycle: CBTCycle) {
    val colors = Theme.colors
    val stages = listOfNotNull(
        cycle.triggerSituation,
        cycle.automaticThought,
        cycle.emotion,
        cycle.behavior,
        cycle.shortTermConsequence,
        cycle.longTermConsequence,
    ).filter { it.isNotBlank() }
    Text(stages.joinToString(" → "), color = colors.textBright)
    if (cycle.evidence.isNotBlank()) Text(cycle.evidence, color = colors.textBody)
}
