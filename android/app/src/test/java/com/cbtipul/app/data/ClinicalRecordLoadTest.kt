package com.cbtipul.app.data
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.CancellationException
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class ClinicalRecordLoadTest {
 private val row=Json.parseToJsonElement("""{"id":"9223372036854775807","_version":"opaque","notes":null,"combined_notes":{"gad7":["",null]}}""").jsonObject
 private fun page(cursor:JsonElement=JsonNull, rows:List<JsonObject> = listOf(row))=buildJsonObject {put("records",JsonArray(rows));put("next_cursor",cursor)}
 @Test fun shortPagesKeepRawShapeAndVersion()=runBlocking {
  var calls=0
  val rows=ClinicalRecordLoad.pages("load-questionnaires",checkpoint={},invoke={_,body->calls++;if(calls==1)page(JsonPrimitive("next")) else {assertEquals("next",body["cursor"]?.jsonPrimitive?.content);page(rows=emptyList())}})
  assertEquals(2,calls);assertEquals(row,rows.single());assertEquals("9223372036854775807",rows.single()["id"]?.jsonPrimitive?.content)
  assertEquals(com.cbtipul.app.model.DatabaseId.Text("123"),Json.decodeFromString(ClinicalStringId,"\"123\""))
 }
 @Test fun lateAccountResponseFails()=runBlocking {
  var current=true
  try {ClinicalRecordLoad.pages("load-patients",checkpoint={if(!current)throw CancellationException()},invoke={_,_->current=false;page()});fail("accepted stale page")}catch(_:CancellationException){}
 }
 @Test fun partialFailureDoesNotReturnResults()=runBlocking {
  var calls=0
  try{ClinicalRecordLoad.pages("load-patients",checkpoint={},invoke={_,_->calls++;if(calls==2)error("offline");page(JsonPrimitive("next"))});fail("returned partial page")}catch(e:IllegalStateException){assertEquals("offline",e.message)}
 }
 @Test fun invalidIdAndRepeatedCursorFail()=runBlocking {
  try{ClinicalRecordLoad.pages("load-patients",checkpoint={},invoke={_,_->page(rows=listOf(buildJsonObject{put("id",1);put("_version","v")}))});fail("numeric id")}catch(_:IllegalStateException){}
  try{ClinicalRecordLoad.pages("load-patients",checkpoint={},invoke={_,_->page(JsonPrimitive("same"),emptyList())});fail("cursor loop")}catch(_:IllegalArgumentException){}
 }
}
