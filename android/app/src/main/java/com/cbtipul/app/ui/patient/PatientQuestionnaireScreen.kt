package com.cbtipul.app.ui.patient

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringArrayResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.data.PatientQuestionnaireSubmitError
import com.cbtipul.app.model.CombinedMoodQuestionnaire
import com.cbtipul.app.ui.patients.MessageOverlay
import com.cbtipul.app.ui.patients.aiMarkdown
import com.cbtipul.app.ui.patients.gad7SeverityLabel
import com.cbtipul.app.ui.patients.phq9SeverityLabel
import com.cbtipul.app.ui.patients.phq9Suggestion
import com.cbtipul.app.ui.theme.BusyOverlay
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.GroupedListDivider
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.themedScreen
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PatientQuestionnaireScreen(
    onSubmit: suspend (gad7Answers: List<Int>, phq9Answers: List<Int>, interferenceLevel: Int) -> Unit,
    onBack: () -> Unit,
) {
    val colors = Theme.colors
    val scope = rememberCoroutineScope()
    var draft by remember { mutableStateOf(CombinedMoodQuestionnaire()) }
    var isSubmitting by remember { mutableStateOf(false) }
    var showIncomplete by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    val gad7 = stringArrayResource(R.array.gad7_questions)
    val phq9 = stringArrayResource(R.array.phq9_questions)
    val answers = stringArrayResource(R.array.answer_descriptions)
    val interference = stringArrayResource(R.array.phq9_interference_options)
    val submitError = stringResource(R.string.patient_questionnaire_submit_error)
    val cancelledError = stringResource(R.string.patient_questionnaire_cancelled_error)
    val accessDenied = stringResource(R.string.patient_questionnaire_access_denied)
    val valid = (0..3).toSet()
    val gad7Ready = draft.gad7Answers.mapNotNull { it }
    val phq9Ready = draft.phq9Answers.mapNotNull { it }
    val interferenceLevel = draft.interferenceLevel
    val isReady = gad7Ready.size == CombinedMoodQuestionnaire.GAD7_COUNT &&
        phq9Ready.size == CombinedMoodQuestionnaire.PHQ9_COUNT &&
        gad7Ready.all { it in valid } &&
        phq9Ready.all { it in valid } &&
        interferenceLevel != null &&
        interferenceLevel in valid

    fun attemptSubmit() {
        if (isSubmitting) return
        if (!isReady || interferenceLevel == null) {
            showIncomplete = true
            return
        }
        isSubmitting = true
        errorMessage = null
        scope.launch {
            try {
                onSubmit(gad7Ready, phq9Ready, interferenceLevel)
                onBack()
            } catch (_: PatientQuestionnaireSubmitError.AlreadyCompleted) {
                onBack()
            } catch (_: PatientQuestionnaireSubmitError.Cancelled) {
                errorMessage = cancelledError
                isSubmitting = false
            } catch (_: PatientQuestionnaireSubmitError.AccessDenied) {
                errorMessage = accessDenied
                isSubmitting = false
            } catch (_: PatientQuestionnaireSubmitError) {
                errorMessage = submitError
                isSubmitting = false
            } catch (_: Exception) {
                errorMessage = submitError
                isSubmitting = false
            }
        }
    }

    BackHandler(enabled = !isSubmitting) { onBack() }

    Box(Modifier.fillMaxSize()) {
        Scaffold(
            modifier = Modifier.themedScreen(colors.gold),
            containerColor = Color.Transparent,
            topBar = {
                TopAppBar(
                    title = {
                        Text(stringResource(R.string.patient_questionnaire_card_title), color = colors.textBright)
                    },
                    navigationIcon = {
                        IconButton(onClick = onBack, enabled = !isSubmitting) {
                            Icon(
                                Icons.AutoMirrored.Outlined.ArrowBack,
                                contentDescription = stringResource(R.string.back),
                                tint = colors.gold,
                            )
                        }
                    },
                    actions = {
                        TextButton(onClick = { attemptSubmit() }, enabled = !isSubmitting) {
                            Text(stringResource(R.string.patient_questionnaire_submit), color = colors.gold)
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
                    .padding(24.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                Text(stringResource(R.string.gad7_title), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                GroupedListCard(accent = colors.gold) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            stringResource(R.string.answer_key_title),
                            color = colors.textBright,
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 14.sp,
                        )
                        answers.forEach { Text(it, color = colors.textBody, fontSize = 13.sp) }
                    }
                    GroupedListDivider()
                    Text(
                        aiMarkdown(stringResource(R.string.gad7_main_question)),
                        color = colors.textBright,
                        modifier = Modifier.padding(16.dp),
                    )
                    gad7.forEachIndexed { index, question ->
                        GroupedListDivider()
                        PatientQuestionBlock(
                            text = question,
                            selection = draft.gad7Answers.getOrNull(index),
                            accent = colors.gold,
                            editable = !isSubmitting,
                            onSelect = { value ->
                                draft = draft.copy(
                                    gad7Answers = draft.gad7Answers.toMutableList().also { it[index] = value },
                                )
                            },
                        )
                    }
                    GroupedListDivider()
                    PatientScoreBlock(score = draft.gad7Score, classification = gad7SeverityLabel(draft.gad7Severity))
                }

                Text(stringResource(R.string.phq9_title), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                GroupedListCard(accent = colors.gold) {
                    Text(
                        aiMarkdown(stringResource(R.string.phq9_main_question)),
                        color = colors.textBright,
                        modifier = Modifier.padding(16.dp),
                    )
                    phq9.forEachIndexed { index, question ->
                        GroupedListDivider()
                        PatientQuestionBlock(
                            text = question,
                            selection = draft.phq9Answers.getOrNull(index),
                            accent = colors.gold,
                            editable = !isSubmitting,
                            onSelect = { value ->
                                draft = draft.copy(
                                    phq9Answers = draft.phq9Answers.toMutableList().also { it[index] = value },
                                )
                            },
                        )
                    }
                    GroupedListDivider()
                    PatientInterferenceBlock(
                        options = interference,
                        selection = draft.interferenceLevel,
                        editable = !isSubmitting,
                        onSelect = { draft = draft.copy(interferenceLevel = it) },
                    )
                    GroupedListDivider()
                    PatientScoreBlock(score = draft.phq9Score, classification = phq9SeverityLabel(draft.phq9Severity))
                    GroupedListDivider()
                    Text(
                        phq9Suggestion(draft.phq9Severity),
                        color = colors.textBody,
                        fontSize = 13.sp,
                        modifier = Modifier.padding(16.dp),
                    )
                }

                errorMessage?.let { Text(it, color = colors.error) }
            }
        }
        BusyOverlay(
            isBusy = isSubmitting,
            label = stringResource(R.string.patient_questionnaire_submitting),
        )
    }

    MessageOverlay(
        visible = showIncomplete,
        title = stringResource(R.string.questionnaire_incomplete_title),
        message = stringResource(R.string.questionnaire_incomplete_message),
        onDismiss = { showIncomplete = false },
    )
}

@Composable
private fun PatientQuestionBlock(
    text: String,
    selection: Int?,
    accent: Color,
    editable: Boolean,
    onSelect: (Int) -> Unit,
) {
    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(aiMarkdown(text), color = Theme.colors.textBright)
        PatientAnswerScale(selection = selection, accent = accent, editable = editable, onSelect = onSelect)
    }
}

@Composable
private fun PatientAnswerScale(
    selection: Int?,
    accent: Color,
    editable: Boolean,
    onSelect: (Int) -> Unit,
) {
    val colors = Theme.colors
    val shape = RoundedCornerShape(8.dp)
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        (0..3).forEach { value ->
            val selected = selection == value
            Box(
                modifier = Modifier
                    .weight(1f)
                    .background(if (selected) colors.gold else colors.elevated, shape)
                    .border(1.dp, if (selected) colors.gold else accent.copy(alpha = 0.35f), shape)
                    .clickable(enabled = editable) { onSelect(value) }
                    .padding(vertical = 10.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    "$value",
                    color = if (selected) colors.textOnAccent else colors.textBright,
                    fontWeight = FontWeight.Medium,
                )
            }
        }
    }
}

@Composable
private fun PatientInterferenceBlock(
    options: Array<String>,
    selection: Int?,
    editable: Boolean,
    onSelect: (Int) -> Unit,
) {
    val colors = Theme.colors
    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(aiMarkdown(stringResource(R.string.phq9_interference_question)), color = colors.textBright)
        options.forEachIndexed { index, option ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(enabled = editable) { onSelect(index) },
                verticalAlignment = Alignment.CenterVertically,
            ) {
                RadioButton(
                    selected = selection == index,
                    onClick = { if (editable) onSelect(index) },
                    enabled = editable,
                    colors = RadioButtonDefaults.colors(
                        selectedColor = colors.gold,
                        unselectedColor = colors.textBody,
                    ),
                )
                Text(option, color = colors.textBright, modifier = Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun PatientScoreBlock(score: Int, classification: String) {
    val colors = Theme.colors
    Row(
        modifier = Modifier.fillMaxWidth().padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            stringResource(R.string.total_score_line, score),
            color = colors.textBright,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.weight(1f),
        )
        Text(classification, color = colors.textBody, fontSize = 14.sp)
    }
}
