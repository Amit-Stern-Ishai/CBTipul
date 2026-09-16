package com.cbtipul.app.ui.onboarding

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Science
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.DirectionsWalk
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.ui.theme.Theme
import kotlin.math.ceil
import kotlin.math.max

@Composable
fun DemoModeBanner(
    onExit: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = Theme.colors
    val shimmer = rememberInfiniteTransition(label = "demoBanner")
    val travel by shimmer.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(4200, easing = LinearEasing),
            repeatMode = RepeatMode.Restart,
        ),
        label = "bannerShimmer",
    )
    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(colors.warning)
            .background(
                Brush.linearGradient(
                    colors = listOf(
                        Color.Transparent,
                        Color.White.copy(alpha = 0.22f),
                        Color.White.copy(alpha = 0.34f),
                        Color.White.copy(alpha = 0.22f),
                        Color.Transparent,
                    ),
                    start = Offset(travel * 800f - 200f, 0f),
                    end = Offset(travel * 800f + 200f, 0f),
                ),
            )
            // Below status bar so title/exit stay clear and tappable with edge-to-edge.
            .statusBarsPadding(),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Icon(
                Icons.Outlined.Science,
                contentDescription = null,
                tint = colors.textOnAccent,
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    stringResource(R.string.demo_mode_banner_title),
                    color = colors.textOnAccent,
                    fontWeight = FontWeight.Bold,
                    fontSize = 13.sp,
                )
                Text(
                    stringResource(R.string.demo_mode_banner_body),
                    color = colors.textOnAccent.copy(alpha = 0.9f),
                    fontSize = 11.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Button(
                onClick = onExit,
                colors = ButtonDefaults.buttonColors(
                    containerColor = colors.surface.copy(alpha = 0.92f),
                    contentColor = colors.warning,
                ),
            ) {
                Text(stringResource(R.string.demo_mode_exit_short), fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
fun TutorialCoachCard(
    progress: GettingStartedProgress,
    placement: TutorialCoachPlacement,
    viewingPatientId: com.cbtipul.app.model.DatabaseId?,
    showcaseLoaded: Boolean,
    countdownEndsAtMillis: Long?,
    onRestart: () -> Unit,
    onDismiss: () -> Unit,
    onSkipToShowcase: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = Theme.colors
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(
                Brush.linearGradient(
                    colors = listOf(colors.gold, colors.warning),
                    start = Offset.Zero,
                    end = Offset(800f, 400f),
                ),
            )
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Icon(
                Icons.Outlined.DirectionsWalk,
                contentDescription = null,
                tint = colors.textOnAccent,
            )
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                if (progress.isComplete) {
                    Text(
                        stringResource(R.string.getting_started_complete_message),
                        color = colors.textOnAccent,
                        fontWeight = FontWeight.Bold,
                        fontSize = 14.sp,
                    )
                } else {
                    val step = progress.currentStep
                    Text(
                        stringResource(
                            R.string.getting_started_progress,
                            progress.currentStepNumber,
                            GettingStartedStep.entries.size,
                        ),
                        color = colors.textOnAccent.copy(alpha = 0.85f),
                        fontWeight = FontWeight.Bold,
                        fontSize = 11.sp,
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(Color.White.copy(alpha = 0.22f))
                            .padding(horizontal = 8.dp, vertical = 3.dp),
                    )
                    if (step != null) {
                        Text(
                            stringResource(step.titleRes),
                            color = colors.textOnAccent,
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp,
                        )
                        val hintRes = TutorialCoach.hintRes(
                            step = step,
                            placement = placement,
                            progress = progress,
                            viewingPatientId = viewingPatientId,
                        )
                        if (hintRes != null) {
                            Text(
                                stringResource(hintRes),
                                color = colors.textOnAccent.copy(alpha = 0.92f),
                                fontSize = 14.sp,
                            )
                        }
                    }
                }
            }
            IconButton(onClick = onDismiss) {
                Icon(
                    Icons.Outlined.Close,
                    contentDescription = stringResource(R.string.getting_started_dismiss_a11y),
                    tint = colors.textOnAccent.copy(alpha = 0.85f),
                )
            }
        }

        when {
            countdownEndsAtMillis != null -> {
                ShowcaseAdvanceButton(
                    endsAtMillis = countdownEndsAtMillis,
                    durationMs = GettingStartedRouter.SHOWCASE_COUNTDOWN_DURATION_MS,
                    onClick = onSkipToShowcase,
                )
            }
            progress.isComplete -> {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (!showcaseLoaded) {
                        Button(
                            onClick = onSkipToShowcase,
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = colors.surface,
                                contentColor = colors.gold,
                            ),
                        ) {
                            Icon(Icons.Outlined.AutoAwesome, contentDescription = null)
                            Spacer(Modifier.width(8.dp))
                            Text(stringResource(R.string.tutorial_coach_skip_to_showcase))
                        }
                    }
                    OutlinedButton(
                        onClick = onRestart,
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = colors.textOnAccent),
                    ) {
                        Text(stringResource(R.string.getting_started_restart_action))
                    }
                }
            }
            !showcaseLoaded -> {
                OutlinedButton(
                    onClick = onSkipToShowcase,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = colors.textOnAccent),
                ) {
                    Icon(Icons.Outlined.AutoAwesome, contentDescription = null)
                    Spacer(Modifier.width(8.dp))
                    Text(stringResource(R.string.tutorial_coach_skip_to_showcase))
                }
            }
        }
    }
}

