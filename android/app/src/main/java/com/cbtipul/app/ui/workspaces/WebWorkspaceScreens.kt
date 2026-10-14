package com.cbtipul.app.ui.workspaces

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.toggleable
import androidx.compose.ui.semantics.Role
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.cbtipul.app.CbTipulApp
import com.cbtipul.app.R
import com.cbtipul.app.data.*
import com.cbtipul.app.model.*
import com.cbtipul.app.ui.diary.DiaryThreeEntryContent
import com.cbtipul.app.ui.patients.QuestionnaireScreen
import com.cbtipul.app.ui.patients.labelRes
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.hebrewDate
import kotlinx.coroutines.launch
import kotlinx.serialization.json.*
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.text.SimpleDateFormat
import java.util.*

private fun stamp(raw: String): String = runCatching {
    OffsetDateTime.parse(raw).atZoneSameInstant(java.time.ZoneId.systemDefault()).format(DateTimeFormatter.ofLocalizedDateTime(FormatStyle.SHORT).withLocale(Locale("he", "IL")))
}.getOrDefault(raw)
private fun dateOnly(date: Date): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(date)
private fun WebWorkspaceFailure.copyRes() = when (this) {
    WebWorkspaceFailure.InvalidSelection -> R.string.ww_selection_required
    WebWorkspaceFailure.Unavailable -> R.string.ww_unavailable
    WebWorkspaceFailure.Conflict -> R.string.ww_conflict
    WebWorkspaceFailure.PatientMissing -> R.string.ww_patient_missing
    WebWorkspaceFailure.SessionMissing -> R.string.ww_session_missing
    WebWorkspaceFailure.ReadOnly -> R.string.entitlement_read_only_explanation
    WebWorkspaceFailure.Uncertain -> R.string.ww_uncertain
}
private fun WebWorksheet.titleRes() = when(type) {
    "questionnaire" -> R.string.questionnaires_title
    "diary_one" -> R.string.diary_one_title
    "diary_two" -> R.string.diary_two_title
    else -> R.string.diary_three_title
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable private fun WorkspacePage(title: String, onBack: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    Scaffold(containerColor = Theme.colors.base, topBar = {
        TopAppBar(title = { Text(title) }, navigationIcon = {
            IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, stringResource(R.string.back)) }
        })
    }) { padding ->
        Column(Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp), content = content)
    }
}

@Composable fun WebWorkspaceInboxScreen(onBack: () -> Unit, onOpen: (String) -> Unit) {
    val app = LocalContext.current.applicationContext as CbTipulApp
    val state by app.webWorkspaces.state.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    LaunchedEffect(Unit) { app.webWorkspaces.refresh() }
    WorkspacePage(stringResource(R.string.ww_inbox), onBack) {
        OutlinedButton(onClick = { scope.launch { app.webWorkspaces.refresh() } }, enabled = !state.loading) { Text(stringResource(R.string.ww_refresh)) }
        if (state.loading) CircularProgressIndicator()
        if (state.failed) Text(stringResource(R.string.ww_load_failed), color = Theme.colors.error)
        if (!state.loading && !state.failed && state.items.isEmpty()) { Text(stringResource(R.string.ww_empty), style = MaterialTheme.typography.titleMedium); Text(stringResource(R.string.ww_empty_body)) }
        state.requests.keys.filter { id -> state.items.none { it.id == id } }.forEach { id ->
            TextButton(onClick = { onOpen(id) }) { Text(stringResource(R.string.ww_retry_association)) }
        }
        state.items.forEach { item ->
            Surface(onClick = { onOpen(item.id) }, color = Theme.colors.surface, shape = MaterialTheme.shapes.medium) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(item.reference_label ?: stringResource(R.string.ww_untitled), style = MaterialTheme.typography.titleMedium)
                    Text(stringResource(R.string.ww_started) + stamp(item.started_at))
                    Text(stringResource(R.string.ww_finished) + stamp(item.finished_at))
                    Text(stringResource(R.string.ww_activity_count, item.item_count) + stringResource(if (item.has_notes) R.string.ww_has_notes else R.string.ww_no_notes))
                }
            }
        }
    }
}

