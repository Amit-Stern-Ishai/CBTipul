package com.cbtipul.app.ui.patients

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
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
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.model.AssignmentForNextWeek
import com.cbtipul.app.model.CBTCycle
import com.cbtipul.app.model.CBTSessionAnalysis
import com.cbtipul.app.model.CognitivePattern
import com.cbtipul.app.model.KeySituation
import com.cbtipul.app.model.PossibleNAT
import com.cbtipul.app.model.TherapistHypothesis
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.themedScreen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SessionAnalysisScreen(
    analysis: CBTSessionAnalysis?,
    atmosphere: Color?,
    persisted: Boolean,
    isSaving: Boolean,
    errorMessage: String?,
    onBack: () -> Unit,
    onSave: (CBTSessionAnalysis) -> Unit,
    onDiscard: () -> Unit,
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
    var showLeave by remember { mutableStateOf(false) }
    val needsDecision = !persisted || edited != analysis

    fun requestBack() {
        if (isSaving) return
        if (needsDecision) showLeave = true else onBack()
    }

    BackHandler(enabled = !isSaving) { requestBack() }

    Scaffold(
        modifier = Modifier.themedScreen(atmosphere),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.session_summary_title), color = colors.textBright) },
                navigationIcon = {
                    IconButton(onClick = { requestBack() }, enabled = !isSaving) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = stringResource(R.string.back), tint = colors.gold)
                    }
                },
                actions = {
                    if (needsDecision) {
                        TextButton(onClick = { onSave(edited) }, enabled = !isSaving) {
                            Text(stringResource(R.string.save), color = colors.gold)
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(28.dp),
        ) {
            AnalysisField(
                value = edited.sessionSummary,
                onValueChange = { edited = edited.copy(sessionSummary = it) },
                placeholder = stringResource(R.string.session_summary_placeholder),
                style = TextStyle(color = colors.textBright, fontSize = 16.sp, lineHeight = 22.sp),
                minLines = 3,
            )

            AnalysisSection(stringResource(R.string.key_situations_section), edited.keySituations.isNotEmpty()) {
                edited.keySituations.forEachIndexed { index, item ->
                    KeySituationCard(
                        item = item,
                        accent = atmosphere,
                        onChange = { updated ->
                            edited = edited.copy(
                                keySituations = edited.keySituations.toMutableList().also { it[index] = updated },
                            )
                        },
                    )
                }
            }

            AnalysisSection(stringResource(R.string.possible_automatic_thoughts_section), edited.possibleNats.isNotEmpty()) {
                edited.possibleNats.forEachIndexed { index, item ->
                    NatAnalysisCard(
                        item = item,
                        original = analysis.possibleNats.getOrNull(index),
                        accent = atmosphere,
                        onChange = { updated ->
                            edited = edited.copy(
                                possibleNats = edited.possibleNats.toMutableList().also { it[index] = updated },
                            )
                        },
                    )
                }
            }

            AnalysisSection(stringResource(R.string.cbt_cycle_section), edited.cbtCycles.isNotEmpty()) {
                edited.cbtCycles.forEach { cycle ->
                    ClinicalCard(accent = atmosphere) { CycleLines(cycle) }
                }
            }

            AnalysisSection(stringResource(R.string.therapist_hypotheses_section), edited.therapistHypotheses.isNotEmpty()) {
                edited.therapistHypotheses.forEach { item ->
                    HypothesisCard(item, atmosphere)
                }
            }

            AnalysisSection(stringResource(R.string.questions_to_revisit_section), edited.followUpQuestions.isNotEmpty()) {
                edited.followUpQuestions.forEachIndexed { index, item ->
                    FollowUpCard(
                        index = index,
                        question = item.question,
                        reason = item.reason,
                        accent = atmosphere,
                        onQuestionChange = { value ->
                            edited = edited.copy(
                                followUpQuestions = edited.followUpQuestions.toMutableList().also {
                                    it[index] = item.copy(question = value)
                                },
                            )
                        },
                        onReasonChange = { value ->
                            edited = edited.copy(
                                followUpQuestions = edited.followUpQuestions.toMutableList().also {
                                    it[index] = item.copy(reason = value)
                                },
                            )
                        },
                    )
                }
            }

            AnalysisSection(stringResource(R.string.assignments_for_next_week_section), edited.assignmentsForNextWeek.isNotEmpty()) {
                edited.assignmentsForNextWeek.forEach { item ->
                    AssignmentCard(item, atmosphere)
                }
            }

            errorMessage?.let { Text(it, color = colors.error, fontSize = 13.sp) }
        }
    }

    AnalysisLeaveDialog(
        visible = showLeave,
        onSave = {
            showLeave = false
            onSave(edited)
        },
        onDiscard = {
            showLeave = false
            onDiscard()
        },
        onKeepViewing = { showLeave = false },
    )
}

