package com.cbtipul.app.ui.patients

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.unit.dp
import com.cbtipul.app.CbTipulApp
import com.cbtipul.app.data.*
import com.cbtipul.app.ui.theme.Theme
import kotlinx.coroutines.launch
import kotlinx.coroutines.CancellationException

@Composable fun ExposureAccessRow(app:CbTipulApp,patientId:String,connected:Boolean,onBusy:(Boolean)->Unit={}){
 val owner=app.authRepository.currentUserId();val scope=rememberCoroutineScope();val service=remember{ExposureService(app.authRepository.supabaseClient)}
 var enabled by remember(owner,patientId){mutableStateOf<Boolean?>(null)};var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)};var editor by remember{mutableStateOf(false)}
 val active=remember(owner,patientId){java.util.concurrent.atomic.AtomicBoolean(true)};DisposableEffect(owner,patientId){onDispose{active.set(false)}}
 fun update(value:Boolean?){if(busy)return;busy=true;onBusy(true);error=false;scope.launch{try{
  if(value!=null){app.appContext.getCurrentAppContext();if(app.authRepository.currentUserId()!=owner)throw CancellationException();service.setEnabled(patientId,value)}
  val result=service.enabled(patientId);if(active.get()&&app.authRepository.currentUserId()==owner)enabled=result
 }catch(e:CancellationException){throw e}catch(_:Exception){if(active.get()&&app.authRepository.currentUserId()==owner)error=true}finally{if(active.get()){busy=false;onBusy(false)}}}}
 LaunchedEffect(owner,patientId,connected){if(connected)update(null)}
 Column(Modifier.fillMaxWidth().padding(vertical=12.dp)){
  TextButton(onClick={editor=true},enabled=!busy){Text("מדרג חשיפות",style=MaterialTheme.typography.titleMedium)}
  if(connected){enabled?.let{value->Row(verticalAlignment=Alignment.CenterVertically){Text("גישה למטופל/ת",modifier=Modifier.weight(1f));Switch(checked=value,onCheckedChange={update(it)},enabled=!busy)}};if(busy)LinearProgressIndicator(Modifier.fillMaxWidth());if(error){Text("לא ניתן לעדכן את הגישה כרגע.",color=Theme.colors.error);TextButton(onClick={update(null)},enabled=!busy){Text("ניסיון נוסף")}}}
 }
 if(editor)ExposureHierarchyDialog(app,patientId){editor=false}
}
