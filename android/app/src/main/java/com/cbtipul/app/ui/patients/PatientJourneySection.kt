package com.cbtipul.app.ui.patients

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowForward
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.cbtipul.app.R
import com.cbtipul.app.data.patientJourney
import com.cbtipul.app.model.Patient
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.hebrewDate

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun PatientJourneySection(patient: Patient, inHeader: Boolean = false) {
    val colors = Theme.colors
    val accent = PatientAvatarColor.background(patient.id)
    val stages = patientJourney(patient.sessions)
    var expanded by remember { mutableStateOf(false) }
    val foreground = if (inHeader) colors.headerInk else colors.textBright
    Surface(color = if (inHeader && !colors.isPaper) Color.Black.copy(alpha = .12f) else accent.copy(alpha = .12f), shape = MaterialTheme.shapes.medium,
        border = BorderStroke(1.dp, accent.copy(alpha = .4f))) {
        Row(Modifier.padding(horizontal = 4.dp, vertical = 2.dp), verticalAlignment = Alignment.CenterVertically) {
            if (stages.isEmpty()) Text(stringResource(R.string.patient_journey_empty), color = foreground,
                modifier = Modifier.weight(1f).padding(8.dp))
            else CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
                LazyRow(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    items(stages.reversed(), key = { it.sessions.first().id }) { stage ->
                        CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                            TextButton(onClick = { expanded = true },
                                colors = ButtonDefaults.textButtonColors(contentColor = foreground),
                                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)) {
                                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                    Text(stringResource(stage.type?.labelRes() ?: R.string.session_type_none), style = MaterialTheme.typography.labelLarge)
                                    Text(stringResource(R.string.patient_journey_count, stage.sessions.size), style = MaterialTheme.typography.labelSmall)
                                }
                            }
                        }
                    }
                }
            }
            IconButton(onClick = { expanded = true }) {
                Icon(Icons.AutoMirrored.Outlined.ArrowForward, tint = foreground,
                    contentDescription = stringResource(R.string.patient_journey_title))
            }
        }
    }
    if (expanded) ModalBottomSheet(onDismissRequest = { expanded = false }) {
        Text(stringResource(R.string.patient_journey_title), style = MaterialTheme.typography.headlineSmall, modifier = Modifier.padding(horizontal = 24.dp))
        LazyColumn(contentPadding = PaddingValues(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            items(stages.reversed(), key = { it.sessions.first().id }) { stage ->
                ListItem(headlineContent = { Text(stringResource(stage.type?.labelRes() ?: R.string.session_type_none)) },
                    supportingContent = { Column {
                        Text(stringResource(R.string.patient_journey_count, stage.sessions.size))
                        Text(hebrewDate(stage.sessions.first().date) + " – " + hebrewDate(stage.sessions.last().date))
                    } }, leadingContent = { Icon(Icons.Outlined.Description, null, tint = accent) })
            }
        }
    }
}
