package com.cbtipul.app.ui.patients

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Assignment
import androidx.compose.material.icons.outlined.Book
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.cbtipul.app.CbTipulApp
import com.cbtipul.app.R
import com.cbtipul.app.data.*
import com.cbtipul.app.model.Patient
import com.cbtipul.app.ui.theme.*
import java.util.Date

private data class RecentSubmission(val route: String, val title: Int, val date: Date)

@Composable
fun PatientRecentActivity(patient: Patient, isDemo: Boolean, onOpen: (String) -> Unit) {
    val app = LocalContext.current.applicationContext as CbTipulApp
    val one by app.diaryOne.entries.collectAsStateWithLifecycle()
    val two by app.diaryTwo.entries.collectAsStateWithLifecycle()
    val three by app.diaryThree.entries.collectAsStateWithLifecycle()
    val questionnaires by app.patientRepository.questionnaires.collectAsStateWithLifecycle()
    val id = patient.id.queryValue
    val cutoff = patient.sessions.map { it.date }.filter { !it.after(Date()) }.maxOrNull()
    var failed by remember(id) { mutableStateOf(false) }
    var dismissed by remember(id) { mutableStateOf(false) }
    var expanded by remember(id) { mutableStateOf(false) }
    var revision by remember(id) { mutableIntStateOf(0) }
    val items = buildList {
        one[id].orEmpty().filter { it.createdBy == DiaryOneEntryCreator.Patient }.forEach { add(RecentSubmission("patient/$id/diary-one?entry=${it.id}", R.string.diary_one_title, it.createdAt)) }
        two[id].orEmpty().filter { it.createdBy == DiaryOneEntryCreator.Patient }.forEach { add(RecentSubmission("patient/$id/diary-two?entry=${it.id}", R.string.diary_two_title, it.createdAt)) }
        three[id].orEmpty().filter { it.createdBy == DiaryOneEntryCreator.Patient }.forEach { add(RecentSubmission("patient/$id/diary-three?entry=${it.id}", R.string.diary_three_title, it.createdAt)) }
        questionnaires[id].orEmpty().filter { it.createdBy == "patient" }.forEach { add(RecentSubmission("patient/$id/questionnaire-result/${it.databaseId.queryValue}", R.string.questionnaire_item_title, it.answeredDate)) }
    }.filter { cutoff == null || it.date.after(cutoff) }.sortedByDescending { it.date }
    LaunchedEffect(id, revision) {
        if (!isDemo) {
            failed = false
            try { app.patientRepository.loadQuestionnaires(patient.id) } catch (_: Exception) { failed = true }
            try { app.diaryOne.loadEntries(patient.id) } catch (_: Exception) { failed = true }
            try { app.diaryTwo.loadEntries(patient.id) } catch (_: Exception) { failed = true }
            try { app.diaryThree.loadEntries(patient.id) } catch (_: Exception) { failed = true }
        }
    }
    if (items.isEmpty() || dismissed) return

    GroupedListCard(accent = Theme.colors.gold) {
        Column(Modifier.padding(horizontal = 14.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(stringResource(if (cutoff == null) R.string.recent_patient_submissions else R.string.since_last_session),
                        style = MaterialTheme.typography.titleMedium, lineHeight = 20.sp, color = Theme.colors.textBright)
                    if (cutoff != null) Text(stringResource(R.string.recent_since_date, hebrewDate(cutoff)),
                        color = Theme.colors.textBody, fontSize = 12.sp, lineHeight = 16.sp)
                }
                FilledTonalIconButton(onClick = { dismissed = true },
                    colors = IconButtonDefaults.filledTonalIconButtonColors(
                        containerColor = Theme.colors.elevated, contentColor = Theme.colors.textBright)) {
                    Icon(Icons.Outlined.Close, contentDescription = stringResource(R.string.close_action),
                        modifier = Modifier.size(18.dp), tint = Theme.colors.textBright)
                }
            }
            if (items.isNotEmpty()) {
                TextButton(onClick = { expanded = !expanded }, contentPadding = PaddingValues(0.dp)) { Text(stringResource(R.string.recent_submission_count, items.size) + " · " + stringResource(if (expanded) R.string.close_action else R.string.recent_view)) }
                if (expanded) items.forEach { item ->
                    Row(Modifier.fillMaxWidth().clickable { onOpen(item.route) }.padding(vertical = 10.dp),
                        horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(if (item.title == R.string.questionnaire_item_title) Icons.Outlined.Assignment else Icons.Outlined.Book,
                            contentDescription = null, tint = Theme.colors.gold, modifier = Modifier.size(22.dp))
                        Column {
                            Text(stringResource(item.title), color = Theme.colors.textBright)
                            Text(hebrewDate(item.date), color = Theme.colors.textBody, fontSize = 12.sp, lineHeight = 16.sp)
                        }
                    }
                }
            }
            if (failed) {
                Text(stringResource(R.string.recent_refresh_failed), color = Theme.colors.error)
                TextButton(onClick = { revision++ }) { Text(stringResource(R.string.retry)) }
            }
        }
    }
}
