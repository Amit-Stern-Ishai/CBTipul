package com.cbtipul.app.ui.patients

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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.background
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Description
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
    onCreateSession: (patientId: String) -> Unit,
) {
    val colors = Theme.colors
    val patients by viewModel.patients.collectAsStateWithLifecycle()
    val questionnaires by viewModel.questionnaires.collectAsStateWithLifecycle()
    val ui by viewModel.ui.collectAsStateWithLifecycle()
    val groups = remember(patients, unnamed) { GlobalSessions.grouped(patients, unnamed) }
    var pickingPatient by remember { mutableStateOf(false) }
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
                    IconButton(onClick = { pickingPatient = true }) {
                        Icon(Icons.Outlined.Add, contentDescription = stringResource(R.string.add_session_action), tint = colors.gold)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            when {
                patients.isEmpty() && ui.isLoading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = colors.gold)
                }
                groups.isEmpty() -> Column(
                    Modifier.fillMaxSize().padding(32.dp),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(stringResource(R.string.empty_sessions_title), color = colors.textBright, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center)
                    Spacer(Modifier.height(8.dp))
                    Text(stringResource(R.string.empty_sessions_body), color = colors.textBody, textAlign = TextAlign.Center)
                }
                else -> LazyColumn(Modifier.weight(1f).fillMaxWidth(), contentPadding = PaddingValues(horizontal = 24.dp, vertical = 8.dp)) {
                    groups.forEach { group ->
                        item(key = "month-${group.month.time}") {
                            Text(
                                hebrewMonthYear(group.month),
                                color = colors.gold,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.padding(top = 12.dp, bottom = 4.dp),
                            )
                        }
                        item(key = "group-${group.month.time}") {
                            GroupedListCard(accent = colors.gold) {
                                group.items.forEachIndexed { row, item ->
                                    val sessionKey = item.session.databaseId?.queryValue ?: item.session.id.toString()
                                    val records = questionnaires[item.patient.id.queryValue].orEmpty()
                                    val linked = GlobalSessions.linkedQuestionnaire(item.session, records)
                                    Row(
                                        Modifier.fillMaxWidth().clickable {
                                            onOpenSession(item.patient.id.queryValue, sessionKey)
                                        }.padding(horizontal = 16.dp, vertical = 10.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                                    ) {
                                        Box(
                                            Modifier.size(34.dp).background(colors.goldGhost, CircleShape),
                                            contentAlignment = Alignment.Center,
                                        ) {
                                            Text("${item.number}", color = colors.gold, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                        }
                                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                            Text(item.patient.displayName(unnamed), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                                            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                                                Text(hebrewDate(item.session.date), color = colors.textBody, fontSize = 14.sp)
                                                if (linked != null) {
                                                    Icon(Icons.Outlined.Description, contentDescription = null, tint = colors.textBody, modifier = Modifier.size(16.dp))
                                                }
                                            }
                                            item.session.type?.let {
                                                Text(stringResource(it.labelRes()), color = colors.textBody, fontSize = 13.sp)
                                            }
                                        }
                                    }
                                    if (row < group.items.lastIndex) GroupedListDivider(startInset = 62.dp)
                                }
                            }
                        }
                    }
                }
            }
            Button(
                onClick = { pickingPatient = true },
                modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(top = 8.dp, bottom = 12.dp),
                colors = ButtonDefaults.buttonColors(containerColor = colors.gold, contentColor = colors.textOnAccent),
            ) {
                Text(stringResource(if (groups.isEmpty()) R.string.empty_sessions_primary_action else R.string.add_session_action))
            }
        }
    }

    if (pickingPatient) {
        AlertDialog(
            onDismissRequest = { pickingPatient = false },
            title = { Text(stringResource(R.string.choose_patient_for_session)) },
            text = {
                LazyColumn {
                    val active = GlobalSessions.activePatients(patients)
                    val inactive = GlobalSessions.inactivePatients(patients)
                    if (active.isNotEmpty()) {
                        item { Text(stringResource(R.string.patient_status_active), fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(vertical = 8.dp)) }
                        items(active, key = { it.id.queryValue }) { patient ->
                            PatientPickRow(patient, unnamed) {
                                pickingPatient = false
                                onCreateSession(patient.id.queryValue)
                            }
                        }
                    }
                    if (inactive.isNotEmpty()) {
                        item { Text(stringResource(R.string.patient_status_inactive), fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(vertical = 8.dp)) }
                        items(inactive, key = { it.id.queryValue }) { patient ->
                            PatientPickRow(patient, unnamed) {
                                pickingPatient = false
                                onCreateSession(patient.id.queryValue)
                            }
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { pickingPatient = false }) { Text(stringResource(R.string.cancel)) }
            },
        )
    }
}

@Composable
private fun PatientPickRow(patient: Patient, unnamed: String, onClick: () -> Unit) {
    Text(
        patient.displayName(unnamed),
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = 10.dp),
    )
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
