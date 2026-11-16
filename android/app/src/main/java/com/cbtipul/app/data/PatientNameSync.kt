package com.cbtipul.app.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.exceptions.RestException
import io.ktor.client.plugins.ResponseException
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.*
import java.time.Instant
import java.util.UUID

object PatientNameRules {
 const val version = "2026-10-29"
 const val type = "patient_name_storage"
 fun valid(name: String) = name.isNotBlank() && name.codePointCount(0,name.length)<=200 && name.none { it.code<32 || it.code==127 }
 fun revision(value: String) = value.isNotEmpty() && value.all { it in '0'..'9' }
 fun older(value:String,current:String):Boolean { val a=value.trimStart('0');val b=current.trimStart('0');return if(a.length==b.length)a<b else a.length<b.length }
 const val title = "שמירת שמות מטופלים וסנכרון בין מכשירים"
 val notice = """מעתה שמות המטופלים יישמרו בשרתי CBTipul בצורה מוצפנת, כדי לאפשר סנכרון בין מכשירים ובהמשך גם בחירת מטופל/ת בסביבת העבודה במחשב.

לאחר אישורך, שמות המטופלים השמורים במכשיר זה יועברו לשרת באמצעות חיבור מוצפן וישויכו לרשומות המטופלים הקיימות. שמות שתזינו או תשנו בהמשך יישמרו גם הם באופן זה.

ההצפנה מנוהלת בשרת: מערכות CBTipul המורשות יכולות לפענח את השמות לצורך מתן השירות. זו אינה הצפנה מקצה לקצה.

שדה שם המטופל/ת לא יצורף אוטומטית לבקשות לכלי בינה מלאכותית. מידע מזהה שהוזן בתוך טקסט חופשי מטופל בנפרד לפי מדיניות עיבוד התוכן.

בחירה באישור והמשך מאשרת את השמירה והסנכרון המתוארים כאן. בחירה בלא עכשיו לא תעלה שמות ותשאיר את תהליך ההגדרה ממתין."""
}
class NameSyncFailure(val code: String, val httpStatus: Int? = null): Exception(if(code=="invalid_name") "יש להזין שם שאינו ריק, עד 200 תווים וללא תווי בקרה." else when(code){"consent_required"->"השרת לא אישר את שמירת השם. אפשר לנסות שוב מאוחר יותר.";"revision_conflict"->"השם השתנה במכשיר אחר. בדקו את השם ונסו שוב.";else->"שמירת השם נכשלה. אפשר לנסות שוב."})
@Serializable data class NameConsentReceipt(val therapist_id:String,val consent_type:String,val required_version:String,
 val accepted_version:String?,val accepted_at:String?,val revoked_at:String?,val status:String,val revision:Long) {
 fun validate(account:String) {
  fun date(v:String?)=v!=null && runCatching { Instant.parse(v) }.isSuccess
  if(!therapist_id.equals(account,true)||consent_type!=PatientNameRules.type||required_version!=PatientNameRules.version||revision !in 0..9007199254740991L||
   status !in listOf("required","accepted","declined","revoked") || (accepted_at!=null && !date(accepted_at)) || (revoked_at!=null && !date(revoked_at)) ||
   (status=="accepted" && (accepted_version!=required_version||!date(accepted_at)||revoked_at!=null)) || (status=="revoked" && !date(revoked_at))) throw NameSyncFailure("invalid_response")
 }
}
@Serializable data class NameConsentDecision(val p_consent_type:String=PatientNameRules.type,val p_required_version:String=PatientNameRules.version,
 val p_decision:String,val p_request_id:String,val p_expected_revision:Long)
@Serializable data class ServerPatientName(val patient_id:String,val name:String?,val revision:String,val updated_at:String?)
@Serializable data class PatientNamePage(val names:List<ServerPatientName>,val next_after:String?)
@Serializable data class PatientNameSetResult(val patient_id:String,val revision:String,val updated_at:String,val unchanged:Boolean)
@Serializable data class PatientNameEdit(val id:String=UUID.randomUUID().toString(),val name:String,val initial:Boolean)
@Serializable data class PatientNameEntry(val confirmed:String?=null,val revision:String="0",val pending:PatientNameEdit?=null,val initialized:Boolean=false)
@Serializable data class PatientNameSyncSnapshot(val entries:Map<String,PatientNameEntry> = emptyMap(),val consentDecision:NameConsentDecision?=null,val migrationVersion:String?=null,val confirmedIDs:Set<String> = emptySet(),val approvalVersion:String?=null,val cleanedLegacyIDs:Set<String> = emptySet())
data class NameSyncState(val accepted:Boolean=false,val busy:Boolean=false,val failed:Boolean=false,val pending:Boolean=false,val consentChecked:Boolean=false,val migrationComplete:Boolean=false,val account:String?=null,val needsApproval:Boolean=false,val approvalFailed:Boolean=false)

