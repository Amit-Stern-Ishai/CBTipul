package com.cbtipul.app.ui.workspaces

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.toggleable
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.contentDescription
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
import androidx.compose.ui.res.stringArrayResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.cbtipul.app.CbTipulApp
import com.cbtipul.app.R
import com.cbtipul.app.data.*
import com.cbtipul.app.model.*
import com.cbtipul.app.ui.diary.DiaryThreeEntryContent
import com.cbtipul.app.ui.diary.DiaryTwoEntryContent
import com.cbtipul.app.ui.patient.DiaryOneEntryContent
import com.cbtipul.app.ui.theme.themedScreen
import com.cbtipul.app.ui.patients.QuestionnaireScreen
import com.cbtipul.app.ui.patients.labelRes
import com.cbtipul.app.ui.patients.ScoreCapsule
import com.cbtipul.app.ui.patients.gad7Color
import com.cbtipul.app.ui.patients.phq9Color
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.hebrewDate
import kotlinx.coroutines.launch
import kotlinx.coroutines.ensureActive
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
    WebWorkspaceFailure.PreviewChanged -> R.string.ww_preview_changed
    WebWorkspaceFailure.Rejected -> R.string.ww_save_rejected
    WebWorkspaceFailure.ServiceUnavailable -> R.string.ww_save_service_unavailable
    WebWorkspaceFailure.QuestionnaireChanged -> R.string.ww_choice_changed
}
private fun WebWorksheet.titleRes() = when(type) {
    "questionnaire" -> R.string.questionnaires_title
    "diary_one" -> R.string.diary_one_title
    "diary_two" -> R.string.diary_two_title
    else -> R.string.diary_three_title
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable private fun WorkspacePage(title: String, onBack: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    Scaffold(modifier = Modifier.themedScreen(Theme.colors.gold), containerColor = androidx.compose.ui.graphics.Color.Transparent, topBar = {
        TopAppBar(title = { Text(title, color = Theme.colors.textBright) }, colors = TopAppBarDefaults.topAppBarColors(containerColor = androidx.compose.ui.graphics.Color.Transparent, navigationIconContentColor = Theme.colors.gold), navigationIcon = {
            IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, stringResource(R.string.back)) }
        })
    }) { padding ->
        CompositionLocalProvider(LocalContentColor provides Theme.colors.textBright) {
            Column(Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp), content = content)
        }
    }
}

