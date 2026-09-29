package com.cbtipul.app.data

import com.cbtipul.app.model.DatabaseId
import com.sun.net.httpserver.HttpServer
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.functions.Functions
import io.github.jan.supabase.postgrest.Postgrest
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.*
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test
import java.net.InetSocketAddress
import java.net.URLDecoder
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicReference

@OptIn(ExperimentalCoroutinesApi::class)
class PatientDiaryThreeServiceTest {
    private val patient = "22222222-2222-2222-2222-222222222222"
    private val id = "11111111-1111-1111-1111-111111111111"
    private val row = """{"id":"$id","patient_id":"$patient","therapist_id":"33333333-3333-3333-3333-333333333333","created_by":"patient",
        "situation":"event","automatic_thoughts":[{"text":"a","beliefBefore":100,"beliefAfter":0}],
        "feelings":[{"name":"עצוב","intensityBefore":100,"intensityAfter":0}],"thinking_errors":["mind_reading"],
        "alternative_thoughts":[{"text":"b","belief":100}],"created_at":"2026-09-01T12:00:00Z","updated_at":"2026-09-01T12:00:00Z"}"""
    data class Request(val method: String, val path: String, val query: String, val body: String)

    @Test fun patientUsesOnlySubmitFunctionAndReadsOwnHistory() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        val response = AtomicReference("[]")
        val requests = CopyOnWriteArrayList<Request>()
        val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        server.createContext("/") { exchange ->
            requests += Request(exchange.requestMethod, exchange.requestURI.path,
                URLDecoder.decode(exchange.requestURI.rawQuery.orEmpty(), "UTF-8"), exchange.requestBody.bufferedReader().readText())
            val body = if (exchange.requestURI.path.endsWith("is_patient_connected")) "true" else response.get()
            val bytes = body.toByteArray(Charsets.UTF_8)
            exchange.responseHeaders.add("Content-Type", "application/json")
            exchange.sendResponseHeaders(200, bytes.size.toLong())
            exchange.responseBody.use { it.write(bytes) }
        }
        server.start()
        val client = createSupabaseClient("http://127.0.0.1:${server.address.port}", "test") {
            install(Postgrest); install(Functions)
            install(Auth) { enableLifecycleCallbacks = false; codeVerifierCache = io.github.jan.supabase.auth.MemoryCodeVerifierCache(); sessionManager = io.github.jan.supabase.auth.MemorySessionManager(); autoLoadFromStorage = false; autoSaveToStorage = false; alwaysAutoRefresh = false }
        }
        try {
            val service = PatientDiaryThreeService(client)
            val draft = DiaryThreeEntryDraft(situation = "event", automaticThoughts = listOf(DiaryThreeAutomaticThoughtDraft(text = "a", beliefBefore = 100, beliefAfter = 0)), feelings = listOf(DiaryThreeFeelingDraft(name = "עצוב", intensityBefore = 100, intensityAfter = 0)), thinkingErrors = listOf(ThinkingError.MindReading), alternativeThoughts = listOf(DiaryThreeAlternativeThoughtDraft(text = "b", belief = 100)))
            response.set("""{"success":true,"entryId":"$id"}""")
            assertEquals(id, service.submitEntry(SubmitDiaryThreeEntryRequest.from(draft)))
            assertEquals(1, requests.size)
            assertEquals("POST", requests.single().method)
            assertEquals("/functions/v1/submit-diary-three-entry", requests.single().path)
            val body = Json.parseToJsonElement(requests.single().body).jsonObject
            assertEquals(setOf("situation", "automaticThoughts", "feelings", "thinkingErrors", "alternativeThoughts"), body.keys)
            assertEquals(setOf("text", "beliefBefore", "beliefAfter"), body.getValue("automaticThoughts").jsonArray[0].jsonObject.keys)
            assertEquals(setOf("name", "intensityBefore", "intensityAfter"), body.getValue("feelings").jsonArray[0].jsonObject.keys)
            assertEquals(setOf("text", "belief"), body.getValue("alternativeThoughts").jsonArray[0].jsonObject.keys)
            val older = row.replace("2026-09-01", "2026-08-01").replace(id, "44444444-4444-4444-4444-444444444444")
            val therapist = row.replace("\"created_by\":\"patient\"", "\"created_by\":\"therapist\"")
            val otherPatient = row.replace(patient, "55555555-5555-5555-5555-555555555555")
            response.set("[$older,$therapist,$row,$otherPatient]"); requests.clear()
            val entries = service.loadPatientCreatedEntries(patient)
            assertEquals(listOf(id, "44444444-4444-4444-4444-444444444444"), entries.map { it.id })
            assertEquals(100, entries[0].automaticThoughts[0].beliefBefore)
            assertEquals(0, entries[0].automaticThoughts[0].beliefAfter)
            assertEquals(100, entries[0].feelings[0].intensityBefore)
            assertEquals(0, entries[0].feelings[0].intensityAfter)
            assertEquals(ThinkingError.MindReading, entries[0].thinkingErrors[0])
            assertEquals(100, entries[0].alternativeThoughts[0].belief)
            assertEquals("GET", requests.single().method)
            assertEquals("/rest/v1/diary_three_entries", requests.single().path)
            assertTrue(requests.single().query.contains("created_by=eq.patient"))
            assertTrue(requests.single().query.contains("patient_id=eq.$patient"))
            assertTrue(requests.single().query.contains("order=created_at.desc"))
        } finally { client.close(); server.stop(0); Dispatchers.resetMain() }
    }
}
