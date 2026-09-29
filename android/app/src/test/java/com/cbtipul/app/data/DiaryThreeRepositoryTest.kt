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
class DiaryThreeRepositoryTest {
    private val patient = "22222222-2222-2222-2222-222222222222"
    private val id = "11111111-1111-1111-1111-111111111111"
    private val row = """{"id":"$id","patient_id":"$patient","therapist_id":"33333333-3333-3333-3333-333333333333","created_by":"patient",
        "situation":"event","automatic_thoughts":[{"text":"a","beliefBefore":100,"beliefAfter":0}],
        "feelings":[{"name":"עצוב","intensityBefore":100,"intensityAfter":0}],"thinking_errors":["mind_reading"],
        "alternative_thoughts":[{"text":"b","belief":100}],"created_at":"2026-09-01T12:00:00Z","updated_at":"2026-09-01T12:00:00Z"}"""
    data class Request(val method: String, val path: String, val query: String, val body: String)

    @Test fun actualActivationCancelAndEntryMutationUseSeparateContracts() = runTest {
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
            val assignments = PatientAssignmentRepository(client)
            for (created in listOf(true, false)) {
                response.set("""{"success":true,"createdNew":$created,"assignment":{"id":"$id","patientId":"$patient","therapistId":null,"sessionId":null,"type":"diary_three","createdAt":"2026-09-01T12:00:00Z","completedAt":null,"cancelledAt":null}}""")
                requests.clear()
                assertEquals(id, assignments.activateOngoingAssignment(patient, PatientAssignmentType.DiaryThree).id)
                assertEquals(listOf("/rest/v1/rpc/is_patient_connected", "/functions/v1/request-patient-diary-three"), requests.map { it.path })
                assertEquals(buildJsonObject { put("patientId", patient) }, Json.parseToJsonElement(requests[1].body))
            }
            val repo = DiaryThreeRepository(client)
            val owner = DatabaseId.Text(patient)
            response.set("[$row]"); requests.clear()
            val entry = repo.loadEntries(owner).single()
            assertTrue(requests.single().query.contains("order=created_at.desc"))
            response.set("""[{"id":"$id","patient_id":"$patient","therapist_id":null,"session_id":null,"type":"diary_three","created_at":"2026-09-01T12:00:00Z","completed_at":null,"cancelled_at":"2026-09-02T12:00:00Z"}]""")
            requests.clear(); assignments.cancelOngoingAssignment(id)
            assertEquals(listOf(entry), repo.entriesFor(owner))
            assertEquals("PATCH", requests.single().method)
            assertEquals("/rest/v1/patient_assignments", requests.single().path)
            assertEquals(setOf("cancelled_at"), Json.parseToJsonElement(requests.single().body).jsonObject.keys)
            response.set("[$row]"); requests.clear()
            val updated = repo.updateEntry(id, owner, "edited", entry.automaticThoughts, entry.feelings, entry.thinkingErrors, entry.alternativeThoughts)
            assertEquals(DiaryOneEntryCreator.Patient, updated.createdBy)
            assertEquals(entry.createdAt, updated.createdAt)
            assertEquals("PATCH", requests.single().method)
            assertEquals("/rest/v1/diary_three_entries", requests.single().path)
            assertEquals(setOf("situation", "automatic_thoughts", "feelings", "thinking_errors", "alternative_thoughts", "updated_at"), Json.parseToJsonElement(requests.single().body).jsonObject.keys)
            response.set("""[{"id":"$id"}]"""); requests.clear()
            repo.deleteEntry(id, owner)
            assertTrue(repo.entriesFor(owner).isEmpty())
            assertEquals("DELETE", requests.single().method)
            assertEquals("/rest/v1/diary_three_entries", requests.single().path)
            assertTrue(requests.single().query.contains("id=eq.$id"))
            assertTrue(requests.single().query.contains("patient_id=eq.$patient"))
        } finally { client.close(); server.stop(0); Dispatchers.resetMain() }
    }
}
