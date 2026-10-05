package com.cbtipul.app.ui.patient

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringArrayResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.cbtipul.app.R
import com.cbtipul.app.data.*
import com.cbtipul.app.model.CombinedMoodQuestionnaire
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.themedScreen

data class SubmissionReviewSection(val title: String, val lines: List<String>)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PatientSubmissionReview(sections: List<SubmissionReviewSection>, onEdit: (Int) -> Unit, onSend: () -> Unit) {
    Dialog(onDismissRequest = { onEdit(0) }, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        BackHandler { onEdit(0) }
        Scaffold(modifier = Modifier.fillMaxSize().themedScreen(Theme.colors.gold).safeDrawingPadding(), containerColor = Theme.colors.base,
            topBar = { TopAppBar(title = { Text(stringResource(R.string.review_before_sending)) }, navigationIcon = {
                TextButton(onClick = { onEdit(0) }) { Text(stringResource(R.string.back)) }
            }) },
            bottomBar = { Button(onClick = onSend, modifier = Modifier.fillMaxWidth().padding(16.dp)) { Text(stringResource(R.string.patient_diary_one_save_action)) } },
        ) { padding ->
            Column(Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Text(stringResource(R.string.review_sharing_explanation), color = Theme.colors.textBody)
                sections.forEachIndexed { index, section ->
                    Card(colors = CardDefaults.cardColors(containerColor = Theme.colors.surface)) {
                        Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Row {
                                Text(section.title, modifier = Modifier.weight(1f), color = Theme.colors.textBright, style = MaterialTheme.typography.titleMedium)
                                TextButton(onClick = { onEdit(index) }) { Text(stringResource(R.string.review_edit)) }
                            }
                            section.lines.forEach { Text(it.ifBlank { stringResource(R.string.review_not_provided) }, color = Theme.colors.textBody) }
                        }
                    }
                }
            }
        }
    }
}

@Composable fun reviewSections(draft: DiaryOneEntryDraft) = listOf(
    SubmissionReviewSection(stringResource(R.string.diary_one_event_title), listOf(draft.event)),
    SubmissionReviewSection(stringResource(R.string.diary_one_thought_title), draft.persistedAutomaticThoughts),
    SubmissionReviewSection(stringResource(R.string.diary_feelings_title), draft.feelings.map { "${it.name} — ${it.intensity}%" }),
    SubmissionReviewSection(stringResource(R.string.diary_one_behaviour_title), listOf(draft.behaviour)),
    SubmissionReviewSection(stringResource(R.string.diary_one_physical_title), listOf(draft.physicalSymptoms)),
)
@Composable fun reviewSections(draft: DiaryTwoEntryDraft) = listOf(
    SubmissionReviewSection(stringResource(R.string.diary_one_event_title), listOf(draft.event)),
    SubmissionReviewSection(stringResource(R.string.diary_one_thought_title), draft.persistedAutomaticThoughts),
    SubmissionReviewSection(stringResource(R.string.diary_feelings_title), draft.feelings.map { "${it.name} — ${it.intensity}%" }),
    SubmissionReviewSection(stringResource(R.string.diary_thinking_errors_title), draft.thinkingErrors.map { stringResource(it.title) }),
    SubmissionReviewSection(stringResource(R.string.diary_alternative_thoughts_title), draft.persistedAlternativeThoughts),
)
@Composable fun reviewSections(draft: PatientDiaryThreeDraft): List<SubmissionReviewSection> {
    val entry = draft.entry
    return listOf(
        SubmissionReviewSection(stringResource(R.string.diary_three_situation_title), listOf(entry.situation)),
        SubmissionReviewSection(stringResource(R.string.diary_three_belief_before), entry.automaticThoughts.map { "${it.text} — ${it.beliefBefore}%" }),
        SubmissionReviewSection(stringResource(R.string.diary_three_feelings_before), entry.feelings.map { "${it.name} — ${it.intensityBefore}%" }),
        SubmissionReviewSection(stringResource(R.string.diary_thinking_errors_title), entry.thinkingErrors.map { stringResource(it.title) }),
        SubmissionReviewSection(stringResource(R.string.diary_alternative_thoughts_title), entry.alternativeThoughts.map { "${it.text} — ${it.belief}%" }),
        SubmissionReviewSection(stringResource(R.string.diary_three_thoughts_after), entry.automaticThoughts.map { "${it.text} — ${it.beliefAfter}%" }),
        SubmissionReviewSection(stringResource(R.string.diary_three_feelings_after), entry.feelings.map { "${it.name} — ${it.intensityAfter}%" }),
    )
}
@Composable fun reviewSections(draft: CombinedMoodQuestionnaire): List<SubmissionReviewSection> {
    val answers = stringArrayResource(R.array.answer_descriptions)
    val missing = stringResource(R.string.review_not_provided)
    return stringArrayResource(R.array.gad7_questions).mapIndexed { index, question -> SubmissionReviewSection(question, listOf(draft.gad7Answers.getOrNull(index)?.let { answers.getOrNull(it) } ?: missing)) } +
        stringArrayResource(R.array.phq9_questions).mapIndexed { index, question -> SubmissionReviewSection(question, listOf(draft.phq9Answers.getOrNull(index)?.let { answers.getOrNull(it) } ?: missing)) } +
        SubmissionReviewSection(stringResource(R.string.phq9_interference_question), listOf(draft.interferenceLevel?.let { stringArrayResource(R.array.phq9_interference_options).getOrNull(it) } ?: missing))
}
