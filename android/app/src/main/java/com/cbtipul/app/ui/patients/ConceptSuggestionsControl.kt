package com.cbtipul.app.ui.patients

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.toggleable
import androidx.compose.ui.semantics.Role
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.cbtipul.app.CbTipulApp
import com.cbtipul.app.R
import com.cbtipul.app.data.*
import com.cbtipul.app.model.*
import com.cbtipul.app.ui.theme.Theme
import kotlinx.coroutines.*
import java.text.DateFormat
import java.util.Locale

@Composable
internal fun ConceptSuggestionsControl(app:CbTipulApp, patientId:String, section:ConceptSection, draft:ConceptDocument, disabled:Boolean, add:(List<String>)->Unit) {
    val scope=rememberCoroutineScope()
    var loading by remember { mutableStateOf(false) }
    var suggestions by remember { mutableStateOf<List<String>?>(null) }
    var selected by remember { mutableStateOf(setOf<String>()) }
    var error by remember { mutableStateOf<String?>(null) }
    val colors=Theme.colors
    Column(verticalArrangement=Arrangement.spacedBy(8.dp)) {
        TextButton(contentPadding=PaddingValues(horizontal=4.dp,vertical=0.dp), colors=ButtonDefaults.textButtonColors(contentColor=colors.textBody), enabled=!disabled&&!loading,onClick={
            if(!loading){
                loading=true;error=null;suggestions=null;selected=emptySet()
                val snapshot=draft.mapValues { it.value.toList() };val owner=app.authRepository.currentUserId()
                scope.launch {
                    try {
                        Entitlements.requireWrite();app.aiConsentStore.ensureGranted();ensureActive()
                        if(owner==null||owner!=app.authRepository.currentUserId())throw CancellationException()
                        val patient=app.patientRepository.patient(patientId) ?: error("patient_unavailable")
                        val questionnaires=app.patientRepository.loadQuestionnaires(patient.id)
                        val r=app.resources
                        val context=fullContext(patient,questionnaires,r.getStringArray(R.array.gad7_questions).toList(),r.getStringArray(R.array.phq9_questions).toList(),r.getStringArray(R.array.phq9_interference_options).toList(),DateFormat.getDateInstance(DateFormat.MEDIUM,Locale.forLanguageTag("he-IL")),
                            gad={r.getString(when(it){GAD7Severity.Minimal->R.string.gad7_severity_minimal;GAD7Severity.Mild->R.string.gad7_severity_mild;GAD7Severity.Substantial->R.string.gad7_severity_substantial;GAD7Severity.Extreme->R.string.gad7_severity_extreme})},
                            phq={r.getString(when(it){PHQ9Severity.Minimal->R.string.phq9_severity_minimal;PHQ9Severity.Mild->R.string.phq9_severity_mild;PHQ9Severity.Moderate->R.string.phq9_severity_moderate;PHQ9Severity.ModeratelySevere->R.string.phq9_severity_moderately_severe;PHQ9Severity.Severe->R.string.phq9_severity_severe})})
                        val diaries=diaryChatContext(app.diaryOne.loadEntries(patient.id),app.diaryTwo.loadEntries(patient.id),app.diaryThree.loadEntries(patient.id),emptyList())
                        val rows=ConceptSuggestions.request(app.authRepository.supabaseClient,owner,patientId,section,snapshot,"$context\n\n$diaries")
                        ensureActive();if(owner==app.authRepository.currentUserId())suggestions=rows.filterNot { it in snapshot.getValue(section) }
                    } catch(e:CancellationException){throw e}
                    catch(e:ConsentDeclinedException){ }
                    catch(e:Exception){if(owner==app.authRepository.currentUserId())error=ConceptSuggestions.message(e)}
                    finally{loading=false}
                }
            }
        }){Text(if(loading)"מכינים הצעות…" else if(error!=null)"ניסיון נוסף — הצעות AI" else "הצעות AI",style=MaterialTheme.typography.labelMedium)}
        if(loading) LinearProgressIndicator(Modifier.fillMaxWidth())
        error?.let{Text(it,color=colors.error)}
        suggestions?.let { rows->
            if(rows.isEmpty()) Text("אין מספיק מידע להצעות",color=colors.textBody)
            else {
                Text("הצעות לבדיקה — בחרו מה להוסיף",color=colors.textBody,style=MaterialTheme.typography.bodySmall)
                rows.forEach { text-> Row(Modifier.fillMaxWidth().toggleable(value=text in selected, enabled=!disabled, role=Role.Checkbox, onValueChange={selected=if(it)selected+text else selected-text})) { Checkbox(checked=text in selected,enabled=!disabled,onCheckedChange=null);Text(text,color=colors.textBright,modifier=Modifier.padding(top=12.dp)) } }
                OutlinedButton(enabled=!disabled&&selected.isNotEmpty()&&draft.getValue(section).size+selected.size<=30,onClick={add(rows.filter { it in selected });suggestions=null;selected=emptySet()}){Text("הוספת הנבחרות")}
            }
        }
    }
}
