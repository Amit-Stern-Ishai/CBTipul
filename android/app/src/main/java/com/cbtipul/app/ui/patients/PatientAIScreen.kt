package com.cbtipul.app.ui.patients

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringArrayResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.cbtipul.app.CbTipulApp
import com.cbtipul.app.R
import com.cbtipul.app.data.AiPrompts
import com.cbtipul.app.model.CBTSessionAnalysis
import com.cbtipul.app.model.ChatTurn
import com.cbtipul.app.model.CompletedQuestionnaire
import com.cbtipul.app.model.FollowUpStatus
import com.cbtipul.app.model.GAD7Severity
import com.cbtipul.app.model.PHQ9Severity
import com.cbtipul.app.model.Patient
import com.cbtipul.app.settings.AIResponseStyle
import com.cbtipul.app.ui.theme.Theme
import java.text.DateFormat
import java.util.Locale
import java.util.UUID
import kotlinx.coroutines.delay

private data class ChatEntry(
    val id: UUID = UUID.randomUUID(),
    val role: String,
    val text: String,
    val displayed: String? = null,
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PatientAIScreen(
    patient: Patient?,
    unnamed: String,
    questionnaires: List<CompletedQuestionnaire>,
    errorMessage: String?,
    onBack: () -> Unit,
    onSend: (String, List<ChatTurn>, (String) -> Unit, () -> Unit) -> Unit,
) {
    val colors = Theme.colors
    val app = LocalContext.current.applicationContext as CbTipulApp
    val style by app.preferences.aiResponseStyle.collectAsStateWithLifecycle(AIResponseStyle.Typing)
    val gad7Questions = stringArrayResource(R.array.gad7_questions).toList()
    val phq9Questions = stringArrayResource(R.array.phq9_questions).toList()
    val interference = stringArrayResource(R.array.phq9_interference_options).toList()
    val gadMin = stringResource(R.string.gad7_severity_minimal)
    val gadMild = stringResource(R.string.gad7_severity_mild)
    val gadSub = stringResource(R.string.gad7_severity_substantial)
    val gadExt = stringResource(R.string.gad7_severity_extreme)
    val phqMin = stringResource(R.string.phq9_severity_minimal)
    val phqMild = stringResource(R.string.phq9_severity_mild)
    val phqMod = stringResource(R.string.phq9_severity_moderate)
    val phqModSev = stringResource(R.string.phq9_severity_moderately_severe)
    val phqSev = stringResource(R.string.phq9_severity_severe)
    val suggested = stringArrayResource(R.array.ai_suggested_questions).toList()
    val dateFormat = remember { DateFormat.getDateInstance(DateFormat.MEDIUM, Locale("iw")) }

    if (patient == null) {
        Column(Modifier.fillMaxSize().padding(24.dp)) {
            Text(stringResource(R.string.unnamed_patient), color = colors.textBright)
            TextButton(onClick = onBack) { Text(stringResource(R.string.back), color = colors.gold) }
        }
        return
    }

    var entries by remember { mutableStateOf(listOf<ChatEntry>()) }
    var prompt by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    val listState = rememberLazyListState()
    val digest = remember(patient, questionnaires) {
        fullContext(
            patient,
            questionnaires,
            gad7Questions,
            phq9Questions,
            interference,
            dateFormat,
            gad = { when (it) { GAD7Severity.Minimal -> gadMin; GAD7Severity.Mild -> gadMild; GAD7Severity.Substantial -> gadSub; GAD7Severity.Extreme -> gadExt } },
            phq = { when (it) { PHQ9Severity.Minimal -> phqMin; PHQ9Severity.Mild -> phqMild; PHQ9Severity.Moderate -> phqMod; PHQ9Severity.ModeratelySevere -> phqModSev; PHQ9Severity.Severe -> phqSev } },
        )
    }

    val typingId = entries.lastOrNull()?.takeIf { it.role == "assistant" && it.displayed != null }?.id
    LaunchedEffect(typingId, style) {
        val entry = entries.lastOrNull() ?: return@LaunchedEffect
        if (entry.role != "assistant" || entry.displayed == null) return@LaunchedEffect
        if (style != AIResponseStyle.Typing) {
            entries = entries.map { if (it.id == entry.id) it.copy(displayed = null) else it }
            return@LaunchedEffect
        }
        val words = entry.text.split(Regex("(?<=\\s)"))
        var shown = ""
        for (word in words) {
            shown += word
            entries = entries.map { if (it.id == entry.id) it.copy(displayed = shown) else it }
            delay(30)
        }
        entries = entries.map { if (it.id == entry.id) it.copy(displayed = null) else it }
    }

    LaunchedEffect(entries.size, isLoading) {
        if (entries.isNotEmpty()) listState.animateScrollToItem(entries.lastIndex)
    }

    fun send(question: String) {
        val trimmed = question.trim()
        if (trimmed.isEmpty() || isLoading) return
        prompt = ""
        val user = ChatEntry(role = "user", text = trimmed)
        entries = entries + user
        isLoading = true
        val turns = (entries).map { ChatTurn(it.role, it.text) }
        val system = "${AiPrompts.SYSTEM}\n\n=== Patient data ===\n$digest"
        onSend(system, turns, { answer ->
            entries = entries + ChatEntry(
                role = "assistant",
                text = answer,
                displayed = if (style == AIResponseStyle.Typing) "" else null,
            )
        }) { isLoading = false }
    }

    Scaffold(
        containerColor = colors.base,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.ai_chat_navigation_title), color = colors.textBright) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = stringResource(R.string.back), tint = colors.gold)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = colors.base),
            )
        },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            Box(Modifier.weight(1f).fillMaxWidth()) {
                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    items(entries, key = { it.id }) { entry ->
                        val mine = entry.role == "user"
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = if (mine) Arrangement.End else Arrangement.Start) {
                            Text(
                                entry.displayed ?: entry.text,
                                color = if (mine) colors.textOnAccent else colors.textBright,
                                modifier = Modifier
                                    .widthIn(max = 320.dp)
                                    .background(
                                        if (mine) colors.gold else colors.surface,
                                        RoundedCornerShape(18.dp),
                                    )
                                    .padding(horizontal = 14.dp, vertical = 10.dp),
                            )
                        }
                    }
                    if (isLoading) {
                        item {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                CircularProgressIndicator(Modifier.size(18.dp), color = colors.gold, strokeWidth = 2.dp)
                                Text(stringResource(R.string.ai_thinking_label), color = colors.textBody)
                            }
                        }
                    }
                }
                if (entries.isEmpty() && !isLoading) {
                    Column(
                        modifier = Modifier.align(Alignment.Center).padding(24.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(stringResource(R.string.ai_title), color = colors.textBright, fontWeight = FontWeight.Bold)
                        Text(stringResource(R.string.ai_empty_message), color = colors.textBody)
                        suggested.forEach { question ->
                            TextButton(onClick = { prompt = question }) {
                                Text(question, color = colors.gold)
                            }
                        }
                    }
                }
            }
            errorMessage?.let { Text(it, color = colors.error, modifier = Modifier.padding(horizontal = 16.dp)) }
            Row(
                modifier = Modifier.fillMaxWidth().padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                OutlinedTextField(
                    value = prompt,
                    onValueChange = { prompt = it },
                    modifier = Modifier.weight(1f),
                    enabled = !isLoading,
                )
                Button(
                    onClick = { send(prompt) },
                    enabled = !isLoading && prompt.isNotBlank(),
                    colors = ButtonDefaults.buttonColors(containerColor = colors.gold, contentColor = colors.textOnAccent),
                ) {
                    Text(stringResource(R.string.ai_send_action))
                }
            }
            Spacer(Modifier.height(4.dp))
        }
    }
}

