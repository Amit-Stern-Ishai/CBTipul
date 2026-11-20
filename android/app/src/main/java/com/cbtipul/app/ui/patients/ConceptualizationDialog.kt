package com.cbtipul.app.ui.patients

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.semantics.*
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.cbtipul.app.CbTipulApp
import com.cbtipul.app.auth.AuthSession
import com.cbtipul.app.data.*
import com.cbtipul.app.ui.theme.Theme
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

@Composable
fun ConceptualizationDialog(app: CbTipulApp, patientId: String, readOnly: Boolean = false, onDismiss: () -> Unit) {
    val owner = remember(patientId) { app.authRepository.currentUserId() }
    val session by app.authRepository.session.collectAsStateWithLifecycle(initialValue = AuthSession.Loading)
    val entitlement by Entitlements.state.collectAsStateWithLifecycle()
    val service = remember { PatientConceptualization(app.authRepository.supabaseClient) }
    val scope = rememberCoroutineScope()
    var record by remember(owner, patientId) { mutableStateOf<ConceptRecord?>(null) }
    var draft by remember(owner, patientId) { mutableStateOf(emptyConcept()) }
    var backup by remember(owner, patientId) { mutableStateOf<ConceptDocument?>(null) }
    var editing by remember(owner, patientId) { mutableStateOf(false) }
    var cancelEditing by remember { mutableStateOf(false) }
    var loaded by remember { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    var conflict by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var message by remember { mutableStateOf<String?>(null) }
    var discard by remember { mutableStateOf(false) }
    var reload by remember { mutableStateOf(false) }
    val dirty = loaded && draft != (record?.document ?: emptyConcept())
    val canWrite = !readOnly && entitlement.canWrite && entitlement.role == AppRole.Therapist
    fun run(action: String) {
        if (busy || readOnly && action != "load_published") return
        if ((action == "save" || action == "publish") && !canWrite) return
        busy = true; error = null; message = null
        val submitted = draft; val revision = record?.revision
        scope.launch {
            try {
                val result = service.request(action, if (readOnly) null else patientId, revision, submitted)
                if (owner != app.authRepository.currentUserId()) return@launch
                if (!result.patientId.equals(patientId, true)) throw ConceptFailure(ConceptFailure.Kind.Access)
                record = result; draft = result.document ?: emptyConcept(); loaded = true; conflict = false; editing = false
                message = when(action) { "save" -> "ההמשגה נשמרה"; "publish" -> "ההמשגה נשלחה למטופל/ת"; else -> null }
            } catch (e: CancellationException) { throw e }
            catch (e: Exception) {
                if (owner == app.authRepository.currentUserId()) {
                    conflict = (e as? ConceptFailure)?.kind == ConceptFailure.Kind.Conflict
                    error = if (conflict) "ההמשגה השתנתה במכשיר אחר. השינויים שלכם נשארו כאן." else if ((e as? ConceptFailure)?.kind == ConceptFailure.Kind.Access) "אין הרשאה לפעולה זו." else "לא ניתן לאשר שהפעולה הושלמה. השינויים נשארו כאן. אפשר לנסות שוב."
                }
            } finally { if (owner == app.authRepository.currentUserId()) busy = false }
        }
    }
    fun refresh() { if (dirty) reload = true else run(if(readOnly) "load_published" else "load_draft") }
    LaunchedEffect(owner, patientId) { run(if(readOnly) "load_published" else "load_draft") }
    LaunchedEffect(session) { if (owner != app.authRepository.currentUserId()) { draft = emptyConcept(); backup = null; record = null; onDismiss() } }
    val colors = Theme.colors
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
        Dialog(onDismissRequest = { if (!busy) { if (dirty) discard = true else onDismiss() } }, properties = DialogProperties(usePlatformDefaultWidth = false, dismissOnClickOutside = false)) {
            Surface(modifier = Modifier.fillMaxSize(), color = colors.base) {
                Column(Modifier.safeDrawingPadding().padding(16.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("המשגה", style = MaterialTheme.typography.headlineSmall, color = colors.textBright)
                        if(canWrite && loaded) TextButton(enabled=!busy,onClick={ if(editing) { if(dirty) cancelEditing=true else editing=false } else editing=true }) { Text(if(editing) "ביטול עריכה" else "עריכה") }
                        TextButton(enabled = !busy, onClick = { if(dirty) discard = true else onDismiss() }) { Text("סגירה") }
                    }
                    if(busy) LinearProgressIndicator(Modifier.fillMaxWidth())
                    Column(Modifier.weight(1f).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        error?.let { Text(it, color = colors.error); TextButton(enabled = !busy, onClick = { refresh() }) { Text(if(conflict) "טעינת הגרסה העדכנית" else "ניסיון נוסף") } }
                        backup?.let { previous -> TextButton(enabled = !busy, onClick = { backup = draft; draft = previous; editing = true; message = "השינויים הוחזרו לעריכה. יש לשמור אותם." }) { Text("חזרה לשינויים שלי") } }
                        if(loaded && !editing && !readOnly && draft.values.all { it.isEmpty() }) Text("אין עדיין משפטים בהמשגה.", color=colors.textBody)
                        if(loaded && readOnly && record?.document == null) Text("עדיין לא נשלחה המשגה.", color = colors.textBody)
                        if(loaded && (!readOnly || record?.document != null)) ConceptSection.entries.filter { editing || draft.getValue(it).isNotEmpty() }.forEach { section ->
                            Card(colors = CardDefaults.cardColors(containerColor = colors.surface), modifier = Modifier.fillMaxWidth()) {
                                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Text(section.title, style = MaterialTheme.typography.titleMedium, color = colors.textBright)
                                    draft.getValue(section).forEachIndexed { index, text ->
                                        if(readOnly || !editing) SelectionContainer { Text("${index+1}. $text", color = colors.textBody) }
                                        else {
                                            OutlinedTextField(value = text, onValueChange = { value -> draft = draft + (section to draft.getValue(section).mapIndexed { i, s -> if(i==index) value else s }); message = null }, enabled = !busy && canWrite, minLines = 2, modifier = Modifier.fillMaxWidth(), label = { Text("${section.title}, משפט ${index+1}") })
                                            TextButton(enabled = !busy && canWrite, onClick = { draft = draft + (section to draft.getValue(section).filterIndexed { i, _ -> i != index }) }) { Text("הסרת משפט ${index+1}") }
                                        }
                                    }
                                    if(editing && !readOnly) key(owner,patientId,section) { ConceptSuggestionsControl(app,patientId,section,draft,busy || !canWrite) { values -> draft=draft+(section to ConceptSuggestions.append(draft.getValue(section),values));message=null } }
                                    if(draft.getValue(section).isEmpty()) Text("אין עדיין משפטים", color = colors.textBody)
                                    if(editing && !readOnly) TextButton(enabled = !busy && canWrite && draft.getValue(section).size < 30, onClick = { draft = draft + (section to (draft.getValue(section) + "")) }) { Text("הוספת משפט") }
                                }
                            }
                        }
                        if(loaded && !readOnly) {
                            if(editing && !validConcept(draft)) Text("יש למלא כל משפט (עד 1,500 תווים), או להסיר משפט ריק.", color = colors.error)
                            if(dirty) Text("יש לשמור את השינויים לפני השליחה.", color = colors.textBody)
                            else if(record?.revision != null) Text(if(record?.publishedRevision == record?.revision) "הגרסה השמורה נשלחה למטופל/ת" else if(record?.publishedRevision != null) "שינויים שמורים שטרם נשלחו" else "טרם נשלחה למטופל/ת", color = colors.textBody)
                        }
                        message?.let { Text(it, modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite }, color = colors.textBright) }
                    }
                    if(loaded && !readOnly) Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        if(editing) Button(enabled = !busy && canWrite && validConcept(draft) && (dirty || record?.revision == null), onClick = { run("save") }) { Text("שמירה") }
                        OutlinedButton(enabled = !busy && canWrite && !dirty && record?.revision != null && !conflict, onClick = { run("publish") }) { Text("שליחה למטופל/ת") }
                    }
                }
            }
        }
        if(cancelEditing) AlertDialog(onDismissRequest={cancelEditing=false},title={Text("לבטל את השינויים?")},confirmButton={TextButton(onClick={cancelEditing=false;draft=record?.document?:emptyConcept();editing=false;error=null;conflict=false}){Text("ביטול השינויים")}},dismissButton={TextButton(onClick={cancelEditing=false}){Text("המשך עריכה")}})
        if(discard) AlertDialog(onDismissRequest = { discard=false }, title = { Text("לצאת בלי לשמור את השינויים?") }, confirmButton = { TextButton(onClick = { discard=false; onDismiss() }) { Text("יציאה ללא שמירה") } }, dismissButton = { TextButton(onClick = { discard=false }) { Text("המשך עריכה") } })
        if(reload) AlertDialog(onDismissRequest = { reload=false }, title = { Text("טעינת הגרסה העדכנית") }, text = { Text("השינויים שלכם יישמרו כעותק כאן.") }, confirmButton = { TextButton(onClick = { reload=false; backup=draft; run(if(readOnly) "load_published" else "load_draft") }) { Text("טעינה ושמירת עותק") } }, dismissButton = { TextButton(onClick = { reload=false }) { Text("ביטול") } })
    }
}
