package com.cbtipul.app.ui.diary

import com.cbtipul.app.ui.entitlementCreateControl
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.createSavedStateHandle
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import androidx.navigation.compose.*
import com.cbtipul.app.R
import com.cbtipul.app.data.*
import com.cbtipul.app.model.DatabaseId
import com.cbtipul.app.ui.patients.NotesField
import com.cbtipul.app.ui.patients.ConfirmDeleteOverlay
import com.cbtipul.app.ui.theme.*
import java.text.DateFormat

@Composable
fun TherapistDiaryThreeScreen(
    patientId: DatabaseId,
    patientName: String,
    atmosphere: Color?,
    diary: DiaryThreeRepository,
    assignments: PatientAssignmentRepository,
    isDemo: Boolean,
    focusEntryId: String? = null,
    returnDirectly: Boolean = false,
    onBack: () -> Unit,
) {
    val vm: DiaryThreeViewModel = viewModel(key = "diary-three-${patientId.queryValue}", factory = viewModelFactory {
        initializer { DiaryThreeViewModel(patientId, diary, assignments, isDemo, createSavedStateHandle()) }
    })
    val state by vm.state.collectAsStateWithLifecycle()
    val entryMap by vm.entries.collectAsStateWithLifecycle()
    val entries = entryMap[patientId.queryValue].orEmpty()
    val draft by vm.draft.collectAsStateWithLifecycle()
    val nav = rememberNavController()
    androidx.lifecycle.compose.LifecycleEventEffect(androidx.lifecycle.Lifecycle.Event.ON_RESUME) { vm.refreshConnection() }
    var consumedFocus by rememberSaveable(patientId.queryValue, focusEntryId) { mutableStateOf(false) }
    LaunchedEffect(focusEntryId, state.loading) {
        // Finish the initial history load first so it cannot overwrite the exact-entry cache.
        if (!state.loading && !consumedFocus && focusEntryId != null) {
            val entry = try { diary.loadEntry(focusEntryId, patientId) }
                catch (cancelled: kotlinx.coroutines.CancellationException) { throw cancelled }
                catch (_: Exception) { null }
            consumedFocus = true
            if (entry != null) nav.navigate("detail/${entry.id}") { launchSingleTop = true }
        }
    }
    NavHost(navController = nav, startDestination = "history") {
        composable("history") {
            var stop by rememberSaveable { mutableStateOf(false) }
            DiaryThreeFrame(patientName, atmosphere, onBack, bottom = {
                Button(onClick = { if (com.cbtipul.app.data.Entitlements.allowMutation()) { vm.openEditor(null); nav.navigate("new") } }, modifier = Modifier.fillMaxWidth().entitlementCreateControl()) {
                    Icon(Icons.Outlined.Add, null); Text(stringResource(R.string.diary_one_add_entry))
                }
            }) {
                if (PatientAssignmentType.diaryThreeSendingEnabled) {
                    DiaryThreeCard(stringResource(R.string.diary_patient_mode_title)) {
                        when (state.connection) {
                            DiaryThreeConnection.Loading -> CircularProgressIndicator()
                            DiaryThreeConnection.Connected -> Text(stringResource(R.string.patient_connected_status))
                            DiaryThreeConnection.NotConnected -> Text(stringResource(R.string.diary_patient_mode_not_connected))
                            DiaryThreeConnection.Inactive -> {
                                if (PatientAssignmentType.diaryThreeSendingEnabled) {
                                    Text(stringResource(R.string.diary_patient_mode_inactive_body))
                                    TextButton(onClick = vm::activate, enabled = !state.busy, modifier = Modifier.entitlementCreateControl()) { Text(stringResource(R.string.diary_patient_mode_activate)) }
                                } else {
                                    Text(stringResource(R.string.diary_three_sending_paused))
                                }
                            }
                            DiaryThreeConnection.Active -> {
                                Text(stringResource(R.string.diary_patient_mode_active), color = Theme.colors.success)
                                TextButton(onClick = { stop = true }, enabled = com.cbtipul.app.ui.entitlementCanWrite() && !state.busy) { Text(stringResource(R.string.diary_patient_mode_stop)) }
                            }
                            DiaryThreeConnection.Failed -> {
                                Text(stringResource(R.string.patient_connection_check_error))
                                TextButton(onClick = vm::refreshConnection) { Text(stringResource(R.string.retry_action)) }
                            }
                        }
                    }
                }
                state.error?.let { Text(stringResource(it), color = Theme.colors.error) }
                if (state.loading && entries.isEmpty()) CircularProgressIndicator()
                if (state.loadFailed) {
                    Text(stringResource(R.string.diary_three_load_failed), color = Theme.colors.error)
                    TextButton(onClick = vm::refresh) { Text(stringResource(R.string.retry_action)) }
                }
                if (!state.loading && !state.loadFailed && entries.isEmpty()) Text(stringResource(R.string.diary_three_empty_title))
                entries.forEach { entry ->
                    GroupedListCard(accent = atmosphere ?: Theme.colors.gold) {
                        Column(Modifier.fillMaxWidth().clickable { nav.navigate("detail/${entry.id}") }.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(entryDate(entry), fontWeight = FontWeight.SemiBold)
                            Text(entry.situation, maxLines = 2)
                            Text(entry.automaticThoughtsPreview, maxLines = 2, color = Theme.colors.textBody)
                            Text(source(entry), style = MaterialTheme.typography.labelSmall)
                        }
                    }
                }
            }
            ConfirmDeleteOverlay(visible = stop, title = stringResource(R.string.diary_patient_mode_stop_title),
                message = stringResource(R.string.diary_patient_mode_stop_message), confirmLabel = stringResource(R.string.diary_patient_mode_stop_confirm),
                onConfirm = { stop = false; vm.cancel() }, onDismiss = { stop = false })
        }
        composable("detail/{entryId}") { destination ->
            val id = destination.arguments?.getString("entryId")
            val entry = entries.find { it.id == id }
            fun closeDetail() { if (returnDirectly && id == focusEntryId) onBack() else nav.popBackStack() }
            var delete by rememberSaveable { mutableStateOf(false) }
            DiaryThreeFrame(patientName, atmosphere, { if (!state.busy) closeDetail() }, actions = {
                if (entry != null && entry.createdBy == com.cbtipul.app.data.DiaryOneEntryCreator.Therapist) {
                    IconButton(onClick = { if (com.cbtipul.app.data.Entitlements.allowMutation()) { vm.openEditor(entry.id); nav.navigate("edit/${entry.id}") } }, enabled = !state.busy) {
                        Icon(Icons.Outlined.Edit, stringResource(R.string.diary_entry_edit))
                    }
                    IconButton(onClick = { delete = true }, enabled = com.cbtipul.app.ui.entitlementCanWrite() && !state.busy) {
                        Icon(Icons.Outlined.Delete, stringResource(R.string.diary_one_delete_action))
                    }
                }
            }) {
                if (entry != null) {
                    Text(entryDate(entry)); Text(if (entry.createdBy == com.cbtipul.app.data.DiaryOneEntryCreator.Patient) stringResource(R.string.patient_submission_read_only) else source(entry), color = Theme.colors.textBody)
                    DiaryThreeEntryContent(entry)
                } else if (state.loading) {
                    CircularProgressIndicator()
                } else {
                    Text(stringResource(if (state.loadFailed) R.string.diary_three_load_failed else R.string.notification_target_unavailable))
                    if (state.loadFailed) TextButton(onClick = vm::refresh) { Text(stringResource(R.string.retry_action)) }
                }
                state.error?.let { Text(stringResource(it), color = Theme.colors.error) }
            }
            BackHandler { if (!state.busy) closeDetail() }
            ConfirmDeleteOverlay(visible = delete, title = stringResource(R.string.diary_one_delete_confirm_title),
                message = stringResource(R.string.diary_one_delete_confirm_message), confirmLabel = stringResource(R.string.diary_one_delete_action),
                onConfirm = { delete = false; if (id != null) vm.delete(id) { closeDetail() } }, onDismiss = { delete = false })
        }
        composable("new") { DiaryThreeEditor(vm, draft, state, null, patientName, atmosphere) { nav.popBackStack() } }
        composable("edit/{entryId}") { destination ->
            DiaryThreeEditor(vm, draft, state, destination.arguments?.getString("entryId"), patientName, atmosphere) { nav.popBackStack() }
        }
    }
}

