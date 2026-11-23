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
import com.cbtipul.app.ui.diary.DiaryFeelingIntensityControl
import com.cbtipul.app.ui.diary.DiaryFeelingPickerSheet

@Composable
fun CoreBeliefWorksheetDialog(app: CbTipulApp, patientId: String, readOnly: Boolean = false, onDismiss: () -> Unit) {
    val owner = remember(patientId) { app.authRepository.currentUserId() }
    val session by app.authRepository.session.collectAsStateWithLifecycle(initialValue = AuthSession.Loading)
    val entitlement by Entitlements.state.collectAsStateWithLifecycle()
    val service = remember { CoreBeliefService(app.authRepository.supabaseClient) }
    val scope = rememberCoroutineScope()
    val active = remember(owner, patientId) { java.util.concurrent.atomic.AtomicBoolean(true) }
    DisposableEffect(owner, patientId) { onDispose { active.set(false) } }
    var record by remember(owner, patientId) { mutableStateOf<CoreBeliefWorksheetRecord?>(null) }
    var draft by remember(owner, patientId) { mutableStateOf(CoreBeliefWorksheet()) }
    var backup by remember(owner, patientId) { mutableStateOf<CoreBeliefWorksheet?>(null) }
    var editing by remember(owner, patientId) { mutableStateOf(false) }
    var cancelEditing by remember { mutableStateOf(false) }
    var loaded by remember { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    var conflict by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var message by remember { mutableStateOf<String?>(null) }
    var discard by remember { mutableStateOf(false) }
    var reload by remember { mutableStateOf(false) }
    val dirty = loaded && draft != (record?.document ?: CoreBeliefWorksheet())
    val canWrite = !readOnly && entitlement.canWrite && entitlement.role == AppRole.Therapist
    fun run(action: String) {
        if (busy || readOnly && action != "load_published") return
        if ((action == "save" || action == "publish") && !canWrite) return
        busy = true; error = null; message = null
        val submitted = draft; val revision = record?.revision
        scope.launch {
            try {
                val result = service.request(action, if (readOnly) null else patientId, revision, submitted)
                if (!active.get() || owner != app.authRepository.currentUserId()) return@launch
                if (!result.patientId.equals(patientId, true)) throw CoreBeliefFailure(CoreBeliefFailure.Kind.Access)
                record = result; draft = result.document ?: CoreBeliefWorksheet(); loaded = true; conflict = false; editing = action == "load_draft" && result.document == null && canWrite
                message = when(action) { "save" -> "המסמך נשמר"; "publish" -> "המסמך נשלח למטופל/ת"; else -> null }
            } catch (e: CancellationException) { throw e }
            catch (e: Exception) {
                if (active.get() && owner == app.authRepository.currentUserId()) {
                    conflict = (e as? CoreBeliefFailure)?.kind == CoreBeliefFailure.Kind.Conflict
                    error = if (conflict) "המסמך השתנה במכשיר אחר. השינויים שלכם נשארו כאן." else if ((e as? CoreBeliefFailure)?.kind == CoreBeliefFailure.Kind.Access) "אין הרשאה לפעולה זו." else "לא ניתן לאשר שהפעולה הושלמה. השינויים נשארו כאן. אפשר לנסות שוב."
                }
            } finally { if (owner == app.authRepository.currentUserId()) busy = false }
        }
    }
    fun refresh() { if (dirty) reload = true else run(if(readOnly) "load_published" else "load_draft") }
    LaunchedEffect(owner, patientId) { run(if(readOnly) "load_published" else "load_draft") }
    LaunchedEffect(session) { if (owner != app.authRepository.currentUserId()) { draft = CoreBeliefWorksheet(); backup = null; record = null; onDismiss() } }
    val colors = Theme.colors
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
        Dialog(onDismissRequest = { if (!busy) { if (dirty) discard = true else onDismiss() } }, properties = DialogProperties(usePlatformDefaultWidth = false, dismissOnClickOutside = false, decorFitsSystemWindows = false)) {
            val dialogView = androidx.compose.ui.platform.LocalView.current
            SideEffect {
                (dialogView.parent as? androidx.compose.ui.window.DialogWindowProvider)?.window?.let { window ->
                    // The document draws its own safe-area padding; do not also crop its window.
                    if (android.os.Build.VERSION.SDK_INT >= 30) {
                        val attributes = window.attributes
                        attributes.setFitInsetsTypes(0)
                        window.attributes = attributes
                    }
                }
            }
            Surface(modifier = Modifier.fillMaxSize(), color = colors.base) {
                Column(Modifier.safeDrawingPadding().imePadding().padding(16.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("ערעור אמונת יסוד", modifier=Modifier.weight(1f), style = MaterialTheme.typography.titleLarge, color = colors.textBright)
                        if(canWrite && loaded) TextButton(enabled=!busy,onClick={ if(editing) { if(dirty) cancelEditing=true else editing=false } else editing=true }) { Text(if(editing) "ביטול עריכה" else "עריכה") }
                        TextButton(enabled = !busy, onClick = { if(dirty) discard = true else onDismiss() }) { Text("סגירה") }
                    }
                    if(busy) LinearProgressIndicator(Modifier.fillMaxWidth())
                    Column(Modifier.weight(1f).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        error?.let { Text(it, color = colors.error); TextButton(enabled = !busy, onClick = { refresh() }) { Text(if(conflict) "טעינת הגרסה העדכנית" else "ניסיון נוסף") } }
                        backup?.let { previous -> TextButton(enabled = !busy, onClick = { backup = draft; draft = previous; editing = true; message = "השינויים הוחזרו לעריכה. יש לשמור אותם." }) { Text("חזרה לשינויים שלי") } }
                        if(loaded && readOnly && record?.document == null) Text("עדיין לא נשלח עותק.", color=colors.textBody)
                        if(loaded && (!readOnly || record?.document != null)) {
                            CoreBeliefFields(draft, editing && !readOnly, !busy && canWrite) { draft=it;message=null }
                        }
                        if(loaded && !readOnly) {
                            if(editing && !validWorksheet(draft)) Text("כל שדה יכול להכיל עד 10,000 תווים.", color = colors.error)
                            if(dirty) Text("יש לשמור את השינויים לפני השליחה.", color = colors.textBody)
                            else if(record?.revision != null) Text(if(record?.publishedRevision == record?.revision) "הגרסה השמורה נשלחה למטופל/ת" else if(record?.publishedRevision != null) "שינויים שמורים שטרם נשלחו" else "טרם נשלחה למטופל/ת", color = colors.textBody)
                        }
                    if(loaded && !readOnly) Row(modifier=Modifier.fillMaxWidth().padding(top=16.dp,bottom=40.dp),horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        if(editing) Button(enabled = !busy && canWrite && validWorksheet(draft) && (dirty || record?.revision == null), onClick = { run("save") }) { Text("שמירה") }
                        OutlinedButton(enabled = !busy && canWrite && !dirty && record?.revision != null && !conflict, onClick = { run("publish") }) { Text("שליחת עותק למטופל/ת") }
                    }
                        message?.let { Text(it, modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite }, color = colors.textBright) }
                    }

                }
            }
        }
        if(cancelEditing) AlertDialog(onDismissRequest={cancelEditing=false},title={Text("לבטל את השינויים?")},confirmButton={TextButton(onClick={cancelEditing=false;draft=record?.document?:CoreBeliefWorksheet();editing=false;error=null;conflict=false}){Text("ביטול השינויים")}},dismissButton={TextButton(onClick={cancelEditing=false}){Text("המשך עריכה")}})
        if(discard) AlertDialog(onDismissRequest = { discard=false }, title = { Text("לצאת בלי לשמור את השינויים?") }, confirmButton = { TextButton(onClick = { discard=false; onDismiss() }) { Text("יציאה ללא שמירה") } }, dismissButton = { TextButton(onClick = { discard=false }) { Text("המשך עריכה") } })
        if(reload) AlertDialog(onDismissRequest = { reload=false }, title = { Text("טעינת הגרסה העדכנית") }, text = { Text("השינויים שלכם יישמרו כעותק כאן.") }, confirmButton = { TextButton(onClick = { reload=false; backup=draft; run(if(readOnly) "load_published" else "load_draft") }) { Text("טעינה ושמירת עותק") } }, dismissButton = { TextButton(onClick = { reload=false }) { Text("ביטול") } })
    }
}

