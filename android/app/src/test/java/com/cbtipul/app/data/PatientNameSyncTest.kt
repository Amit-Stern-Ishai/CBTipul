package com.cbtipul.app.data
import kotlinx.coroutines.*
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test
import java.math.BigInteger

class PatientNameSyncTest {
 private val account="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
 private val patient="11111111-1111-1111-1111-111111111111"
 private val second="22222222-2222-2222-2222-222222222222"
 private val date="2026-10-29T10:00:00Z"
 private class Memory:DeviceDraftStorage {
  val values=mutableMapOf<String,String>();var fail=false
  override fun read(key:String)=values[key]
  override fun write(key:String,value:String){if(fail)throw IllegalStateException();values[key]=value}
  override fun clear(key:String){values.remove(key)}
 }
 private inner class Harness(val disk:Memory=Memory()) {
  val json=Json {encodeDefaults=true;explicitNulls=true}
  var allowed=true;var full=true;var consent="accepted";var consentRev=0L;var owner=account
  var nameFailure:Exception?=null;var emptyPage=false
  var nameError:String?=null
  var lookupFailure=false;var unknownDecision=false;var decisionError:String?=null
  var sets=0;var lists=0;var calls=mutableListOf<Pair<String,JsonObject>>()
  val rows=mutableMapOf(patient to ServerPatientName(patient,null,"0",null))
  var onSet:(suspend (JsonObject)->Unit)?=null
  var page=false
  val scope=CoroutineScope(SupervisorJob()+Dispatchers.Unconfined)
  val sync=PatientNameSync(::call,disk,scope,{allowed},{full})
  init {sync.setAccount(owner);sync.register(mapOf(patient to "שם בדיקה"))}
  fun receipt()=json.encodeToString(NameConsentReceipt(owner,PatientNameRules.type,PatientNameRules.version,if(consent=="accepted")PatientNameRules.version else null,if(consent=="accepted")date else null,if(consent=="revoked")date else null,consent,consentRev))
  suspend fun call(method:String,p:JsonObject):String {
   calls+=method to p
   if(method=="get_my_consent"){if(lookupFailure)throw NameSyncFailure("connection");return receipt()}
   if(method=="record_my_consent") {
    decisionError?.let {throw NameSyncFailure(it)}
    consent=p["p_decision"]!!.jsonPrimitive.content;consentRev++
    if(unknownDecision)throw NameSyncFailure("connection")
    return receipt()
   }
   nameFailure?.let {throw it}
   nameError?.let {throw NameSyncFailure(it)}
   if(p["operation"]!!.jsonPrimitive.content=="list") {
    lists++
    val last=page && p["after"]!=JsonNull
    return json.encodeToString(PatientNamePage(if(last||emptyPage)emptyList() else rows.values.toList(),if(page&&!last)patient else null))
   }
   sets++;onSet?.invoke(p)
   val id=p["patient_id"]!!.jsonPrimitive.content;val name=p["name"]!!.jsonPrimitive.content
   val row=rows[id]?:throw NameSyncFailure("patient_not_found")
   if(row.name!=name && row.revision!=p["expected_revision"]!!.jsonPrimitive.content)throw NameSyncFailure("revision_conflict")
   val revision=if(row.name==name)row.revision else (BigInteger(row.revision)+BigInteger.ONE).toString()
   rows[id]=ServerPatientName(id,name,revision,date)
   return json.encodeToString(PatientNameSetResult(id,revision,date,row.name==name))
  }
 }
 @Test fun sameAccountContextRefreshRetainsInlineNamesWithoutDirectoryRead()=runBlocking {
  val h=Harness();h.sync.waitForPatientRows=true
  h.sync.receivePatientRows(listOf(buildJsonObject {put("id",patient);put("decryptedName","inline name")}))
  h.sync.refresh(true)
  for(context in listOf(EntitlementSnapshot(),EntitlementSnapshot(identity=account),EntitlementSnapshot(identity=account,role=AppRole.Therapist,access=EntitlementAccess.Full))) {
   h.sync.updateAuthenticatedContext(account,context);h.sync.refresh(true)
   assertEquals("inline name",h.sync.displayed(patient,null));assertEquals(0,h.lists)
  }
 }
 @Test fun accountSwitchLogoutAndConfirmedPatientClearNames()=runBlocking {
  for(mode in listOf("switch","logout","patient")) {
   val h=Harness();h.sync.waitForPatientRows=true
   h.sync.receivePatientRows(listOf(buildJsonObject {put("id",patient);put("decryptedName","old owner name")}))
   val other="bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
   when(mode) {
    "switch" -> h.sync.updateAuthenticatedContext(other,EntitlementSnapshot(identity=account,role=AppRole.Therapist))
    "logout" -> h.sync.updateAuthenticatedContext(null,EntitlementSnapshot(identity=account,role=AppRole.Therapist))
    else -> h.sync.updateAuthenticatedContext(account,EntitlementSnapshot(identity=account,role=AppRole.Patient))
   }
   assertNull(h.sync.displayed(patient,null));assertNull(h.sync.account)
   h.sync.updateAuthenticatedContext(other,EntitlementSnapshot(identity=other))
   assertNull(h.sync.account)
   h.sync.updateAuthenticatedContext(other,EntitlementSnapshot(identity=other,role=AppRole.Therapist))
   assertEquals(other,h.sync.account);assertNull(h.sync.displayed(patient,null))
   h.sync.refresh(true);assertEquals(0,h.lists)
  }
 }
 @Test fun pagedInlineNamesResolveTogetherWithoutDirectoryLookup()=runBlocking {
  val h=Harness();val second="22222222-2222-4222-8222-222222222222";var calls=0
  val records=ClinicalRecordLoad.pages("load-patients",checkpoint={},invoke={_,body->
   calls++;assertFalse(body.containsKey("include_names"))
   if(calls==1)buildJsonObject {put("records",buildJsonArray {add(buildJsonObject {put("id",patient);put("_version","v");put("decryptedName","inline")})});put("next_cursor","next")}
   else {assertEquals("next",body["cursor"]?.jsonPrimitive?.content);buildJsonObject {put("records",buildJsonArray {add(buildJsonObject {put("id",second);put("_version","v");put("decryptedName",JsonNull)})});put("next_cursor",JsonNull)}}
  })
  h.sync.receivePatientRows(records);h.sync.refresh(true)
  assertEquals(2,calls);assertEquals(0,h.lists);assertEquals("inline",h.sync.displayed(patient,null));assertNull(h.sync.displayed(second,null))
 }
 @Test fun compatibilityReadCannotOverrideInlineNullOrString()=runBlocking {
  val h=Harness();val absent="22222222-2222-4222-8222-222222222222";val named="33333333-3333-4333-8333-333333333333"
  h.rows[patient]=ServerPatientName(patient,"directory stale","1",date)
  h.rows[absent]=ServerPatientName(absent,"compatibility name","1",date)
  h.rows[named]=ServerPatientName(named,"directory stale","1",date)
  h.sync.receivePatientRows(listOf(
   buildJsonObject {put("id",patient);put("decryptedName",JsonNull)},
   buildJsonObject {put("id",absent)},
   buildJsonObject {put("id",named);put("decryptedName","inline name")}))
  h.sync.refresh(true)
  assertEquals(1,h.lists);assertNull(h.sync.displayed(patient,null))
  assertEquals("inline name",h.sync.displayed(named,null));assertEquals("compatibility name",h.sync.displayed(absent,null))
 }
 @Test fun inlineNamesNullAndMissingHaveDistinctReads()=runBlocking {
  val h=Harness();h.sync.waitForPatientRows=true
  h.sync.refresh(true);assertEquals(0,h.lists)
  h.sync.receivePatientRows(listOf(buildJsonObject {put("id",patient.uppercase());put("decryptedName","שם שרת")}))
  h.sync.refresh(true);assertEquals("שם שרת",h.sync.displayed(patient,null));assertEquals(0,h.lists)
  h.sync.receivePatientRows(listOf(buildJsonObject {put("id",patient);put("decryptedName",JsonNull)}))
  h.sync.refresh(true);assertNull(h.sync.displayed(patient,null));assertEquals(0,h.lists)
  h.sync.receivePatientRows(listOf(buildJsonObject {put("id",patient)}))
  h.sync.refresh(true);assertEquals(1,h.lists)
 }
 @Test fun inlineNamesKeepRenameRevisionLookupAndClearOnAccountChange()=runBlocking {
  val h=Harness()
  h.sync.receivePatientRows(listOf(buildJsonObject {put("id",patient);put("decryptedName","שם שרת")}))
  h.sync.refresh(true);assertFalse(h.disk.values.values.any {it.contains("שם שרת")});h.sync.edit(patient,"שם חדש")
  assertEquals(1,h.lists);assertEquals(1,h.sets);assertEquals("שם חדש",h.sync.displayed(patient,null))
  h.sync.setAccount(null);assertNull(h.sync.displayed(patient,null))
 }
 @Test fun inlineNullKeepsLegacyAndApprovedUpload()=runBlocking {
  val h=Harness();h.consent="required";h.sync.readLegacy={"שם מקומי"}
  h.sync.receivePatientRows(listOf(buildJsonObject {put("id",patient);put("decryptedName",JsonNull)}))
  h.sync.refresh(true);assertEquals("שם מקומי",h.sync.displayed(patient,null));assertEquals(0,h.lists);assertEquals(0,h.sets)
  h.sync.decide();assertEquals(1,h.sets)
 }
 @Test fun legacyRequiresConsent()=runBlocking {
  val h=Harness();h.consent="required";h.sync.refresh(true)
  assertTrue(h.sync.shouldGate(true,false));assertEquals(1,h.lists);assertEquals(0,h.sets)
 }
 @Test fun noLegacyNeverPrompts()=runBlocking {
  val h=Harness();h.sync.register(mapOf(patient to null));h.consent="required";h.sync.refresh(true)
  assertFalse(h.sync.shouldGate(true,false));assertEquals(1,h.lists);assertTrue(h.calls.all {it.first=="patient-names"})
 }
 @Test fun confirmedCacheIsNotLegacy()=runBlocking {
  val h=Harness();val key=DeviceFormDraftStore.key(account,"patient-name-sync","v1")
  h.disk.values[key]=h.json.encodeToString(PatientNameSyncSnapshot(entries=mapOf(patient to PatientNameEntry(confirmed="cached synthetic",revision="3",initialized=true))))
  val next=Harness(h.disk);next.consent="required";next.sync.refresh(true)
  assertFalse(next.sync.shouldGate(true,false));assertNull(next.sync.displayed(patient,null));assertFalse(h.disk.values[key]!!.contains("cached synthetic"))
 }
 @Test fun serverWinsOverOldLegacy()=runBlocking {
  val h=Harness();h.rows[patient]=ServerPatientName(patient,"server synthetic","7",date);h.sync.refresh(true)
  assertEquals(0,h.sets);assertEquals("server synthetic",h.sync.displayed(patient,null))
 }
 @Test fun interruptedMigrationResumes()=runBlocking {
  val h=Harness();h.onSet={throw NameSyncFailure("connection")};h.sync.refresh(true)
  assertTrue(h.sync.state.value.pending)
  val next=Harness(h.disk);next.sync.refresh(true);assertEquals(1,next.sets);assertFalse(next.sync.state.value.pending)
  assertFalse(h.disk.values.values.any {it.contains("שם בדיקה")})
 }
 @Test fun acceptedMigrationDoesNotAskAgainOffline()=runBlocking {
  val h=Harness();h.consent="required";h.onSet={throw NameSyncFailure("connection")}
  h.sync.refresh(true);assertTrue(h.sync.shouldGate(true,false));h.sync.decide()
  assertEquals(1,h.calls.count {it.first=="record_my_consent"});assertTrue(h.sync.state.value.pending);assertFalse(h.sync.state.value.approvalFailed)
  val next=Harness(h.disk);next.consent="required";next.lookupFailure=true;next.nameError="connection";next.sync.refresh(true)
  assertFalse(next.sync.shouldGate(true,false));assertTrue(next.sync.state.value.pending)
  next.nameError=null;next.sync.refresh(true);assertFalse(next.sync.state.value.pending);assertEquals(1,next.sets)
  assertFalse(next.sync.shouldGate(true,false));assertTrue(next.calls.all {it.first=="patient-names"})
 }
 @Test fun createRenameAreAwaitedAndNeverQueued()=runBlocking {
  val h=Harness();h.sync.register(mapOf(patient to null));h.sync.refresh(true)
  h.sync.rememberCreated(patient,"created synthetic");h.sync.edit(patient,"renamed synthetic")
  assertEquals("renamed synthetic",h.sync.displayed(patient,null));assertFalse(h.disk.values.values.any {it.contains("synthetic")})
 }
 @Test fun failedRenamePreservesResult()=runBlocking {
  val h=Harness();h.rows[patient]=ServerPatientName(patient,"existing","1",date);h.sync.refresh(true)
  h.onSet={throw NameSyncFailure("connection")}
  try{h.sync.edit(patient,"unsaved");fail()}catch(_:NameSyncFailure){}
  assertEquals("existing",h.sync.displayed(patient,null));assertFalse(h.sync.state.value.pending)
 }
 @Test fun conflictDoesNotRetryAndAccountSwitchCancels()=runBlocking {
  val h=Harness();h.sync.refresh(true);val before=h.sets
  h.onSet={throw NameSyncFailure("revision_conflict")}
  try{h.sync.edit(patient,"unsaved");fail()}catch(_:NameSyncFailure){}
  assertEquals(before+1,h.sets)
  h.onSet={h.sync.setAccount("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")}
  try{h.sync.edit(patient,"unsaved");fail()}catch(_:CancellationException){}
  assertNull(h.sync.displayed(patient,null))
 }
 @Test fun patientAndDemoDoNothing()=runBlocking {
  val h=Harness();h.allowed=false;h.sync.refresh(true);assertTrue(h.calls.isEmpty())
 }

