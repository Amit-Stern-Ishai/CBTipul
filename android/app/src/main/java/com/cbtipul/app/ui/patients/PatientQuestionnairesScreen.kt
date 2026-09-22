package com.cbtipul.app.ui.patients

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.ShowChart
import androidx.compose.material.icons.outlined.KeyboardArrowDown
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
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
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringArrayResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.model.CompletedQuestionnaire
import com.cbtipul.app.model.GAD7Severity
import com.cbtipul.app.model.PHQ9Severity
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.GroupedListDivider
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.groupedListCard
import com.cbtipul.app.ui.theme.hebrewDate
import com.cbtipul.app.ui.theme.hebrewShortDate
import com.cbtipul.app.ui.theme.themedScreen
import java.util.Date

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PatientQuestionnairesScreen(
    records: List<CompletedQuestionnaire>,
    patientName: String = "",
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
                title = {
                    Column {
                        Text(stringResource(R.string.questionnaires_title), color = colors.textBright)
                        if (patientName.isNotBlank()) {
                            Text(patientName, color = colors.textBody, fontSize = 13.sp)
                        }
                    }
                },
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
                    ) { Text(stringResource(R.string.retry_action)) }
                }
            }
            newestFirst.isEmpty() -> {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding)
                        .padding(horizontal = 32.dp),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        stringResource(R.string.empty_questionnaires_title),
                        color = colors.textBright,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 20.sp,
                        textAlign = TextAlign.Center,
                    )
                    Text(
                        stringResource(R.string.empty_questionnaires_body),
                        color = colors.textBody,
                        modifier = Modifier.padding(top = 12.dp),
                        textAlign = TextAlign.Center,
                    )
                }
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
                    entries = oldestFirst.map { it.answeredDate to it.questionnaire.gad7Answers },
                    shortNames = stringArrayResource(R.array.gad7_question_short_names),
                    tint = theme.accentFill,
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
                    entries = oldestFirst.map { it.answeredDate to it.questionnaire.phq9Answers },
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
            item {
                GroupedListCard(accent = atmosphere ?: colors.gold) {
                    newestFirst.forEachIndexed { index, record ->
                        val previous = newestFirst.getOrNull(index + 1)?.questionnaire
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { onOpen(record) }
                                .padding(horizontal = 16.dp, vertical = 12.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Text(hebrewDate(record.answeredDate), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                GAD7ScoreCapsule(record.questionnaire, previous)
                                PHQ9ScoreCapsule(record.questionnaire, previous)
                            }
                        }
                        if (index < newestFirst.lastIndex) {
                            GroupedListDivider()
                        }
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
    entries: List<Pair<Date, List<Int?>>>,
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
        entries.mapNotNull { (date, answers) ->
            val value = if (metric < 0) {
                val answered = answers.filterNotNull()
                if (answered.isEmpty()) null else answered.sum()
            } else {
                answers.getOrNull(metric)
            }
            value?.let { date to it }
        }
    }
    val maxScore = if (metric < 0) 3 * shortNames.size else 3
    val yTicks = remember(maxScore) { yAxisTicks(maxScore) }
    val xTickIndexes = remember(points.size) { xAxisIndexes(points.size) }
    val textMeasurer = rememberTextMeasurer()
    val axisStyle = TextStyle(color = colors.textBody, fontSize = 10.sp)
    val pointColors = points.map { (_, value) ->
        if (metric < 0) totalColor(value) else answerColors[value.coerceIn(0, answerColors.lastIndex)]
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .groupedListCard(tint)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(28.dp)
                    .background(tint, RoundedCornerShape(7.dp)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.AutoMirrored.Outlined.ShowChart,
                    contentDescription = null,
                    tint = colors.textOnAccent,
                    modifier = Modifier.size(16.dp),
                )
            }
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        name,
                        color = colors.textBright,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 17.sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    if (metric < 0 && points.isNotEmpty()) {
                        val latest = points.last().second
                        ScoreCapsule(
                            text = latest.toString(),
                            color = totalColor(latest),
                            delta = if (points.size >= 2) latest - points[points.size - 2].second else null,
                        )
                    }
                }
                Text(
                    subtitle,
                    color = colors.textBody,
                    fontSize = 12.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        Box(modifier = Modifier.fillMaxWidth().wrapContentWidth(Alignment.Start)) {
            TextButton(
                onClick = { expanded = true },
                contentPadding = PaddingValues(horizontal = 4.dp, vertical = 0.dp),
            ) {
                Text(
                    stringResource(R.string.metric_picker_title),
                    color = colors.textBody,
                    fontSize = 12.sp,
                )
                Text(
                    selectedLabel,
                    color = tint,
                    fontWeight = FontWeight.Medium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier
                        .padding(start = 6.dp)
                        .widthIn(max = 180.dp),
                )
                Icon(
                    Icons.Outlined.KeyboardArrowDown,
                    contentDescription = null,
                    tint = tint,
                    modifier = Modifier.size(18.dp),
                )
            }
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
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
        CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
            Canvas(modifier = Modifier.fillMaxWidth().height(220.dp)) {
                val labelPad = 8.dp.toPx()
                val yLabelWidth = 36.dp.toPx()
                val xLabelHeight = 28.dp.toPx()
                val plotLeft = yLabelWidth
                val plotRight = size.width
                val plotTop = 8.dp.toPx()
                val plotBottom = size.height - xLabelHeight
                val plotWidth = (plotRight - plotLeft).coerceAtLeast(1f)
                val plotHeight = (plotBottom - plotTop).coerceAtLeast(1f)
                val maxY = maxScore.toFloat().coerceAtLeast(1f)

                fun xFor(index: Int): Float {
                    if (points.size <= 1) return plotLeft + plotWidth / 2
                    return plotLeft + plotWidth * index / (points.size - 1)
                }

                fun yFor(value: Int): Float = plotTop + plotHeight * (1f - (value / maxY).coerceIn(0f, 1f))

                yTicks.forEach { tick ->
                    val y = yFor(tick)
                    drawLine(color = colors.borderFaint, start = Offset(plotLeft, y), end = Offset(plotRight, y), strokeWidth = 1.dp.toPx())
                    val label = textMeasurer.measure(tick.toString(), axisStyle)
                    drawText(
                        label,
                        topLeft = Offset(
                            (plotLeft - labelPad - label.size.width).coerceAtLeast(0f),
                            y - label.size.height / 2f,
                        ),
                    )
                }

                if (points.isNotEmpty()) {
                    val path = Path()
                    val fill = Path()
                    points.forEachIndexed { index, (_, value) ->
                        val x = xFor(index)
                        val y = yFor(value)
                        if (index == 0) {
                            path.moveTo(x, y)
                            fill.moveTo(x, plotBottom)
                            fill.lineTo(x, y)
                        } else {
                            path.lineTo(x, y)
                            fill.lineTo(x, y)
                        }
                    }
                    val lastX = xFor(points.lastIndex)
                    fill.lineTo(lastX, plotBottom)
                    fill.close()
                    drawPath(
                        fill,
                        Brush.verticalGradient(
                            colors = listOf(tint.copy(alpha = 0.25f), tint.copy(alpha = 0.02f)),
                            startY = plotTop,
                            endY = plotBottom,
                        ),
                    )
                    drawPath(path, color = tint, style = Stroke(width = 2.dp.toPx()))
                    points.forEachIndexed { index, _ ->
                        drawCircle(color = pointColors[index], radius = 5.dp.toPx(), center = Offset(xFor(index), yFor(points[index].second)))
                    }
                    xTickIndexes.forEach { index ->
                        val label = textMeasurer.measure(hebrewShortDate(points[index].first), axisStyle)
                        val x = xFor(index) - label.size.width / 2f
                        drawText(
                            label,
                            topLeft = Offset(
                                x.coerceIn(plotLeft, plotRight - label.size.width),
                                plotBottom + 4.dp.toPx(),
                            ),
                        )
                    }
                }
            }
        }
    }
}

private fun yAxisTicks(max: Int): List<Int> {
    if (max <= 3) return (0..max).toList()
    val step = (max / 3).coerceAtLeast(1)
    val ticks = (0..max step step).toList()
    return if (ticks.last() == max) ticks else ticks + max
}

private fun xAxisIndexes(count: Int): List<Int> {
    if (count <= 0) return emptyList()
    if (count <= 5) return (0 until count).toList()
    return listOf(0, count / 3, (2 * count) / 3, count - 1).distinct()
}

