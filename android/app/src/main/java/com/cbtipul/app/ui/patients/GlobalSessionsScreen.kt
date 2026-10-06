package com.cbtipul.app.ui.patients

import com.cbtipul.app.ui.entitlementCreateControl
import androidx.compose.material.icons.outlined.EventAvailable
import androidx.compose.material.icons.outlined.Search
import com.cbtipul.app.ui.theme.PrimaryActionButton
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
import androidx.compose.foundation.lazy.rememberLazyListState
import com.cbtipul.app.ui.therapist.TabReselectionEffect
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.cbtipul.app.R
import com.cbtipul.app.data.GlobalSessions
import com.cbtipul.app.model.Patient
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.GroupedListDivider
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.hebrewDate
import com.cbtipul.app.ui.theme.hebrewMonthYear
import com.cbtipul.app.ui.theme.themedScreen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GlobalSessionsScreen(
    viewModel: PatientListViewModel,
    unnamed: String,
    onOpenSession: (patientId: String, sessionId: String) -> Unit,
    onCreateSession: () -> Unit,
) {
    val hasRecovery = rememberSessionRecovery("_:new")
    val colors = Theme.colors
    val listState = rememberLazyListState()
    TabReselectionEffect { listState.animateScrollToItem(0) }
    val patients by viewModel.patients.collectAsStateWithLifecycle()
    val questionnaires by viewModel.questionnaires.collectAsStateWithLifecycle()
    val ui by viewModel.ui.collectAsStateWithLifecycle()
    var query by remember { mutableStateOf("") }
    val upcoming = GlobalSessions.timeline(patients, unnamed, query, true)
    val past = GlobalSessions.timeline(patients, unnamed, query, false)
    val groups = upcoming + past
    val notConfigured = stringResource(R.string.supabase_not_configured_error)
    val rejected = stringResource(R.string.update_rejected_error)

    LaunchedEffect(patients.map { it.id.queryValue }) {
        patients.forEach { patient ->
            if (questionnaires[patient.id.queryValue] == null) {
                viewModel.loadQuestionnaires(patient.id, notConfigured, rejected)
            }
        }
    }

    Scaffold(
        modifier = Modifier.themedScreen(colors.gold),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.therapist_tab_sessions), color = colors.textBright) },
                actions = {
                    IconButton(onClick = onCreateSession, modifier = Modifier.entitlementCreateControl()) {
                        Icon(Icons.Outlined.Add, contentDescription = stringResource(R.string.add_session_action), tint = colors.gold)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            OutlinedTextField(value = query, onValueChange = { query = it }, singleLine = true,
                label = { Text(stringResource(R.string.sessions_search_prompt)) },
                leadingIcon = { Icon(Icons.Outlined.Search, contentDescription = null) },
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp))
            when {
                patients.isEmpty() && ui.isLoading -> Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = colors.gold)
                }
                groups.isEmpty() -> Column(
                    Modifier.weight(1f).fillMaxWidth().padding(32.dp),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Icon(if (query.isBlank()) Icons.Outlined.EventAvailable else Icons.Outlined.Search, contentDescription = null, tint = colors.textBody, modifier = Modifier.size(48.dp).padding(bottom = 12.dp))
                    Text(stringResource(if (query.isBlank()) R.string.empty_sessions_title else R.string.sessions_search_empty), color = colors.textBright, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center)
                    Spacer(Modifier.height(8.dp))
                    Text(stringResource(R.string.empty_sessions_body), color = colors.textBody, textAlign = TextAlign.Center)
                }
                else -> LazyColumn(state = listState, modifier = Modifier.weight(1f).fillMaxWidth(), contentPadding = PaddingValues(horizontal = 24.dp, vertical = 8.dp)) {
                    listOf(true to upcoming, false to past).forEach { (isUpcoming, section) ->
                    item(key = "section-$isUpcoming") {
                        Text(stringResource(if (isUpcoming) R.string.upcoming_sessions_section else R.string.past_sessions_section),
                            fontWeight = FontWeight.Bold, color = colors.textBright, modifier = Modifier.padding(top = 14.dp))
                        if (isUpcoming && section.isEmpty()) Text(stringResource(R.string.no_upcoming_sessions_body), color = colors.textBody)
                    }
                    section.forEach { group ->
                        item(key = "month-$isUpcoming-${group.month.time}") {
                            Text(
                                hebrewMonthYear(group.month),
                                color = colors.gold,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.padding(top = 8.dp, bottom = 4.dp),
                            )
                        }
                        item(key = "group-$isUpcoming-${group.month.time}") {
                            GroupedListCard(accent = colors.gold) {
                                group.items.forEachIndexed { row, item ->
                                    val sessionKey = item.session.databaseId?.queryValue ?: item.session.id.toString()
                                    val records = questionnaires[item.patient.id.queryValue].orEmpty()
                                    val patientSessions = item.patient.sessions.sortedByDescending { it.date.time }
                                    SessionListRow(
                                        session = item.session,
                                        number = item.number,
                                        patientName = item.patient.displayName(unnamed),
                                        scores = sessionScores(
                                            item.session,
                                            patientSessions.indexOfFirst { it.id == item.session.id },
                                            patientSessions,
                                            records,
                                        ),
                                        onClick = { onOpenSession(item.patient.id.queryValue, sessionKey) },
                                    )
                                    if (row < group.items.lastIndex) GroupedListDivider(startInset = 0.dp)
                                }
                            }
                        }
                    }
                }
            }
            }
            PrimaryActionButton(
                label = stringResource(if (hasRecovery) R.string.resume_session_summary else if (groups.isEmpty()) R.string.empty_sessions_primary_action else R.string.add_session_action),
                icon = Icons.Outlined.Add,
                onClick = onCreateSession,
                modifier = Modifier.padding(horizontal = 16.dp).padding(top = 6.dp, bottom = 8.dp).entitlementCreateControl(),
            )
        }
    }

}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LibraryPlaceholderScreen() {
    val colors = Theme.colors
    Scaffold(
        modifier = Modifier.themedScreen(colors.gold),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.therapist_tab_library), color = colors.textBright) },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding).padding(24.dp), contentAlignment = Alignment.Center) {
            Text(stringResource(R.string.library_placeholder_body), color = colors.textBody, textAlign = TextAlign.Center)
        }
    }
}
