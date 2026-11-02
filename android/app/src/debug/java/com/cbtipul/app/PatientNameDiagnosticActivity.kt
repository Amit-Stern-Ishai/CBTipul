package com.cbtipul.app

import android.os.Bundle
import android.util.Log
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.lifecycle.lifecycleScope
import com.cbtipul.app.data.*
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.from
import io.ktor.client.statement.bodyAsText
import kotlinx.coroutines.launch
import kotlinx.serialization.json.*

/** Debug-only read-only probe. Never records consent or sets a name; never emits response bodies. */
class PatientNameDiagnosticActivity : ComponentActivity() {
 override fun onCreate(savedInstanceState: Bundle?) {
  super.onCreate(savedInstanceState)
  val view=TextView(this);view.text="Checking name synchronization (read only)…";setContentView(view)
  val lines=mutableListOf<String>()
  fun report(value:String){lines+=value;Log.i("NameSyncProbe",value);view.text=lines.joinToString("\n")}
  lifecycleScope.launch {
   val app=application as CbTipulApp;val client=app.authRepository.supabaseClient
   val json=Json {ignoreUnknownKeys=true;explicitNulls=true}
   var operation="identity"
   try {
    client.auth.awaitInitialization()
    val user=client.auth.currentSessionOrNull()?.user
    report("project=${java.net.URI(SupabaseConfig.URL).host} signed_in=${user!=null} anonymous=${app.authRepository.isAnonymousSession()}")
    val expected=intent.getStringExtra("expected_email")
    report("expected_account_match=${expected?.let {it.equals(user?.email,true)} ?: "not_supplied"} coordinator_account_match=${user!=null&&user.id.equals(app.patientRepository.nameSync.account,true)}")
    if(user==null||app.authRepository.isAnonymousSession())return@launch
    operation="consent_lookup"
    val raw=client.postgrest.rpc("get_my_consent",buildJsonObject {put("p_consent_type",PatientNameRules.type);put("p_required_version",PatientNameRules.version)}).data
    val obj=json.parseToJsonElement(raw).jsonObject
    report("consent_shape=object required_keys=${listOf("therapist_id","consent_type","required_version","accepted_version","accepted_at","revoked_at","status","revision").all {it in obj}}")
    val receipt=json.decodeFromString<NameConsentReceipt>(raw);receipt.validate(user.id)
    report("consent_accepted=${receipt.status=="accepted"} receipt_account_match=${receipt.therapist_id.equals(user.id,true)}")
    if(receipt.status!="accepted")return@launch
    operation="patient_ids"
    val patients=json.parseToJsonElement(client.from("Patients").select(io.github.jan.supabase.postgrest.query.Columns.raw("id")).data).jsonArray
    val ids=patients.map {it.jsonObject.getValue("id").jsonPrimitive.content.lowercase()}.toSet()
    operation="names_list"
    var after:String?=null;val seen=mutableSetOf<String>();var total=0;var named=0;var matched=0
    do {
     val response=client.functions.invoke("patient-names",headers=PatientNameSync.jsonHeaders(),body=buildJsonObject {put("operation","list");put("after",after?.let(::JsonPrimitive)?:JsonNull);put("limit",100)})
     report("operation=names_list http=${response.status.value}")
     val body=response.bodyAsText()
     val page=json.decodeFromString<PatientNamePage>(body)
     total+=page.names.size;named+=page.names.count {it.name!=null};matched+=page.names.count {it.patient_id.lowercase() in ids&&it.name!=null}
     after=page.next_after
     report("page_records=${page.names.size} has_next=${after!=null}")
     check(after==null||seen.add(after!!))
    }while(after!=null)
    val state=app.patientRepository.nameSync.state.value
    report("patient_ids=${ids.size} name_records=$total nonnull_names=$named matching_named_patients=$matched")
    report("coordinator_accepted=${state.accepted} failed=${state.failed} busy=${state.busy} displayed_names=${app.patientRepository.patients.value.count { !it.localName.isNullOrEmpty() }}")
   }catch(e:Exception){report("operation=$operation http=${EdgePayload.httpStatus(e)?:0} failure_type=${e.javaClass.simpleName}")}
  }
 }
}
