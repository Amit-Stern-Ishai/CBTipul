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
   if(p["operation"]!!.jsonPrimitive.content=="list") {
    lists++
    val last=page && p["after"]!=JsonNull
    return json.encodeToString(PatientNamePage(if(last)emptyList() else rows.values.toList(),if(page&&!last)patient else null))
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
 @Test fun noRequestsBeforeConsentAndOfflineKeepsLegacy()=runBlocking {
  val h=Harness();h.consent="required";h.sync.refresh(true);assertEquals(0,h.lists);assertEquals(0,h.sets)
  assertEquals("ישן",h.sync.displayed(patient,"ישן"));h.lookupFailure=true;h.sync.refresh(true);assertEquals(0,h.lists);assertTrue(h.sync.state.value.failed)
 }
 @Test fun acceptanceOnAnotherDeviceMigratesAndFollowsFinalEmptyPage()=runBlocking {
  val h=Harness();h.page=true;h.sync.refresh(true);assertEquals(2,h.lists);assertEquals(1,h.sets);assertEquals("שם בדיקה",h.rows[patient]?.name)
 }
 @Test fun existingServerWinsAndLateLegacyNeverReuploads()=runBlocking {
  val h=Harness();h.rows[patient]=ServerPatientName(patient,"שרת","900719925474099312345",date)
  h.sync.refresh(true);h.sync.register(mapOf(patient to "ערך iCloud מאוחר"));h.sync.refresh(true)
  assertEquals(0,h.sets);assertEquals("שרת",h.sync.displayed(patient,"ישן"))
 }
 @Test fun racingInitialUploadAdoptsWinnerWithoutRetryingLegacy()=runBlocking {
  val h=Harness();h.onSet={h.rows[patient]=ServerPatientName(patient,"מכשיר אחר","1",date);h.onSet=null}
  h.sync.refresh(true);assertEquals(1,h.sets);assertEquals("מכשיר אחר",h.sync.displayed(patient,null))
 }
 @Test fun explicitRenameRetriesLatestStringRevision()=runBlocking {
  val h=Harness();h.rows[patient]=ServerPatientName(patient,"קיים","9007199254740993",date);h.sync.refresh(true)
  h.onSet={h.rows[patient]=ServerPatientName(patient,"אחר","9007199254740994",date);h.onSet=null}
  h.sync.edit(patient,"שינוי מכוון");assertEquals(2,h.sets);assertEquals("9007199254740995",h.rows[patient]?.revision);assertEquals("שינוי מכוון",h.rows[patient]?.name)
 }
 @Test fun newerEditSupersedesConflictedRequest()=runBlocking {
  val h=Harness();h.rows[patient]=ServerPatientName(patient,"קיים","1",date);h.sync.refresh(true)
  h.onSet={h.onSet=null;h.sync.edit(patient,"חדש");h.rows[patient]=ServerPatientName(patient,"אחר","2",date)}
  h.sync.edit(patient,"ישן");assertEquals("חדש",h.rows[patient]?.name)
  val writes=h.calls.filter {it.second["operation"]?.jsonPrimitive?.content=="set"}.map {it.second["name"]!!.jsonPrimitive.content}
  assertEquals(listOf("ישן","חדש"),writes)
 }
 @Test fun conflictsAreBoundedAndPendingSurvivesRelaunch()=runBlocking {
  val h=Harness();h.rows[patient]=ServerPatientName(patient,"קיים","1",date);h.sync.refresh(true)
  h.onSet={throw NameSyncFailure("revision_conflict")};h.sync.edit(patient,"ממתין")
  assertEquals(3,h.sets);assertTrue(h.sync.state.value.pending)
  val next=Harness(h.disk);next.rows[patient]=h.rows[patient]!!;assertEquals("ממתין",next.sync.displayed(patient,null));next.sync.refresh(true)
  assertEquals("ממתין",next.rows[patient]?.name);assertFalse(next.sync.state.value.pending)
 }
 @Test fun uncertainNameResponseReconcilesWithoutSecondWrite()=runBlocking {
  val h=Harness();h.onSet={p->h.rows[patient]=ServerPatientName(patient,p["name"]!!.jsonPrimitive.content,"1",date);throw NameSyncFailure("connection")}
  h.sync.refresh(true);assertTrue(h.sync.state.value.pending);h.onSet=null;h.sync.refresh(true);assertEquals(1,h.sets);assertFalse(h.sync.state.value.pending)
 }
 @Test fun pendingEditWinsDuringRefreshAndReadonlyCannotOverwrite()=runBlocking {
  val h=Harness();h.rows[patient]=ServerPatientName(patient,"שרת","1",date);h.full=false
  h.sync.edit(patient,"מקומי");h.sync.refresh(true);assertEquals(0,h.sets);assertEquals("מקומי",h.sync.displayed(patient,null))
  h.rows[patient]=ServerPatientName(patient,"מקומי","2",date);h.sync.refresh(true);assertFalse(h.sync.state.value.pending);assertEquals(0,h.sets)
 }
 @Test fun readonlyCanUploadInitialNameAndMissingNamesDoNothing()=runBlocking {
  val h=Harness();h.full=false;h.rows[second]=ServerPatientName(second,null,"0",null);h.sync.register(mapOf(patient to "מקומי",second to null));h.sync.refresh(true);assertEquals(1,h.sets)
 }
 @Test fun deletionDuringRequestDoesNotResurrectMapping()=runBlocking {
  val h=Harness();h.onSet={h.sync.beginDeletion(patient);h.sync.remove(patient)};h.sync.refresh(true);assertNull(h.sync.displayed(patient,null))
 }
 @Test fun accountSwitchAndDisabledModesIgnoreLateResults()=runBlocking {
  val h=Harness();h.onSet={h.sync.setAccount("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")};h.sync.refresh(true);assertNull(h.sync.displayed(patient,null))
  h.allowed=false;val count=h.calls.size;h.sync.refresh(true);h.sync.decide();assertEquals(count,h.calls.size)
 }
 @Test fun uncertainConsentKeepsExactArgumentsAcrossRelaunch()=runBlocking {
  val h=Harness();h.consent="required";h.unknownDecision=true;h.sync.decide();assertEquals(0,h.lists)
  val payload=h.calls.single {it.first=="record_my_consent"}.second
  val next=Harness(h.disk);next.sync.decide();assertEquals(payload,next.calls.single {it.first=="record_my_consent"}.second)
 }
 @Test fun supersededConsentRefreshesWithoutRestoringAcceptance()=runBlocking {
  val h=Harness();h.consent="required";h.decisionError="consent_request_superseded";h.sync.decide();assertFalse(h.sync.state.value.accepted);assertEquals(0,h.lists)
 }
 @Test fun storageFailureDoesNotClaimPendingIsDurable()=runBlocking {
  val h=Harness();h.disk.fail=true;assertThrows(Exception::class.java){h.sync.edit(patient,"שינוי")};assertFalse(h.sync.state.value.pending);assertEquals(0,h.sets)
 }
 @Test fun revokedConsentStopsNamesAndDisplayCallbackTracksPending()=runBlocking {
  val h=Harness();var mirrored:String?=null;h.sync.changed={mirrored=h.sync.displayed(patient,null)}
  h.sync.refresh(true);assertEquals("שם בדיקה",mirrored)
  h.consent="revoked";h.consentRev=1;val before=h.lists;h.sync.edit(patient,"ממתין")
  assertEquals(before,h.lists);assertEquals("ממתין",mirrored)
 }
 @Test fun createdNameSurvivesTemporaryStorageFailure()=runBlocking {
  val h=Harness();h.disk.fail=true;h.sync.rememberCreated(patient,"שם חדש")
  h.sync.refresh(true);assertEquals(0,h.sets);assertEquals("שם חדש",h.sync.displayed(patient,null))
  h.disk.fail=false;h.sync.refresh(true);assertEquals("שם חדש",h.rows[patient]?.name)
 }
 @Test fun invalidReceiptAccountTypeVersionAndRevisionAreErrors(){
  val base=NameConsentReceipt(account,PatientNameRules.type,PatientNameRules.version,PatientNameRules.version,date,null,"accepted",0)
  listOf(base.copy(therapist_id="other"),base.copy(consent_type="other"),base.copy(required_version="old"),base.copy(revision=-1),base.copy(accepted_at=null),base.copy(revoked_at=date)).forEach {
   assertThrows(NameSyncFailure::class.java){it.validate(account)}
  }
 }
 @Test fun consentRequiredAfterApprovalStopsAndReloadsConsent()=runBlocking {
  val h=Harness();h.consent="required"
  h.onSet={h.consent="revoked";h.consentRev=2;throw NameSyncFailure("consent_required")}
  h.sync.decide();assertFalse(h.sync.state.value.accepted);assertEquals(1,h.sets)
  assertEquals(2,h.calls.count {it.first=="get_my_consent"})
 }
 @Test fun serverCacheSurvivesRelaunchAndBlankLegacyRefresh()=runBlocking {
  val patient="abcdefab-abcd-abcd-abcd-abcdefabcdef"
  val h=Harness();h.rows.clear();h.rows[patient]=ServerPatientName(patient.uppercase(),"שם שרת","9007199254740993",date)
  h.sync.register(mapOf(patient.uppercase() to ""));var updates=0;h.sync.changed={updates++}
  h.sync.refresh(true);assertEquals("שם שרת",h.sync.displayed(patient.uppercase(),""));assertTrue(updates>0)
  val next=Harness(h.disk);next.rows.clear();next.sync.register(mapOf(patient.uppercase() to ""))
  assertEquals("שם שרת",next.sync.displayed(patient,""))
  next.rows[patient]=ServerPatientName(patient.uppercase(),"שם מעודכן","9007199254740994",date)
  next.sync.refresh(true);assertEquals("שם מעודכן",next.sync.displayed(patient,""));assertEquals(0,next.sets)
 }
 @Test fun unicodeAndSpacingValidation(){
  assertTrue(PatientNameRules.valid("  שם  בדיקה  "));assertTrue(PatientNameRules.valid("😀".repeat(200)))
  assertFalse(PatientNameRules.valid("😀".repeat(201)));assertFalse(PatientNameRules.valid("\u0000שם"));assertFalse(PatientNameRules.valid("שם\n"));assertFalse(PatientNameRules.valid("\u007f"));assertFalse(PatientNameRules.valid("   "))
 }
 @Test fun migrationRequiresConsentAndLogoutNeverUploads()=runBlocking {
  val h=Harness();h.consent="required";h.sync.loadOwned={error("must not load before approval")}
  h.sync.refresh(true);assertTrue(h.sync.shouldGate(true,false));assertEquals(0,h.lists)
  h.sync.setAccount(null);assertEquals(0,h.sets)
 }
 @Test fun migrationWaitsForAcknowledgementAndDoesNotRecordExistingConsent()=runBlocking {
  val h=Harness();h.sync.loadOwned={mapOf(patient to "מקומי")}
  h.onSet={assertFalse(h.sync.migrationComplete)}
  h.sync.refresh(true);assertTrue(h.sync.migrationComplete);assertFalse(h.calls.any {it.first=="record_my_consent"})
  val missing=Harness();missing.sync.loadOwned={mapOf(patient to null)};missing.sync.refresh(true)
  assertTrue(missing.sync.migrationComplete);assertEquals(0,missing.sets)
 }
 @Test fun migrationApprovalThenPartialUploadFailureResumesAfterRelaunch()=runBlocking {
  val h=Harness();h.consent="required";h.rows[second]=ServerPatientName(second,null,"0",null)
  h.sync.loadOwned={mapOf(patient to "ראשון",second to "שני")}
  h.onSet={if(it["patient_id"]!!.jsonPrimitive.content==second)throw NameSyncFailure("connection")}
  h.sync.decide();assertFalse(h.sync.migrationComplete);assertEquals("ראשון",h.rows[patient]?.name)
  assertEquals("שני",h.sync.displayed(second,null))
  val next=Harness(h.disk);next.rows.clear();next.rows.putAll(h.rows);next.sync.loadOwned={mapOf(patient to "ראשון",second to "שני")}
  next.sync.refresh(true);assertTrue(next.sync.migrationComplete);assertEquals(1,next.sets)
  val offline=Harness(h.disk);offline.lookupFailure=true
  assertFalse(offline.sync.shouldGate(true,false));offline.sync.refresh(true);assertTrue(offline.sync.migrationComplete)
  offline.sync.setAccount("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb");assertTrue(offline.sync.shouldGate(true,false))
  assertFalse(offline.sync.shouldGate(false,false));assertFalse(offline.sync.shouldGate(true,true))
 }
 @Test fun migrationLookupOwnershipAndPersistenceFailuresStayBlocked()=runBlocking {
  val h=Harness();h.lookupFailure=true;h.sync.refresh(true);assertFalse(h.sync.migrationComplete)
  h.lookupFailure=false;h.sync.loadOwned={throw NameSyncFailure("connection")};h.sync.refresh(true)
  assertFalse(h.sync.migrationComplete);assertEquals(0,h.lists)
  h.sync.loadOwned={mapOf(patient to "מקומי")};h.onSet={h.disk.fail=true};h.sync.refresh(true)
  assertFalse(h.sync.migrationComplete)
 }
 @Test fun migrationInitialRaceUsesServerWinnerAndExcludesUnowned()=runBlocking {
  val h=Harness();h.sync.register(mapOf(second to "לא שייך"));h.sync.loadOwned={mapOf(patient to "מקומי")}
  h.onSet={h.rows[patient]=ServerPatientName(patient,"שרת","1",date);h.onSet=null}
  h.sync.refresh(true);assertTrue(h.sync.migrationComplete);assertEquals(1,h.sets);assertEquals("שרת",h.sync.displayed(patient,null))
 }

 @Test fun migrationRetryResumesUncertainConsentAfterRelaunch()=runBlocking {
  val h=Harness();h.consent="required";h.unknownDecision=true;h.sync.decide()
  val next=Harness(h.disk);next.sync.loadOwned={mapOf(patient to "בדיקה")};next.sync.retryMigration()
  assertTrue(next.sync.migrationComplete)
  assertEquals(h.calls.first {it.first=="record_my_consent"}.second,next.calls.first {it.first=="record_my_consent"}.second)
 }

}
