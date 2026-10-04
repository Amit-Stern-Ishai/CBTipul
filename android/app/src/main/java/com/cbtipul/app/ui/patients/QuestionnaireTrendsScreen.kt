package com.cbtipul.app.ui.patients

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.KeyboardArrowDown
import androidx.compose.material.icons.outlined.TrendingDown
import androidx.compose.material.icons.outlined.TrendingUp
import androidx.compose.material.icons.outlined.DragHandle
import androidx.compose.material.icons.outlined.SwapVert
import androidx.compose.material.icons.outlined.HelpOutline
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringArrayResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.model.CompletedQuestionnaire
import com.cbtipul.app.model.QuestionnaireTrend
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.hebrewDate
import com.cbtipul.app.ui.theme.themedScreen
import java.util.Date

private data class TrendQuestion(val id: String, val title: String, val scale: String, val number: Int, val observations: List<Pair<Date, Int?>>) {
    val trend = QuestionnaireTrend.classify(observations.map { it.second })
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuestionnaireTrendsScreen(records: List<CompletedQuestionnaire>, patientName: String, onOpenPatient: () -> Unit, onBack: () -> Unit) {
    val colors = Theme.colors
    val chronological = remember(records) { records.sortedBy { it.answeredDate.time } }
    val gadNames = stringArrayResource(R.array.gad7_questions)
    val phqNames = stringArrayResource(R.array.phq9_questions)
    val gadLabel = stringResource(R.string.gad7_short_name)
    val phqLabel = stringResource(R.string.phq9_short_name)
    val questions = remember(chronological, gadNames.toList(), phqNames.toList(), gadLabel, phqLabel) {
        fun make(names: Array<String>, scale: String, answers: (CompletedQuestionnaire) -> List<Int?>) =
            names.mapIndexed { index, name ->
                TrendQuestion("$scale-$index", name, scale, index + 1, chronological.map {
                    it.answeredDate to answers(it).getOrNull(index)?.takeIf { value -> value in 0..3 }
                })
            }
        make(gadNames, gadLabel) { it.questionnaire.gad7Answers } + make(phqNames, phqLabel) { it.questionnaire.phq9Answers }
    }
    var selectedTrend by rememberSaveable { mutableStateOf(QuestionnaireTrend.Improving) }
    var selectedQuestionID by rememberSaveable { mutableStateOf<String?>(null) }
    var showingTrends by remember { mutableStateOf(false) }
    var showingQuestions by remember { mutableStateOf(false) }
    val matches = questions.filter { it.trend == selectedTrend }
    val selectedQuestion = matches.firstOrNull { it.id == selectedQuestionID } ?: matches.firstOrNull()
    Scaffold(modifier = Modifier.themedScreen(colors.gold), containerColor = Color.Transparent,
        topBar = {
            TopAppBar(title = {
                PatientContextTitle(stringResource(R.string.question_trends_title), patientName, onOpenPatient)
            }, navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = stringResource(R.string.back), tint = colors.gold)
                }
            }, colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent))
        }) { padding ->
        LazyColumn(Modifier.fillMaxSize().padding(padding), contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item {
                Text(stringResource(R.string.question_trends_help), color = colors.textBody)
                if (chronological.isNotEmpty()) Text(
                    stringResource(R.string.question_trends_count, records.size) + " · " + hebrewDate(chronological.first().answeredDate)
                        + " – " + hebrewDate(chronological.last().answeredDate),
                    color = colors.textBody, fontSize = 12.sp, modifier = Modifier.padding(top = 8.dp))
            }
            item {
                TrendPicker(label = stringResource(R.string.question_trends_trend_picker), onClick = { showingTrends = true }) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Icon(selectedTrend.icon, contentDescription = null, tint = colors.gold)
                        Text(stringResource(selectedTrend.titleRes), color = colors.textBright, modifier = Modifier.weight(1f))
                        QuestionCount(matches.size)
                    }
                }
            }
            item { Text(stringResource(selectedTrend.helpRes), color = colors.textBody, fontSize = 13.sp) }
            item {
                TrendPicker(label = stringResource(R.string.question_trends_question_picker),
                    onClick = { showingQuestions = true }, enabled = matches.isNotEmpty()) {
                    selectedQuestion?.let { QuestionLabel(it) }
                        ?: Text(stringResource(R.string.question_trends_no_questions), color = colors.textBody)
                }
            }
            selectedQuestion?.let { question ->
                item {
                    QuestionnaireScoreChart(
                        name = stringResource(R.string.question_trends_graph_title),
                        subtitle = question.title,
                        entries = question.observations.map { it.first to listOf(it.second) },
                        shortNames = arrayOf(question.title),
                        tint = colors.gold,
                        totalColor = { colors.gold },
                        chartHeight = 220f,
                        fixedQuestionIndex = 0,
                    )
                }
                item { Text(stringResource(R.string.questionnaire_graph_help), color = colors.textBody, fontSize = 12.sp) }
            }
            item { Text(stringResource(R.string.question_trends_missing), color = colors.textBody, fontSize = 13.sp) }
        }
    }
    if (showingTrends || showingQuestions) {
        ModalBottomSheet(
            onDismissRequest = { showingTrends = false; showingQuestions = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            containerColor = colors.base,
        ) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(if (showingTrends) R.string.question_trends_trend_picker else R.string.question_trends_question_picker),
                    color = colors.textBright, fontSize = 20.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                TextButton(onClick = { showingTrends = false; showingQuestions = false }) { Text(stringResource(R.string.close_action)) }
            }
            LazyColumn(Modifier.fillMaxWidth().heightIn(max = 560.dp), contentPadding = PaddingValues(start = 20.dp, end = 20.dp, bottom = 24.dp)) {
                if (showingTrends) {
                    items(QuestionnaireTrend.entries, key = { it.name }) { trend ->
                        val selected = trend == selectedTrend
                        Row(Modifier.fillMaxWidth().selectable(selected, role = Role.RadioButton, onClick = {
                            selectedTrend = trend; selectedQuestionID = null; showingTrends = false
                        }).padding(vertical = 16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            Icon(trend.icon, contentDescription = null, tint = colors.gold)
                            Text(stringResource(trend.titleRes), color = colors.textBright, modifier = Modifier.weight(1f))
                            QuestionCount(questions.count { it.trend == trend })
                            RadioButton(selected = selected, onClick = null)
                        }
                        HorizontalDivider(color = colors.textFaint.copy(alpha = 0.15f))
                    }
                } else {
                    items(matches, key = { it.id }) { question ->
                        val selected = question.id == selectedQuestion?.id
                        Row(Modifier.fillMaxWidth().selectable(selected, role = Role.RadioButton, onClick = {
                            selectedQuestionID = question.id; showingQuestions = false
                        }).padding(vertical = 16.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                            QuestionLabel(question, Modifier.weight(1f))
                            RadioButton(selected = selected, onClick = null)
                        }
                        HorizontalDivider(color = colors.textFaint.copy(alpha = 0.15f))
                    }
                }
            }
        }
    }

}

