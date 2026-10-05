package com.cbtipul.app.ui.patients

import com.cbtipul.app.ui.entitlementCreateControl
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.PersonAdd
import androidx.compose.material.icons.outlined.WarningAmber
import androidx.compose.ui.graphics.vector.ImageVector
import com.cbtipul.app.ui.theme.PrimaryActionButton
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import com.cbtipul.app.ui.therapist.TabReselectionEffect
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.automirrored.outlined.KeyboardArrowRight
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import java.util.Calendar
import java.text.Collator
import java.util.Locale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.cbtipul.app.R
import com.cbtipul.app.data.DemoData
import com.cbtipul.app.model.Patient
import com.cbtipul.app.model.PatientStatus
import com.cbtipul.app.model.SessionType
import com.cbtipul.app.ui.onboarding.TutorialCoachPlacement
import com.cbtipul.app.ui.onboarding.TutorialHighlight
import com.cbtipul.app.ui.onboarding.tutorialPulse
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.groupedListCard
import com.cbtipul.app.ui.theme.hebrewDate
import com.cbtipul.app.ui.theme.themedScreen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PatientListScreen(
    viewModel: PatientListViewModel,
    unnamed: String,
    onOpenPatient: (String) -> Unit,
    onOpenSettings: (() -> Unit)? = null,
    onAddPatient: () -> Unit,
) {
    val patients by viewModel.patients.collectAsStateWithLifecycle()
    val ui by viewModel.ui.collectAsStateWithLifecycle()
    val isDemoMode by viewModel.isDemoMode.collectAsStateWithLifecycle()
    val routerState by viewModel.gettingStartedState.collectAsStateWithLifecycle()
    val colors = Theme.colors
    val listState = rememberLazyListState()
    TabReselectionEffect { listState.animateScrollToItem(0) }
    var patientSearch by rememberSaveable { mutableStateOf("") }
    val visiblePatients = remember(patients, patientSearch, unnamed) {
        val query = patientSearch.trim()
        val collator = Collator.getInstance(Locale("he", "IL"))
        patients.filter { query.isEmpty() || it.displayName(unnamed).contains(query, ignoreCase = true) }
            .sortedWith { first, second -> collator.compare(first.displayName(unnamed), second.displayName(unnamed)) }
    }
    val activePatients = visiblePatients.filter { it.status == PatientStatus.Active }
    val inactivePatients = visiblePatients.filter { it.status != PatientStatus.Active }

    LaunchedEffect(Unit) {
        viewModel.gettingStarted.setPlacement(TutorialCoachPlacement.PatientList)
        viewModel.refreshGettingStartedProgress()
    }

    Scaffold(
        modifier = Modifier.themedScreen(colors.gold),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.patients_title), color = colors.textBright) },
                navigationIcon = {
                    if (onOpenSettings != null) {
                        IconButton(onClick = onOpenSettings) {
                            Icon(Icons.Outlined.Settings, contentDescription = stringResource(R.string.settings_title), tint = colors.gold)
                        }
                    }
                },
                actions = {
                    IconButton(onClick = onAddPatient, modifier = Modifier.entitlementCreateControl()) {
                        Icon(Icons.Outlined.Add, contentDescription = stringResource(R.string.add_patient_action), tint = colors.gold)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
    ) { padding ->
        val showLoadingEmpty =
            patients.isEmpty() && ui.loadError == null && (ui.isLoading || !ui.hasLoaded) && !isDemoMode
        val showLoadError = ui.loadError != null && patients.isEmpty() && !isDemoMode
        val showPatientAddCta = !showLoadingEmpty && !showLoadError

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            if (patients.isNotEmpty()) {
                OutlinedTextField(
                    value = patientSearch,
                    onValueChange = { patientSearch = it },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp)
                        .padding(bottom = 8.dp),
                    singleLine = true,
                    leadingIcon = { Icon(Icons.Outlined.Search, contentDescription = null) },
                    trailingIcon = {
                        if (patientSearch.isNotEmpty()) {
                            IconButton(onClick = { patientSearch = "" }) {
                                Icon(Icons.Outlined.Close, contentDescription = stringResource(R.string.patients_clear_search))
                            }
                        }
                    },
                    label = { Text(stringResource(R.string.patients_search_prompt)) },
                )
            }
            PullToRefreshBox(
                isRefreshing = ui.isLoading && patients.isNotEmpty() && !isDemoMode,
                onRefresh = { viewModel.refresh(fromUser = true) },
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
            ) {
                when {
                    showLoadingEmpty -> {
                        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                CircularProgressIndicator(color = colors.gold)
                                Spacer(Modifier.height(12.dp))
                                Text(stringResource(R.string.loading_patients_label), color = colors.textBody)
                            }
                        }
                    }
                    showLoadError -> {
                        EmptyState(
                            title = stringResource(R.string.couldnt_load_patients_title),
                            icon = Icons.Outlined.WarningAmber,
                            message = ui.loadError.orEmpty(),
                            action = stringResource(R.string.retry),
                            onAction = viewModel::refresh,
                        )
                    }
                    patients.isEmpty() -> {
                        EmptyState(
                            title = stringResource(R.string.no_patients_title),
                            icon = Icons.Outlined.PersonAdd,
                            message = stringResource(R.string.add_first_patient_message),
                        )
                    }
                    else -> {
                        val focusId = routerState.progress.focusPatientId?.queryValue
                        if (visiblePatients.isEmpty()) {
                            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                                Text(stringResource(R.string.patients_search_empty), color = colors.textBody)
                            }
                        } else {
                        LazyColumn(
                            state = listState,
                            modifier = Modifier.padding(horizontal = 16.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            listOf(
                                R.string.patient_list_active_section to activePatients,
                                R.string.patient_list_inactive_section to inactivePatients,
                            ).forEach { (title, group) ->
                                if (group.isNotEmpty()) {
                                    item(key = title) {
                                        Text(
                                            stringResource(title, group.size),
                                            color = colors.textBody,
                                            fontWeight = FontWeight.SemiBold,
                                            modifier = Modifier.padding(top = 16.dp, bottom = 4.dp),
                                        )
                                    }
                                    items(group, key = { it.id.queryValue }) { patient ->
                                        val pulse = isDemoMode &&
                                            DemoData.isTutorialPatientId(patient.id) &&
                                            patient.id.queryValue == focusId &&
                                            viewModel.gettingStarted.shouldPulse(TutorialHighlight.TutorialPatient)
                                        PatientRow(
                                            patient = patient,
                                            unnamed = unnamed,
                                            onClick = { onOpenPatient(patient.id.queryValue) },
                                            pulse = pulse,
                                        )
                                    }
                                }
                            }
                            item { Spacer(Modifier.height(8.dp)) }
                        }
                        }
                    }
                }
            }
            if (showPatientAddCta) {
                PersistentAddButton(
                    label = stringResource(
                        if (patients.isEmpty()) R.string.empty_patients_primary_action
                        else R.string.add_patient_action,
                    ),
                    onClick = onAddPatient,
                    pulse = isDemoMode && viewModel.gettingStarted.shouldPulse(TutorialHighlight.AddPatient),
                )
                if (patients.isEmpty() && !isDemoMode) {
                    OutlinedButton(
                        onClick = { viewModel.requestDemoConsent() },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 24.dp)
                            .padding(bottom = 12.dp),
                    ) {
                        Text(stringResource(R.string.enter_demo_mode_action), color = colors.gold)
                    }
                }
            }
        }
    }
}