/** Server names live in account-scoped memory; only unfinished legacy migration input is durable. */
class PatientNameSync(
 private val call:suspend (String,JsonObject)->String,
 private val storage:DeviceDraftStorage,
 private val scope:CoroutineScope,
 private val eligible:()->Boolean,
 private val fullAccess:()->Boolean,
) {
 private val json=Json { ignoreUnknownKeys=true; encodeDefaults=true; explicitNulls=true }
 private val mutable=MutableStateFlow(NameSyncState()); val state=mutable.asStateFlow()
 var account:String?=null
  private set
 private var epoch=0
 private var snapshot=PatientNameSyncSnapshot(); private var owned=emptySet<String>(); private var legacy=emptyMap<String,String>()
 private var rowNames=emptyMap<String,String?>(); private var rowLegacy=emptyMap<String,String>(); private var rowsReceived=false
 var writeRevision=0
  private set
 var waitForPatientRows=false
 fun receivePatientRows(records:List<JsonObject>) {
  val names=mutableMapOf<String,String?>();val fallback=mutableMapOf<String,String>()
  records.forEach { row ->
   val id=row.getValue("id").jsonPrimitive.content.lowercase()
   if(row.containsKey("decryptedName")) {
    val value=row["decryptedName"]
    names[id]=when { value==JsonNull -> null; value is JsonPrimitive && value.isString -> value.content; else -> throw NameSyncFailure("invalid_response") }
   }
   if(names[id]==null)runCatching {readLegacy?.invoke(id)}.getOrNull()?.takeIf {it.isNotEmpty()}?.let { fallback[id]=it }
  }
  rowNames=names;rowLegacy=fallback;rowsReceived=true
  register(records.associate {it.getValue("id").jsonPrimitive.content to null})
  snapshot=snapshot.copy(entries=snapshot.entries.mapValues {(id,entry)->if(names[id]!=null&&entry.pending?.initial==true)entry.copy(pending=null) else entry})
 }
 private var deleting=emptySet<String>(); private var diskReady=false; private var busy=false; private var rerun=false; private var lastRefresh=0L; private var consentRevision:Long?=null
 var changed:(()->Unit)?=null
 var loadOwned:(suspend ()->Map<String,String?>)?=null
 private var approvalFailed=false
 private var consentChecked=false
 private var legacyChecked=false
 var readLegacy:((String)->String?)?=null
 var removeConfirmedLegacy:((String)->Boolean)?=null
 val migrationComplete get()=snapshot.migrationVersion==PatientNameRules.version
 private val hasOwnedLegacy get()=owned.any {snapshot.entries[it]?.pending!=null}
 private val migrationApproved get()=snapshot.approvalVersion==PatientNameRules.version
 fun shouldGate(therapist:Boolean,demo:Boolean)=therapist&&!demo&&legacyChecked&&hasOwnedLegacy&&!migrationApproved
 private fun publish(accepted:Boolean=mutable.value.accepted,failed:Boolean=mutable.value.failed) { mutable.value=NameSyncState(accepted,busy,failed,snapshot.entries.values.any { it.pending!=null },consentChecked,migrationComplete,account,shouldGate(true,false),approvalFailed) }
 /** Context refresh temporarily clears the role, not the authenticated account.
  * Retain only the same owner's memory through that unresolved interval. */
 fun updateAuthenticatedContext(authenticatedOwner:String?,context:EntitlementSnapshot) {
  val owner=authenticatedOwner?.lowercase()
  val matching=context.identity?.lowercase()==owner
  val next=when {
   owner==null -> null
   matching && context.role==AppRole.Patient -> null
   matching && context.role==AppRole.Therapist -> owner
   account==owner -> owner
   else -> null
  }
  setAccount(next)
 }
 fun setAccount(value:String?) {
  val value=value?.lowercase(); if(value==account)return
  rowNames=emptyMap();rowLegacy=emptyMap();rowsReceived=false;writeRevision=0
  epoch++;approvalFailed=false;legacyChecked=false;account=value;snapshot=PatientNameSyncSnapshot();owned=emptySet();deleting=emptySet();legacy=emptyMap();busy=false;rerun=false;diskReady=false;lastRefresh=0;consentRevision=null;consentChecked=false
  mutable.value=NameSyncState();changed?.invoke()
  if(value!=null) try { snapshot=storage.read(key())?.let { json.decodeFromString<PatientNameSyncSnapshot>(it) }?:PatientNameSyncSnapshot();diskReady=true;discardConfirmedCache();publish() } catch(_:Exception){publish(failed=true)}
 }
 fun hasConfirmed(id:String)=rowNames[id.lowercase()]!=null || id.lowercase() in snapshot.confirmedIDs || snapshot.entries[id.lowercase()]?.confirmed!=null
 private fun discardConfirmedCache(){
  snapshot=snapshot.copy(confirmedIDs=snapshot.confirmedIDs+snapshot.entries.filterValues {it.confirmed!=null&&it.pending==null}.keys,entries=snapshot.entries.filterValues {it.pending!=null}.mapValues {it.value.copy(confirmed=null)})
 }
 private fun cleanConfirmedLegacy(){
  val remove=removeConfirmedLegacy?:return
  val cleaned=(snapshot.confirmedIDs-snapshot.cleanedLegacyIDs).filter {runCatching {remove(it)}.getOrDefault(false)}
  if(cleaned.isNotEmpty()){snapshot=snapshot.copy(cleanedLegacyIDs=snapshot.cleanedLegacyIDs+cleaned);persist()}
 }
 private fun key()=DeviceFormDraftStore.key(account!!,"patient-name-sync","v1")
 private fun persist(){if(!diskReady||account==null)throw NameSyncFailure("local_storage");val confirmed=snapshot.confirmedIDs+snapshot.entries.filterValues {it.confirmed!=null&&it.pending==null}.keys
  snapshot=snapshot.copy(confirmedIDs=confirmed)
  val durable=snapshot.copy(entries=snapshot.entries.filterValues {it.pending!=null}.mapValues {it.value.copy(confirmed=null)})
  storage.write(key(),json.encodeToString(durable));publish()}
 fun register(values:Map<String,String?>) {
  if(account==null)return
  owned=values.keys.map(String::lowercase).filter(::uuid).toSet()-deleting
  legacy=values.mapKeys { it.key.lowercase() }.filter { it.key in owned && !hasConfirmed(it.key) && it.value?.let(PatientNameRules::valid)==true }.mapValues { it.value!! }
 }
 fun displayed(id:String,fallback:String?):String? {
  val key=id.lowercase();val entry=snapshot.entries[key]
  return if(rowNames.containsKey(key))rowNames[key]?:entry?.pending?.name?:rowLegacy[key]?:fallback
   else entry?.pending?.name?:entry?.confirmed?:rowLegacy[key]?:fallback
 }
 suspend fun edit(id:String,name:String) {
  if(!PatientNameRules.valid(name)||!uuid(id))throw NameSyncFailure("invalid_name")
  val e=epoch;val id=id.lowercase()
  val row=fetch(e)[id]?:throw NameSyncFailure("patient_not_found")
  val result=request<PatientNameSetResult>("patient-names",buildJsonObject {put("operation","set");put("patient_id",id);put("name",name);put("expected_revision",row.revision)},e)
  if(!result.patient_id.equals(id,true)||!PatientNameRules.revision(result.revision)||result.updated_at.isBlank())throw NameSyncFailure("invalid_response")
  writeRevision++
  owned=owned+id;snapshot=snapshot.copy(entries=snapshot.entries+(id to PatientNameEntry(confirmed=name,revision=result.revision,initialized=true)))
  if(rowNames.containsKey(id))rowNames=rowNames+(id to name)
  changed?.invoke();publish()
 }
 suspend fun rememberCreated(id:String,name:String)=edit(id,name)
 fun beginDeletion(id:String){deleting=deleting+id.lowercase();owned=owned-id.lowercase()}
 fun cancelDeletion(id:String){deleting=deleting-id.lowercase();owned=owned+id.lowercase()}
 fun remove(id:String){val id=id.lowercase();owned=owned-id;legacy=legacy-id;snapshot=snapshot.copy(entries=snapshot.entries-id);runCatching {persist()}.onFailure {publish(failed=true)}}
 private fun check(e:Int){if(e!=epoch||account==null||!eligible())throw CancellationException()}
 private suspend inline fun <reified T> request(method:String,payload:JsonObject,e:Int):T {check(e);val data=call(method,payload);check(e);return try {json.decodeFromString<T>(data)}catch(_:kotlinx.serialization.SerializationException){throw NameSyncFailure("invalid_response")}}
 private suspend fun lookup(e:Int):NameConsentReceipt {
  val r=request<NameConsentReceipt>("get_my_consent",buildJsonObject {put("p_consent_type",PatientNameRules.type);put("p_required_version",PatientNameRules.version)},e)
  r.validate(account!!);if(consentRevision!=null&&r.revision<consentRevision!!)throw NameSyncFailure("invalid_response")
  consentRevision=r.revision;consentChecked=true;snapshot=snapshot.copy(approvalVersion=if(r.status=="accepted")PatientNameRules.version else null);publish(accepted=r.status=="accepted");return r
 }
 private fun reopenStorage(){if(!diskReady&&account!=null)try {snapshot=storage.read(key())?.let {json.decodeFromString<PatientNameSyncSnapshot>(it)}?:PatientNameSyncSnapshot();diskReady=true;discardConfirmedCache()}catch(_:Exception){publish(failed=true)}}
 suspend fun decide(decision:String="accepted",userInitiated:Boolean=true) {
  reopenStorage()
  if(busy||account==null||!eligible())return
  if(!diskReady){if(userInitiated)approvalFailed=true;publish();return}
  val e=epoch;busy=true;if(userInitiated)approvalFailed=false;publish(accepted=false,failed=false);var decisionConfirmed=false
  try {
   val pending=snapshot.consentDecision
   if(pending!=null&&(pending.p_consent_type!=PatientNameRules.type||pending.p_required_version!=PatientNameRules.version)){snapshot=snapshot.copy(consentDecision=null);persist()}
   if(snapshot.consentDecision==null){val r=lookup(e);snapshot=snapshot.copy(consentDecision=NameConsentDecision(p_decision=decision,p_request_id=UUID.randomUUID().toString(),p_expected_revision=r.revision));persist()}
   val r=request<NameConsentReceipt>("record_my_consent",json.encodeToJsonElement(snapshot.consentDecision!!).jsonObject,e)
   r.validate(account!!);if(consentRevision!=null&&r.revision<consentRevision!!)throw NameSyncFailure("invalid_response")
   consentRevision=r.revision;snapshot=snapshot.copy(consentDecision=null,approvalVersion=if(r.status=="accepted")PatientNameRules.version else null);persist();decisionConfirmed=true;consentChecked=true;publish(accepted=r.status=="accepted")

  }catch(error:CancellationException){throw error}
  catch(error:Exception){if(e!=epoch)return;if(userInitiated)approvalFailed=true;publish(accepted=decisionConfirmed&&mutable.value.accepted,failed=true)
   if((error as? NameSyncFailure)?.code=="consent_required"){publish(accepted=false);runCatching {lookup(e)}}
   if((error as? NameSyncFailure)?.code in listOf("consent_revision_conflict","consent_request_superseded","consent_request_id_reused")){
    snapshot=snapshot.copy(consentDecision=null);runCatching {persist()};runCatching {lookup(e)}
   }
  }finally{if(e==epoch){busy=false;publish();if(mutable.value.accepted)scope.launch {refresh(true)}}}
 }
 suspend fun retryMigration() { if(snapshot.consentDecision!=null)decide(userInitiated=false) else refresh(true) }
 suspend fun refresh(force:Boolean=false) {
  if(waitForPatientRows&&!rowsReceived)return
  reopenStorage()
  if(account==null||!eligible()||!diskReady)return
  if(busy){rerun=true;return}
  if(!force&&System.nanoTime()-lastRefresh<30_000_000_000L)return
  val e=epoch;busy=true;lastRefresh=System.nanoTime();publish()
  try {
   if(!legacyChecked){
    if(!migrationComplete){
     if(!rowsReceived)loadOwned?.let {val values=it();check(e);register(values)}
     val confirmed=snapshot.confirmedIDs+snapshot.entries.filterValues {it.confirmed!=null&&it.pending==null}.keys
     val entries=snapshot.entries.toMutableMap()
     for(id in owned-confirmed){if(rowNames[id]!=null)continue;val value=readLegacy?.invoke(id)?:legacy[id]
      if(value!=null&&PatientNameRules.valid(value)&&entries[id]?.pending==null)entries[id]=(entries[id]?:PatientNameEntry()).copy(pending=PatientNameEdit(name=value,initial=true))
     }
     snapshot=snapshot.copy(entries=entries)
    }
    legacyChecked=true
    if(snapshot.entries.values.none {it.pending!=null})snapshot=snapshot.copy(migrationVersion=PatientNameRules.version)
   }
   if(hasOwnedLegacy&&snapshot.consentDecision!=null){busy=false;decide(userInitiated=false);return}
   persist();cleanConfirmedLegacy()
   // Ordinary reads use the encrypted API under the normal terms flow.
   publish(failed=false);sync(e)
  }catch(error:CancellationException){throw error}
  catch(error:Exception){if(e!=epoch)return;publish(failed=true)
   val code=(error as? NameSyncFailure)?.code
   // Keep backend rejection as a failure; only legacy upload may request approval.
   if(code=="consent_required"&&hasOwnedLegacy&&!migrationApproved)runCatching {lookup(e)}
  }finally{if(e==epoch){busy=false;publish();if(rerun){rerun=false;scope.launch {refresh(true)}}}}
 }
 private suspend fun fetch(e:Int):Map<String,ServerPatientName>{
  var after:String?=null;val seen=mutableSetOf<String>();val rows=mutableMapOf<String,ServerPatientName>()
  do {
   val page=request<PatientNamePage>("patient-names",buildJsonObject {put("operation","list");put("after",after?.let(::JsonPrimitive)?:JsonNull);put("limit",100)},e)
   page.names.forEach {if(!uuid(it.patient_id)||!PatientNameRules.revision(it.revision)||(it.name!=null&&!PatientNameRules.valid(it.name)))throw NameSyncFailure("invalid_response");rows[it.patient_id.lowercase()]=it}
   after=page.next_after;if(after!=null&&(!uuid(after)||!seen.add(after)))throw NameSyncFailure("invalid_response")
  }while(after!=null)
  return rows
 }
 private fun adopt(rows:Map<String,ServerPatientName>){
  val entries=snapshot.entries.toMutableMap()
  rows.forEach { (id,row)->if(id in owned){
   if(rowNames.containsKey(id)&&entries[id]?.pending==null)return@forEach
   var entry=entries[id]?:PatientNameEntry()
   if(PatientNameRules.older(row.revision,entry.revision))return@forEach
   if(row.name!=null)entry=entry.copy(confirmed=row.name,revision=row.revision,initialized=true,pending=null)
   else entry=entry.copy(confirmed=null,revision=row.revision)
   entries[id]=entry
   if(rowNames.containsKey(id))rowNames=rowNames+(id to row.name)
  }}
  snapshot=snapshot.copy(entries=entries);persist();cleanConfirmedLegacy();changed?.invoke()
 }
 private suspend fun sync(e:Int){
  val migrating=!migrationComplete
  if(rowsReceived&&owned.all {rowNames.containsKey(it)}) {
   if(!hasOwnedLegacy)return
   if(!migrationApproved){lookup(e);if(!migrationApproved)return}
  }
  var rows=fetch(e);adopt(rows)
  // Explicit approval protects automatic legacy uploads, not ordinary server-name reads.
  if(hasOwnedLegacy&&!migrationApproved){lookup(e);if(!migrationApproved)return;persist()}
  for(id in owned.sorted()){
   var attempts=0
   while(id in owned && attempts<3){
    val intent=snapshot.entries[id]?.pending?:break;val row=rows[id]?:break
    if(migrating&&row.name!=null)break
    if(row.name==intent.name){snapshot=snapshot.copy(entries=snapshot.entries+(id to snapshot.entries[id]!!.copy(pending=null)));persist();changed?.invoke();break}
    if(!intent.initial&&row.name!=null&&!fullAccess()){publish(failed=true);break}
    attempts++
    try {
     val result=request<PatientNameSetResult>("patient-names",buildJsonObject{put("operation","set");put("patient_id",id);put("name",intent.name);put("expected_revision",if(intent.initial)"0" else row.revision)},e)
     if(id !in owned)break
     if(!result.patient_id.equals(id,true)||!PatientNameRules.revision(result.revision)||result.updated_at.isBlank())throw NameSyncFailure("invalid_response")
     writeRevision++
     val current=snapshot.entries[id]?:break
     snapshot=snapshot.copy(entries=snapshot.entries+(id to current.copy(confirmed=intent.name,revision=result.revision,initialized=true,pending=if(current.pending?.id==intent.id)null else current.pending)))
     if(rowNames.containsKey(id))rowNames=rowNames+(id to intent.name)
     rows=rows+(id to ServerPatientName(id,intent.name,result.revision,result.updated_at));persist();cleanConfirmedLegacy();changed?.invoke()
    }catch(error:Exception){check(e);if(id !in owned)break
     when((error as? NameSyncFailure)?.code){
      "revision_conflict"->{rows=fetch(e);adopt(rows)}
      "patient_not_found","patient_ownership_changed"->{remove(id);break}
      else->throw error
     }
    }
   }
   if(snapshot.entries[id]?.pending!=null&&!(migrating&&rows[id]?.name!=null))publish(failed=true)
  }
  if(migrating){
   val reconciled=owned.all {id->(legacy[id]==null&&snapshot.entries[id]?.pending==null)||rows[id]?.name!=null}
   if(!reconciled||mutable.value.failed)throw NameSyncFailure("migration_incomplete")
   val previous=snapshot.migrationVersion;snapshot=snapshot.copy(migrationVersion=PatientNameRules.version)
   try{persist()}catch(e:Exception){snapshot=snapshot.copy(migrationVersion=previous);throw e}
  }
 }
 companion object {
  internal fun jsonHeaders() = Headers.build { append(HttpHeaders.ContentType, ContentType.Application.Json.toString()) }
  fun uuid(id:String)=runCatching { UUID.fromString(id).toString().equals(id,true) }.getOrDefault(false)
  // SDK 3.2.2 serializes the body, but deliberately does not set Content-Type.
  // Keep this adapter shared by production and transport-level regression tests.
  internal suspend fun callService(client:SupabaseClient,method:String,payload:JsonObject):String {
   try {
    if(com.cbtipul.app.BuildConfig.DEBUG && method=="patient-names") runCatching { android.util.Log.i("PatientLaunchTrace", "request=patient-names operation=${payload["operation"]?.jsonPrimitive?.content} t=${android.os.SystemClock.elapsedRealtime()}") }
    return if(method=="patient-names")client.functions.invoke(method,body=payload,headers=jsonHeaders()).bodyAsText()
    else client.postgrest.rpc(method,payload).data
   }catch(e:CancellationException){throw e}
   catch(e:Exception){
    val rest=e as? RestException
    val raw=when {e is ResponseException->e.response.bodyAsText();rest!=null->rest.error;else->""}
    val obj=runCatching {Json.parseToJsonElement(raw).jsonObject}.getOrNull()
    fun primitive(key:String)=(obj?.get(key) as? JsonPrimitive)?.contentOrNull
    val nested=(obj?.get("error") as? JsonObject)?.get("code") as? JsonPrimitive
    val candidates=listOfNotNull(primitive("code"),nested?.contentOrNull,primitive("error"),primitive("message"),rest?.description,rest?.error)
    val known=setOf("consent_required","therapist_access_required","patient_not_found","revision_conflict","patient_ownership_changed","invalid_request","request_too_large","consent_registry_not_ready","unauthorized","consent_revision_conflict","consent_request_superseded","consent_request_id_reused","unsupported_media_type","invalid_content_type")
    val status=EdgePayload.httpStatus(e)
    throw NameSyncFailure(candidates.firstOrNull {it in known} ?: "http_${status?:0}",status)
   }
  }
  fun live(client:SupabaseClient,storage:DeviceDraftStorage,scope:CoroutineScope,localName:(String)->String?={null})=PatientNameSync(call={method,payload->callService(client,method,payload)},storage=storage,scope=scope,eligible={Entitlements.state.value.role==AppRole.Therapist&&!Entitlements.state.value.localDemo},fullAccess={Entitlements.state.value.access==EntitlementAccess.Full}).also { sync ->
   sync.waitForPatientRows=true
   sync.readLegacy=localName
   sync.loadOwned={
    val values=mutableMapOf<String,String?>();var offset=0L
    do {
     val data=client.from("Patients").select(Columns.raw("id")){order("id",Order.ASCENDING);range(offset,offset+499)}.data
     val page=Json.parseToJsonElement(data).jsonArray
     page.forEach {val id=it.jsonObject.getValue("id").jsonPrimitive.content;values[id]=null}
     if(page.size<500)break;offset+=500
    }while(true)
    values
   }
  }
 }
}
