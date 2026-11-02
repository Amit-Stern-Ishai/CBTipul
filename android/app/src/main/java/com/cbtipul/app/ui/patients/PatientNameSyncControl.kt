package com.cbtipul.app.ui.patients
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.contentDescription
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.cbtipul.app.data.PatientNameRules
import com.cbtipul.app.data.PatientNameSync
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable internal fun PatientNameSyncControl(sync:PatientNameSync) {
 val state by sync.state.collectAsStateWithLifecycle()
 val scope=rememberCoroutineScope();var show by remember {mutableStateOf(false)}
 LifecycleEventEffect(Lifecycle.Event.ON_RESUME){scope.launch {sync.refresh()}}
 if(!state.accepted||state.pending||state.failed) TextButton(onClick={if(state.accepted)scope.launch {sync.refresh(true)} else show=true},enabled=!state.busy) {
  Text(if(state.accepted) "סנכרון שמות ממתין — ניסיון נוסף" else "הגדרת סנכרון שמות")
 }
 if(show) ModalBottomSheet(onDismissRequest={if(!state.busy)show=false}) {
  Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(24.dp),verticalArrangement=Arrangement.spacedBy(20.dp)) {
   Text(PatientNameRules.title,style=MaterialTheme.typography.titleLarge)
   Text(PatientNameRules.notice,style=MaterialTheme.typography.bodyLarge)
   if(state.failed)Text("לא ניתן להשלים את סנכרון השמות כרגע. אפשר לנסות שוב; הגישה לתיקי המטופלים נשארת זמינה.",color=MaterialTheme.colorScheme.error)
   if(state.busy)CircularProgressIndicator()
   Button(onClick={scope.launch {sync.decide();if(sync.state.value.accepted&&!sync.state.value.failed)show=false}},enabled=!state.busy,modifier=Modifier.fillMaxWidth()){Text("אישור והמשך")}
   val context=androidx.compose.ui.platform.LocalContext.current
   TextButton(onClick={sync.setAccount(null);scope.launch {(context.applicationContext as com.cbtipul.app.CbTipulApp).authRepository.signOut()}}){Text("יציאה מהחשבון")}
  }
 }
}

/** Root-level gate. Completion is a durable device/account checkpoint, not cached consent. */
@Composable internal fun PatientNameMigrationScreen(sync:PatientNameSync, contextKey:String, retry:suspend ()->Unit, logout:()->Unit) {
 val state by sync.state.collectAsStateWithLifecycle()
 val scope=rememberCoroutineScope()
 androidx.activity.compose.BackHandler { /* Back cannot expose the clinic. */ }
 LaunchedEffect(contextKey){sync.refresh(true)}
 Surface(Modifier.fillMaxSize()) {
  Column(Modifier.fillMaxSize().safeDrawingPadding().verticalScroll(rememberScrollState()).padding(24.dp),verticalArrangement=Arrangement.spacedBy(20.dp)) {
   Text(PatientNameRules.title,style=MaterialTheme.typography.titleLarge)
   if(state.consentChecked&&!state.accepted)Text(PatientNameRules.notice,style=MaterialTheme.typography.bodyLarge)
   Text(if(state.accepted)"מסנכרנים את שמות המטופלים במכשיר זה. המרפאה תיפתח לאחר השלמת הסנכרון." else "בודקים את אישור שמירת השמות.")
   if(state.busy)CircularProgressIndicator(Modifier.semantics {contentDescription="מסנכרנים שמות"})
   if(state.failed)Text("לא ניתן להשלים את הבדיקה או הסנכרון כרגע. השמות המקומיים לא נמחקו. יש לבדוק את החיבור ולנסות שוב.",color=MaterialTheme.colorScheme.error)
   if(state.consentChecked&&!state.accepted)Button(onClick={scope.launch {sync.decide()}},enabled=!state.busy,modifier=Modifier.fillMaxWidth()){Text("אישור והמשך")}
   if(!state.busy)OutlinedButton(onClick={scope.launch {retry()}},modifier=Modifier.fillMaxWidth()){Text("ניסיון נוסף")}
   TextButton(onClick=logout,modifier=Modifier.fillMaxWidth().heightIn(min=48.dp)) {
    Text("לא עכשיו — יציאה מהחשבון",textAlign=androidx.compose.ui.text.style.TextAlign.Center,softWrap=true)
   }
  }
 }
}