private fun fullContext(
    patient: Patient,
    questionnaires: List<CompletedQuestionnaire>,
    gad7Questions: List<String>,
    phq9Questions: List<String>,
    interference: List<String>,
    dateFormat: DateFormat,
    gad: (GAD7Severity) -> String,
    phq: (PHQ9Severity) -> String,
): String {
    val parts = mutableListOf<String>()
    if (patient.notes.isNotBlank()) {
        parts += "Patient notes (general, not tied to a session):\n${patient.notes.trim()}"
    }
    val sessions = patient.sessions.sortedBy { it.date.time }
    val recentReviewIds = sessions.filter { it.structuredNotes != null }.takeLast(5).map { it.id }.toSet()
    if (sessions.isEmpty()) {
        parts += "No sessions yet."
    } else {
        val lines = mutableListOf("Sessions:")
        sessions.forEach { session ->
            var line = "- Session on ${dateFormat.format(session.date)}"
            if (session.notes.isNotEmpty()) line += "\n  Notes: ${session.notes}"
            val analysis = session.structuredNotes
            if (analysis != null && session.id in recentReviewIds) {
                val digest = structuredContext(analysis).lines().joinToString("\n") { "  $it" }
                line += "\n  Structured AI review:\n$digest"
            }
            lines += line
        }
        parts += lines.joinToString("\n")
    }
    parts += "Questionnaires:\n" + questionnaireContext(questionnaires, gad7Questions, phq9Questions, interference, dateFormat, gad, phq)
    return parts.joinToString("\n\n")
}

