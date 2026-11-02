package com.cbtipul.app.data

import com.sun.net.httpserver.HttpServer
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.functions.Functions
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.user.UserInfo
import io.github.jan.supabase.auth.user.UserSession
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test
import java.net.InetSocketAddress

@OptIn(kotlin.time.ExperimentalTime::class)
class PatientNameTransportTest {
 private val owner="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
 @Test fun actualSdkSendsJsonAndAuthenticatedSessionForListAndSet()=runBlocking {
  val requests=mutableListOf<JsonObject>();val headers=mutableListOf<Pair<String?,String?>>()
  val server=HttpServer.create(InetSocketAddress("127.0.0.1",0),0)
  server.createContext("/functions/v1/patient-names") { exchange->
   val type=exchange.requestHeaders.getFirst("Content-Type")
   headers+=type to exchange.requestHeaders.getFirst("Authorization")
   val body=Json.parseToJsonElement(exchange.requestBody.bufferedReader().readText()).jsonObject;requests+=body
   val response=if(type?.substringBefore(';')!="application/json") """{"error":"unsupported_media_type"}"""
    else if(body["operation"]?.jsonPrimitive?.content=="list") """{"names":[{"patient_id":"AAAAAAAA-1111-1111-1111-111111111111","name":null,"revision":"9007199254740993","updated_at":null}],"next_after":null}"""
    else """{"patient_id":"aaaaaaaa-1111-1111-1111-111111111111","revision":"9007199254740994","updated_at":"2026-10-29T00:00:00Z","unchanged":false}"""
   val bytes=response.toByteArray();exchange.responseHeaders.add("Content-Type","application/json")
   exchange.sendResponseHeaders(if(type?.substringBefore(';')=="application/json")200 else 415,bytes.size.toLong());exchange.responseBody.use {it.write(bytes)}
  };server.start()
  val client=createSupabaseClient("http://127.0.0.1:${server.address.port}","mock-public") {
   install(Functions)
   install(Auth){enableLifecycleCallbacks=false;codeVerifierCache=io.github.jan.supabase.auth.MemoryCodeVerifierCache();sessionManager=io.github.jan.supabase.auth.MemorySessionManager();autoLoadFromStorage=false;autoSaveToStorage=false;alwaysAutoRefresh=false}
  }
  try {
   client.auth.importSession(UserSession("synthetic-access","synthetic-refresh",expiresIn=3600,tokenType="bearer",user=UserInfo(aud="authenticated",id=owner)))
   val raw=PatientNameSync.callService(client,"patient-names",buildJsonObject {put("operation","list");put("after",JsonNull);put("limit",100)})
   val page=Json.decodeFromString<PatientNamePage>(raw)
   assertNull(page.names.single().name);assertNull(page.names.single().updated_at);assertEquals("9007199254740993",page.names.single().revision)
   PatientNameSync.callService(client,"patient-names",buildJsonObject {put("operation","set");put("patient_id",page.names.single().patient_id.lowercase());put("name","שם סינתטי");put("expected_revision",page.names.single().revision)})
   assertEquals(2,requests.size);assertEquals(JsonNull,requests.first()["after"])
   assertTrue(requests.last()["expected_revision"]!!.jsonPrimitive.isString)
   assertTrue(headers.all {it.first?.substringBefore(';')=="application/json"&&it.second=="Bearer synthetic-access"})
  }finally {client.close();server.stop(0)}
 }
 @Test fun structuredErrorsRetainHttpStatusAndSafeCode()=runBlocking {
  var status=409;var body="""{"error":{"code":"revision_conflict","message":"SENSITIVE_SYNTHETIC_BODY"}}"""
  val server=HttpServer.create(InetSocketAddress("127.0.0.1",0),0)
  server.createContext("/"){e->val bytes=body.toByteArray();e.responseHeaders.add("Content-Type","application/json");e.sendResponseHeaders(status,bytes.size.toLong());e.responseBody.use {it.write(bytes)}};server.start()
  val client=createSupabaseClient("http://127.0.0.1:${server.address.port}","mock-public"){install(Functions)}
  try {
   for((http,raw,code) in listOf(Triple(409,body,"revision_conflict"),Triple(403,"""{"code":"consent_required","error":"detail"}""","consent_required"),Triple(415,"""{"error":"unsupported_media_type"}""","unsupported_media_type"),Triple(500,"SENSITIVE_SYNTHETIC_BODY","http_500"))){
    status=http;body=raw
    val failure=try {PatientNameSync.callService(client,"patient-names",buildJsonObject {put("operation","list")});error("expected failure")}catch(e:NameSyncFailure){e}
    assertEquals(code,failure.code);assertEquals(http,failure.httpStatus);assertFalse(failure.toString().contains("SENSITIVE_SYNTHETIC_BODY"))
   }
  }finally{client.close();server.stop(0)}
 }
}
