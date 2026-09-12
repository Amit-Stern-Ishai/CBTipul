package com.cbtipul.app.ui.patients

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Settings
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
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.cbtipul.app.R
import com.cbtipul.app.model.Patient
import com.cbtipul.app.model.PatientStatus
import com.cbtipul.app.model.SessionType
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.themedScreen
import java.text.DateFormat
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PatientListScreen(
    viewModel: PatientListViewModel,
    unnamed: String,
    onOpenPatient: (String) -> Unit,
    onOpenSettings: () -> Unit,
) {
    val patients by viewModel.patients.collectAsStateWithLifecycle()
    val ui by viewModel.ui.collectAsStateWithLifecycle()
    val colors = Theme.colors
    val notConfigured = stringResource(R.string.supabase_not_configured_error)
    val rejected = stringResource(R.string.update_rejected_error)

    Scaffold(
        modifier = Modifier.themedScreen(colors.gold),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.patients_title), color = colors.textBright) },
                navigationIcon = {
                    IconButton(onClick = onOpenSettings) {
                        Icon(Icons.Outlined.Settings, contentDescription = stringResource(R.string.settings_title), tint = colors.gold)
                    }
                },
                actions = {
                    IconButton(onClick = { viewModel.setAdding(true) }) {
                        Icon(Icons.Outlined.Add, contentDescription = stringResource(R.string.add_patient_action), tint = colors.gold)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
    ) { padding ->
        PullToRefreshBox(
            isRefreshing = ui.isLoading && patients.isNotEmpty(),
            onRefresh = viewModel::refresh,
            modifier = Modifier.fillMaxSize().padding(padding),
        ) {
            when {
                ui.isLoading && patients.isEmpty() -> {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            CircularProgressIndicator(color = colors.gold)
                            Spacer(Modifier.height(12.dp))
                            Text(stringResource(R.string.loading_patients_label), color = colors.textBody)
                        }
                    }
                }
                ui.loadError != null && patients.isEmpty() -> {
                    EmptyState(
                        title = stringResource(R.string.couldnt_load_patients_title),
                        message = ui.loadError.orEmpty(),
                        action = stringResource(R.string.retry),
                        onAction = viewModel::refresh,
                    )
                }
                patients.isEmpty() -> {
                    EmptyState(
                        title = stringResource(R.string.no_patients_title),
                        message = stringResource(R.string.add_first_patient_message),
                        action = stringResource(R.string.add_patient_action),
                        onAction = { viewModel.setAdding(true) },
                    )
                }
                else -> {
                    LazyColumn(
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        items(patients, key = { it.id.queryValue }) { patient ->
                            PatientRow(
                                patient = patient,
                                unnamed = unnamed,
                                onClick = { onOpenPatient(patient.id.queryValue) },
                            )
                        }
                    }
                }
            }
        }
    }

    if (ui.isAdding) {
        AddPatientSheet(
            isSaving = ui.isSavingAdd,
            errorMessage = ui.addError,
            onDismiss = { if (!ui.isSavingAdd) viewModel.setAdding(false) },
            onSave = { first, last, status ->
                viewModel.addPatient(first, last, status, notConfigured, rejected)
            },
        )
    }
}