private fun structuredContext(analysis: CBTSessionAnalysis): String {
    val lines = mutableListOf("Summary: ${analysis.sessionSummary}")
    if (analysis.possibleNats.isNotEmpty()) {
        lines += "Possible NATs:"
        analysis.possibleNats.forEach { nat ->
            val details = mutableListOf("situation: ${nat.situation}")
            nat.emotion?.takeIf { it.isNotBlank() }?.let { details += "emotion: $it" }
            nat.behavior?.takeIf { it.isNotBlank() }?.let { details += "behavior: $it" }
            details += "confidence: ${nat.confidence}"
            lines += "- ${nat.thought} (${details.joinToString()})"
        }
    }
    if (analysis.cbtCycles.isNotEmpty()) {
        lines += "CBT cycles:"
        analysis.cbtCycles.forEach { cycle ->
            val stages = listOfNotNull(
                cycle.triggerSituation, cycle.automaticThought, cycle.emotion,
                cycle.behavior, cycle.shortTermConsequence, cycle.longTermConsequence,
            ).filter { it.isNotBlank() }
            lines += "- ${stages.joinToString(" → ")} (confidence: ${cycle.confidence})"
        }
    }
    if (analysis.therapistHypotheses.isNotEmpty()) {
        lines += "Therapist hypotheses:"
        analysis.therapistHypotheses.forEach { lines += "- ${it.hypothesis} (confidence: ${it.confidence})" }
    }
    val open = analysis.followUpQuestions.filter {
        it.status != FollowUpStatus.Discussed && it.status != FollowUpStatus.NotRelevant
    }
    if (open.isNotEmpty()) {
        lines += "Open follow-up questions:"
        open.forEach { lines += "- ${it.question} (${it.reason})" }
    }
    if (analysis.assignmentsForNextWeek.isNotEmpty()) {
        lines += "Assignments for next week:"
        analysis.assignmentsForNextWeek.forEach { assignment ->
            var line = "- ${assignment.assignment}"
            assignment.details?.takeIf { it.isNotBlank() }?.let { line += " ($it)" }
            lines += line
        }
    }
    return lines.joinToString("\n")
}

private fun questionnaireContext(
    questionnaires: List<CompletedQuestionnaire>,
    gad7Questions: List<String>,
    phq9Questions: List<String>,
    interference: List<String>,
    dateFormat: DateFormat,
    gad: (GAD7Severity) -> String,
    phq: (PHQ9Severity) -> String,
): String {
    if (questionnaires.isEmpty()) return "No questionnaires have been filled in yet."
    return questionnaires.sortedBy { it.answeredDate.time }.joinToString("\n\n") { record ->
        val q = record.questionnaire
        buildString {
            append("Questionnaire answered on ${dateFormat.format(record.answeredDate)}:\n")
            append("GAD-7 (each answer 0-3):\n")
            gad7Questions.forEachIndexed { index, question ->
                val answer = q.gad7Answers.getOrNull(index)
                var line = "- $question: ${answer?.toString() ?: "unanswered"}"
                q.gad7Notes.getOrNull(index)?.takeIf { it.isNotEmpty() }?.let { line += " [note: $it]" }
                append(line).append('\n')
            }
            append("GAD-7 total: ${q.gad7Score} (${gad(q.gad7Severity)})\n")
            append("PHQ-9 (each answer 0-3):\n")
            phq9Questions.forEachIndexed { index, question ->
                val answer = q.phq9Answers.getOrNull(index)
                var line = "- $question: ${answer?.toString() ?: "unanswered"}"
                q.phq9Notes.getOrNull(index)?.takeIf { it.isNotEmpty() }?.let { line += " [note: $it]" }
                append(line).append('\n')
            }
            append("PHQ-9 total: ${q.phq9Score} (${phq(q.phq9Severity)})")
            val level = q.interferenceLevel
            if (level != null && level in interference.indices) {
                var line = "\nInterference: ${interference[level]} ($level)"
                if (q.interferenceNote.isNotEmpty()) line += " [note: ${q.interferenceNote}]"
                append(line)
            }
        }
    }
}