@Composable
internal fun PatientRow(
    patient: Patient,
    unnamed: String,
    onClick: () -> Unit,
    pulse: Boolean = false,
    actionSubtitle: String? = null,
) {
    val colors = Theme.colors
    val status = stringResource(
        if (patient.status == PatientStatus.Active) R.string.patient_status_active else R.string.patient_status_inactive,
    )
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .groupedListCard(colors.gold)
            .tutorialPulse(pulse)
            .semantics { stateDescription = status }
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        InitialsAvatar(name = patient.displayName(unnamed), patientId = patient.id)
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(if (actionSubtitle == null) 3.dp else 7.dp)) {
            Text(patient.displayName(unnamed), color = colors.textBright, fontWeight = FontWeight.SemiBold)
            if (actionSubtitle != null) {
                Row(
                    modifier = Modifier.background(colors.gold.copy(alpha = 0.10f), RoundedCornerShape(50))
                        .padding(horizontal = 10.dp, vertical = 5.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Icon(Icons.Outlined.ChatBubbleOutline, contentDescription = null, tint = colors.gold, modifier = Modifier.size(16.dp))
                    Text(actionSubtitle, color = colors.gold, fontSize = 13.sp)
                }
            } else {
                Text(patientSubtitle(patient), color = colors.textBody, fontSize = 13.sp)
            }
        }
        Icon(Icons.AutoMirrored.Outlined.KeyboardArrowRight, contentDescription = null, tint = colors.textFaint)
    }
}

@Composable
private fun patientSubtitle(patient: Patient): String {
    // Match the date-only split used by the sessions list: today is upcoming.
    val today = Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }.time
    val next = patient.sessions.filter { it.date >= today }.minByOrNull { it.date.time }
    if (next != null) return stringResource(R.string.patient_list_next_session, hebrewDate(next.date))
    val last = patient.sessions.maxByOrNull { it.date.time }
        ?: return stringResource(R.string.no_sessions_yet_label)
    return stringResource(R.string.patient_list_last_session, hebrewDate(last.date))
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
private fun PersistentAddButton(
    label: String,
    onClick: () -> Unit,
    pulse: Boolean = false,
) {
    val colors = Theme.colors
    PrimaryActionButton(
        label = label,
        icon = Icons.Outlined.Add,
        onClick = onClick,
        modifier = Modifier.padding(horizontal = 24.dp)
            .padding(top = 8.dp, bottom = 12.dp).tutorialPulse(pulse).entitlementCreateControl(),
    )
}

@Composable
internal fun EmptyState(
    title: String,
    icon: ImageVector,
    message: String,
    action: String? = null,
    onAction: (() -> Unit)? = null,
    pulseAction: Boolean = false,
) {
    val colors = Theme.colors
    Column(
        modifier = Modifier.fillMaxSize().padding(32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(icon, contentDescription = null, tint = colors.textBody, modifier = Modifier.size(48.dp))
        Spacer(Modifier.height(12.dp))
        Text(title, color = colors.textBright, fontWeight = FontWeight.Bold, fontSize = 20.sp)
        Spacer(Modifier.height(8.dp))
        Text(message, color = colors.textBody)
        if (action != null && onAction != null) {
            Spacer(Modifier.height(16.dp))
            Button(
                onClick = onAction,
                modifier = Modifier.tutorialPulse(pulseAction),
                colors = ButtonDefaults.buttonColors(containerColor = colors.accentFill, contentColor = colors.textOnAccent),
            ) { Text(action) }
        }
    }
}