@Composable
private fun PatientRow(patient: Patient, unnamed: String, onClick: () -> Unit) {
    val colors = Theme.colors
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(colors.surface, RoundedCornerShape(16.dp))
            .border(1.dp, colors.borderFaint, RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box {
            InitialsAvatar(name = patient.displayName(unnamed), patientId = patient.id)
            Box(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .size(12.dp)
                    .background(
                        if (patient.status == PatientStatus.Active) colors.success else colors.textFaint,
                        CircleShape,
                    )
                    .border(2.dp, colors.surface, CircleShape),
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(patient.displayName(unnamed), color = colors.textBright, fontWeight = FontWeight.SemiBold)
            Text(patientSubtitle(patient), color = colors.textBody, fontSize = 13.sp)
        }
    }
}

@Composable
private fun patientSubtitle(patient: Patient): String {
    val last = patient.sessions.maxByOrNull { it.date.time }
        ?: return stringResource(R.string.no_sessions_yet_label)
    val typeOrDate = last.type?.let { stringResource(it.labelRes()) }
        ?: DateFormat.getDateInstance(DateFormat.MEDIUM, Locale("he", "IL")).format(last.date)
    val count = if (patient.sessionsUpToTodayCount == 1) {
        stringResource(R.string.sessions_count_one)
    } else {
        stringResource(R.string.sessions_count_other, patient.sessionsUpToTodayCount)
    }
    return stringResource(R.string.last_session_summary, typeOrDate, count)
}

fun SessionType.labelRes(): Int = when (this) {
    SessionType.FirstPhoneCall -> R.string.session_type_first_phone_call
    SessionType.Intake -> R.string.session_type_intake
    SessionType.PsychoEducation -> R.string.session_type_psycho_education
    SessionType.DiaryOne -> R.string.session_type_diary_one
    SessionType.DiaryTwo -> R.string.session_type_diary_two
    SessionType.DiaryThree -> R.string.session_type_diary_three
    SessionType.CaseFormulation -> R.string.session_type_case_formulation
    SessionType.BehavioralInterventions -> R.string.session_type_behavioral_interventions
    SessionType.RelapsePreventionAndTermination -> R.string.session_type_relapse_prevention_and_termination
}

@Composable
private fun EmptyState(title: String, message: String, action: String, onAction: () -> Unit) {
    val colors = Theme.colors
    Column(
        modifier = Modifier.fillMaxSize().padding(32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(title, color = colors.textBright, fontWeight = FontWeight.Bold, fontSize = 20.sp)
        Spacer(Modifier.height(8.dp))
        Text(message, color = colors.textBody)
        Spacer(Modifier.height(16.dp))
        Button(
            onClick = onAction,
            colors = ButtonDefaults.buttonColors(containerColor = colors.gold, contentColor = colors.textOnAccent),
        ) { Text(action) }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AddPatientSheet(
    isSaving: Boolean,
    errorMessage: String?,
    onDismiss: () -> Unit,
    onSave: (String, String, PatientStatus) -> Unit,
) {
    var first by remember { mutableStateOf("") }
    var last by remember { mutableStateOf("") }
    var status by remember { mutableStateOf(PatientStatus.Active) }
    val colors = Theme.colors
    val canSave = (first.trim().isNotEmpty() || last.trim().isNotEmpty()) && !isSaving
    androidx.compose.material3.ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = colors.surface,
    ) {
        Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(stringResource(R.string.new_patient_title), color = colors.textBright, fontWeight = FontWeight.Bold, fontSize = 22.sp)
            androidx.compose.material3.OutlinedTextField(
                value = first,
                onValueChange = { first = it },
                placeholder = { Text(stringResource(R.string.first_name_placeholder)) },
                modifier = Modifier.fillMaxWidth(),
            )
            androidx.compose.material3.OutlinedTextField(
                value = last,
                onValueChange = { last = it },
                placeholder = { Text(stringResource(R.string.last_name_placeholder)) },
                modifier = Modifier.fillMaxWidth(),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                TextButton(onClick = { status = PatientStatus.Active }) {
                    Text("Active", color = if (status == PatientStatus.Active) colors.gold else colors.textBody)
                }
                TextButton(onClick = { status = PatientStatus.Inactive }) {
                    Text("Inactive", color = if (status == PatientStatus.Inactive) colors.gold else colors.textBody)
                }
            }
            errorMessage?.let { Text(it, color = colors.error) }
            Button(
                onClick = { onSave(first.trim(), last.trim(), status) },
                enabled = canSave,
                modifier = Modifier.fillMaxWidth().height(48.dp),
                colors = ButtonDefaults.buttonColors(containerColor = colors.gold, contentColor = colors.textOnAccent),
            ) {
                if (isSaving) CircularProgressIndicator(Modifier.size(22.dp), color = colors.textOnAccent, strokeWidth = 2.dp)
                else Text(stringResource(R.string.add_patient_action), fontWeight = FontWeight.SemiBold)
            }
            TextButton(onClick = onDismiss, enabled = !isSaving, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.cancel), color = colors.gold)
            }
        }
    }
}