@Composable fun WebWorkspaceInboxScreen(onBack: () -> Unit, onOpen: (String) -> Unit) {
    val app = LocalContext.current.applicationContext as CbTipulApp
    val state by app.webWorkspaces.state.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    LaunchedEffect(Unit) { app.webWorkspaces.refresh() }
    WorkspacePage(stringResource(R.string.ww_inbox), onBack) {
        OutlinedButton(onClick = { scope.launch { app.webWorkspaces.refresh() } }, enabled = !state.loading) { Text(stringResource(R.string.ww_refresh)) }
        if (state.refreshFailed) { Text(stringResource(R.string.ww_refresh_failed)); TextButton(onClick={scope.launch{app.webWorkspaces.refreshAfterSuccess()}}){Text(stringResource(R.string.retry))} }
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

@Composable fun WebWorkspacePreviewScreen(id: String, initialPatientID: String? = null, onBack: () -> Unit) {
    key(id) { WebWorkspaceDestination(id, initialPatientID, onBack) }
}

@Composable private fun WebWorkspaceDestination(id: String, initialPatientID: String?, onBack: () -> Unit) {
    val app = LocalContext.current.applicationContext as CbTipulApp
    val state by app.webWorkspaces.state.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    var workspace by remember(id) { mutableStateOf<WebWorkspace?>(null) }
    var error by remember(id) { mutableStateOf<Int?>(null) }
    var loadRevision by remember { mutableIntStateOf(0) }
    var discard by remember { mutableStateOf(false) }
    val busy = id in state.busy
    LaunchedEffect(id,loadRevision) {
        try { workspace=app.webWorkspaces.load(id);error=null }
        catch(e:kotlinx.coroutines.CancellationException){throw e}
        catch(e:Exception){
            val unavailable=WebWorkspaceFailure.classify(e)==WebWorkspaceFailure.Unavailable
            error=if(unavailable)R.string.ww_unavailable else R.string.ww_content_loading_failed
            if(unavailable && app.webWorkspaces.state.value.requests[id]==null){app.webWorkspaces.markUnavailable(id);app.webWorkspaces.refresh()}
        }
    }
    BackHandler { if(!busy) onBack() }
    if(error==R.string.ww_unavailable && state.requests[id]==null) {
        WorkspacePage(stringResource(R.string.ww_preview),onBack) {
            Text(stringResource(R.string.ww_unavailable))
            TextButton(onClick=onBack){Text(stringResource(R.string.back))}
        }
        return
    }
    WebAssociationScreen(id,workspace?.payload,onBack,onBack,initialPatientID,error,{loadRevision++},onDiscard={discard=true}, workspace=workspace)
    if(discard) AlertDialog(onDismissRequest={discard=false},title={Text(stringResource(R.string.ww_discard))},text={Text(stringResource(R.string.ww_discard_confirm))},confirmButton={TextButton(onClick={discard=false;scope.launch{try{app.webWorkspaces.discard(id);onBack()}catch(e:Exception){error=WebWorkspaceFailure.classify(e).copyRes()}}}){Text(stringResource(R.string.ww_discard))}},dismissButton={TextButton(onClick={discard=false}){Text(stringResource(R.string.cancel))}})
}

@Composable internal fun Choice(label: String, options: List<Pair<String, String>>, selected: String, enabled: Boolean = true, onSelect: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Column {
        Text(label, style = MaterialTheme.typography.titleSmall)
        OutlinedButton(onClick = { expanded = true }, enabled = enabled, shape = MaterialTheme.shapes.medium, modifier = Modifier.fillMaxWidth()) { Text(options.firstOrNull { it.first == selected }?.second ?: label) }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            options.forEach { (id, title) -> DropdownMenuItem(text = { Text(title) }, onClick = { onSelect(id); expanded = false }) }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable private fun WebAssociationScreen(id: String, payload: WebWorkspacePayload?, onBack: () -> Unit, onSuccess: () -> Unit, initialPatientID: String? = null, contentError: Int? = null, reloadContent: () -> Unit = {}, onDiscard: () -> Unit = {}, workspace: WebWorkspace? = null) {
    val app = LocalContext.current.applicationContext as CbTipulApp
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val patients by app.patientRepository.patients.collectAsStateWithLifecycle()
    val state by app.webWorkspaces.state.collectAsStateWithLifecycle()
    val entitlement by Entitlements.state.collectAsStateWithLifecycle()
    var patientID by rememberSaveable(id) { mutableStateOf(initialPatientID.orEmpty()) }
    var sessionID by rememberSaveable(id) { mutableStateOf("") }
    var createSession by rememberSaveable(id) { mutableStateOf(false) }
    var linkQuestionnaire by rememberSaveable(id) { mutableStateOf(false) }
    var dateMillis by rememberSaveable(id) { mutableLongStateOf(System.currentTimeMillis()) }
    var typeName by rememberSaveable(id) { mutableStateOf("") }
    var showDate by remember { mutableStateOf(false) }
    var showContent by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<Int?>(null) }
    var loading by remember { mutableStateOf(false) }
    var submitting by remember { mutableStateOf(false) }
    var closed by rememberSaveable(id) { mutableStateOf(false) }
    var preview by remember { mutableStateOf<WebAssociationPreview?>(null) }
    var previewFor by remember { mutableStateOf<WebAssociationTarget?>(null) }
    var previewLoading by remember { mutableStateOf(false) }
    var previewGeneration by remember { mutableIntStateOf(0) }
    var previewRevision by remember { mutableIntStateOf(0) }
    var choice by remember { mutableStateOf<JsonObject?>(null) }
    var choiceWasExplicit by remember { mutableStateOf(false) }
    var inspected by remember { mutableStateOf<WebAssociationCandidate?>(null) }
    val patient = patients.firstOrNull { it.id.queryValue == patientID }
    val locked = state.requests[id]
    val busy = submitting || id in state.busy
    val hasNotes = preview?.has_notes ?: payload?.hasNotes ?: false
    val needsSession = hasNotes || linkQuestionnaire
    val request = WebAssociationRequest(id, patientID,
        p_existing_session_id = sessionID.takeIf { needsSession && !createSession && it.isNotEmpty() },
        p_create_session = needsSession && createSession, p_link_questionnaire = linkQuestionnaire,
        p_session_date = if (needsSession && createSession) dateOnly(Date(dateMillis)) else null,
        p_session_type = if (needsSession && createSession) typeName.takeIf { it.isNotEmpty() } else null)
    val params = request.target
    val targetReady = (payload != null || preview != null) && patient != null && params.valid && (!needsSession || createSession || patient.sessions.any { it.databaseId?.queryValue == sessionID })
    val readyPreview = preview.takeIf { previewFor == params && !previewLoading }
    val valid = !closed && id !in state.closedIDs && entitlement.access == EntitlementAccess.Full && (locked != null || (targetReady && readyPreview != null && (!linkQuestionnaire || choice != null) && request.valid(hasNotes,payload?.hasQuestionnaire == true) && runCatching { readyPreview.prepare(request,choice) }.isSuccess))
    suspend fun refreshPatients() {
        loading = true
        try {
            app.patientRepository.loadPatients()
            val updated = app.patientRepository.patients.value.firstOrNull { it.id.queryValue == patientID }
            if (!createSession && sessionID.isNotEmpty() && updated?.sessions?.none { it.databaseId?.queryValue == sessionID } != false) sessionID = ""
        } catch (e: kotlinx.coroutines.CancellationException) { throw e }
        catch (_: Exception) { error = R.string.ww_load_failed }
        finally { loading = false }
    }
    suspend fun fetchPreview(rejectedRequest: WebAssociationRequest? = null): WebAssociationPreview? {
        val generation = ++previewGeneration
        if (app.webWorkspaces.state.value.requests[id] != null || !(rejectedRequest?.target?.valid == true || targetReady)) { previewLoading=false;return null }
        val intended=rejectedRequest?.target?:params
        val explicit = choice.takeIf { choiceWasExplicit }
        previewFor=intended;previewLoading=true;preview=null
        try {
            val result=app.webWorkspaces.preview(intended)
            kotlinx.coroutines.currentCoroutineContext().ensureActive()
            if (generation!=previewGeneration) return null
            preview=result;choice=result.resolvedChoice(explicit)
            choiceWasExplicit=result.eligibleQuestionnaires.size>1 && choice!=null && explicit!=null
            return result
        } catch(e:kotlinx.coroutines.CancellationException){throw e}
        catch(e:Exception){val failure=WebWorkspaceFailure.classify(e);error=if(failure==WebWorkspaceFailure.Uncertain)R.string.ww_load_failed else failure.copyRes();return null}
        finally{if(generation==previewGeneration)previewLoading=false}
    }
    LaunchedEffect(id) { refreshPatients() }
    LaunchedEffect(id,locked) {
        locked?.let { r ->
            patientID=r.p_patient_id;sessionID=r.p_existing_session_id.orEmpty();createSession=r.p_create_session;linkQuestionnaire=r.p_link_questionnaire
            typeName=r.p_session_type.orEmpty();choice=r.p_questionnaire_choice;choiceWasExplicit=choice!=null
            r.p_session_date?.let { raw -> runCatching { SimpleDateFormat("yyyy-MM-dd",Locale.US).parse(raw)?.time }.getOrNull()?.let {dateMillis=it} }
        }
    }
    LaunchedEffect(params,targetReady,previewRevision) { fetchPreview() }
    if(inspected!=null){BackHandler{inspected=null};WebCandidateAnswers(inspected!!){inspected=null};return}
    if(showContent && payload!=null){BackHandler{showContent=false};WebWorkspaceContentScreen(payload,onBack={showContent=false},onDiscard=onDiscard.takeIf { locked==null });return}
    val destination=locked?.let { r ->
        val name=patients.firstOrNull { it.id.queryValue==r.p_patient_id }?.displayName(context.getString(R.string.unnamed_patient))?:context.getString(R.string.unnamed_patient)
        val session=patients.flatMap { it.sessions }.firstOrNull { it.databaseId?.queryValue==r.p_existing_session_id }
        name + if(r.p_create_session) " · "+context.getString(R.string.ww_new_session)+" · "+r.p_session_date.orEmpty() else session?.let{" · "+hebrewDate(it.date)}.orEmpty()
    }
    WorkspacePage(stringResource(R.string.ww_associate), {if(!busy)onBack()}) {
        if(payload!=null) {
            WebWorkspaceContext(workspace,payload)
            TextButton(onClick={showContent=true},enabled=!busy,modifier=Modifier.testTag("workspace.associate.content")){Text(stringResource(R.string.ww_preview))}
        }
        WebAssociationForm(
            state=WebAssociationFormState(
                patients=patients.map { it.id.queryValue to it.displayName(context.getString(R.string.unnamed_patient)) },patientID=patientID,
                sessions=patient?.sessions?.filter { it.databaseId!=null }?.sortedByDescending { it.date }?.map { it.databaseId!!.queryValue to (hebrewDate(it.date)+" · "+(it.type?.let {t->stringResource(t.labelRes())}?:"")) }.orEmpty(),
                sessionKey=if(createSession)"new" else sessionID,needsSession=needsSession,createSession=createSession,
                types=SessionType.entries.map {webWorkspaceJson.encodeToJsonElement(it).jsonPrimitive.content to stringResource(it.labelRes())},typeName=typeName,dateLabel=hebrewDate(Date(dateMillis)),
                offerLink=payload?.hasQuestionnaire==true || hasNotes && (preview?.eligibleQuestionnaires?.isNotEmpty()==true || linkQuestionnaire),link=linkQuestionnaire,
                candidates=readyPreview?.questionnaires.orEmpty(),choice=choice,append=readyPreview?.notes_will_append==true || locked?.p_acknowledge_existing_notes==true,
                loadingPatients=loading,loadingPreview=previewLoading,hasContent=false,loadingContent=payload==null&&locked==null&&contentError==null,
                error=error?:contentError.takeIf { locked==null },busy=busy,valid=valid,closed=closed,lockedDestination=destination),
            onPatient={next->error=null;patientID=next;choiceWasExplicit=false;if(patients.firstOrNull{it.id.queryValue==next}?.sessions?.none{it.databaseId?.queryValue==sessionID}!=false)sessionID=""},
            onSession={error=null;createSession=it=="new";if(!createSession)sessionID=it},onLink={error=null;linkQuestionnaire=it;choiceWasExplicit=false;choice=readyPreview?.resolvedChoice(null)},
            onDate={showDate=true},onType={error=null;typeName=it},onChoice={choice=it;choiceWasExplicit=true;error=null},onInspect={inspected=it},onContent={showContent=true},
            onRetry={if(contentError!=null)reloadContent() else scope.launch {error=null;refreshPatients();previewRevision++}},
            onSave={
                if(!busy&&valid){
                    val original=locked?:readyPreview?.let{it.confirmed(it.prepare(request,choice))}
                    if(original!=null){
                        val appendWasVisible=readyPreview?.notes_will_append==true || locked?.p_acknowledge_existing_notes==true
                        submitting=true;error=null
                        app.applicationScope.launch {
                            try {
                                try{app.webWorkspaces.associate(original)}
                                catch(e:Exception){
                                    if(e is kotlinx.coroutines.CancellationException)throw e
                                    if(WebWorkspaceFailure.classify(e)!=WebWorkspaceFailure.PreviewChanged)throw e
                                    val fresh=fetchPreview(original)?:return@launch
                                    if(!fresh.canContinueSaving(original,choice,appendWasVisible)){
                                        error=if(fresh.notes_will_append&&!appendWasVisible)R.string.ww_summary_changed else if(original.p_link_questionnaire&&choice!=original.p_questionnaire_choice)R.string.ww_choice_changed else R.string.ww_preview_changed
                                        return@launch
                                    }
                                    app.webWorkspaces.associate(fresh.confirmed(fresh.prepare(original,choice)))
                                }
                                closed=true
                                android.widget.Toast.makeText(context,R.string.ww_done,android.widget.Toast.LENGTH_SHORT).show();onSuccess()
                            }catch(e:kotlinx.coroutines.CancellationException){throw e}
                            catch(e:Exception){
                                val failure=WebWorkspaceFailure.classify(e);error=failure.copyRes();closed=failure==WebWorkspaceFailure.Unavailable
                                if(failure in listOf(WebWorkspaceFailure.PatientMissing,WebWorkspaceFailure.SessionMissing))refreshPatients()
                                if(failure in listOf(WebWorkspaceFailure.PreviewChanged,WebWorkspaceFailure.InvalidSelection,WebWorkspaceFailure.QuestionnaireChanged,WebWorkspaceFailure.PatientMissing,WebWorkspaceFailure.SessionMissing))previewRevision++
                            }finally{submitting=false}
                        }
                    }
                }
            })
    }
    if(showDate){
        val dateState=rememberDatePickerState(initialSelectedDateMillis=WebWorkspaceDates.toPicker(dateMillis))
        DatePickerDialog(onDismissRequest={showDate=false},confirmButton={TextButton(onClick={dateState.selectedDateMillis?.let{dateMillis=WebWorkspaceDates.fromPicker(it)};showDate=false}){Text(stringResource(R.string.save))}},dismissButton={TextButton(onClick={showDate=false}){Text(stringResource(R.string.cancel))}}){DatePicker(state=dateState)}
    }
}

@Composable internal fun WebWorkspaceContext(workspace: WebWorkspace?, payload: WebWorkspacePayload) {
    Column(Modifier.fillMaxWidth().testTag("workspace.context"),verticalArrangement=Arrangement.spacedBy(6.dp)) {
        Text(workspace?.reference_label?.takeIf { it.isNotBlank() } ?: stringResource(R.string.ww_untitled),style=MaterialTheme.typography.titleMedium)
        workspace?.let {
            Text(stringResource(R.string.ww_started)+stamp(it.started_at),style=MaterialTheme.typography.bodySmall)
            it.finished_at?.let { end -> Text(stringResource(R.string.ww_finished)+stamp(end),style=MaterialTheme.typography.bodySmall) }
        }
        Text(stringResource(R.string.ww_activity_count,payload.items.size)+stringResource(if(payload.hasNotes)R.string.ww_has_notes else R.string.ww_no_notes),style=MaterialTheme.typography.bodyMedium,color=Theme.colors.textBody)
        if(payload.hasNotes) {
            Text(stringResource(R.string.ww_notes),style=MaterialTheme.typography.titleSmall)
            Text(payload.notes,maxLines=3,overflow=androidx.compose.ui.text.style.TextOverflow.Ellipsis)
        }
        payload.items.take(3).forEach { item ->
            Text(stringResource(item.titleRes()),style=MaterialTheme.typography.titleSmall)
            when(item.type) {
                "diary_one", "diary_two" -> Text(item.diary().event,maxLines=2,overflow=androidx.compose.ui.text.style.TextOverflow.Ellipsis)
                "diary_three" -> Text(item.diaryThree().situation,maxLines=2,overflow=androidx.compose.ui.text.style.TextOverflow.Ellipsis)
                "questionnaire" -> {
                    val q=item.questionnaire()
                    Text(stringResource(R.string.ww_measurement_date)+item.measurement_date,style=MaterialTheme.typography.bodySmall)
                    Text(stringResource(R.string.ww_scores,q.gad7_answers.sum(),q.phq9_answers.sum()))
                    if(q.flagsQuestionNine)Text(stringResource(R.string.ww_question_nine_flag),style=MaterialTheme.typography.bodySmall,color=Theme.colors.error)
                }
            }
        }
    }
}

@Composable private fun WebWorkspaceContentScreen(payload: WebWorkspacePayload,onBack:()->Unit,onDiscard:(()->Unit)?=null){
    var itemID by remember{mutableStateOf<String?>(null)}
    val item=payload.items.firstOrNull{it.id==itemID}
    if(item!=null){BackHandler{itemID=null};WebWorksheetScreen(item){itemID=null};return}
    WorkspacePage(stringResource(R.string.ww_preview),onBack){
        payload.items.forEach{worksheet->OutlinedButton(onClick={itemID=worksheet.id},modifier=Modifier.fillMaxWidth()){Text(stringResource(worksheet.titleRes()))}}
        if(payload.hasNotes){Text(stringResource(R.string.ww_notes),style=MaterialTheme.typography.titleMedium);SelectionContainer{Text(payload.notes)}}
        if(onDiscard!=null)TextButton(onClick=onDiscard){Text(stringResource(R.string.ww_discard),color=Theme.colors.error)}
    }
}

@Composable internal fun WebCandidateSummary(c: WebAssociationCandidate) {
    Text(stringResource(if(c.source=="incoming")R.string.ww_incoming_result else R.string.ww_existing_result),style=MaterialTheme.typography.labelMedium,color=Theme.colors.textBody)
    Text(stringResource(R.string.ww_measurement_date)+(c.measurement_date?:stringResource(R.string.ww_date_unavailable)))
    Text(stringResource(if(c.time_kind=="completed_at")R.string.ww_completed_time else R.string.ww_recorded_time)+(c.recorded_at?.let(::stamp)?:stringResource(R.string.ww_date_unavailable)))
    Row(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
        Box(Modifier.weight(1f)) { c.gad7_score?.let {ScoreCapsule(stringResource(R.string.score_badge,stringResource(R.string.gad7_short_name),it),gad7Color(GAD7Severity.from(it)))} ?: Text(stringResource(R.string.gad7_short_name)+": "+stringResource(R.string.ww_score_unavailable)) }
        Box(Modifier.weight(1f)) { c.phq9_score?.let {ScoreCapsule(stringResource(R.string.score_badge,stringResource(R.string.phq9_short_name),it),phq9Color(PHQ9Severity.from(it)))} ?: Text(stringResource(R.string.phq9_short_name)+": "+stringResource(R.string.ww_score_unavailable)) }
    }
    if(c.is_current_session_questionnaire) Text(stringResource(R.string.ww_current_result),style=MaterialTheme.typography.labelLarge)
    if(!c.selectable) Text(stringResource(R.string.ww_other_session_result))
    if(c.flagsQuestionNine) Text(stringResource(R.string.ww_question_nine_flag),style=MaterialTheme.typography.bodySmall,color=Theme.colors.error)
}
@Composable private fun WebCandidateAnswers(c: WebAssociationCandidate,onBack:()->Unit) {
    if(c.hasCompleteAnswers) Column(Modifier.fillMaxSize()) {
        Column(Modifier.padding(16.dp)) {WebCandidateSummary(c)}
        Box(Modifier.weight(1f)) {QuestionnaireScreen(session=null,existing=c.questionnaire,allowRecordEditing=false,previous=null,atmosphere=null,isSaving=false,errorMessage=null,onBack=onBack,onSave={},onDelete={})}
    } else WorkspacePage(stringResource(R.string.ww_inspect_answers),onBack) {
        WebCandidateSummary(c)
        val descriptions=stringArrayResource(R.array.answer_descriptions)
        listOf(R.array.gad7_questions to c.gad7_answers,R.array.phq9_questions to c.phq9_answers).forEach {(questions,answers)->
            stringArrayResource(questions).forEachIndexed {i,q-> Text(q);Text(answers?.getOrNull(i)?.let {descriptions.getOrNull(it)}?:stringResource(R.string.ww_date_unavailable))}
        }
    }
}

@Composable internal fun WebWorksheetScreen(item: WebWorksheet, onBack: () -> Unit) {
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
                if(item.type == "diary_one") {
                    DiaryOneEntryContent(d.event,d.automatic_thoughts,d.feelings,d.behaviour.orEmpty(),d.physical_symptoms)
                } else {
                    DiaryTwoEntryContent(d.event,d.automatic_thoughts,d.feelings,d.thinking_errors.orEmpty(),d.alternative_thoughts.orEmpty())
                }
            }
        } }
    }
}