@Composable
private fun ShowcaseAdvanceButton(
    endsAtMillis: Long,
    durationMs: Long,
    onClick: () -> Unit,
) {
    val colors = Theme.colors
    val now = System.currentTimeMillis()
    val remaining = max(0L, endsAtMillis - now)
    val fill = if (durationMs > 0) remaining.toFloat() / durationMs.toFloat() else 0f
    val seconds = ceil(remaining / 1000.0).toInt()
    // Recompose while counting down
    val tick = rememberInfiniteTransition(label = "countdown")
    tick.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(250), RepeatMode.Restart),
        label = "tick",
    )

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(44.dp)
            .clip(RoundedCornerShape(50))
            .background(Color.White.copy(alpha = 0.22f)),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth(fraction = fill.coerceIn(0f, 1f))
                .height(44.dp)
                .clip(RoundedCornerShape(50))
                .background(colors.surface),
        )
        TextButton(
            onClick = onClick,
            modifier = Modifier.fillMaxWidth().height(44.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Outlined.AutoAwesome, contentDescription = null, tint = colors.gold)
                Spacer(Modifier.width(8.dp))
                Text(
                    stringResource(R.string.tutorial_coach_skip_to_showcase),
                    color = colors.gold,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    modifier = Modifier.weight(1f),
                )
                Text(
                    "$seconds",
                    color = colors.gold,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }
}

@Composable
fun DemoModeChrome(
    isDemoMode: Boolean,
    checklistDismissed: Boolean,
    routerState: GettingStartedRouterState,
    showcaseLoaded: Boolean,
    onExitDemo: () -> Unit,
    onRestart: () -> Unit,
    onDismissCoach: () -> Unit,
    onSkipToShowcase: () -> Unit,
    content: @Composable () -> Unit,
) {
    Column {
        if (isDemoMode) {
            DemoModeBanner(onExit = onExitDemo)
        }
        Box(modifier = Modifier.weight(1f, fill = true)) {
            content()
        }
        if (isDemoMode && !checklistDismissed) {
            TutorialCoachCard(
                progress = routerState.progress,
                placement = routerState.placement,
                viewingPatientId = routerState.viewingPatientId,
                showcaseLoaded = showcaseLoaded,
                countdownEndsAtMillis = routerState.showcaseCountdownEndsAtMillis,
                onRestart = onRestart,
                onDismiss = onDismissCoach,
                onSkipToShowcase = onSkipToShowcase,
            )
        }
    }
}
