package com.cbtipul.app.ui.patient

import com.cbtipul.app.ui.entitlementCreateControl
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.outlined.Assignment
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringArrayResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import com.cbtipul.app.R
import com.cbtipul.app.data.PatientAssignment
import com.cbtipul.app.data.PatientAssignmentType
import com.cbtipul.app.model.CompletedQuestionnaire
import com.cbtipul.app.ui.patients.GAD7ScoreCapsule
import com.cbtipul.app.ui.patients.PHQ9ScoreCapsule
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.themedScreen
import kotlinx.coroutines.CancellationException
import com.cbtipul.app.ui.theme.hebrewDateTime

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PatientQuestionnaireHubScreen(
    loadAssignments: suspend () -> List<PatientAssignment>,
    loadHistory: suspend () -> List<CompletedQuestionnaire>,
    onNew: (String) -> Unit,
    onOpen: (CompletedQuestionnaire) -> Unit,
    onLoaded: (List<CompletedQuestionnaire>) -> Unit,
    onBack: () -> Unit,
) {
    var assignment by remember { mutableStateOf<PatientAssignment?>(null) }
    var history by remember { mutableStateOf<List<CompletedQuestionnaire>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var historyFailed by remember { mutableStateOf(false) }
    var accessFailed by remember { mutableStateOf(false) }
    var revision by remember { mutableIntStateOf(0) }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { revision++ }
    LaunchedEffect(revision) {
        try {
            assignment = loadAssignments().firstOrNull { it.type == PatientAssignmentType.Questionnaire && it.cancelledAt == null }
            accessFailed = false
        } catch (e: CancellationException) { throw e } catch (_: Exception) { accessFailed = true }
        try { history = loadHistory(); onLoaded(history); historyFailed = false }
        catch (e: CancellationException) { throw e } catch (_: Exception) { historyFailed = true }
        loading = false
    }
    Scaffold(modifier = Modifier.themedScreen(Theme.colors.gold), containerColor = Color.Transparent,
        topBar = { TopAppBar(title = { Text(stringResource(R.string.patient_questionnaire_card_title)) },
            navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, stringResource(R.string.back)) } },
            actions = { TextButton(onClick = { revision++ }) { Text(stringResource(R.string.patient_tasks_refresh)) } }) },
        bottomBar = {
            assignment?.let { current ->
                Surface(color = Theme.colors.base) {
                    Box(Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp)) {
                        Button(
                            onClick = { onNew(current.id) },
                            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).entitlementCreateControl(),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = Theme.colors.accentFill,
                                contentColor = Theme.colors.textOnAccent,
                            ),
                            shape = RoundedCornerShape(14.dp),
                        ) {
                            Icon(Icons.Outlined.Add, null)
                            Spacer(Modifier.width(8.dp))
                            Text(stringResource(R.string.patient_questionnaire_start))
                        }
                    }
                }
            }
        }) { padding ->
        LazyColumn(Modifier.fillMaxSize().padding(padding).padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(16.dp), contentPadding = PaddingValues(vertical = 16.dp)) {
            item { Text(stringResource(R.string.patient_questionnaire_card_body), color = Theme.colors.textBody) }
            if (assignment != null || (!loading && !accessFailed)) item { PatientToolStatus(assignment != null) }
            if (assignment == null) item {
                when {
                    loading -> CircularProgressIndicator()
                    accessFailed -> Text(stringResource(R.string.patient_tasks_load_error), color = Theme.colors.error)
                    else -> Text(stringResource(R.string.patient_questionnaire_cancelled_error), color = Theme.colors.textBody)
                }
            }
            item { Text(stringResource(R.string.patient_questionnaire_history), style = MaterialTheme.typography.titleLarge, color = Theme.colors.textBright) }
            if (historyFailed) item {
                Text(stringResource(R.string.patient_questionnaire_history_error), color = Theme.colors.error)
                TextButton(onClick = { revision++ }) { Text(stringResource(R.string.retry)) }
            }
            if (history.isEmpty() && !historyFailed && !loading) item { Text(stringResource(R.string.patient_questionnaire_history_empty), color = Theme.colors.textBody) }
            items(history, key = { it.databaseId.queryValue }) { record ->
                OutlinedCard(onClick = { onOpen(record) }, modifier = Modifier.fillMaxWidth()) {
                    Row(Modifier.fillMaxWidth().padding(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                        Row(modifier = Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                            Icon(Icons.Outlined.Assignment, contentDescription = null, tint = Theme.colors.gold, modifier = Modifier.size(22.dp))
                            Text(hebrewDateTime(record.answeredDate))
                        }
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp), horizontalAlignment = androidx.compose.ui.Alignment.End) {
                            GAD7ScoreCapsule(record.questionnaire, null)
                            PHQ9ScoreCapsule(record.questionnaire, null)
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PatientQuestionnaireResultScreen(record: CompletedQuestionnaire?, onBack: () -> Unit) {
    val questions = stringArrayResource(R.array.gad7_questions).toList() + stringArrayResource(R.array.phq9_questions).toList()
    val labels = stringArrayResource(R.array.answer_descriptions)
    val interference = stringArrayResource(R.array.phq9_interference_options)
    Scaffold(modifier = Modifier.themedScreen(Theme.colors.gold), containerColor = Color.Transparent,
        topBar = { TopAppBar(title = { Text(stringResource(R.string.patient_questionnaire_history)) },
            navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, stringResource(R.string.back)) } }) }) { padding ->
        LazyColumn(Modifier.fillMaxSize().padding(padding).padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(16.dp), contentPadding = PaddingValues(vertical = 16.dp)) {
            if (record == null) item { Text(stringResource(R.string.patient_questionnaire_history_error), color = Theme.colors.textBody) }
            else {
                item {
                    Text(hebrewDateTime(record.answeredDate), color = Theme.colors.textBright)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        GAD7ScoreCapsule(record.questionnaire, null); PHQ9ScoreCapsule(record.questionnaire, null)
                    }
                }
                val answers = record.questionnaire.gad7Answers + record.questionnaire.phq9Answers
                items(questions.size) { index ->
                    OutlinedCard(Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(questions[index])
                            Text(answers.getOrNull(index)?.let { labels.getOrNull(it) } ?: stringResource(R.string.patient_questionnaire_history_error), color = Theme.colors.textBody)
                        }
                    }
                }
                item {
                    Text(stringResource(R.string.phq9_interference_question), color = Theme.colors.textBright)
                    Text(record.questionnaire.interferenceLevel?.let { interference.getOrNull(it) }.orEmpty(), color = Theme.colors.textBody)
                }
            }
        }
    }
}