@Composable
private fun DiaryThreeEditor(vm: DiaryThreeViewModel, draft: DiaryThreeEntryDraft, state: DiaryThreeState, id: String?, patientName: String, atmosphere: Color?, onBack: () -> Unit) {
    var attempted by rememberSaveable { mutableStateOf(false) }
    var discard by rememberSaveable { mutableStateOf(false) }
    var feedback by rememberSaveable { mutableStateOf<Int?>(null) }
    LaunchedEffect(state.error) { state.error?.let { feedback = it } }
    fun requestBack() { if (!state.busy) { if (vm.hasChanges()) discard = true else { vm.closeEditor(); onBack() } } }
    BackHandler { requestBack() }
    DiaryThreeFrame(patientName, atmosphere, ::requestBack, bottom = {
        Button(onClick = {
            attempted = true
            val validation = draft.validationError()
            if (validation != null) feedback = validation else vm.save(id, onBack)
        }, enabled = !state.busy, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.diary_one_save_entry))
        }
    }) {
        DiaryThreeDraftFields(draft, attempted, state.error, onChange = vm::changeDraft)
    }
    feedback?.let { message ->
        AlertDialog(onDismissRequest = { feedback = null }, title = { Text(stringResource(R.string.diary_three_title)) },
            text = { Text(stringResource(message)) },
            confirmButton = { TextButton(onClick = { feedback = null }) { Text(stringResource(R.string.ok)) } })
    }
    if (discard) AlertDialog(onDismissRequest = { discard = false }, title = { Text(stringResource(R.string.discard_changes_title)) },
        confirmButton = { TextButton(onClick = { discard = false; vm.closeEditor(); onBack() }) { Text(stringResource(R.string.discard_changes_action)) } },
        dismissButton = { TextButton(onClick = { discard = false }) { Text(stringResource(R.string.keep_editing_action)) } })
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DiaryThreeFrame(patientName: String, atmosphere: Color?, onBack: () -> Unit, actions: @Composable RowScope.() -> Unit = {}, bottom: @Composable () -> Unit = {}, content: @Composable ColumnScope.() -> Unit) {
    Scaffold(modifier = Modifier.themedScreen(atmosphere).imePadding(), containerColor = Color.Transparent,
        topBar = { TopAppBar(title = { Column {
            Text(stringResource(R.string.diary_three_title), color = Theme.colors.textBright)
            Text(patientName, style = MaterialTheme.typography.labelMedium, color = Theme.colors.textBody)
        } }, navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, stringResource(R.string.back)) } }, actions = actions,
            colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent)) },
        bottomBar = { Box(Modifier.navigationBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp)) { bottom() } },
    ) { padding ->
        CompositionLocalProvider(LocalContentColor provides Theme.colors.textBright) {
            Column(Modifier.fillMaxSize().padding(padding).editorScroll().padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp), content = content)
        }
    }
}

@Composable
private fun DiaryThreeCard(title: String, content: @Composable ColumnScope.() -> Unit) {
    GroupedListCard(accent = Theme.colors.gold) {
        Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(title, fontWeight = FontWeight.SemiBold)
            content()
        }
    }
}
private fun entryDate(entry: DiaryThreeEntry) = DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.SHORT).format(entry.createdAt)
@Composable private fun source(entry: DiaryThreeEntry) = stringResource(if (entry.createdBy == DiaryOneEntryCreator.Patient) R.string.diary_entry_patient_source else R.string.diary_entry_therapist_source)