@Composable fun WebWorkspacePreviewScreen(id: String, onBack: () -> Unit) {
    val app = LocalContext.current.applicationContext as CbTipulApp
    val state by app.webWorkspaces.state.collectAsStateWithLifecycle()
    val entitlement by Entitlements.state.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    var workspace by remember(id) { mutableStateOf<WebWorkspace?>(null) }
    var loading by remember(id) { mutableStateOf(true) }
    var error by remember(id) { mutableStateOf<Int?>(null) }
    var unavailable by remember(id) { mutableStateOf(false) }
    var completed by rememberSaveable(id) { mutableStateOf(false) }
    var showAssociation by rememberSaveable(id) { mutableStateOf(false) }
    var itemID by rememberSaveable(id) { mutableStateOf<String?>(null) }
    var discard by remember { mutableStateOf(false) }
    var loadRevision by remember { mutableIntStateOf(0) }
    val busy = id in state.busy
    LaunchedEffect(id, loadRevision) {
        loading = true
        try { workspace = app.webWorkspaces.load(id); error = null; unavailable = false }
        catch (e: Exception) {
            unavailable = WebWorkspaceFailure.classify(e) == WebWorkspaceFailure.Unavailable
            error = if (unavailable) R.string.ww_unavailable else R.string.ww_load_failed
            if (unavailable) {
                if (id !in state.requests) app.webWorkspaces.markUnavailable(id)
                app.webWorkspaces.refresh()
            }
        } finally { loading = false }
    }
    val item = workspace?.payload?.items?.firstOrNull { it.id == itemID }
    if (item != null) {
        BackHandler { itemID = null }
        WebWorksheetScreen(item) { itemID = null }
    } else if (showAssociation) {
        BackHandler(enabled = !busy) { showAssociation = false }
        WebAssociationScreen(id, workspace?.payload, onBack = { showAssociation = false }, onSuccess = { completed = true; showAssociation = false })
    } else {
        WorkspacePage(stringResource(R.string.ww_preview), onBack) {
            if (completed) {
                Text(stringResource(R.string.ww_done), style = MaterialTheme.typography.titleLarge)
                if (state.refreshFailed) { Text(stringResource(R.string.ww_refresh_failed)); TextButton(onClick = { scope.launch { app.webWorkspaces.refreshAfterSuccess() } }) { Text(stringResource(R.string.retry)) } }
            } else {
                if (loading || busy) CircularProgressIndicator()
                error?.let { Text(stringResource(it), color = Theme.colors.error) }
                if (!unavailable) OutlinedButton(onClick = { loadRevision++ }, enabled = !loading && !busy) { Text(stringResource(R.string.ww_refresh)) }
                workspace?.let { w ->
                    w.reference_label?.let { Text(it, style = MaterialTheme.typography.titleLarge) }
                    Text(stringResource(R.string.ww_started) + stamp(w.started_at))
                    w.finished_at?.let { Text(stringResource(R.string.ww_finished) + stamp(it)) }
                    Text(stringResource(R.string.ww_activity_count, w.payload.items.size) + stringResource(if (w.payload.hasNotes) R.string.ww_has_notes else R.string.ww_no_notes))
                    w.payload.items.forEach { worksheet ->
                        OutlinedButton(onClick = { itemID = worksheet.id }, modifier = Modifier.fillMaxWidth()) {
                            Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Text(stringResource(worksheet.titleRes()))
                                Text(stamp(worksheet.completed_at))
                                if (worksheet.type == "questionnaire") {
                                    val q = worksheet.questionnaire()
                                    Text(stringResource(R.string.ww_scores, q.questionnaire.gad7Score, q.questionnaire.phq9Score))
                                    if (q.flagsQuestionNine) Text(stringResource(R.string.ww_question_nine_flag), color = Theme.colors.error)
                                }
                            }
                        }
                    }
                    if (w.payload.hasNotes) { Text(stringResource(R.string.ww_notes), style = MaterialTheme.typography.titleMedium); SelectionContainer { Text(w.payload.notes) } }
                }
                if (entitlement.access == EntitlementAccess.Full) {
                    if ((!unavailable && id !in state.closedIDs && workspace != null) || id in state.requests) {
                        Button(onClick = { showAssociation = true }, enabled = !busy, modifier = Modifier.fillMaxWidth()) { Text(stringResource(if (id in state.requests) R.string.ww_retry_association else R.string.ww_associate)) }
                    }
                    if (!unavailable && id !in state.closedIDs && workspace != null && id !in state.requests) TextButton(onClick = { discard = true }, enabled = !busy) { Text(stringResource(R.string.ww_discard), color = Theme.colors.error) }
                } else Text(stringResource(R.string.entitlement_read_only_explanation))
            }
        }
    }
    if (discard) AlertDialog(onDismissRequest = { discard = false }, title = { Text(stringResource(R.string.ww_discard)) }, text = { Text(stringResource(R.string.ww_discard_confirm)) },
        confirmButton = { TextButton(onClick = {
            discard = false
            app.applicationScope.launch {
                try { app.webWorkspaces.discard(id); completed = true }
                catch (e: Exception) { error = ((e as? WebWorkspaceException)?.failure ?: WebWorkspaceFailure.Uncertain).copyRes(); app.webWorkspaces.refresh() }
            }
        }) { Text(stringResource(R.string.ww_discard)) } }, dismissButton = { TextButton(onClick = { discard = false }) { Text(stringResource(R.string.cancel)) } })
}

