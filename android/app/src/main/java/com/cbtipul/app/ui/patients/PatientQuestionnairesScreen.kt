package com.cbtipul.app.ui.patients

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.stringArrayResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.cbtipul.app.R
import com.cbtipul.app.model.CompletedQuestionnaire
import com.cbtipul.app.model.GAD7Severity
import com.cbtipul.app.model.PHQ9Severity
import com.cbtipul.app.ui.theme.GroupRowPosition
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.groupBordered
import com.cbtipul.app.ui.theme.hebrewDate
import com.cbtipul.app.ui.theme.themedScreen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PatientQuestionnairesScreen(
    records: List<CompletedQuestionnaire>,
    atmosphere: Color?,
    isLoading: Boolean,
    loadError: String?,
    onRetry: () -> Unit,
    onBack: () -> Unit,
    onOpen: (CompletedQuestionnaire) -> Unit,
) {
    val colors = Theme.colors
    var graphsMode by remember { mutableStateOf(false) }
    val newestFirst = remember(records) { records.sortedByDescending { it.answeredDate.time } }
    val oldestFirst = remember(records) { records.sortedBy { it.answeredDate.time } }

    Scaffold(
        modifier = Modifier.themedScreen(atmosphere),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.questionnaires_title), color = colors.textBright) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = stringResource(R.string.back), tint = colors.gold)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
    ) { padding ->
        when {
            isLoading && newestFirst.isEmpty() -> {
                Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = colors.gold)
                }
            }
            loadError != null && newestFirst.isEmpty() -> {
                Column(
                    modifier = Modifier.fillMaxSize().padding(padding).padding(24.dp),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(stringResource(R.string.load_error_title), color = colors.textBright, fontWeight = FontWeight.Bold)
                    Text(loadError, color = colors.textBody, modifier = Modifier.padding(top = 8.dp))
                    Button(
                        onClick = onRetry,
                        modifier = Modifier.padding(top = 16.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = colors.gold, contentColor = colors.textOnAccent),
                    ) { Text(stringResource(R.string.retry)) }
                }
            }
            newestFirst.isEmpty() -> {
            Text(
                stringResource(R.string.no_questionnaires_message),
                color = colors.textBody,
                modifier = Modifier.padding(padding).padding(24.dp),
            )
            }
            else -> {
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            item {
                SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                    listOf(false, true).forEachIndexed { index, graphs ->
                        SegmentedButton(
                            selected = graphsMode == graphs,
                            onClick = { graphsMode = graphs },
                            shape = SegmentedButtonDefaults.itemShape(index, 2),
                            colors = SegmentedButtonDefaults.colors(
                                activeContainerColor = colors.gold,
                                activeContentColor = colors.textOnAccent,
                                inactiveContainerColor = colors.surface,
                                inactiveContentColor = colors.textBright,
                            ),
                            label = {
                                Text(stringResource(if (graphs) R.string.graphs_mode_title else R.string.list_mode_title))
                            },
                        )
                    }
                }
            }
            if (graphsMode) {
            item {
                val theme = Theme.colors
                QuestionnaireScoreChart(
                    name = stringResource(R.string.gad7_short_name),
                    subtitle = stringResource(R.string.gad7_title),
                    entries = oldestFirst.map { it.questionnaire.gad7Answers },
                    shortNames = stringArrayResource(R.array.gad7_question_short_names),
                    tint = theme.gold,
                    totalColor = { score ->
                        when (GAD7Severity.from(score)) {
                            GAD7Severity.Minimal -> theme.success
                            GAD7Severity.Mild -> theme.warning
                            GAD7Severity.Substantial, GAD7Severity.Extreme -> theme.error
                        }
                    },
                )
            }
            item {
                val theme = Theme.colors
                QuestionnaireScoreChart(
                    name = stringResource(R.string.phq9_short_name),
                    subtitle = stringResource(R.string.phq9_title),
                    entries = oldestFirst.map { it.questionnaire.phq9Answers },
                    shortNames = stringArrayResource(R.array.phq9_question_short_names),
                    tint = theme.goldVivid,
                    totalColor = { score ->
                        when (PHQ9Severity.from(score)) {
                            PHQ9Severity.Minimal -> theme.success
                            PHQ9Severity.Mild, PHQ9Severity.Moderate -> theme.warning
                            PHQ9Severity.ModeratelySevere, PHQ9Severity.Severe -> theme.error
                        }
                    },
                )
            }
            } else {
            itemsIndexed(newestFirst, key = { _, item -> item.databaseId.queryValue }) { index, record ->
                val previous = newestFirst.getOrNull(index + 1)?.questionnaire
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .groupBordered(GroupRowPosition.at(index, newestFirst.size), atmosphere ?: colors.gold)
                        .clickable { onOpen(record) }
                        .padding(horizontal = 14.dp, vertical = 12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(hebrewDate(record.answeredDate), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        GAD7ScoreCapsule(record.questionnaire, previous)
                        PHQ9ScoreCapsule(record.questionnaire, previous)
                    }
                }
            }
            }
        }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun QuestionnaireScoreChart(
    name: String,
    subtitle: String,
    entries: List<List<Int?>>,
    shortNames: Array<String>,
    tint: Color,
    totalColor: (Int) -> Color,
) {
    val colors = Theme.colors
    val answerColors = listOf(colors.success, colors.warning, colors.warning, colors.error)
    var metric by remember { mutableIntStateOf(-1) }
    var expanded by remember { mutableStateOf(false) }
    val totalLabel = stringResource(R.string.total_option_label)
    val selectedLabel = if (metric < 0) totalLabel else shortNames.getOrElse(metric) { totalLabel }
    val points = remember(entries, metric) {
        entries.mapNotNull { answers ->
            if (metric < 0) {
                val answered = answers.filterNotNull()
                if (answered.isEmpty()) null else answered.sum()
            } else {
                answers.getOrNull(metric)
            }
        }
    }
    val maxScore = if (metric < 0) (3 * shortNames.size).toFloat() else 3f
    val pointColors = points.map { value ->
        if (metric < 0) totalColor(value) else answerColors[value.coerceIn(0, answerColors.lastIndex)]
    }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(name, color = colors.textBright, fontWeight = FontWeight.SemiBold)
                    if (metric < 0 && points.isNotEmpty()) {
                        val latest = points.last()
                        ScoreCapsule(
                            text = latest.toString(),
                            color = totalColor(latest),
                            delta = if (points.size >= 2) latest - points[points.size - 2] else null,
                        )
                    }
                }
                Text(subtitle, color = colors.textBody)
            }
            ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
                OutlinedTextField(
                    value = selectedLabel,
                    onValueChange = {},
                    readOnly = true,
                    label = { Text(stringResource(R.string.metric_picker_title)) },
                    modifier = Modifier.menuAnchor(),
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                )
                ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                    DropdownMenuItem(
                        text = { Text(totalLabel) },
                        onClick = {
                            metric = -1
                            expanded = false
                        },
                    )
                    shortNames.forEachIndexed { index, label ->
                        DropdownMenuItem(
                            text = { Text(label) },
                            onClick = {
                                metric = index
                                expanded = false
                            },
                        )
                    }
                }
            }
        }
        Canvas(modifier = Modifier.fillMaxWidth().height(140.dp)) {
            if (points.isEmpty()) return@Canvas
            val maxY = maxScore.coerceAtLeast(1f)
            val path = Path()
            val fill = Path()
            points.forEachIndexed { index, value ->
                val x = if (points.size == 1) size.width / 2 else size.width * index / (points.size - 1)
                val y = size.height * (1f - (value / maxY).coerceIn(0f, 1f))
                if (index == 0) {
                    path.moveTo(x, y)
                    fill.moveTo(x, size.height)
                    fill.lineTo(x, y)
                } else {
                    path.lineTo(x, y)
                    fill.lineTo(x, y)
                }
                drawCircle(color = pointColors[index], radius = 6f, center = Offset(x, y))
            }
            val lastX = if (points.size == 1) size.width / 2 else size.width
            fill.lineTo(lastX, size.height)
            fill.close()
            drawPath(
                fill,
                Brush.verticalGradient(
                    colors = listOf(tint.copy(alpha = 0.25f), tint.copy(alpha = 0.02f)),
                ),
            )
            drawPath(path, color = tint, style = Stroke(width = 4f))
        }
    }
}
