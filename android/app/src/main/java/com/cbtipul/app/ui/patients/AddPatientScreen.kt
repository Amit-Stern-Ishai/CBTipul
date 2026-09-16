package com.cbtipul.app.ui.patients

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.PersonAdd
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Icon
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.cbtipul.app.R
import com.cbtipul.app.model.PatientStatus
import com.cbtipul.app.ui.theme.BusyOverlay
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.dismissKeyboardOnTap
import com.cbtipul.app.ui.theme.groupedListCard
import com.cbtipul.app.ui.theme.themedScreen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddPatientScreen(
    isSaving: Boolean,
    errorMessage: String?,
    onCancel: () -> Unit,
    onSave: (String, String, PatientStatus) -> Unit,
    gettingStarted: com.cbtipul.app.ui.onboarding.GettingStartedRouter? = null,
) {
    val colors = Theme.colors
    var first by remember { mutableStateOf("") }
    var last by remember { mutableStateOf("") }
    var status by remember { mutableStateOf(PatientStatus.Active) }
    var statusExpanded by remember { mutableStateOf(false) }
    val canSave = (first.trim().isNotEmpty() || last.trim().isNotEmpty()) && !isSaving

    LaunchedEffect(Unit) {
        gettingStarted?.setPlacement(com.cbtipul.app.ui.onboarding.TutorialCoachPlacement.AddPatient)
    }

    Box(Modifier.fillMaxSize()) {
        Scaffold(
            modifier = Modifier
                .themedScreen(colors.gold)
                .dismissKeyboardOnTap(),
            containerColor = Color.Transparent,
            topBar = {
                TopAppBar(
                    title = { Text(stringResource(R.string.new_patient_title), color = colors.textBright) },
                    navigationIcon = {
                        TextButton(onClick = onCancel, enabled = !isSaving) {
                            Text(stringResource(R.string.cancel), color = colors.gold)
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
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Icon(
                    Icons.Outlined.PersonAdd,
                    contentDescription = null,
                    tint = colors.textOnAccent,
                    modifier = Modifier
                        .size(64.dp)
                        .background(colors.accentFill, CircleShape)
                        .padding(16.dp),
                )
                Column(Modifier.fillMaxWidth().groupedListCard(colors.gold).padding(16.dp)) {
                    Text(
                        stringResource(R.string.patient_section_title),
                        color = colors.textBright,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(bottom = 12.dp),
                    )
                    OutlinedTextField(
                        value = first,
                        onValueChange = { first = it },
                        placeholder = { Text(stringResource(R.string.first_name_placeholder)) },
                        modifier = Modifier.fillMaxWidth(),
                        enabled = !isSaving,
                    )
                    OutlinedTextField(
                        value = last,
                        onValueChange = { last = it },
                        placeholder = { Text(stringResource(R.string.last_name_placeholder)) },
                        modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                        enabled = !isSaving,
                    )
                    ExposedDropdownMenuBox(
                        expanded = statusExpanded,
                        onExpandedChange = { if (!isSaving) statusExpanded = it },
                        modifier = Modifier.padding(top = 8.dp),
                    ) {
                        OutlinedTextField(
                            value = stringResource(
                                if (status == PatientStatus.Active) {
                                    R.string.patient_status_active
                                } else {
                                    R.string.patient_status_inactive
                                },
                            ),
                            onValueChange = {},
                            readOnly = true,
                            label = { Text(stringResource(R.string.status_label)) },
                            modifier = Modifier.fillMaxWidth().menuAnchor(),
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = statusExpanded) },
                            enabled = !isSaving,
                        )
                        ExposedDropdownMenu(expanded = statusExpanded, onDismissRequest = { statusExpanded = false }) {
                            PatientStatus.entries.forEach { option ->
                                DropdownMenuItem(
                                    text = {
                                        Text(
                                            stringResource(
                                                if (option == PatientStatus.Active) {
                                                    R.string.patient_status_active
                                                } else {
                                                    R.string.patient_status_inactive
                                                },
                                            ),
                                        )
                                    },
                                    onClick = {
                                        status = option
                                        statusExpanded = false
                                    },
                                )
                            }
                        }
                    }
                }
                errorMessage?.let { Text(it, color = colors.error) }
                Button(
                    onClick = { onSave(first.trim(), last.trim(), status) },
                    enabled = canSave,
                    modifier = Modifier.fillMaxWidth().height(48.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = colors.gold, contentColor = colors.textOnAccent),
                ) {
                    Text(stringResource(R.string.add_patient_action), fontWeight = FontWeight.SemiBold)
                }
            }
        }
        BusyOverlay(isSaving)
    }
}
