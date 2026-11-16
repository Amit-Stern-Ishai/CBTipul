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

@Composable internal fun PatientNameSyncControl(sync:PatientNameSync) {
 val state by sync.state.collectAsStateWithLifecycle()
 val scope=rememberCoroutineScope()
 LaunchedEffect(state.account){sync.refresh(true)}
 LifecycleEventEffect(Lifecycle.Event.ON_RESUME){scope.launch {sync.refresh()}}
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
   Text(PatientNameRules.notice,style=MaterialTheme.typography.bodyLarge)


   if(state.approvalFailed)Text(androidx.compose.ui.res.stringResource(com.cbtipul.app.R.string.patient_name_approval_failed),color=MaterialTheme.colorScheme.error)
   if(!state.accepted)Button(onClick={scope.launch {sync.decide()}},enabled=!state.busy,modifier=Modifier.fillMaxWidth()){Text("אישור והמשך")}
   TextButton(onClick=logout,modifier=Modifier.fillMaxWidth().heightIn(min=48.dp)) {
    Text("לא עכשיו — יציאה מהחשבון",textAlign=androidx.compose.ui.text.style.TextAlign.Center,softWrap=true)
   }
  }
 }
}
