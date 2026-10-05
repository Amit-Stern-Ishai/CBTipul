package com.cbtipul.app.ui.onboarding

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.selection.selectable
import androidx.compose.ui.semantics.Role
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.ArrowForward
import androidx.compose.material.icons.automirrored.outlined.Chat
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.themedScreen
import kotlinx.coroutines.launch

/** Five short, RTL pages; illustrations never contain real patient data. */
@Composable
fun AppIntroductionScreen(
    onTrySample: () -> Unit,
    onContinue: () -> Unit,
    isReview: Boolean = false,
    isPatientMode: Boolean = false,
) {
    val pageCount = if (isPatientMode) 4 else 5
    val pager = rememberPagerState(pageCount = { pageCount })
    var showSampleGate by remember { mutableStateOf(false) }
    if (showSampleGate) {
        WelcomeOnboardingScreen(
            onStartDemoTour = onTrySample,
            onSkip = { showSampleGate = false },
        )
        return
    }
    val colors = Theme.colors
    val scope = rememberCoroutineScope()
    val page = pager.currentPage
    val last = page == pageCount - 1
    var navigationJob by remember { mutableStateOf<kotlinx.coroutines.Job?>(null) }
    fun goTo(index: Int) {
        if (index !in 0 until pageCount) return
        navigationJob?.cancel()
        navigationJob = scope.launch { pager.animateScrollToPage(index) }
    }
    BackHandler { if (page > 0) goTo(page - 1) else onContinue() }

    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
        Column(Modifier.fillMaxSize().themedScreen(colors.gold).safeDrawingPadding(), horizontalAlignment = Alignment.CenterHorizontally) {
            Column(Modifier.widthIn(max = 540.dp).fillMaxWidth().padding(horizontal = 24.dp).padding(top = 4.dp),
                verticalArrangement = Arrangement.spacedBy(0.dp)) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = { goTo(page - 1) }, enabled = page > 0,
                        modifier = Modifier.controlVisibility(page > 0).testTag("introduction.back")) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, stringResource(R.string.back), tint = colors.gold)
                    }
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        Text(stringResource(R.string.app_title), color = colors.gold, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                        Text(stringResource(R.string.introduction_page, page + 1, pageCount), color = colors.textBody, fontSize = 12.sp,
                            modifier = Modifier.testTag("introduction.page.${page + 1}"))
                    }

                }
                val topics = if (isPatientMode) listOf(R.string.patient_intro_welcome_title, R.string.patient_intro_questionnaires_title, R.string.patient_intro_diaries_title, R.string.patient_intro_updates_title) else listOf(R.string.introduction_topic_patient, R.string.introduction_topic_session,
                    R.string.introduction_topic_connect, R.string.introduction_topic_progress, R.string.introduction_topic_sample)
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                    topics.forEachIndexed { index, topic ->
                        val label = stringResource(topic)
                        val progress = stringResource(R.string.introduction_page, index + 1, pageCount)
                        Column(Modifier.weight(1f).heightIn(min = 48.dp)
                            .selectable(selected = index == page, role = Role.Tab, onClick = { goTo(index) })
                            .semantics { contentDescription = "$label, $progress" }
                            .testTag("introduction.topic.${index + 1}"),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterVertically)) {
                            Box(Modifier.fillMaxWidth().height(4.dp).background(if (index == page) colors.gold else colors.borderDefault, RoundedCornerShape(50)))
                        }
                    }
                }

            }
            HorizontalPager(state = pager, modifier = Modifier.weight(1f).fillMaxWidth(), verticalAlignment = Alignment.Top) { index ->
                IntroductionSlide(index, isPatientMode)
            }
            // Keep one stable control row throughout the pager.
            Row(Modifier.widthIn(max = 540.dp).fillMaxWidth().padding(horizontal = 24.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Button(
                    onClick = {
                        if (!last) goTo(page + 1)
                        else if (isPatientMode) onContinue()
                        else showSampleGate = true
                    },
                    modifier = Modifier.weight(1f).heightIn(min = 52.dp)
                        .testTag(if (last) "introduction.sample" else "introduction.next"),
                    shape = RoundedCornerShape(16.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = colors.accentFill, contentColor = colors.textOnAccent),
                ) {
                    Text(
                        stringResource(if (!last) R.string.introduction_next else if (isPatientMode) R.string.patient_intro_start else R.string.introduction_sample_action),
                        textAlign = TextAlign.Center,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Spacer(Modifier.width(8.dp))
                    Icon(
                        if (!last) Icons.AutoMirrored.Outlined.ArrowForward else if (isPatientMode) Icons.Outlined.Check else Icons.Outlined.RecentActors,
                        contentDescription = null,
                    )
                }
                TextButton(onClick = onContinue,
                    modifier = Modifier.heightIn(min = 48.dp).testTag("introduction.skip")) {
                    Text(stringResource(R.string.introduction_skip), color = colors.textBody, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

private fun Modifier.controlVisibility(visible: Boolean): Modifier =
    if (visible) this else alpha(0f).clearAndSetSemantics { }

@Composable
private fun IntroductionSlide(index: Int, isPatientMode: Boolean) {
    val colors = Theme.colors
    val title = if (isPatientMode) listOf(R.string.patient_intro_welcome_title, R.string.patient_intro_questionnaires_title, R.string.patient_intro_diaries_title, R.string.patient_intro_updates_title)[index] else when (index) {
        0 -> R.string.introduction_patient_title
        1 -> R.string.introduction_session_title
        2 -> R.string.introduction_connect_title
        3 -> R.string.introduction_progress_title
        else -> R.string.introduction_sample_title
    }
    val body = if (isPatientMode) listOf(R.string.patient_intro_welcome_body, R.string.patient_intro_questionnaires_body, R.string.patient_intro_diaries_body, R.string.patient_intro_updates_body)[index] else when (index) {
        0 -> R.string.introduction_patient_body
        1 -> R.string.introduction_session_body
        2 -> R.string.introduction_connect_body
        3 -> R.string.introduction_progress_body
        else -> R.string.introduction_sample_body
    }
    BoxWithConstraints(Modifier.fillMaxSize(), contentAlignment = Alignment.TopCenter) {
        val compact = maxHeight < 520.dp
        val patientIllustrationHeight = minOf(230.dp, maxHeight * 0.45f)
        Column(Modifier.widthIn(max = 540.dp).fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp, vertical = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(if (compact) 12.dp else 18.dp)) {
            if (isPatientMode) {
                Box(Modifier.fillMaxWidth().height(patientIllustrationHeight).background(colors.goldGhost, RoundedCornerShape(28.dp)), contentAlignment = Alignment.Center) {
                    Icon(listOf(Icons.Outlined.People, Icons.Outlined.Assignment, Icons.Outlined.MenuBook, Icons.Outlined.Notifications)[index], null, Modifier.size(86.dp), tint = colors.gold)
                }
            } else IntroductionIllustration(index)
            Column(Modifier.widthIn(max = 492.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(stringResource(title), color = colors.textBright, fontSize = 28.sp, lineHeight = 34.sp,
                    fontWeight = FontWeight.Bold, textAlign = TextAlign.Center, modifier = Modifier.semantics { heading() })
                Text(stringResource(body), color = colors.textBody, fontSize = 16.sp, lineHeight = 24.sp, textAlign = TextAlign.Center)
                if (!isPatientMode && index == 4) {
                    Text(stringResource(R.string.introduction_sample_hint), color = colors.textBody, fontSize = 14.sp, lineHeight = 22.sp,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth().background(colors.goldGhost, RoundedCornerShape(18.dp)).padding(12.dp))
                }
            }
        }
    }
}

@Composable
private fun IntroductionIllustration(index: Int) {
    val colors = Theme.colors
    Surface(Modifier.widthIn(max = 420.dp).fillMaxWidth().clearAndSetSemantics { },
        shape = RoundedCornerShape(28.dp), color = colors.surface,
        border = androidx.compose.foundation.BorderStroke(1.dp, colors.borderFaint), shadowElevation = 2.dp) {
        Column(Modifier.heightIn(min = 240.dp).padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            if (index == 2) {
                Text(stringResource(R.string.introduction_connected), color = colors.gold, fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
            } else {
                val icon = when (index) {
                    0 -> Icons.Outlined.Badge
                    1 -> Icons.Outlined.GraphicEq
                    3 -> Icons.Outlined.ShowChart
                    else -> Icons.Outlined.RecentActors
                }
                val title = when (index) {
                    0 -> R.string.patient_records_title
                    1 -> R.string.introduction_session_notes
                    3 -> R.string.introduction_trend
                    else -> R.string.introduction_sample_badge
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    Icon(icon, contentDescription = null, tint = colors.gold,
                        modifier = Modifier.size(64.dp).background(colors.goldGhost, RoundedCornerShape(18.dp)).padding(16.dp))
                    Text(stringResource(title), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                }
            }
            when (index) {
                0 -> {
                    IllustrationRow(R.string.introduction_goal, Icons.Outlined.TrackChanges)
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        IllustrationRow(R.string.therapist_tab_sessions, Icons.Outlined.CalendarToday, Modifier.weight(1f))
                        IllustrationRow(R.string.patient_diaries_title, Icons.Outlined.MenuBook, Modifier.weight(1f))
                    }
                }
                1 -> {
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        IllustrationRow(R.string.introduction_write, Icons.Outlined.Edit, Modifier.weight(1f))
                        IllustrationRow(R.string.introduction_record, Icons.Outlined.Mic, Modifier.weight(1f))
                    }
                    IllustrationRow(R.string.introduction_ai, Icons.Outlined.AutoAwesome)
                }
                2 -> {
                    IllustrationRow(R.string.introduction_message, Icons.AutoMirrored.Outlined.Chat)
                    IllustrationRow(R.string.introduction_questionnaire, Icons.Outlined.Assignment)
                    IllustrationRow(R.string.introduction_diary, Icons.Outlined.MenuBook)
                }
                3 -> {
                    val rtl = LocalLayoutDirection.current == LayoutDirection.Rtl
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(stringResource(R.string.introduction_graph_measure), color = colors.textBody, fontSize = 12.sp)
                        Canvas(Modifier.fillMaxWidth().height(130.dp).padding(8.dp)) {
                            repeat(3) { row ->
                                val y = size.height * (row + 1) / 4
                                drawLine(colors.borderFaint, Offset(0f, y), Offset(size.width, y),
                                    pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 5.dp.toPx())))
                            }
                            val values = listOf(.15f, .30f, .27f, .52f, .63f, .83f)
                            val points = values.mapIndexed { i, value ->
                                val fraction = i.toFloat() / values.lastIndex
                                Offset(size.width * (if (rtl) 1f - fraction else fraction), size.height * value)
                            }
                            val area = Path().apply {
                                moveTo(points.first().x, size.height)
                                points.forEach { lineTo(it.x, it.y) }
                                lineTo(points.last().x, size.height)
                                close()
                            }
                            drawPath(area, colors.success.copy(alpha = .12f))
                            val line = Path().apply {
                                moveTo(points.first().x, points.first().y)
                                points.drop(1).forEach { lineTo(it.x, it.y) }
                            }
                            drawPath(line, colors.success, style = Stroke(width = 4.dp.toPx(), cap = StrokeCap.Round))
                            points.forEach {
                                drawCircle(colors.surface, 6.dp.toPx(), it)
                                drawCircle(colors.success, 4.dp.toPx(), it)
                            }
                        }
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(stringResource(R.string.introduction_graph_start), color = colors.textBody, fontSize = 12.sp)
                            Text(stringResource(R.string.introduction_graph_latest), color = colors.textBody, fontSize = 12.sp)
                        }
                        Text(stringResource(R.string.introduction_graph_hint), color = colors.success, fontSize = 12.sp)
                    }
                }
                else -> {
                    IllustrationRow(R.string.introduction_sample_patient, Icons.Outlined.AccountCircle)
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        IllustrationRow(R.string.therapist_tab_sessions, Icons.Outlined.CalendarToday, Modifier.weight(1f))
                        IllustrationRow(R.string.introduction_diary, Icons.Outlined.MenuBook, Modifier.weight(1f))
                    }
                }
            }
        }
    }
}

@Composable
private fun IllustrationRow(text: Int, icon: ImageVector, modifier: Modifier = Modifier) {
    val colors = Theme.colors
    Row(modifier.fillMaxWidth().background(colors.elevated.copy(alpha = .65f), RoundedCornerShape(12.dp)).padding(12.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = colors.gold, modifier = Modifier.size(22.dp))
        Text(stringResource(text), color = colors.textBright, fontSize = 14.sp, fontWeight = FontWeight.Medium)
    }
}