@Composable private fun Choice(label: String, options: List<Pair<String, String>>, selected: String, enabled: Boolean = true, onSelect: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Column {
        Text(label, style = MaterialTheme.typography.titleSmall)
        OutlinedButton(onClick = { expanded = true }, enabled = enabled, modifier = Modifier.fillMaxWidth()) { Text(options.firstOrNull { it.first == selected }?.second ?: label) }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            options.forEach { (id, title) -> DropdownMenuItem(text = { Text(title) }, onClick = { onSelect(id); expanded = false }) }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable private fun WebAssociationScreen(id: String, payload: WebWorkspacePayload?, onBack: () -> Unit, onSuccess: () -> Unit) {
    val app = LocalContext.current.applicationContext as CbTipulApp
    val context = LocalContext.current
    val patients by app.patientRepository.patients.collectAsStateWithLifecycle()
    val questionnaires by app.patientRepository.questionnaires.collectAsStateWithLifecycle()
    val state by app.webWorkspaces.state.collectAsStateWithLifecycle()
    val entitlement by Entitlements.state.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    var patientID by rememberSaveable(id) { mutableStateOf("") }
    var sessionID by rememberSaveable(id) { mutableStateOf("") }
    var target by rememberSaveable(id) { mutableStateOf("") }
    var linkQuestionnaire by rememberSaveable(id) { mutableStateOf(false) }
    var dateMillis by rememberSaveable(id) { mutableLongStateOf(System.currentTimeMillis()) }
    var typeName by rememberSaveable(id) { mutableStateOf("") }
    var showDate by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<Int?>(null) }
    var closed by rememberSaveable(id) { mutableStateOf(false) }
    var confirming by remember { mutableStateOf<WebAssociationRequest?>(null) }
    var loading by remember { mutableStateOf(false) }
    val patient = patients.firstOrNull { it.id.queryValue == patientID }
    val locked = state.requests[id]
    val busy = id in state.busy
    val needsSession = payload?.hasNotes == true || linkQuestionnaire
    val conflict = linkQuestionnaire && target == "existing" && questionnaires[patientID]?.any { it.sessionId?.queryValue == sessionID } == true
    val request = WebAssociationRequest(id, patientID,
        p_existing_session_id = sessionID.takeIf { needsSession && target == "existing" && it.isNotEmpty() },
        p_create_session = needsSession && target == "new", p_link_questionnaire = linkQuestionnaire,
        p_session_date = if (needsSession && target == "new") dateOnly(Date(dateMillis)) else null,
        p_session_type = if (needsSession && target == "new") typeName.takeIf { it.isNotEmpty() } else null)
    val valid = !closed && id !in state.closedIDs && !loading && entitlement.access == EntitlementAccess.Full && (locked != null || (patient != null && payload != null && !conflict &&
        (!needsSession || target == "new" || patient.sessions.any { it.databaseId?.queryValue == sessionID }) && request.valid(payload.hasNotes, payload.hasQuestionnaire)))
    suspend fun refreshPatients() {
        loading = true
        try { app.patientRepository.loadPatients(); patient?.let { app.patientRepository.loadQuestionnaires(it.id) } }
        catch (_: Exception) { error = R.string.ww_load_failed }
        finally { loading = false }
    }
    LaunchedEffect(Unit) { refreshPatients() }
    LaunchedEffect(patientID) {
        patient?.let { try { app.patientRepository.loadQuestionnaires(it.id) } catch (_: Exception) { error = R.string.ww_load_failed } }
    }
    fun summary(r: WebAssociationRequest): String {
        val name = patients.firstOrNull { it.id.queryValue == r.p_patient_id }?.displayName(context.getString(R.string.unnamed_patient)) ?: context.getString(R.string.unnamed_patient)
        val session = patients.flatMap { it.sessions }.firstOrNull { it.databaseId?.queryValue == r.p_existing_session_id }
        val destination = if (r.p_create_session) context.getString(R.string.ww_new_session) + ": " + r.p_session_date + " · " + (runCatching { webWorkspaceJson.decodeFromJsonElement<SessionType>(JsonPrimitive(r.p_session_type)) }.getOrNull()?.let { context.getString(it.labelRes()) } ?: "")
            else session?.let { context.getString(R.string.ww_existing_session) + ": " + dateOnly(it.date) } ?: context.getString(R.string.ww_no_session)
        return listOfNotNull(context.getString(R.string.ww_patient) + ": " + name, context.getString(R.string.ww_diaries_patient_level), destination,
            if (payload?.hasQuestionnaire == true || r.p_link_questionnaire) context.getString(if (r.p_link_questionnaire) R.string.ww_questionnaire_to_session else R.string.ww_questionnaire_patient_level) else null,
            if (payload?.hasNotes == true) context.getString(R.string.ww_notes_to_session) else null,
            if ((payload?.hasNotes == true || payload == null) && r.p_existing_session_id != null) context.getString(R.string.ww_append_warning) else null).joinToString("\n\n")
    }
    WorkspacePage(stringResource(R.string.ww_associate), onBack) {
        if (locked != null) { Text(stringResource(R.string.ww_uncertain)); Text(summary(locked)) }
        else {
            Choice(stringResource(R.string.ww_choose_patient), patients.map { it.id.queryValue to it.displayName(context.getString(R.string.unnamed_patient)) }, patientID, !busy) { patientID = it; sessionID = "" }
            OutlinedButton(onClick = { scope.launch { refreshPatients() } }, enabled = !busy && !loading) { Text(stringResource(R.string.ww_refresh)) }
            if (payload?.hasQuestionnaire == true) {
                Row(Modifier.fillMaxWidth().toggleable(value = linkQuestionnaire, enabled = !busy, role = Role.Switch, onValueChange = { linkQuestionnaire = it }), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(stringResource(R.string.ww_link_questionnaire), modifier = Modifier.weight(1f))
                    Switch(checked = linkQuestionnaire, onCheckedChange = null, enabled = !busy)
                }
                Text(stringResource(R.string.ww_questionnaire_help))
            }
            if (needsSession) {
                if (payload?.hasNotes == true) Text(stringResource(R.string.ww_notes_require_session))
                Choice(stringResource(R.string.ww_session_target), listOf("existing" to stringResource(R.string.ww_existing_session), "new" to stringResource(R.string.ww_new_session)), target, !busy) { target = it }
                if (target == "existing") {
                    Choice(stringResource(R.string.ww_choose_session), patient?.sessions?.filter { it.databaseId != null }?.sortedByDescending { it.date }?.map { it.databaseId!!.queryValue to (hebrewDate(it.date) + " · " + (it.type?.let { t -> stringResource(t.labelRes()) } ?: "")) }.orEmpty(), sessionID, !busy) { sessionID = it }
                    if (payload?.hasNotes == true) Text(stringResource(R.string.ww_append_warning))
                }
                if (target == "new") {
                    OutlinedButton(onClick = { showDate = true }, enabled = !busy) { Text(stringResource(R.string.session_date_title) + ": " + hebrewDate(Date(dateMillis))) }
                    Choice(stringResource(R.string.ww_choose_type), SessionType.entries.map { webWorkspaceJson.encodeToJsonElement(it).jsonPrimitive.content to stringResource(it.labelRes()) }, typeName, !busy) { typeName = it }
                }
            }
            Text(stringResource(R.string.ww_diaries_patient_level))
            if (conflict) Text(stringResource(R.string.ww_conflict), color = Theme.colors.error)
        }
        error?.let { Text(stringResource(it), color = Theme.colors.error) }
        if (busy || loading) CircularProgressIndicator()
        if (!closed) Button(onClick = { confirming = locked ?: request }, enabled = valid && !busy, modifier = Modifier.fillMaxWidth().testTag("workspace.associate.review")) { Text(stringResource(if (locked == null) R.string.ww_review else R.string.ww_retry_association)) }
    }
    if (showDate) {
        val dateState = rememberDatePickerState(initialSelectedDateMillis = WebWorkspaceDates.toPicker(dateMillis))
        DatePickerDialog(onDismissRequest = { showDate = false }, confirmButton = { TextButton(onClick = {
            dateState.selectedDateMillis?.let { dateMillis = WebWorkspaceDates.fromPicker(it) }; showDate = false
        }) { Text(stringResource(R.string.ww_confirm)) } }, dismissButton = { TextButton(onClick = { showDate = false }) { Text(stringResource(R.string.cancel)) } }) { DatePicker(state = dateState) }
    }
    confirming?.let { r ->
        AlertDialog(onDismissRequest = { confirming = null }, title = { Text(stringResource(R.string.ww_review)) }, text = { Column(Modifier.verticalScroll(rememberScrollState())) { Text(summary(r)) } },
            confirmButton = { TextButton(onClick = {
                confirming = null
                app.applicationScope.launch {
                    try { app.webWorkspaces.associate(r); onSuccess() }
                    catch (e: Exception) {
                        val failure = (e as? WebWorkspaceException)?.failure ?: WebWorkspaceFailure.Uncertain
                        error = failure.copyRes(); closed = failure == WebWorkspaceFailure.Unavailable
                        if (failure in listOf(WebWorkspaceFailure.Conflict, WebWorkspaceFailure.PatientMissing, WebWorkspaceFailure.SessionMissing)) refreshPatients()
                    }
                }
            }) { Text(stringResource(R.string.ww_confirm)) } }, dismissButton = { TextButton(onClick = { confirming = null }) { Text(stringResource(R.string.cancel)) } })
    }
}

@Composable private fun WebWorksheetScreen(item: WebWorksheet, onBack: () -> Unit) {
    if (item.type == "questionnaire") {
        val q = item.questionnaire()
        Column(Modifier.fillMaxSize()) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(stamp(item.completed_at))
                Text(stringResource(R.string.ww_measurement_date) + item.measurement_date)
                if (q.flagsQuestionNine) Text(stringResource(R.string.ww_question_nine_flag), color = Theme.colors.error)
                q.notes?.takeIf { it.isNotBlank() }?.let { SelectionContainer { Text(it, modifier = Modifier.heightIn(max = 160.dp).verticalScroll(rememberScrollState())) } }
            }
            Box(Modifier.weight(1f)) { QuestionnaireScreen(session = null, existing = q.questionnaire, allowRecordEditing = false, previous = null, atmosphere = null, isSaving = false, errorMessage = null, onBack = onBack, onSave = {}, onDelete = {}) }
        }
    } else WorkspacePage(stringResource(item.titleRes()), onBack) {
        Text(stamp(item.completed_at))
        SelectionContainer { Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            if (item.type == "diary_three") {
                val d = item.diaryThree()
                // Preview-only adapter; no clinical record is persisted or added to a store.
                DiaryThreeEntryContent(DiaryThreeEntry(item.id, DatabaseId.Text("preview"), "", DiaryOneEntryCreator.Therapist, d.situation, d.automatic_thoughts, d.feelings, d.thinking_errors, d.alternative_thoughts, Date(0), Date(0)))
            } else {
                val d = item.diary()
                PreviewSection(R.string.diary_one_event_title, listOf(d.event))
                PreviewSection(R.string.diary_one_thought_title, d.automatic_thoughts)
                PreviewSection(R.string.diary_two_feelings_title, d.feelings.map { "${it.name} — ${it.intensity}%" })
                d.behaviour?.let { PreviewSection(R.string.diary_one_behaviour_title, listOf(it)) }
                d.physical_symptoms?.takeIf { it.isNotBlank() }?.let { PreviewSection(R.string.diary_one_physical_title, listOf(it)) }
                d.thinking_errors?.let { PreviewSection(R.string.diary_thinking_errors_title, it.map { e -> stringResource(e.title) }) }
                d.alternative_thoughts?.let { PreviewSection(R.string.diary_alternative_thoughts_title, it) }
            }
        } }
    }
}
@Composable private fun PreviewSection(title: Int, values: List<String>) {
    Text(stringResource(title), style = MaterialTheme.typography.titleMedium)
    values.forEach { Text(it) }
}
