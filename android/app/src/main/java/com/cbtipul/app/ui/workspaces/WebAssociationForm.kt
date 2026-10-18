package com.cbtipul.app.ui.workspaces

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.cbtipul.app.R
import com.cbtipul.app.data.WebAssociationCandidate
import com.cbtipul.app.ui.theme.Theme
import kotlinx.serialization.json.JsonObject

internal data class WebAssociationFormState(
    val patients:List<Pair<String,String>>,val patientID:String,val sessions:List<Pair<String,String>>,val sessionKey:String,
    val needsSession:Boolean,val createSession:Boolean,val types:List<Pair<String,String>>,val typeName:String,val dateLabel:String,
    val offerLink:Boolean,val link:Boolean,val candidates:List<WebAssociationCandidate>,val choice:JsonObject?,val append:Boolean,
    val loadingPatients:Boolean=false,val loadingPreview:Boolean=false,val hasContent:Boolean=true,val loadingContent:Boolean=false,
    val error:Int?=null,val busy:Boolean=false,val valid:Boolean=false,val closed:Boolean=false,val lockedDestination:String?=null,
)

@Composable internal fun ColumnScope.WebAssociationForm(
    state:WebAssociationFormState,onPatient:(String)->Unit,onSession:(String)->Unit,onLink:(Boolean)->Unit,onDate:()->Unit,onType:(String)->Unit,
    onChoice:(JsonObject)->Unit,onInspect:(WebAssociationCandidate)->Unit,onContent:()->Unit,onRetry:()->Unit,onSave:()->Unit,
){
    if(state.lockedDestination!=null){Text(stringResource(R.string.ww_uncertain));Text(state.lockedDestination)}
    else{
        Text(stringResource(R.string.ww_patient),style=MaterialTheme.typography.titleMedium)
        Row(verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(12.dp)){
            Box(Modifier.weight(1f)){Choice(stringResource(R.string.ww_choose_patient),state.patients,state.patientID,!state.busy,onPatient)}
            if(state.loadingPatients||state.loadingPreview&&!state.needsSession)CircularProgressIndicator(Modifier.size(20.dp),strokeWidth=2.dp)
        }
        if(state.offerLink){
            Row(Modifier.fillMaxWidth().toggleable(value=state.link,enabled=!state.busy,role=Role.Switch,onValueChange=onLink),verticalAlignment=Alignment.CenterVertically){
                Text(stringResource(R.string.ww_link_optional),Modifier.weight(1f));Switch(checked=state.link,onCheckedChange=null,enabled=!state.busy)
            }
            if(!state.link)Text(stringResource(R.string.ww_questionnaire_patient_level),style=MaterialTheme.typography.bodySmall,color=Theme.colors.textBody)
        }
        if(state.needsSession){
            Text(stringResource(R.string.ww_session_target),style=MaterialTheme.typography.titleMedium)
            Row(verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(12.dp)){
                Box(Modifier.weight(1f)){Choice(stringResource(R.string.ww_choose_session),state.sessions+listOf("new" to stringResource(R.string.ww_new_session)),state.sessionKey,!state.busy,onSession)}
                if(state.loadingPreview)CircularProgressIndicator(Modifier.size(20.dp),strokeWidth=2.dp)
            }
            if(state.createSession){
                OutlinedButton(onClick=onDate,enabled=!state.busy,shape=MaterialTheme.shapes.medium,modifier=Modifier.fillMaxWidth()){Text(stringResource(R.string.session_date_title)+": "+state.dateLabel)}
                Choice(stringResource(R.string.ww_choose_type),state.types,state.typeName,!state.busy,onType)
            }
        }
    }
    if(state.append){
        Text(stringResource(R.string.ww_append_existing_notes))
        var help by remember{mutableStateOf(false)}
        TextButton(onClick={help=!help}){Text(stringResource(R.string.ww_analysis_help))}
        if(help)Text(stringResource(R.string.ww_regenerate_analysis),style=MaterialTheme.typography.bodySmall,color=Theme.colors.textBody)
    }
    if(state.link && state.lockedDestination==null && !state.loadingPreview){
        val eligible=state.candidates.filter{it.selectable&&it.choice!=null}
        if(eligible.size>1){
            Text(stringResource(R.string.ww_choose_result),style=MaterialTheme.typography.titleMedium)
            Text(stringResource(R.string.ww_preserve_results),style=MaterialTheme.typography.bodySmall,color=Theme.colors.textBody)
            state.candidates.forEach{candidate->key(candidate.key){WebCandidateRow(candidate,state.choice==candidate.choice,!state.busy,{candidate.choice?.let(onChoice)},{onInspect(candidate)})}}
        }else if(eligible.size==1){
            WebCandidateRow(eligible.single(),true,!state.busy,null,{onInspect(eligible.single())})
            Text(stringResource(R.string.ww_preserve_results),style=MaterialTheme.typography.bodySmall,color=Theme.colors.textBody)
        }else if(state.sessionKey.isNotEmpty()){Text(stringResource(R.string.ww_no_linked_questionnaire),color=Theme.colors.error)}
    }
    if(state.hasContent)TextButton(onClick=onContent,modifier=Modifier.testTag("workspace.associate.content")){Text(stringResource(R.string.ww_preview))}
    if(state.loadingContent)CircularProgressIndicator(Modifier.size(20.dp),strokeWidth=2.dp)
    state.error?.let{Text(stringResource(it),color=Theme.colors.error);if(state.lockedDestination==null)TextButton(onClick=onRetry,enabled=!state.busy){Text(stringResource(R.string.retry))}}
    if(!state.closed)Button(onClick=onSave,enabled=state.valid&&!state.busy,shape=MaterialTheme.shapes.medium,colors=ButtonDefaults.buttonColors(containerColor=Theme.colors.accentFill,contentColor=Theme.colors.textOnAccent,disabledContainerColor=Theme.colors.elevated,disabledContentColor=Theme.colors.textFaint),modifier=Modifier.fillMaxWidth().heightIn(min=48.dp).testTag("workspace.associate.save")){
        if(state.busy)CircularProgressIndicator(Modifier.size(18.dp),color=Theme.colors.textOnAccent,strokeWidth=2.dp)
        Text(stringResource(if(state.busy)R.string.ww_saving_to_file else R.string.ww_associate))
    }
}

@Composable private fun WebCandidateRow(candidate:WebAssociationCandidate,selected:Boolean,enabled:Boolean,onChoose:(()->Unit)?,onInspect:()->Unit){
    HorizontalDivider()
    val modifier=if(onChoose!=null)Modifier.fillMaxWidth().selectable(selected=selected,enabled=enabled&&candidate.selectable&&candidate.choice!=null,role=Role.RadioButton,onClick=onChoose) else Modifier.fillMaxWidth()
    Row(modifier.padding(vertical=10.dp),verticalAlignment=Alignment.Top){
        if(onChoose!=null)RadioButton(selected=selected,onClick=null,enabled=enabled&&candidate.selectable&&candidate.choice!=null)
        Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(5.dp)){WebCandidateSummary(candidate)}
    }
    TextButton(onClick=onInspect){Text(stringResource(R.string.ww_inspect_answers))}
}
