package com.cbtipul.app.ui.patients

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.PersonAdd
import androidx.compose.material.icons.outlined.WarningAmber
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.ui.Alignment
import androidx.compose.ui.text.font.FontWeight
import com.cbtipul.app.model.PatientStatus
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.cbtipul.app.R
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.themedScreen
import com.cbtipul.app.ui.therapist.TabReselectionEffect
import java.text.Collator
import java.util.Locale

/** Selects an existing local patient; the shared navigation host opens the chat. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AIPatientPickerScreen(viewModel: PatientListViewModel, unnamed: String, onSelect: (String) -> Unit) {
    val patients by viewModel.patients.collectAsStateWithLifecycle()
    val ui by viewModel.ui.collectAsStateWithLifecycle()
    val isDemoMode by viewModel.isDemoMode.collectAsStateWithLifecycle()
    val colors = Theme.colors
    var search by rememberSaveable { mutableStateOf("") }
    val listState = rememberLazyListState()
    TabReselectionEffect { listState.animateScrollToItem(0) }
    val matching = remember(patients, search, unnamed) {
        val query = search.trim()
        val collator = Collator.getInstance(Locale("he", "IL"))
        patients.filter { query.isEmpty() || it.displayName(unnamed).contains(query, ignoreCase = true) }
            .sortedWith { a, b -> collator.compare(a.displayName(unnamed), b.displayName(unnamed)) }
    }
    Scaffold(
        modifier = Modifier.themedScreen(colors.gold),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.ai_patient_picker_title), color = colors.textBright) },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            Text(
                stringResource(R.string.ai_patient_picker_prompt),
                style = MaterialTheme.typography.bodyMedium,
                color = colors.textBody,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
            )
            if (patients.isNotEmpty()) OutlinedTextField(
                value = search, onValueChange = { search = it }, singleLine = true,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(bottom = 8.dp),
                label = { Text(stringResource(R.string.patients_search_prompt)) },
                leadingIcon = { Icon(Icons.Outlined.Search, contentDescription = null) },
                trailingIcon = {
                    if (search.isNotEmpty()) IconButton(onClick = { search = "" }) {
                        Icon(Icons.Outlined.Close, contentDescription = stringResource(R.string.patients_clear_search))
                    }
                },
            )
            PullToRefreshBox(
                isRefreshing = ui.isLoading && patients.isNotEmpty() && !isDemoMode,
                onRefresh = { viewModel.refresh(fromUser = true) },
                modifier = Modifier.weight(1f).fillMaxWidth(),
            ) {
                when {
                    patients.isEmpty() && ui.loadError == null && (ui.isLoading || !ui.hasLoaded) && !isDemoMode -> {
                        Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) {
                            CircularProgressIndicator(color = colors.gold)
                            Spacer(Modifier.height(12.dp))
                            Text(stringResource(R.string.loading_patients_label), color = colors.textBody)
                        }
                    }
                    patients.isEmpty() && ui.loadError != null && !isDemoMode -> EmptyState(
                        title = stringResource(R.string.couldnt_load_patients_title),
                        icon = Icons.Outlined.WarningAmber,
                        message = ui.loadError.orEmpty(),
                        action = stringResource(R.string.retry),
                        onAction = { viewModel.refresh(fromUser = true) },
                    )
                    patients.isEmpty() -> EmptyState(
                        title = stringResource(R.string.no_patients_title),
                        icon = Icons.Outlined.PersonAdd,
                        message = stringResource(R.string.add_first_patient_message),
                    )
                    matching.isEmpty() -> Text(
                        stringResource(R.string.patients_search_empty), color = colors.textBody,
                        modifier = Modifier.align(Alignment.Center).padding(16.dp),
                    )
                    else -> LazyColumn(
                        state = listState,
                        modifier = Modifier.padding(horizontal = 16.dp),
                        contentPadding = PaddingValues(bottom = 16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        listOf(
                            R.string.patient_list_active_section to matching.filter { it.status == PatientStatus.Active },
                            R.string.patient_list_inactive_section to matching.filter { it.status != PatientStatus.Active },
                        ).forEach { (title, group) ->
                            if (group.isNotEmpty()) {
                                item(key = title) {
                                    Text(
                                        stringResource(title, group.size), color = colors.textBody,
                                        fontWeight = FontWeight.SemiBold,
                                        modifier = Modifier.padding(top = 16.dp, bottom = 4.dp),
                                    )
                                }
                                items(group, key = { it.id.queryValue }) { patient ->
                                    PatientRow(patient, unnamed, onClick = { onSelect(patient.id.queryValue) })
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
