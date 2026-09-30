package com.cbtipul.app.ui.onboarding

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
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
) {
    val colors = Theme.colors
    val pager = rememberPagerState(pageCount = { 5 })
    val scope = rememberCoroutineScope()
    val page = pager.currentPage
    val last = page == 4
    fun goTo(index: Int) {
        if (index in 0..4 && !pager.isScrollInProgress) scope.launch { pager.animateScrollToPage(index) }
    }
    BackHandler { if (page > 0) goTo(page - 1) else onContinue() }

    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
        Column(Modifier.fillMaxSize().themedScreen(colors.gold).safeDrawingPadding(), horizontalAlignment = Alignment.CenterHorizontally) {
            Column(Modifier.widthIn(max = 540.dp).fillMaxWidth().padding(horizontal = 24.dp).padding(top = 8.dp, bottom = 8.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text(stringResource(R.string.app_title), color = colors.gold, fontSize = 20.sp, fontWeight = FontWeight.Bold,
                        modifier = Modifier.weight(1f))
                    TextButton(onClick = onContinue, modifier = Modifier.testTag("introduction.skip")) {
                        Text(stringResource(if (isReview) R.string.done else R.string.introduction_skip), fontWeight = FontWeight.SemiBold)
                    }
                }
                val progress = stringResource(R.string.introduction_page, page + 1, 5)
                Row(Modifier.fillMaxWidth().semantics { contentDescription = progress }.testTag("introduction.page.${page + 1}"),
                    horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                    repeat(5) { index ->
                        Box(Modifier.weight(1f).height(4.dp).background(if (index == page) colors.gold else colors.borderDefault, RoundedCornerShape(50)))
                    }
                }
            }
            HorizontalPager(state = pager, modifier = Modifier.weight(1f).fillMaxWidth(), verticalAlignment = Alignment.Top) { index ->
                IntroductionSlide(index)
            }
            // All three slots remain measured, even when their controls are hidden.
            // This keeps the pager height stable at 1↔2 and 4↔5, also with larger text.
            Column(Modifier.widthIn(max = 540.dp).fillMaxWidth().padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 12.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    Button(onClick = { goTo(page + 1) }, enabled = !last,
                        modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp).controlVisibility(!last).testTag("introduction.next"),
                        shape = RoundedCornerShape(16.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = colors.accentFill, contentColor = colors.textOnAccent)) {
                        Text(stringResource(R.string.introduction_next), fontWeight = FontWeight.SemiBold)
                        Spacer(Modifier.width(8.dp))
                        Icon(Icons.AutoMirrored.Outlined.ArrowForward, contentDescription = null)
                    }
                    Button(onClick = onTrySample, enabled = last,
                        modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp).controlVisibility(last).testTag("introduction.sample"),
                        shape = RoundedCornerShape(16.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = colors.accentFill, contentColor = colors.textOnAccent)) {
                        Icon(Icons.Outlined.RecentActors, contentDescription = null)
                        Spacer(Modifier.width(8.dp))
                        Text(stringResource(R.string.introduction_sample_action), textAlign = TextAlign.Center, fontWeight = FontWeight.SemiBold)
                    }
                }
                TextButton(onClick = onContinue, enabled = last,
                    modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).controlVisibility(last).testTag("introduction.continue")) {
                    Text(stringResource(if (isReview) R.string.introduction_return else R.string.introduction_start),
                        textAlign = TextAlign.Center, fontWeight = FontWeight.SemiBold)
                }
                TextButton(onClick = { goTo(page - 1) }, enabled = page > 0,
                    modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).controlVisibility(page > 0).testTag("introduction.back")) {
                    Text(stringResource(R.string.back), color = colors.textBody)
                }
            }
        }
    }
}

private fun Modifier.controlVisibility(visible: Boolean): Modifier =
    if (visible) this else alpha(0f).clearAndSetSemantics { }

@Composable
private fun IntroductionSlide(index: Int) {
    val colors = Theme.colors
    val title = when (index) {
        0 -> R.string.introduction_patient_title
        1 -> R.string.introduction_session_title
        2 -> R.string.introduction_connect_title
        3 -> R.string.introduction_progress_title
        else -> R.string.introduction_sample_title
    }
    val body = when (index) {
        0 -> R.string.introduction_patient_body
        1 -> R.string.introduction_session_body
        2 -> R.string.introduction_connect_body
        3 -> R.string.introduction_progress_body
        else -> R.string.introduction_sample_body
    }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp).padding(top = 20.dp, bottom = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(24.dp)) {
        IntroductionIllustration(index)
        Column(Modifier.widthIn(max = 492.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Text(stringResource(title), color = colors.textBright, fontSize = 30.sp, lineHeight = 36.sp,
                fontWeight = FontWeight.Bold, textAlign = TextAlign.Center, modifier = Modifier.semantics { heading() })
            Text(stringResource(body), color = colors.textBody, fontSize = 16.sp, lineHeight = 24.sp, textAlign = TextAlign.Center)
            if (index == 4) {
                Text(stringResource(R.string.introduction_sample_hint), color = colors.textBody, fontSize = 14.sp, lineHeight = 22.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().background(colors.goldGhost, RoundedCornerShape(18.dp)).padding(16.dp))
            }
        }
    }
}

@Composable
private fun IntroductionIllustration(index: Int) {
    val colors = Theme.colors
    Surface(Modifier.widthIn(max = 360.dp).fillMaxWidth().clearAndSetSemantics { },
        shape = RoundedCornerShape(28.dp), color = colors.surface,
        border = androidx.compose.foundation.BorderStroke(1.dp, colors.borderFaint), shadowElevation = 2.dp) {
        Column(Modifier.heightIn(min = 220.dp).padding(22.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
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
                        modifier = Modifier.size(58.dp).background(colors.goldGhost, RoundedCornerShape(18.dp)).padding(16.dp))
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
                3 -> Canvas(Modifier.fillMaxWidth().height(115.dp).padding(horizontal = 8.dp)) {
                    repeat(3) { row ->
                        val y = size.height * (row + 1) / 4
                        drawLine(colors.borderFaint, Offset(0f, y), Offset(size.width, y), pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 5.dp.toPx())))
                    }
                    val values = listOf(.22f, .39f, .32f, .61f, .58f, .79f)
                    val path = Path().apply {
                        values.forEachIndexed { i, value ->
                            val x = size.width * i / 5
                            if (i == 0) moveTo(x, size.height * value) else lineTo(x, size.height * value)
                        }
                    }
                    drawPath(path, colors.gold, style = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round))
                    values.forEachIndexed { i, value -> drawCircle(colors.gold, 4.dp.toPx(), Offset(size.width * i / 5, size.height * value)) }
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
