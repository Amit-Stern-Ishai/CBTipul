package com.cbtipul.app.ui.patients

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Search
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
        modifier = Modifier.themedScreen(Theme.colors.gold), containerColor = Color.Transparent,
        topBar = { TopAppBar(title = { Text(stringResource(R.string.ai_patient_picker_title)) },
            colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent)) },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding).padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(stringResource(R.string.ai_patient_picker_prompt), style = MaterialTheme.typography.titleMedium, color = Theme.colors.textBright)
            if (patients.isNotEmpty()) OutlinedTextField(
                value = search, onValueChange = { search = it }, singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text(stringResource(R.string.patients_search_prompt)) },
                leadingIcon = { Icon(Icons.Outlined.Search, contentDescription = null) },
            )
            when {
                patients.isEmpty() && ui.isLoading -> CircularProgressIndicator()
                patients.isEmpty() && ui.loadError != null -> {
                    Text(ui.loadError.orEmpty(), color = Theme.colors.error)
                    TextButton(onClick = { viewModel.refresh(fromUser = true) }) { Text(stringResource(R.string.retry)) }
                }
                patients.isEmpty() -> Text(stringResource(R.string.add_first_patient_message), color = Theme.colors.textBody)
                matching.isEmpty() -> Text(stringResource(R.string.patients_search_empty), color = Theme.colors.textBody)
                else -> LazyColumn(state = listState, contentPadding = PaddingValues(bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(matching, key = { it.id.queryValue }) { patient ->
                        PatientRow(patient, unnamed, onClick = { onSelect(patient.id.queryValue) })
                    }
                }
            }
        }
    }
}