 @Test fun approvalDoesNotWaitForSlowUpload()=runBlocking {
  val h=Harness();h.consent="required";val release=CompletableDeferred<Unit>()
  val sync=PatientNameSync({method,p->if(method=="patient-names"&&h.consent=="accepted")release.await();h.call(method,p)},h.disk,h.scope,{true},{true})
  sync.setAccount(account);sync.register(mapOf(patient to "synthetic legacy"));sync.refresh(true)
  assertTrue(sync.shouldGate(true,false));sync.decide()
  assertTrue(sync.state.value.accepted);assertFalse(sync.shouldGate(true,false));assertTrue(sync.state.value.busy);assertTrue(sync.state.value.pending)
  release.complete(Unit);yield();assertFalse(sync.state.value.pending);assertEquals(1,h.sets)
 }
 @Test fun completedMigrationNeverReadsLegacyAfterRelaunch()=runBlocking {
  val h=Harness();var reads=0;h.sync.readLegacy={reads++;"synthetic legacy"}
  h.sync.refresh(true);h.sync.refresh(true);assertEquals(1,reads)
  val next=Harness(h.disk);next.sync.readLegacy={fail("legacy read after confirmation");null}
  next.sync.refresh(true);assertFalse(next.sync.state.value.pending)
 }
 @Test fun confirmedLocalCleanupRunsOnceAndNeverDeletesUnconfirmedInput()=runBlocking {
  val h=Harness();val removed=mutableListOf<String>();h.sync.removeConfirmedLegacy={removed+=it;true}
  h.onSet={throw NameSyncFailure("connection")};h.sync.refresh(true);assertTrue(removed.isEmpty())
  h.onSet=null;h.sync.refresh(true);assertEquals(listOf(patient),removed)
  h.sync.refresh(true);assertEquals(listOf(patient),removed)
 }