@Composable
private fun AnalysisSection(
    title: String,
    visible: Boolean,
    content: @Composable ColumnScope.() -> Unit,
) {
    if (!visible) return
    val colors = Theme.colors
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(title, color = colors.textBright, fontWeight = FontWeight.Bold, fontSize = 20.sp)
        content()
    }
}

@Composable
private fun AnalysisField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    style: TextStyle,
    modifier: Modifier = Modifier,
    minLines: Int = 1,
) {
    val colors = Theme.colors
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier.fillMaxWidth(),
        textStyle = style,
        cursorBrush = SolidColor(colors.gold),
        minLines = minLines,
        decorationBox = { inner ->
            if (value.isEmpty()) {
                Text(placeholder, color = colors.textBody, style = style)
            }
            inner()
        },
    )
}

@Composable
private fun LabeledAnalysisField(
    title: String,
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    style: TextStyle? = null,
) {
    val colors = Theme.colors
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(title, color = colors.textBody, fontSize = 12.sp)
        AnalysisField(
            value = value,
            onValueChange = onValueChange,
            placeholder = title,
            style = style ?: TextStyle(color = colors.textBright, fontSize = 14.sp),
        )
    }
}

@Composable
private fun KeySituationCard(
    item: KeySituation,
    accent: Color?,
    onChange: (KeySituation) -> Unit,
) {
    val colors = Theme.colors
    ClinicalCard(accent = accent) {
        AnalysisField(
            value = item.situation,
            onValueChange = { onChange(item.copy(situation = it)) },
            placeholder = stringResource(R.string.situation_label),
            style = TextStyle(color = colors.textBright, fontSize = 17.sp, fontWeight = FontWeight.SemiBold),
        )
        AnalysisField(
            value = item.whyItMatters,
            onValueChange = { onChange(item.copy(whyItMatters = it)) },
            placeholder = stringResource(R.string.why_it_matters_label),
            style = TextStyle(color = colors.textBody, fontSize = 14.sp),
        )
    }
}

@Composable
private fun NatAnalysisCard(
    item: PossibleNAT,
    original: PossibleNAT?,
    accent: Color?,
    onChange: (PossibleNAT) -> Unit,
) {
    val colors = Theme.colors
    val high = stringResource(R.string.confidence_high)
    val medium = stringResource(R.string.confidence_medium)
    val low = stringResource(R.string.confidence_low)
    val showEmotion = !original?.emotion.isNullOrBlank()
    val showBehavior = !original?.behavior.isNullOrBlank()
    ClinicalCard(accent = accent) {
        if (item.source.isNotBlank()) SourceBadge(item.source)
        AnalysisField(
            value = item.thought,
            onValueChange = { onChange(item.copy(thought = it)) },
            placeholder = stringResource(R.string.thought_label),
            style = TextStyle(
                color = colors.textBright,
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                fontStyle = FontStyle.Italic,
            ),
        )
        HorizontalDivider(color = colors.borderFaint)
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            LabeledAnalysisField(
                title = stringResource(R.string.situation_label),
                value = item.situation,
                onValueChange = { onChange(item.copy(situation = it)) },
                modifier = Modifier.weight(1f),
            )
            if (showEmotion) {
                LabeledAnalysisField(
                    title = stringResource(R.string.emotion_label),
                    value = item.emotion.orEmpty(),
                    onValueChange = { onChange(item.copy(emotion = it.ifBlank { null })) },
                    modifier = Modifier.weight(1f),
                )
            }
        }
        if (showBehavior) {
            LabeledAnalysisField(
                title = stringResource(R.string.behavior_label),
                value = item.behavior.orEmpty(),
                onValueChange = { onChange(item.copy(behavior = it.ifBlank { null })) },
            )
        }
        if (item.cognitivePatterns.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    stringResource(R.string.possible_cognitive_patterns_label),
                    color = colors.textBody,
                    fontSize = 12.sp,
                )
                sortedByConfidence(item.cognitivePatterns).forEach { pattern ->
                    CognitivePatternRow(pattern, high, medium, low)
                }
            }
        }
    }
}

