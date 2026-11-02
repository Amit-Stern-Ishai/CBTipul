package com.cbtipul.app.data
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.CancellationException
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class ClinicalRecordSaveTest {
 private val old=Json.parseToJsonElement("""{"id":"9223372036854775807","_version":"v1","notes":null,"combined_notes":{"gad7":["old"]}}""").jsonObject
 @Test fun exactChangedFieldsAndClears() {
  val proposed=buildJsonObject {put("notes", "");put("combined_notes",JsonNull);put("patient_id","immutable")}
  val body=ClinicalRecordSave.request(old,proposed)
  assertEquals(JsonPrimitive("9223372036854775807"),body["id"]);assertEquals(JsonPrimitive("v1"),body["expected_version"])
  assertEquals(Json.parseToJsonElement("""{"notes":"","combined_notes":null}"""),body["changes"])
  assertEquals(JsonObject(emptyMap()),ClinicalRecordSave.request(old,old.filterKeys {it=="notes"||it=="combined_notes"}.let(::JsonObject))["changes"])
 }
 @Test fun originalTextAndAnalysisStayExact() {
  val text="  טקסט סינתטי!\nבדיוק.  "
  val body=ClinicalRecordSave.request(null,buildJsonObject {put("notes",text);put("structured_notes",buildJsonObject{put("summary",text)})})
  assertEquals(text,body["changes"]!!.jsonObject["notes"]!!.jsonPrimitive.content)
  assertFalse(body.containsKey("expected_version"))
 }
 @Test fun responseKeepsNewVersionAndRejectsWrongIdentity() {
  val saved=JsonObject(old + ("_version" to JsonPrimitive("v2")))
  assertEquals(saved,ClinicalRecordSave.record(buildJsonObject{put("record",saved)},old,JsonObject(emptyMap())))
  try{ClinicalRecordSave.record(buildJsonObject{put("record",JsonObject(saved+("id" to JsonPrimitive("wrong"))))},old,JsonObject(emptyMap()));fail("wrong id")}catch(_:IllegalArgumentException){}
  try{ClinicalRecordSave.request(JsonObject(old-"_version"),JsonObject(emptyMap()));fail("blind update")}catch(_:IllegalArgumentException){}
 }
 @Test fun transportConflictAndUncertainSaveNeverRetry()=runBlocking {
  for(code in listOf("record_changed","save_outcome_unknown","save_not_confirmed","request_never_arrived")) {
   var calls=0
   try {ClinicalRecordSave.save(null,buildJsonObject{put("notes","draft")},{}) {calls++;error(code)};fail("accepted error")}catch(e:IllegalStateException){assertEquals(code,e.message)}
   assertEquals(1,calls)
  }
  var current=true
  try {ClinicalRecordSave.save(old,JsonObject(emptyMap()),{if(!current)throw CancellationException()}) {current=false;buildJsonObject{put("record",old)}};fail("late save") }catch(_:CancellationException){}
 }
}