private fun validWorksheet(value: CoreBeliefWorksheet) = runCatching { CoreBeliefWorksheetCodec.encodeDocument(value) }.isSuccess
@Composable
private fun CoreBeliefFields(draft: CoreBeliefWorksheet, editing: Boolean, enabled: Boolean, change: (CoreBeliefWorksheet)->Unit) {
    CoreBeliefGroup("אמונת היסוד הישנה") { BeliefFields(draft.oldBelief,editing,enabled) { change(draft.copy(oldBelief=it)) } }
    CoreBeliefGroup("אמונת יסוד מאוזנת") { BeliefFields(draft.balancedBelief,editing,enabled) { change(draft.copy(balancedBelief=it)) } }
    CoreBeliefGroup("הוכחות בעד האמונה הישנה") { CoreText("הוכחות בעד האמונה הישנה",draft.oldEvidence,editing,enabled) {change(draft.copy(oldEvidence=it))} }
    CoreBeliefGroup("דרכים חלופיות להסתכל על הראיות") { CoreText("דרכים חלופיות להסתכל על הראיות",draft.alternativeInterpretations,editing,enabled) {change(draft.copy(alternativeInterpretations=it))} }
    CoreBeliefGroup("הוכחות בעד האמונה המאוזנת") { CoreText("הוכחות בעד האמונה המאוזנת",draft.balancedEvidence,editing,enabled) {change(draft.copy(balancedEvidence=it))} }
    CoreBeliefGroup("התנהגות חדשה / ניסויים") { CoreText("התנהגות חדשה / ניסויים",draft.experiments,editing,enabled) {change(draft.copy(experiments=it))} }
    CoreBeliefGroup("דירוג מסכם") {
        CoreRating("האמונה הישנה",draft.finalOldRating,editing,enabled) {change(draft.copy(finalOldRating=it))}
        CoreRating("האמונה המאוזנת",draft.finalBalancedRating,editing,enabled) {change(draft.copy(finalBalancedRating=it))}
    }
}
@Composable private fun CoreBeliefGroup(title:String,content:@Composable ColumnScope.()->Unit) {
    Column(Modifier.fillMaxWidth().padding(vertical=16.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) {
        Text(title,style=MaterialTheme.typography.titleMedium,color=Theme.colors.textBright)
        content()
        HorizontalDivider(color=MaterialTheme.colorScheme.outlineVariant)
    }
}
@Composable private fun BeliefFields(value:CoreBeliefWorksheet.Belief,editing:Boolean,enabled:Boolean,change:(CoreBeliefWorksheet.Belief)->Unit) {
    CoreText("האמונה",value.text,editing,enabled) {change(value.copy(text=it))}
    CoreRating("עכשיו",value.now,editing,enabled) {change(value.copy(now=it))}
    CoreRating("הכי הרבה",value.most,editing,enabled) {change(value.copy(most=it))}
    CoreRating("הכי מעט",value.least,editing,enabled) {change(value.copy(least=it))}
    Text("רגשות",style=MaterialTheme.typography.labelLarge,color=Theme.colors.textBody)
    if(editing) CoreFeelings(value.feelings,enabled) {change(value.copy(feelings=it))}
    else CoreText("רגשות",value.feelings,false,enabled) {}
}
@Composable private fun CoreText(title:String,value:String,editing:Boolean,enabled:Boolean,change:(String)->Unit) {
    if(editing) OutlinedTextField(value=value,onValueChange={if(it.length<=10000)change(it)},label={Text(title)},minLines=3,enabled=enabled,modifier=Modifier.fillMaxWidth())
    else SelectionContainer { Text(value.ifEmpty{"לא מולא"},style=MaterialTheme.typography.bodyLarge,color=Theme.colors.textBody) }
}
@Composable private fun CoreRating(title:String,value:Int?,editing:Boolean,enabled:Boolean,change:(Int?)->Unit) {
    if(editing) {
        DiaryFeelingIntensityControl(intensity=value,title=title,requiresExplicitChoice=false,enabled=enabled,onIntensityChange={change(it)})
        if(value!=null) TextButton(enabled=enabled,onClick={change(null)}) { Text("ניקוי דירוג") }
    } else Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween) {
        Text(title,color=Theme.colors.textBody)
        Text(value?.let{"$it%"}?:"—",color=Theme.colors.textBright)
    }
}
@Composable private fun CoreFeelings(value:String,enabled:Boolean,change:(String)->Unit) {
    var picking by remember { mutableStateOf(false) }
    val names=value.split("\n").filter { it.isNotEmpty() }
    names.forEachIndexed { index,name ->
        Row(Modifier.fillMaxWidth()) {
            Text(name,Modifier.weight(1f),color=Theme.colors.textBody)
            TextButton(enabled=enabled,onClick={change(names.filterIndexed { i,_ -> i!=index }.joinToString("\n"))}) { Text("הסרה",modifier=Modifier.semantics { contentDescription="הסרת רגש: $name" }) }
        }
    }
    OutlinedButton(enabled=enabled,onClick={picking=true}) { Text("הוספת רגש") }
    if(picking && enabled) DiaryFeelingPickerSheet(names.toSet(),onPick={name ->
        if(name !in names) change((names+name).joinToString("\n"))
        picking=false
    },onDismiss={picking=false})
}