 @Test fun olderRefreshCannotUndoRenameAndMissingClearsIt()=runBlocking {
  val h=Harness();h.rows[patient]=ServerPatientName(patient,"original","7",date);h.sync.refresh(true)
  h.sync.edit(patient,"renamed");h.rows[patient]=ServerPatientName(patient,"stale","7",date);h.sync.refresh(true)
  assertEquals("renamed",h.sync.displayed(patient,null))
  h.rows[patient]=ServerPatientName(patient,null,"9",date);h.sync.refresh(true);assertNull(h.sync.displayed(patient,null))
 }
 @Test fun malformedWriteNeverReportsSuccess()=runBlocking {
  val h=Harness();val sync=PatientNameSync({method,p->if(p["operation"]?.jsonPrimitive?.content=="set")"{}" else h.call(method,p)},h.disk,h.scope,{true},{true})
  sync.setAccount(account);sync.register(mapOf(patient to null));sync.refresh(true)
  try{sync.edit(patient,"unsaved");fail()}catch(_:NameSyncFailure){}
  assertNull(sync.displayed(patient,null));assertFalse(sync.state.value.pending)
 }
 @Test fun invalidReceiptAccountTypeVersionAndRevisionAreErrors(){
  val base=NameConsentReceipt(account,PatientNameRules.type,PatientNameRules.version,PatientNameRules.version,date,null,"accepted",0)
  listOf(base.copy(therapist_id="other"),base.copy(consent_type="other"),base.copy(required_version="old"),base.copy(revision=-1),base.copy(accepted_at=null),base.copy(revoked_at=date)).forEach {
   assertThrows(NameSyncFailure::class.java){it.validate(account)}
  }
 }
 @Test fun unicodeAndSpacingValidation(){
  assertTrue(PatientNameRules.valid("  שם  בדיקה  "));assertTrue(PatientNameRules.valid("😀".repeat(200)))
  assertFalse(PatientNameRules.valid("😀".repeat(201)));assertFalse(PatientNameRules.valid("\u0000שם"));assertFalse(PatientNameRules.valid("שם\n"));assertFalse(PatientNameRules.valid("\u007f"));assertFalse(PatientNameRules.valid("   "))
 }
 @Test fun racingInitialUploadAdoptsWinnerWithoutRetryingLegacy()=runBlocking {
  val h=Harness();h.onSet={h.rows[patient]=ServerPatientName(patient,"מכשיר אחר","1",date);h.onSet=null}
  h.sync.refresh(true);assertEquals(1,h.sets);assertEquals("מכשיר אחר",h.sync.displayed(patient,null))
 }
 @Test fun partialMigrationResumesOnlyRemainingPatient()=runBlocking {
  val h=Harness();h.rows[second]=ServerPatientName(second,null,"0",null)
  h.sync.loadOwned={mapOf(patient to "first synthetic",second to "second synthetic")}
  h.onSet={if(it["patient_id"]!!.jsonPrimitive.content==second)throw NameSyncFailure("connection")}
  h.sync.refresh(true);assertFalse(h.sync.migrationComplete);assertNotNull(h.rows[patient]?.name)
  val next=Harness(h.disk);next.rows.clear();next.rows.putAll(h.rows);next.sync.loadOwned={mapOf(patient to "first synthetic",second to "second synthetic")}
  next.sync.refresh(true);assertTrue(next.sync.migrationComplete);assertEquals(1,next.sets)
 }
 @Test fun formerPatientDoesNotTriggerApprovalOrUpload()=runBlocking {
  val h=Harness();val key=DeviceFormDraftStore.key(account,"patient-name-sync","v1")
  h.disk.values[key]=h.json.encodeToString(PatientNameSyncSnapshot(entries=mapOf(patient to PatientNameEntry(pending=PatientNameEdit(name="legacy unavailable patient",initial=true)))))
  val next=Harness(h.disk);next.consent="required";next.sync.loadOwned={emptyMap()};next.sync.refresh(true)
  assertFalse(next.sync.shouldGate(true,false));assertEquals(0,next.sets)
  assertTrue(h.disk.values[key]!!.contains("legacy unavailable patient"))
 }
 @Test fun cleanAccountReadsCreatesAndRenamesWithoutConsentRPCs()=runBlocking {
  val h=Harness();h.consent="required";h.lookupFailure=true;h.sync.register(mapOf(patient to null))
  h.rows[patient]=ServerPatientName(patient,"fetched synthetic","1",date);h.sync.refresh(true)
  assertEquals("fetched synthetic",h.sync.displayed(patient,null));assertFalse(h.sync.shouldGate(true,false));assertFalse(h.sync.state.value.failed)
  h.sync.rememberCreated(patient,"created synthetic");h.sync.edit(patient,"renamed synthetic")
  assertEquals("renamed synthetic",h.sync.displayed(patient,null));assertFalse(h.sync.state.value.pending)
  assertTrue(h.calls.all {it.first=="patient-names"});assertFalse(h.disk.values.values.any {it.contains("synthetic")})
  h.sync.setAccount(null);assertNull(h.sync.displayed(patient,null))
 }
 @Test fun cleanBackendRejectionIsFailureAndNeverRequestsApproval()=runBlocking {
  val h=Harness();h.sync.register(mapOf(patient to null));h.consent="required";h.nameError="consent_required";h.sync.refresh(true)
  assertTrue(h.sync.state.value.failed);assertFalse(h.sync.shouldGate(true,false))
  try{h.sync.rememberCreated(patient,"unsaved synthetic");fail()}catch(e:NameSyncFailure){assertEquals("consent_required",e.code)}
  assertNull(h.sync.displayed(patient,null));assertFalse(h.sync.state.value.pending);assertTrue(h.calls.all {it.first=="patient-names"})
 }
 @Test fun rejectedSetPreservesNameAndHasNoQueue()=runBlocking {
  val h=Harness();h.sync.register(mapOf(patient to null));h.rows[patient]=ServerPatientName(patient,"existing synthetic","3",date);h.sync.refresh(true)
  h.onSet={throw NameSyncFailure("consent_required")}
  try{h.sync.edit(patient,"unsaved synthetic");fail()}catch(e:NameSyncFailure){assertEquals("consent_required",e.code)}
  assertEquals("existing synthetic",h.sync.displayed(patient,null));assertFalse(h.sync.state.value.pending);assertTrue(h.calls.all {it.first=="patient-names"})
 }
 @Test fun cleanAccountDoesNotReplayOldConsentDecision()=runBlocking {
  val h=Harness();val key=DeviceFormDraftStore.key(account,"patient-name-sync","v1")
  h.disk.values[key]=h.json.encodeToString(PatientNameSyncSnapshot(consentDecision=NameConsentDecision(p_decision="accepted",p_request_id="old-request",p_expected_revision=0)))
  val next=Harness(h.disk);next.sync.register(mapOf(patient to null));next.consent="required";next.sync.refresh(true)
  assertFalse(next.sync.shouldGate(true,false));assertEquals(1,next.lists);assertTrue(next.calls.all {it.first=="patient-names"})
 }
 @Test fun backgroundFailureOnLegacyGateDoesNotBecomeApprovalError()=runBlocking {
  val h=Harness();h.consent="required";h.sync.refresh(true);assertTrue(h.sync.shouldGate(true,false))
  h.nameError="connection";h.sync.refresh(true)
  assertTrue(h.sync.state.value.failed);assertFalse(h.sync.state.value.approvalFailed);assertTrue(h.sync.state.value.pending)
 }
 @Test fun failedBackgroundFetchKeepsMemoryAndCleanAccountHasNoUI()=runBlocking {
  val h=Harness();h.sync.register(mapOf(patient to null));h.rows[patient]=ServerPatientName(patient,"synthetic loaded","1",date)
  h.sync.refresh(true);h.nameError="connection";h.sync.refresh(true)
  assertEquals("synthetic loaded",h.sync.displayed(patient,null));assertFalse(h.sync.state.value.approvalFailed);assertFalse(h.sync.shouldGate(true,false))
  h.nameError=null;h.emptyPage=true;h.sync.refresh(true);assertFalse(h.sync.state.value.failed);assertFalse(h.sync.state.value.approvalFailed)
 }
 @Test fun cancelledBackgroundRequestIsNotFailure()=runBlocking {
  val h=Harness();h.sync.register(mapOf(patient to null));h.nameFailure=CancellationException()
  try{h.sync.refresh(true);fail("must preserve cancellation")}catch(_:CancellationException){}
  assertFalse(h.sync.state.value.failed);assertFalse(h.sync.state.value.approvalFailed);assertFalse(h.sync.state.value.busy)
 }
 @Test fun explicitApprovalFailureIsSeparateFromAutomaticResume()=runBlocking {
  val h=Harness();h.consent="required";h.sync.refresh(true);h.decisionError="connection";h.sync.decide()
  assertTrue(h.sync.state.value.approvalFailed)
  val next=Harness(h.disk);next.consent="required";next.decisionError="connection";next.sync.refresh(true)
  assertTrue(next.sync.state.value.failed);assertFalse(next.sync.state.value.approvalFailed);assertTrue(next.sync.state.value.pending)
 }

 @Test fun cancelledApprovedUploadResumesSilentlyAfterRelaunch()=runBlocking {
  val h=Harness();h.onSet={throw CancellationException()}
  try{h.sync.refresh(true);fail()}catch(_:CancellationException){}
  assertTrue(h.sync.state.value.pending);assertFalse(h.sync.state.value.failed);assertFalse(h.sync.state.value.approvalFailed);assertFalse(h.sync.shouldGate(true,false))
  val next=Harness(h.disk);next.consent="required";next.lookupFailure=true;next.sync.refresh(true)
  assertEquals(1,next.sets);assertFalse(next.sync.state.value.pending);assertFalse(next.sync.state.value.approvalFailed);assertFalse(next.sync.shouldGate(true,false))
  assertTrue(next.calls.all {it.first=="patient-names"})
 }
 @Test fun emptyPageRetainsLegacyWithoutSyncFeedback()=runBlocking {
  val h=Harness();h.emptyPage=true;h.sync.refresh(true)
  assertTrue(h.sync.state.value.pending);assertTrue(h.sync.state.value.failed);assertFalse(h.sync.state.value.approvalFailed);assertFalse(h.sync.shouldGate(true,false));assertEquals(0,h.sets)
 }

}