@Composable
private fun QuestionCount(count: Int) {
    val colors = Theme.colors
    val description = stringResource(R.string.question_trends_matching_count, count)
    Surface(color = colors.gold.copy(alpha = 0.12f), shape = RoundedCornerShape(50),
        modifier = Modifier.semantics { contentDescription = description }) {
        run {
            Text(description, color = colors.gold, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 5.dp))
        }
    }
}

@Composable
private fun QuestionLabel(question: TrendQuestion, modifier: Modifier = Modifier) {
    val colors = Theme.colors
    Column(modifier, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(question.title, color = colors.textBright, fontWeight = FontWeight.Medium, modifier = Modifier.fillMaxWidth())
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(stringResource(R.string.question_trends_question_picker), color = colors.textBody, fontSize = 12.sp)
            Text(question.number.toString(), color = colors.textBody, fontSize = 12.sp)
            Spacer(Modifier.weight(1f))
            Surface(color = colors.gold.copy(alpha = 0.08f), shape = RoundedCornerShape(50)) {
                CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
                    Text(question.scale, color = colors.textBody, fontSize = 12.sp, fontFamily = FontFamily.Monospace,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp))
                }
            }
        }
    }
}

@Composable
private fun TrendPicker(
    label: String,
    onClick: () -> Unit,
    enabled: Boolean = true,
    content: @Composable () -> Unit,
) {
    val colors = Theme.colors
    OutlinedCard(onClick = onClick, enabled = enabled, modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(label, color = colors.textBody, fontSize = 12.sp)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                Box(Modifier.weight(1f)) { content() }
                Icon(Icons.Outlined.KeyboardArrowDown, contentDescription = null, tint = colors.gold)
            }
        }
    }
}

private val QuestionnaireTrend.icon: ImageVector get() = when (this) {
    QuestionnaireTrend.Improving -> Icons.Outlined.TrendingDown
    QuestionnaireTrend.Worsening -> Icons.Outlined.TrendingUp
    QuestionnaireTrend.Unchanged -> Icons.Outlined.DragHandle
    QuestionnaireTrend.BetterThanBeginning -> Icons.Outlined.TrendingDown
    QuestionnaireTrend.WorseThanBeginning -> Icons.Outlined.TrendingUp
    QuestionnaireTrend.Insufficient -> Icons.Outlined.HelpOutline
}

private val QuestionnaireTrend.titleRes: Int get() = when (this) {
    QuestionnaireTrend.Improving -> R.string.question_trend_improving
    QuestionnaireTrend.Worsening -> R.string.question_trend_worsening
    QuestionnaireTrend.Unchanged -> R.string.question_trend_unchanged
    QuestionnaireTrend.BetterThanBeginning -> R.string.question_trend_better
    QuestionnaireTrend.WorseThanBeginning -> R.string.question_trend_worse
    QuestionnaireTrend.Insufficient -> R.string.question_trend_insufficient
}
private val QuestionnaireTrend.helpRes: Int get() = when (this) {
    QuestionnaireTrend.Improving -> R.string.question_trend_improving_help
    QuestionnaireTrend.Worsening -> R.string.question_trend_worsening_help
    QuestionnaireTrend.Unchanged -> R.string.question_trend_unchanged_help
    QuestionnaireTrend.BetterThanBeginning -> R.string.question_trend_better_help
    QuestionnaireTrend.WorseThanBeginning -> R.string.question_trend_worse_help
    QuestionnaireTrend.Insufficient -> R.string.question_trend_insufficient_help
}
