package com.cbtipul.app.ui.patients

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.cbtipul.app.CbTipulApp
import com.cbtipul.app.auth.AuthSession
import com.cbtipul.app.data.*
import com.cbtipul.app.ui.theme.Theme
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import kotlinx.coroutines.isActive

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ExposureHierarchyDialog(app:CbTipulApp,patientId:String?,review:Boolean=false,reviewEditing:Boolean=false,onDismiss:()->Unit){
 val owner=remember(patientId){app.authRepository.currentUserId()}
 val session by app.authRepository.session.collectAsStateWithLifecycle(initialValue=AuthSession.Loading)
 val entitlement by Entitlements.state.collectAsStateWithLifecycle()
 val service=remember{ExposureService(app.authRepository.supabaseClient)};val scope=rememberCoroutineScope();val colors=Theme.colors
 var record by remember{mutableStateOf<ExposureRecord?>(null)};var draft by remember{mutableStateOf(ExposureDocument())};var backup by remember{mutableStateOf<ExposureDocument?>(null)}
 var loaded by remember{mutableStateOf(false)};var editing by remember{mutableStateOf(false)};var busy by remember{mutableStateOf(false)};var conflict by remember{mutableStateOf(false)};var denied by remember{mutableStateOf(false)}
 var error by remember{mutableStateOf<String?>(null)};var message by remember{mutableStateOf<String?>(null)};var confirm by remember{mutableStateOf<String?>(null)}
 val active=remember{java.util.concurrent.atomic.AtomicBoolean(true)};DisposableEffect(Unit){onDispose{active.set(false)}}
 val preview=com.cbtipul.app.BuildConfig.DEBUG&&review
 val dirty=loaded&&draft!=(record?.document?:ExposureDocument());val write=preview||entitlement.canWrite
 val list=rememberLazyListState();var dragging by remember{mutableStateOf<String?>(null)};var dragY by remember{mutableFloatStateOf(0f)}
 val currentDraft by rememberUpdatedState(draft)
 fun move(id:String,to:Int){draft=draft.move(id,to)}
 fun run(action:String,checkOnly:Boolean=false){if(busy)return;busy=true;error=null;message=null;scope.launch{
  try {val result=if(preview)ExposureRecord("11111111-1111-4111-8111-111111111111",if(action=="save")draft else ExposureDocument(listOf(ExposureItem(situation="לשאול שאלה בשיחה עם אדם מוכר",difficulty=80),ExposureItem(situation="להציג רעיון קצר בפני שני אנשים"),ExposureItem(situation="לצאת להליכה קצרה במקום מוכר",difficulty=0))),"synthetic") else service.request(action,patientId,record?.revision,draft);if(!active.get()||app.authRepository.currentUserId()!=owner)return@launch;denied=false;if(!checkOnly){record=result;draft=result.document?:ExposureDocument();loaded=true;conflict=false;editing=action=="load"&&(result.document==null||preview&&reviewEditing)&&write};if(action=="save")message="המדרג נשמר"}
  catch(e:CancellationException){throw e}catch(e:Exception){if(active.get()&&app.authRepository.currentUserId()==owner){conflict=(e as? ExposureFailure)?.kind==ExposureFailure.Kind.Conflict;denied=(e as? ExposureFailure)?.kind==ExposureFailure.Kind.Access;error=if(conflict)"המדרג השתנה במכשיר אחר. השינויים שלכם נשארו כאן." else if(denied)"אין כרגע גישה למדרג. אפשר לבדוק שוב." else "לא ניתן לאשר שהפעולה הושלמה. השינויים נשארו כאן. אפשר לנסות שוב."}}
  finally{if(active.get()&&app.authRepository.currentUserId()==owner)busy=false}
 }}
 fun reload(){if(dirty)confirm="reload" else run("load")}
 fun close(){if(!busy){if(dirty)confirm="close" else onDismiss()}}
 LaunchedEffect(Unit){run("load")}
 androidx.lifecycle.compose.LifecycleEventEffect(androidx.lifecycle.Lifecycle.Event.ON_RESUME){if(patientId==null&&loaded)run("load",checkOnly=dirty)}
 LaunchedEffect(session){if(app.authRepository.currentUserId()!=owner)onDismiss()}
 // The pointer remains on the handle; long-press never intercepts ordinary text/scroll gestures.
 LaunchedEffect(dragging){while(dragging!=null&&isActive){val layout=list.layoutInfo;val edge=72f;val delta=when{dragY<layout.viewportStartOffset+edge->-18f;dragY>layout.viewportEndOffset-edge->18f;else->0f};if(delta!=0f)list.scroll{scrollBy(delta)};kotlinx.coroutines.delay(32)}}
 Dialog(onDismissRequest=::close,properties=DialogProperties(usePlatformDefaultWidth=false,dismissOnBackPress=!busy,dismissOnClickOutside=false,decorFitsSystemWindows=false)){
  val dialogView=androidx.compose.ui.platform.LocalView.current
  SideEffect{(dialogView.parent as? androidx.compose.ui.window.DialogWindowProvider)?.window?.let{window->if(android.os.Build.VERSION.SDK_INT>=30){val attributes=window.attributes;attributes.setFitInsetsTypes(0);window.attributes=attributes}}}
  CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl){
   Scaffold(modifier=Modifier.fillMaxSize().safeDrawingPadding(),containerColor=colors.base,topBar={TopAppBar(title={Text("מדרג חשיפות")},navigationIcon={TextButton(onClick={if(editing){if(dirty)confirm="cancel" else editing=false}else close()},enabled=!busy){Text(if(editing)"ביטול עריכה" else "סגירה")}},actions={if(loaded&&!denied&&write)TextButton(onClick={if(editing)run("save") else editing=true},enabled=!busy&&(!editing||(draft.valid()&&!conflict))){Text(if(editing)"שמירה" else "עריכה")}})}){padding->
    LazyColumn(state=list,modifier=Modifier.fillMaxSize().padding(padding).imePadding(),contentPadding=PaddingValues(16.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){
     item{if(busy)LinearProgressIndicator(Modifier.fillMaxWidth());error?.let{Text(it,color=colors.error);TextButton(onClick=::reload,enabled=!busy){Text(if(conflict)"טעינת המדרג העדכני" else "ניסיון נוסף")}};if(backup!=null&&!denied)TextButton(onClick={confirm="backup"},enabled=!busy){Text("חזרה לשינויים שלי")}}
     if(loaded&&!denied){
      item{if(editing)Text("לחצו לחיצה ארוכה על הידית וגררו לשינוי הסדר.",color=colors.textBody);if(draft.items.isEmpty()&&!editing)Text("אין עדיין מצבים במדרג.")}
      itemsIndexed(draft.items,key={_,x->x.id}){index,item->
       OutlinedCard(colors=CardDefaults.outlinedCardColors(containerColor=colors.surface),modifier=Modifier.fillMaxWidth().semantics {if(editing&&!busy)customActions=listOf(CustomAccessibilityAction("הזזה למעלה"){move(item.id,index-1);true},CustomAccessibilityAction("הזזה למטה"){move(item.id,index+1);true})}){
        Column(Modifier.padding(16.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){
         Row(verticalAlignment=Alignment.CenterVertically){Text("${index+1}",color=colors.textBody,modifier=Modifier.weight(1f));if(editing){
          Icon(Icons.Outlined.DragHandle,contentDescription="לחיצה ארוכה לגרירה",modifier=Modifier.size(48.dp).pointerInput(item.id,busy,editing){if(!busy)detectDragGesturesAfterLongPress(onDragStart={offset->dragging=item.id;dragY=(list.layoutInfo.visibleItemsInfo.firstOrNull{it.key==item.id}?.offset?:0)+offset.y},onDragEnd={dragging=null},onDragCancel={dragging=null}){change,amount->change.consume();dragY+=amount.y;val target=list.layoutInfo.visibleItemsInfo.firstOrNull{dragY>=it.offset&&dragY<it.offset+it.size};val to=currentDraft.items.indexOfFirst{it.id==target?.key};if(to>=0)move(item.id,to)}})
         }else Text(item.difficulty?.let{"$it%"}?:"טרם דורג",color=colors.gold)}
         if(editing){
          OutlinedTextField(value=item.situation,onValueChange={v->draft=draft.copy(items=draft.items.map{if(it.id==item.id)it.copy(situation=v)else it})},label={Text("המצב")},minLines=2,enabled=!busy,modifier=Modifier.fillMaxWidth())
          Text("רמת הקושי · "+(item.difficulty?.let{"$it%"}?:"טרם דורג"),color=colors.textBody)
          Slider(value=(item.difficulty?:50).toFloat(),onValueChange={v->draft=draft.copy(items=draft.items.map{if(it.id==item.id)it.copy(difficulty=v.toInt())else it})},valueRange=0f..100f,steps=99,enabled=!busy,modifier=Modifier.semantics{contentDescription="רמת הקושי";stateDescription=item.difficulty?.let{"$it%"}?:"טרם דורג"})
          Row{TextButton(onClick={draft=draft.copy(items=draft.items.map{if(it.id==item.id)it.copy(difficulty=null)else it})},enabled=!busy&&item.difficulty!=null){Text("ניקוי דירוג")};Spacer(Modifier.weight(1f));IconButton(onClick={move(item.id,index-1)},enabled=!busy&&index>0){Icon(Icons.Outlined.ArrowUpward,"הזזה למעלה")};IconButton(onClick={move(item.id,index+1)},enabled=!busy&&index<draft.items.lastIndex){Icon(Icons.Outlined.ArrowDownward,"הזזה למטה")};IconButton(onClick={draft=draft.copy(items=draft.items.filter{it.id!=item.id})},enabled=!busy){Icon(Icons.Outlined.Delete,"מחיקת מצב",tint=colors.error)}}
         }else SelectionContainer{Text(item.situation,color=colors.textBright)}
        }
       }
      }
      item{if(editing){OutlinedButton(onClick={draft=draft.copy(items=draft.items+ExposureItem())},enabled=!busy&&draft.items.size<100){Icon(Icons.Outlined.Add,null);Text("הוספת מצב")};if(!draft.valid())Text("יש לכתוב מצב בכל שורה (עד 1,000 תווים).",color=colors.error)};message?.let{Text(it,color=colors.success)}}
     }
    }
   }
  }
 }
 if(confirm!=null)AlertDialog(onDismissRequest={confirm=null},title={Text("יש שינויים שלא נשמרו")},text={Text(if(confirm=="reload")"השינויים שלכם יישמרו כאן בנפרד." else "השינויים יוחלפו רק לאחר אישור.")},dismissButton={TextButton(onClick={confirm=null}){Text("חזרה")}},confirmButton={TextButton(onClick={val action=confirm;confirm=null;when(action){"reload"->{backup=draft;run("load")};"backup"->{draft=backup!!;backup=null;editing=true};"close"->onDismiss();else->{draft=record?.document?:ExposureDocument();editing=false;conflict=false;error=null}}}){Text(if(confirm=="reload")"טעינת המדרג העדכני" else if(confirm=="backup")"חזרה לשינויים שלי" else "ויתור על השינויים")}})
}
