package com.cbtipul.app.ui.patients

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.model.CombinedMoodQuestionnaire
import com.cbtipul.app.model.CompletedQuestionnaire
import com.cbtipul.app.model.Patient
import com.cbtipul.app.model.Session
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.GroupedListDivider
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.hebrewDate
import com.cbtipul.app.ui.onboarding.TutorialHighlight
import com.cbtipul.app.ui.onboarding.tutorialPulse
import com.cbtipul.app.ui.theme.themedScreen
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PatientSessionsScreen(
    patient: Patient?,
    unnamed: String,
    questionnaires: List<CompletedQuestionnaire>,
    onBack: () -> Unit,
    onAdd: () -> Unit,
    onOpenSession: (Session) -> Unit,
    onLoadQuestionnaires: () -> Unit,
    gettingStarted: com.cbtipul.app.ui.onboarding.GettingStartedRouter? = null,
) {
    val colors = Theme.colors
    val pulseAddSession = gettingStarted?.shouldPulse(TutorialHighlight.AddSession) == true

    LaunchedEffect(patient?.id?.queryValue) {
        gettingStarted?.setPlacement(
            com.cbtipul.app.ui.onboarding.TutorialCoachPlacement.Sessions,
            viewingPatientId = patient?.id,
        )
    }

    if (patient == null) {
        Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.Center) {
            Text(stringResource(R.string.unnamed_patient), color = colors.textBright)
            androidx.compose.material3.TextButton(onClick = onBack) {
                Text(stringResource(R.string.back), color = colors.gold)
            }
        }
        return
    }
    LaunchedEffect(patient.id.queryValue) { onLoadQuestionnaires() }
    val sorted = remember(patient.sessions) { patient.sessions.sortedByDescending { it.date.time } }
    val groups = remember(sorted) { groupByHebrewMonth(sorted) }
    val accent = PatientAvatarColor.background(patient.id)

    Scaffold(
        modifier = Modifier.themedScreen(PatientAvatarColor.background(patient.id)),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.sessions_title), color = colors.textBright) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = stringResource(R.string.back), tint = colors.gold)
                    }
                },
                actions = {
                    IconButton(
                        onClick = onAdd,
                        modifier = Modifier.tutorialPulse(pulseAddSession),
                    ) {
                        Icon(
                            Icons.Outlined.Add,
                            contentDescription = stringResource(R.string.add_session_action),
                            tint = colors.gold,
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            if (sorted.isEmpty()) {
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth()
                        .padding(horizontal = 32.dp),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        stringResource(R.string.empty_sessions_title),
                        color = colors.textBright,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 20.sp,
                        textAlign = TextAlign.Center,
                    )
                    Spacer(Modifier.height(12.dp))
                    Text(
                        stringResource(R.string.empty_sessions_body),
                        color = colors.textBody,
                        fontSize = 14.sp,
                        textAlign = TextAlign.Center,
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth(),
                    contentPadding = PaddingValues(horizontal = 24.dp, vertical = 8.dp),
                ) {
                    groups.forEach { group ->
                        item(key = "month-${group.month.time}") {
                            Text(
                                hebrewMonth(group.month),
                                color = colors.gold,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.padding(top = 12.dp, bottom = 4.dp),
                            )
                        }
                        item(key = "group-${group.month.time}") {
                            GroupedListCard(accent = accent) {
                                group.items.forEachIndexed { row, item ->
                                    val number = sorted.size - item.index
                                    val isLatest = item.session.id == sorted.firstOrNull()?.id
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .tutorialPulse(
                                                isLatest &&
                                                    gettingStarted?.shouldPulse(TutorialHighlight.LatestSession) == true,
                                            )
                                            .clickable { onOpenSession(item.session) }
                                            .padding(horizontal = 16.dp, vertical = 10.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                                    ) {
                                        Box(
                                            modifier = Modifier
                                                .size(34.dp)
                                                .background(colors.goldGhost, CircleShape),
                                            contentAlignment = Alignment.Center,
                                        ) {
                                            Text("$number", color = colors.gold, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                        }
                                        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                            Row(
                                                horizontalArrangement = Arrangement.spacedBy(6.dp),
                                                verticalAlignment = Alignment.CenterVertically,
                                            ) {
                                                Text(hebrewDate(item.session.date), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                                                if (item.session.structuredNotes != null) {
                                                    Icon(
                                                        Icons.Outlined.Description,
                                                        contentDescription = stringResource(R.string.has_structured_summary_label),
                                                        tint = colors.textBody,
                                                        modifier = Modifier.size(16.dp),
                                                    )
                                                }
                                            }
                                            item.session.type?.let {
                                                Text(stringResource(it.labelRes()), color = colors.textBody, fontSize = 14.sp)
                                            }
                                        }
                                        sessionScores(item.session, item.index, sorted, questionnaires)?.let { preview ->
                                            Column(verticalArrangement = Arrangement.spacedBy(4.dp), horizontalAlignment = Alignment.End) {
                                                GAD7ScoreCapsule(preview.first, preview.second)
                                                PHQ9ScoreCapsule(preview.first, preview.second)
                                            }
                                        }
                                    }
                                    if (row < group.items.lastIndex) {
                                        GroupedListDivider(startInset = 62.dp)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Button(
                onClick = onAdd,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp)
                    .padding(top = 8.dp, bottom = 12.dp)
                    .tutorialPulse(pulseAddSession),
                colors = ButtonDefaults.buttonColors(
                    containerColor = colors.gold,
                    contentColor = colors.textOnAccent,
                ),
            ) {
                Text(
                    stringResource(
                        if (sorted.isEmpty()) R.string.empty_sessions_primary_action
                        else R.string.add_session_action,
                    ),
                )
            }
        }
    }
}

private data class MonthGroup(
    val month: Date,
    val items: List<IndexedSession>,
)

private data class IndexedSession(val index: Int, val session: Session)

private fun groupByHebrewMonth(sortedNewestFirst: List<Session>): List<MonthGroup> {
    val calendar = Calendar.getInstance()
    return sortedNewestFirst
        .mapIndexed { index, session -> IndexedSession(index, session) }
        .groupBy { item ->
            calendar.time = item.session.date
            calendar.set(Calendar.DAY_OF_MONTH, 1)
            calendar.set(Calendar.HOUR_OF_DAY, 0)
            calendar.set(Calendar.MINUTE, 0)
            calendar.set(Calendar.SECOND, 0)
            calendar.set(Calendar.MILLISECOND, 0)
            calendar.time
        }
        .entries
        .sortedByDescending { it.key.time }
        .map { MonthGroup(it.key, it.value) }
}

private fun hebrewMonth(date: Date): String =
    SimpleDateFormat("LLLL yyyy", Locale.forLanguageTag("he-IL")).format(date)

private fun sessionScores(
    session: Session,
    index: Int,
    sortedNewestFirst: List<Session>,
    records: List<CompletedQuestionnaire>,
): Pair<CombinedMoodQuestionnaire, CombinedMoodQuestionnaire?>? {
    val sessionId = session.databaseId?.queryValue ?: return null
    val record = records.firstOrNull { it.sessionId?.queryValue == sessionId } ?: return null
    val previous = sortedNewestFirst.drop(index + 1).firstNotNullOfOrNull { earlier ->
        val earlierId = earlier.databaseId?.queryValue ?: return@firstNotNullOfOrNull null
        records.firstOrNull { it.sessionId?.queryValue == earlierId }
    }
    return record.questionnaire to previous?.questionnaire
}
