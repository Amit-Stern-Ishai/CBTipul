package com.cbtipul.app.ui.patient

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.data.DiaryFeeling
import com.cbtipul.app.data.PatientAssignment
import com.cbtipul.app.data.PatientAssignmentType
import com.cbtipul.app.ui.patients.MessageOverlay
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.themedScreen
import kotlinx.coroutines.launch

private enum class TasksLoadState { Loading, Loaded, Failed }

private sealed class PatientHomePage {
    data object Home : PatientHomePage()
    data class Questionnaire(val assignmentId: String) : PatientHomePage()
    data object DiaryOne : PatientHomePage()
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PatientModeScreen(
    loadAssignments: suspend () -> List<PatientAssignment>,
    submitQuestionnaire: suspend (
        assignmentId: String,
        gad7Answers: List<Int>,
        phq9Answers: List<Int>,
        interferenceLevel: Int,
    ) -> Unit,
    submitDiaryOne: suspend (
        event: String,
        thought: String,
        feelings: List<DiaryFeeling>,
        behaviour: String,
        physicalSymptoms: String?,
    ) -> Unit,
    onOpenSettings: () -> Unit,
) {
    val colors = Theme.colors
    val scope = rememberCoroutineScope()
    var loadState by remember { mutableStateOf(TasksLoadState.Loading) }
    var assignments by remember { mutableStateOf<List<PatientAssignment>>(emptyList()) }
    var didSubmitQuestionnaire by remember { mutableStateOf(false) }
    var didSubmitDiaryOne by remember { mutableStateOf(false) }
    var page by remember { mutableStateOf<PatientHomePage>(PatientHomePage.Home) }
    val openAssignments = assignments.filter { it.isOpen }

    suspend fun reload() {
        if (assignments.isEmpty()) loadState = TasksLoadState.Loading
        try {
            assignments = loadAssignments()
            loadState = TasksLoadState.Loaded
        } catch (_: Exception) {
            loadState = TasksLoadState.Failed
        }
    }

    LaunchedEffect(Unit) { reload() }

    when (val current = page) {
        is PatientHomePage.Questionnaire -> PatientQuestionnaireScreen(
            onSubmit = { gad7, phq9, interference ->
                submitQuestionnaire(current.assignmentId, gad7, phq9, interference)
                didSubmitQuestionnaire = true
            },
            onBack = {
                page = PatientHomePage.Home
                scope.launch { reload() }
            },
        )
        PatientHomePage.DiaryOne -> PatientDiaryOneEntryScreen(
            onSubmit = { event, thought, feelings, behaviour, physicalSymptoms ->
                submitDiaryOne(event, thought, feelings, behaviour, physicalSymptoms)
                didSubmitDiaryOne = true
                reload()
            },
            onDiaryInactive = { scope.launch { reload() } },
            onBack = { page = PatientHomePage.Home },
        )
        PatientHomePage.Home -> Scaffold(
            modifier = Modifier.themedScreen(colors.gold),
            containerColor = Color.Transparent,
            topBar = {
                TopAppBar(
                    title = { Text(stringResource(R.string.app_title), color = colors.textBright) },
                    navigationIcon = {
                        IconButton(onClick = onOpenSettings) {
                            Icon(
                                Icons.Outlined.Settings,
                                contentDescription = stringResource(R.string.settings_title),
                                tint = colors.gold,
                            )
                        }
                    },
                    actions = {
                        IconButton(
                            onClick = { scope.launch { reload() } },
                            enabled = loadState != TasksLoadState.Loading,
                        ) {
                            Icon(
                                Icons.Outlined.Refresh,
                                contentDescription = stringResource(R.string.patient_tasks_refresh),
                                tint = colors.gold,
                            )
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                )
            },
        ) { padding ->
            when {
                loadState == TasksLoadState.Loading && assignments.isEmpty() -> {
                    Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = colors.gold)
                    }
                }
                loadState == TasksLoadState.Failed && assignments.isEmpty() -> {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(padding)
                            .padding(horizontal = 24.dp),
                        verticalArrangement = Arrangement.Center,
                    ) {
                        Text(
                            stringResource(R.string.patient_tasks_load_error),
                            color = colors.textBody,
                        )
                        GoldActionButton(
                            text = stringResource(R.string.patient_activation_retry),
                            onClick = { scope.launch { reload() } },
                            modifier = Modifier.padding(top = 16.dp),
                        )
                    }
                }
                else -> {
                    PullToRefreshBox(
                        isRefreshing = loadState == TasksLoadState.Loading && assignments.isNotEmpty(),
                        onRefresh = { scope.launch { reload() } },
                        modifier = Modifier.fillMaxSize().padding(padding),
                    ) {
                        Column(
                            modifier = Modifier
                                .fillMaxSize()
                                .verticalScroll(rememberScrollState())
                                .padding(horizontal = 24.dp)
                                .padding(top = 24.dp, bottom = 28.dp),
                            verticalArrangement = Arrangement.spacedBy(20.dp),
                        ) {
                            Text(
                                stringResource(R.string.app_title),
                                color = colors.textBright,
                                fontWeight = FontWeight.Bold,
                                fontSize = 28.sp,
                            )
                            Text(
                                stringResource(R.string.patient_tasks_title),
                                color = colors.textBright,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 22.sp,
                            )
                            if (openAssignments.isEmpty()) {
                                GroupedListCard(accent = colors.gold) {
                                    Column(
                                        Modifier.padding(16.dp),
                                        verticalArrangement = Arrangement.spacedBy(8.dp),
                                    ) {
                                        Text(
                                            stringResource(R.string.patient_tasks_empty_title),
                                            color = colors.textBright,
                                            fontWeight = FontWeight.SemiBold,
                                        )
                                        Text(
                                            stringResource(R.string.patient_tasks_empty_body),
                                            color = colors.textBody,
                                        )
                                    }
                                }
                            } else {
                                openAssignments.forEach { assignment ->
                                    when (assignment.type) {
                                        PatientAssignmentType.Questionnaire -> QuestionnaireCard(
                                            onStart = { page = PatientHomePage.Questionnaire(assignment.id) },
                                        )
                                        PatientAssignmentType.DiaryOne -> DiaryOneCard(
                                            onStart = { page = PatientHomePage.DiaryOne },
                                        )
                                        PatientAssignmentType.DiaryTwo, null -> UpcomingTaskCard()
                                    }
                                }
                            }
                            if (loadState == TasksLoadState.Failed) {
                                Text(
                                    stringResource(R.string.patient_tasks_load_error),
                                    color = colors.error,
                                    fontSize = 13.sp,
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    MessageOverlay(
        visible = didSubmitQuestionnaire,
        title = stringResource(R.string.patient_questionnaire_submitted),
        message = "",
        onDismiss = { didSubmitQuestionnaire = false },
    )
    MessageOverlay(
        visible = didSubmitDiaryOne,
        title = stringResource(R.string.patient_diary_one_saved),
        message = "",
        onDismiss = { didSubmitDiaryOne = false },
    )
}

@Composable
private fun QuestionnaireCard(onStart: () -> Unit) {
    val colors = Theme.colors
    GroupedListCard(accent = colors.gold) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                stringResource(R.string.patient_questionnaire_card_title),
                color = colors.textBright,
                fontWeight = FontWeight.SemiBold,
            )
            Text(stringResource(R.string.patient_questionnaire_card_body), color = colors.textBody)
            GoldActionButton(text = stringResource(R.string.patient_questionnaire_start), onClick = onStart)
        }
    }
}

@Composable
private fun DiaryOneCard(onStart: () -> Unit) {
    val colors = Theme.colors
    GroupedListCard(accent = colors.gold) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                stringResource(R.string.patient_diary_one_card_title),
                color = colors.textBright,
                fontWeight = FontWeight.SemiBold,
            )
            Text(stringResource(R.string.patient_diary_one_card_body), color = colors.textBody)
            Text(
                stringResource(R.string.patient_diary_one_ongoing_hint),
                color = colors.textFaint,
                fontSize = 13.sp,
            )
            GoldActionButton(text = stringResource(R.string.diary_one_add_entry), onClick = onStart)
        }
    }
}

@Composable
private fun UpcomingTaskCard() {
    val colors = Theme.colors
    GroupedListCard(accent = colors.gold) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                stringResource(R.string.patient_upcoming_task_title),
                color = colors.textBright,
                fontWeight = FontWeight.SemiBold,
            )
            Text(stringResource(R.string.patient_upcoming_task_body), color = colors.textBody)
        }
    }
}

@Composable
private fun GoldActionButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = Theme.colors
    Button(
        onClick = onClick,
        modifier = modifier.fillMaxWidth().height(48.dp),
        colors = ButtonDefaults.buttonColors(containerColor = colors.gold, contentColor = colors.textOnAccent),
        shape = RoundedCornerShape(14.dp),
    ) {
        Text(text, fontWeight = FontWeight.SemiBold)
    }
}
