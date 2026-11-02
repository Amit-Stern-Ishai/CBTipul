package com.cbtipul.app.data

import com.cbtipul.app.model.DatabaseId
import com.sun.net.httpserver.HttpServer
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.postgrest.Postgrest
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test
import java.net.InetSocketAddress
import java.net.URLDecoder
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference

class DiaryHistoryEditingTest {
    private val id = "11111111-1111-1111-1111-111111111111"
    private val patient = "22222222-2222-2222-2222-222222222222"
    private fun row(n: Int, author: String): String {
        val content = when(n) {
            1 -> """"event":"test","automatic_thoughts":["one","two"],"feelings":[{"name":"עצוב","intensity":0}],"behaviour":"test","physical_symptoms":null"""
            2 -> """"event":"test","automatic_thoughts":["one","two"],"feelings":[{"name":"עצוב","intensity":100}],"thinking_errors":["mind_reading"],"alternative_thoughts":["other"]"""
            else -> """"situation":"test","automatic_thoughts":[{"text":"one","beliefBefore":100,"beliefAfter":0}],"feelings":[{"name":"עצוב","intensityBefore":100,"intensityAfter":0}],"thinking_errors":["mind_reading"],"alternative_thoughts":[{"text":"other","belief":50}]"""
        }
        return """{"id":"$id","patient_id":"$patient","therapist_id":"33333333-3333-3333-3333-333333333333","created_by":"$author",$content,"created_at":"2026-01-01T12:00:00Z","updated_at":"2026-11-01T12:00:00Z"}"""
    }
    data class Request(val method:String,val path:String,val query:String,val body:String)
    @Test fun allDiariesBothRolesAuthorsAndFailedRetryUseOnlyConfirmedUpdates() = runBlocking {
        val pages=java.util.concurrent.ConcurrentLinkedQueue<String>()
        val status=AtomicInteger(200);val response=AtomicReference("[]");val requests=CopyOnWriteArrayList<Request>()
        val server=HttpServer.create(InetSocketAddress("127.0.0.1",0),0)
        server.createContext("/") { e ->
            requests += Request(e.requestMethod,e.requestURI.path,URLDecoder.decode(e.requestURI.rawQuery.orEmpty(),"UTF-8"),e.requestBody.bufferedReader().readText())
            val bytes=(pages.poll() ?: response.get()).toByteArray();e.responseHeaders.add("Content-Type","application/json")
            e.sendResponseHeaders(status.get(),bytes.size.toLong());e.responseBody.use { it.write(bytes) }
        }
        server.start()
        val client=createSupabaseClient("http://127.0.0.1:${server.address.port}","test") {
            install(Postgrest)
            install(Auth) { enableLifecycleCallbacks=false;autoLoadFromStorage=false;autoSaveToStorage=false;alwaysAutoRefresh=false
                codeVerifierCache=io.github.jan.supabase.auth.MemoryCodeVerifierCache();sessionManager=io.github.jan.supabase.auth.MemorySessionManager() }
        }
        try {
            for (role in listOf(AppRole.Patient,AppRole.Therapist)) for (author in listOf("patient","therapist")) for(n in 1..3) {
                Entitlements.apply(AppContext(role=role,activation=PatientActivation.Active,patientId=patient,entitlement=AppEntitlement(EntitlementAccess.Full)))
                val one=DiaryOneRepository(client);val two=DiaryTwoRepository(client);val three=DiaryThreeRepository(client);val owner=DatabaseId.Text(patient)
                suspend fun save() {
                    when(n) {
                        1 -> one.updateEntry(id,owner,"test",listOf("one","two"),listOf(DiaryFeeling("עצוב",0)),"test",null).let {
                            assertEquals(id,it.id);assertEquals(author,it.createdBy.raw);assertTrue(it.createdAt.before(it.updatedAt));assertEquals(1,one.entriesFor(owner).size)
                        }
                        2 -> two.updateEntry(id,owner,"test",listOf("one","two"),listOf(DiaryFeeling("עצוב",100)),listOf(ThinkingError.MindReading),listOf("other")).let {
                            assertEquals(id,it.id);assertEquals(author,it.createdBy.raw);assertTrue(it.createdAt.before(it.updatedAt));assertEquals(1,two.entriesFor(owner).size)
                        }
                        3 -> three.updateEntry(id,owner,"test",listOf(DiaryThreeAutomaticThought("one",100,0)),listOf(DiaryThreeFeeling("עצוב",100,0)),listOf(ThinkingError.MindReading),listOf(DiaryThreeAlternativeThought("other",50))).let {
                            assertEquals(id,it.id);assertEquals(author,it.createdBy.raw);assertTrue(it.createdAt.before(it.updatedAt));assertEquals(1,three.entriesFor(owner).size)
                        }
                    }
                }
                val original=row(n,author)
                for ((code,body) in listOf(403 to """{"code":"42501","message":"denied"}""",200 to "[]",
                    200 to "[${original.replace(id,"44444444-4444-4444-4444-444444444444")}]",
                    200 to "[${original.replace(patient,"55555555-5555-5555-5555-555555555555")}]",503 to """{"message":"unavailable"}""")) {
                    status.set(code);response.set(body)
                    var failed=false;try { save() } catch(_:Exception) { failed=true };assertTrue("Unconfirmed update must fail",failed)
                    assertTrue(one.entriesFor(owner).isEmpty()&&two.entriesFor(owner).isEmpty()&&three.entriesFor(owner).isEmpty())
                }
                status.set(200);response.set("[$original]");requests.clear();save();save()
                assertEquals(2,requests.size);assertEquals(requests[0].body,requests[1].body)
                requests.forEach {
                    assertEquals("PATCH",it.method);assertEquals("/rest/v1/diary_${listOf("one","two","three")[n-1]}_entries",it.path)
                    assertTrue(it.query.contains("id=eq.$id"));assertTrue(it.query.contains("patient_id=eq.$patient"));assertFalse(it.query.contains("created_by="))
                    val payload=Json.parseToJsonElement(it.body).jsonObject
                    assertTrue(payload.keys.intersect(setOf("id","patient_id","therapist_id","created_by","created_at","updated_at")).isEmpty())
                }
            }
            for(n in 1..3) {
                val first=(0 until 250).map { index -> row(n,if(index%2==0)"patient" else "therapist").replace(id,"00000000-0000-0000-0000-%012d".format(index)) }
                pages.add(first.joinToString(",","[","]"));pages.add("[${row(n,"therapist")}] ");requests.clear()
                val count=when(n) {
                    1 -> DiaryOneRepository(client).loadPatientCreatedEntries(DatabaseId.Text(patient)).size
                    2 -> PatientDiaryTwoService(client).loadPatientCreatedEntries(patient).size
                    else -> PatientDiaryThreeService(client).loadPatientCreatedEntries(patient).size
                }
                assertEquals(251,count);assertEquals(2,requests.size)
                assertTrue(requests.all {it.method=="GET" && it.path.endsWith("_entries") && !it.query.contains("created_by=")})
                assertTrue(requests[1].query.contains("offset=250"))
            }
        } finally { client.close();server.stop(0);Entitlements.clear() }
    }
}
