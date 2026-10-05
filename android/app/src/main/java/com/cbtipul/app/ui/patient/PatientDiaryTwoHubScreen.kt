package com.cbtipul.app.ui.patient

import com.cbtipul.app.ui.entitlementCreateControl
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.data.DiaryTwoEntry
import com.cbtipul.app.data.PatientDiaryTwoAccess
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.createSavedStateHandle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.hebrewDateTime
import com.cbtipul.app.ui.theme.themedScreen
import kotlinx.coroutines.launch

private enum class DiaryTwoHubLoadState { Loading, Loaded, Failed }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PatientDiaryTwoHubScreen(
    patientId: String,
    service: PatientDiaryTwoAccess,
    active: Boolean,
    onLoaded: (List<DiaryTwoEntry>) -> Unit,
    onAddEntry: () -> Unit,
    onOpenEntry: (DiaryTwoEntry) -> Unit,
    onBack: () -> Unit,
) {
    val colors = Theme.colors
    val vm: PatientDiaryTwoViewModel = viewModel(key = "patient-diary-two-hub-$patientId", factory = viewModelFactory {
        initializer { PatientDiaryTwoViewModel(patientId, service, createSavedStateHandle()) }
    })
    val state by vm.state.collectAsStateWithLifecycle()
    val entries = state.entries
    val loadState = if (state.loading) DiaryTwoHubLoadState.Loading else if (state.historyFailed) DiaryTwoHubLoadState.Failed else DiaryTwoHubLoadState.Loaded
    LaunchedEffect(entries) { onLoaded(entries) }
    LifecycleEventEffect(androidx.lifecycle.Lifecycle.Event.ON_RESUME) { vm.refresh() }

    Scaffold(
        modifier = Modifier.themedScreen(colors.gold),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.diary_two_title), color = colors.textBright) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.AutoMirrored.Outlined.ArrowBack,
                            contentDescription = stringResource(R.string.back),
                            tint = colors.gold,
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
        bottomBar = {
            if (loadState == DiaryTwoHubLoadState.Loaded || entries.isNotEmpty()) {
                Surface(color = colors.base) {
                    Box(Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp)) {
                        Button(
                            onClick = onAddEntry,
                            enabled = active,
                            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).entitlementCreateControl(),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = colors.accentFill,
                                contentColor = colors.textOnAccent,
                            ),
                            shape = RoundedCornerShape(14.dp),
                        ) {
                            Text(
                                stringResource(
                                    if (entries.isEmpty()) R.string.empty_diary_one_primary_action
                                    else R.string.diary_one_add_entry,
                                ),
                                fontWeight = FontWeight.SemiBold,
                            )
                        }
                    }
                }
            }
        },
    ) { padding ->
        when {
            loadState == DiaryTwoHubLoadState.Loading && entries.isEmpty() ->
                Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = colors.gold)
                }
            loadState == DiaryTwoHubLoadState.Failed && entries.isEmpty() ->
                Column(
                    Modifier.fillMaxSize().padding(padding).padding(24.dp),
                    verticalArrangement = Arrangement.Center,
                ) {
                    Text(stringResource(R.string.diary_two_load_failed), color = colors.textBody)
                    TextButton(onClick = { vm.refresh() }) {
                        Text(stringResource(R.string.retry_action), color = colors.gold)
                    }
                }
            else -> Column(
                Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp)
                    .padding(top = 12.dp, bottom = 28.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Text(stringResource(R.string.patient_diary_two_description), color = colors.textBody)
                PatientToolStatus(active)
                if (state.historyFailed) {
                    Text(stringResource(R.string.diary_two_load_failed), color = colors.error)
                    TextButton(onClick = vm::refresh) { Text(stringResource(R.string.retry_action)) }
                }
                Text(
                    stringResource(R.string.diary_one_my_entries),
                    color = colors.textBright,
                    fontWeight = FontWeight.SemiBold,
                )
                if (entries.isEmpty()) {
                    Text(stringResource(R.string.diary_two_empty_title), color = colors.textBody)
                } else {
                    entries.forEach { entry ->
                        GroupedListCard(accent = colors.gold) {
                            Column(
                                Modifier
                                    .fillMaxWidth()
                                    .clickable { onOpenEntry(entry) }
                                    .padding(16.dp),
                                verticalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                Text(
                                    hebrewDateTime(entry.createdAt),
                                    color = colors.textBright,
                                    fontWeight = FontWeight.SemiBold,
                                )
                                Text(entry.event, color = colors.textBody, maxLines = 2)
                                if (entry.automaticThoughtsPreview.isNotEmpty()) {
                                    Text(
                                        entry.automaticThoughtsPreview,
                                        color = colors.textBody,
                                        fontSize = 14.sp,
                                        maxLines = 2,
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PatientDiaryTwoDetailScreen(
    entry: DiaryTwoEntry,
    onBack: () -> Unit,
) {
    val colors = Theme.colors
    val context = androidx.compose.ui.platform.LocalContext.current
    Scaffold(
        modifier = Modifier.themedScreen(colors.gold),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.diary_two_title), color = colors.textBright) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.AutoMirrored.Outlined.ArrowBack,
                            contentDescription = stringResource(R.string.back),
                            tint = colors.gold,
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(top = 12.dp, bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text(
                hebrewDateTime(entry.createdAt),
                color = colors.textBright,
                fontWeight = FontWeight.SemiBold,
            )
            DetailBlock(stringResource(R.string.diary_one_event_title), entry.event)
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    stringResource(R.string.diary_one_thought_title),
                    color = colors.textBody,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 12.sp,
                )
                entry.automaticThoughts.forEach { thought ->
                    Text(thought, color = colors.textBright)
                }
            }
            DetailBlock(
                stringResource(R.string.diary_two_feelings_title),
                entry.feelings.joinToString(" · ") { "${it.name} ${it.intensity}%" },
            )
            DetailBlock(stringResource(R.string.diary_thinking_errors_title), entry.thinkingErrors.joinToString("\n") { context.getString(it.title) })
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(stringResource(R.string.diary_alternative_thoughts_title), color = colors.textBody, fontWeight = FontWeight.SemiBold)
                entry.alternativeThoughts.forEach { Text(it, color = colors.textBright) }
            }
        }
    }
}

@Composable
private fun DetailBlock(title: String, value: String) {
    val colors = Theme.colors
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(title, color = colors.textBody, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
        Text(value, color = colors.textBright)
    }
}
