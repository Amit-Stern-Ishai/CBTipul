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

internal data class RecentSubmission(val id: String, val route: String, val title: Int, val date: Date)

/** Both list badges and detail rows use the same cached, patient-authored records. */
internal fun recentSubmissions(
    patient: Patient, one: List<DiaryOneEntry>, two: List<DiaryTwoEntry>, three: List<DiaryThreeEntry>,
    questionnaires: List<com.cbtipul.app.model.CompletedQuestionnaire>,
    dismissals: RecentActivityDismissals, owner: String?, now: Date = Date(),
): List<RecentSubmission> {
    val id = patient.id.queryValue
    val cutoff = patient.sessions.map { it.date }.filter { !it.after(now) }.maxOrNull()
    return buildList {
        one.filter { it.createdBy == DiaryOneEntryCreator.Patient }.forEach { add(RecentSubmission("diary-one-${it.id}", "patient/$id/diary-one?entry=${it.id}", R.string.diary_one_title, it.createdAt)) }
        two.filter { it.createdBy == DiaryOneEntryCreator.Patient }.forEach { add(RecentSubmission("diary-two-${it.id}", "patient/$id/diary-two?entry=${it.id}", R.string.diary_two_title, it.createdAt)) }
        three.filter { it.createdBy == DiaryOneEntryCreator.Patient }.forEach { add(RecentSubmission("diary-three-${it.id}", "patient/$id/diary-three?entry=${it.id}", R.string.diary_three_title, it.createdAt)) }
        questionnaires.filter { it.createdBy == "patient" }.forEach { add(RecentSubmission("questionnaire-${it.databaseId.queryValue}", "patient/$id/questionnaire-result/${it.databaseId.queryValue}", R.string.questionnaire_item_title, it.answeredDate)) }
    }.filter { (cutoff == null || it.date.after(cutoff)) && !dismissals.contains(it.id, owner, id) }
        .sortedWith(compareByDescending<RecentSubmission> { it.date }.thenBy { it.id })
}

@Composable
fun PatientRecentActivity(patient: Patient, isDemo: Boolean, onOpen: (String) -> Unit) {
    val app = LocalContext.current.applicationContext as CbTipulApp
    val one by app.diaryOne.entries.collectAsStateWithLifecycle()
    val two by app.diaryTwo.entries.collectAsStateWithLifecycle()
    val three by app.diaryThree.entries.collectAsStateWithLifecycle()
    val questionnaires by app.patientRepository.questionnaires.collectAsStateWithLifecycle()
    val id = patient.id.queryValue
    val cutoff = patient.sessions.map { it.date }.filter { !it.after(Date()) }.maxOrNull()
    val activityIdentity by Entitlements.state.collectAsStateWithLifecycle()
    val owner = if (isDemo) "local-demo" else activityIdentity.identity
    var failed by remember(id, owner) { mutableStateOf(false) }
    var dismissed by remember(id, owner) { mutableStateOf(false) }
    var expanded by remember(id, owner) { mutableStateOf(false) }
    var revision by remember(id, owner) { mutableIntStateOf(0) }
    val dismissals = app.recentActivityDismissals
    val dismissalRevision by dismissals.revision.collectAsStateWithLifecycle()
    val items = remember(patient, one, two, three, questionnaires, owner, dismissalRevision) {
        recentSubmissions(patient, one[id].orEmpty(), two[id].orEmpty(), three[id].orEmpty(),
            questionnaires[id].orEmpty(), dismissals, owner)
    }
    LaunchedEffect(id, owner, revision) {
        if (!isDemo && owner != null) {
            failed = false
            try { app.patientRepository.loadQuestionnaires(patient.id) } catch (e: kotlinx.coroutines.CancellationException) { throw e } catch (_: Exception) { failed = true }
            try { app.diaryOne.loadEntries(patient.id) } catch (e: kotlinx.coroutines.CancellationException) { throw e } catch (_: Exception) { failed = true }
            try { app.diaryTwo.loadEntries(patient.id) } catch (e: kotlinx.coroutines.CancellationException) { throw e } catch (_: Exception) { failed = true }
            try { app.diaryThree.loadEntries(patient.id) } catch (e: kotlinx.coroutines.CancellationException) { throw e } catch (_: Exception) { failed = true }
        }
    }
    if (items.isEmpty() && (dismissed || !failed)) return

    RecentActivityCard(items, cutoff, failed, expanded, onExpand = { expanded = !expanded },
        onDismiss = { dismissals.dismiss(items.map { it.id }, owner, id); dismissed = true },
        onRetry = { revision++ }, onOpen = onOpen)
}

@Composable
internal fun RecentActivityCard(items: List<RecentSubmission>, cutoff: Date?, failed: Boolean, expanded: Boolean,
    onExpand: () -> Unit, onDismiss: () -> Unit, onRetry: () -> Unit, onOpen: (String) -> Unit) {
    GroupedListCard(accent = Theme.colors.gold) {
        Column(Modifier.padding(horizontal = 14.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(stringResource(if (cutoff == null) R.string.recent_patient_submissions else R.string.since_last_session),
                        style = MaterialTheme.typography.titleMedium, lineHeight = 20.sp, color = Theme.colors.textBright)
                    if (cutoff != null) Text(stringResource(R.string.recent_since_date, hebrewDate(cutoff)),
                        color = Theme.colors.textBody, fontSize = 12.sp, lineHeight = 16.sp)
                }
                FilledTonalIconButton(onClick = onDismiss,
                    colors = IconButtonDefaults.filledTonalIconButtonColors(
                        containerColor = Theme.colors.elevated, contentColor = Theme.colors.textBright)) {
                    Icon(Icons.Outlined.Close, contentDescription = stringResource(R.string.close_action),
                        modifier = Modifier.size(18.dp), tint = Theme.colors.textBright)
                }
            }
            if (items.isNotEmpty()) {
                Text(stringResource(R.string.recent_submission_count, items.size), style = MaterialTheme.typography.titleSmall)
                items.take(if (expanded) items.size else 3).forEach { item ->
                    Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(role = androidx.compose.ui.semantics.Role.Button) { onOpen(item.route) }.padding(vertical = 10.dp),
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
            if (items.size > 3) TextButton(onClick = onExpand) {
                Text(if (expanded) stringResource(R.string.recent_show_less) else stringResource(R.string.recent_show_all, items.size))
            }
            if (failed) {
                Text(stringResource(R.string.recent_refresh_failed), color = Theme.colors.error)
                TextButton(onClick = onRetry) { Text(stringResource(R.string.retry)) }
            }
        }
    }
}