@Composable
private fun CognitivePatternRow(
    pattern: CognitivePattern,
    high: String,
    medium: String,
    low: String,
) {
    val colors = Theme.colors
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

@Composable
private fun HypothesisCard(item: TherapistHypothesis, accent: Color?) {
    val colors = Theme.colors
    ClinicalCard(accent = accent) {
        Row(verticalAlignment = Alignment.Top) {
            Text(
                item.hypothesis,
                color = colors.textBright,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.weight(1f),
            )
            HypothesisBadge(R.string.possible_inference_badge)
        }
        if (item.evidence.isNotBlank()) {
            Text(item.evidence, color = colors.textBody, fontSize = 14.sp)
        }
    }
}

@Composable
private fun FollowUpCard(
    index: Int,
    question: String,
    reason: String,
    accent: Color?,
    onQuestionChange: (String) -> Unit,
    onReasonChange: (String) -> Unit,
) {
    val colors = Theme.colors
    ClinicalCard(accent = accent) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.Top,
        ) {
            Text(
                "${index + 1}.",
                color = colors.textBody,
                fontWeight = FontWeight.SemiBold,
                fontSize = 17.sp,
            )
            AnalysisField(
                value = question,
                onValueChange = onQuestionChange,
                placeholder = stringResource(R.string.question_placeholder),
                style = TextStyle(color = colors.textBright, fontSize = 17.sp, fontWeight = FontWeight.SemiBold),
                modifier = Modifier.weight(1f),
            )
        }
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                stringResource(R.string.why_it_matters_label),
                color = colors.textBody,
                fontWeight = FontWeight.SemiBold,
                fontSize = 12.sp,
            )
            AnalysisField(
                value = reason,
                onValueChange = onReasonChange,
                placeholder = stringResource(R.string.reason_placeholder),
                style = TextStyle(color = colors.textBody, fontSize = 14.sp),
            )
        }
    }
}

@Composable
private fun AssignmentCard(item: AssignmentForNextWeek, accent: Color?) {
    val colors = Theme.colors
    ClinicalCard(accent = accent) {
        Text(item.assignment, color = colors.textBright, fontWeight = FontWeight.SemiBold)
        item.details?.takeIf { it.isNotBlank() }?.let {
            Text(it, color = colors.textBody, fontSize = 14.sp)
        }
    }
}

private fun sortedByConfidence(patterns: List<CognitivePattern>): List<CognitivePattern> {
    fun rank(raw: String): Int {
        val lowered = raw.lowercase()
        return when {
            lowered.contains("high") || lowered.contains("גבוה") -> 0
            lowered.contains("med") || lowered.contains("בינוני") -> 1
            lowered.contains("low") || lowered.contains("נמוך") -> 2
            else -> 3
        }
    }
    return patterns.withIndex()
        .sortedWith(compareBy({ rank(it.value.confidence) }, { it.index }))
        .map { it.value }
}

@Composable
internal fun CycleLines(cycle: CBTCycle, elevatedStages: Boolean = false) {
    val colors = Theme.colors
    val stages = listOfNotNull(
        cycle.triggerSituation?.takeIf { it.isNotBlank() }?.let {
            stringResource(R.string.situation_label) to it
        },
        cycle.automaticThought?.takeIf { it.isNotBlank() }?.let {
            stringResource(
                if (elevatedStages) R.string.automatic_thought_label else R.string.thought_label,
            ) to it
        },
        cycle.emotion?.takeIf { it.isNotBlank() }?.let {
            stringResource(R.string.emotion_label) to it
        },
        cycle.behavior?.takeIf { it.isNotBlank() }?.let {
            stringResource(R.string.behavior_label) to it
        },
        cycle.shortTermConsequence?.takeIf { it.isNotBlank() }?.let {
            stringResource(R.string.short_term_consequence_label) to it
        },
        cycle.longTermConsequence?.takeIf { it.isNotBlank() }?.let {
            stringResource(R.string.long_term_consequence_label) to it
        },
    )
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        stages.forEachIndexed { index, (title, text) ->
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .then(
                        if (elevatedStages) {
                            Modifier
                                .background(colors.elevated, RoundedCornerShape(8.dp))
                                .padding(10.dp)
                        } else {
                            Modifier
                        },
                    ),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(
                    title,
                    color = colors.textBody,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 12.sp,
                )
                Text(text, color = colors.textBright, fontSize = 14.sp)
            }
            if (index < stages.lastIndex) {
                Icon(
                    Icons.Filled.ArrowDownward,
                    contentDescription = null,
                    tint = colors.textBody,
                    modifier = Modifier
                        .padding(
                            start = if (elevatedStages) 16.dp else 0.dp,
                            top = if (elevatedStages) 0.dp else 2.dp,
                            bottom = if (elevatedStages) 0.dp else 2.dp,
                        )
                        .size(if (elevatedStages) 16.dp else 14.dp),
                )
            }
        }
        if (elevatedStages) {
            EvidenceDisclosure(cycle.evidence)
        } else if (cycle.evidence.isNotBlank()) {
            Text(
                "${stringResource(R.string.evidence_label)}: ${cycle.evidence}",
                color = colors.textBody,
                fontSize = 12.sp,
                modifier = Modifier.padding(top = 6.dp),
            )
        }
    }
}
