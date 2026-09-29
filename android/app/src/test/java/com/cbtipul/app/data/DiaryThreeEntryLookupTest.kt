package com.cbtipul.app.data

import com.cbtipul.app.model.DatabaseId
import com.sun.net.httpserver.HttpServer
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test
import java.net.InetSocketAddress
import java.net.URI
import java.net.URLDecoder
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicReference

class DiaryThreeEntryLookupTest {
    @Test fun repositoryQueriesBothIdentifiersAndNeverTrustsCachedOrMismatchedEntry() = runTest {
        val patient = "22222222-2222-2222-2222-222222222222"
        val target = "11111111-1111-1111-1111-111111111111"
        fun row(id: String = target, owner: String = patient) = """[{"id":"$id","patient_id":"$owner",
            "therapist_id":"33333333-3333-3333-3333-333333333333","created_by":"patient","situation":"authoritative event",
            "automatic_thoughts":[{"text":"original","beliefBefore":90,"beliefAfter":35}],"feelings":[{"name":"עצוב","intensityBefore":85,"intensityAfter":40}],
            "thinking_errors":["mind_reading"],"alternative_thoughts":[{"text":"alternative","belief":80}],
            "created_at":"2026-09-01T12:00:00Z","updated_at":"2026-09-01T12:00:00Z"}]"""
        val response = AtomicReference(row())
        val status = java.util.concurrent.atomic.AtomicInteger(200)
        val requests = CopyOnWriteArrayList<URI>()
        val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        server.createContext("/rest/v1/diary_three_entries") { exchange ->
            requests += exchange.requestURI
            val bytes = response.get().toByteArray(Charsets.UTF_8)
            exchange.responseHeaders.add("Content-Type", "application/json")
            exchange.sendResponseHeaders(status.get(), bytes.size.toLong())
            exchange.responseBody.use { it.write(bytes) }
        }
        server.start()
        val client = createSupabaseClient("http://127.0.0.1:${server.address.port}", "test") { install(Postgrest) }
        try {
            val repository = DiaryThreeRepository(client)
            val owner = DatabaseId.Text(patient)
            val entry = requireNotNull(repository.loadEntry(target, owner))
            assertEquals(target, entry.id)
            assertEquals("authoritative event", entry.situation)
            assertEquals(DiaryThreeAutomaticThought("original", 90, 35), entry.automaticThoughts.single())
            assertEquals(DiaryThreeFeeling("עצוב", 85, 40), entry.feelings.single())
            assertEquals(listOf(ThinkingError.MindReading), entry.thinkingErrors)
            assertEquals(DiaryThreeAlternativeThought("alternative", 80), entry.alternativeThoughts.single())
            val request = requests.single()
            assertEquals("/rest/v1/diary_three_entries", request.path)
            val query = URLDecoder.decode(request.rawQuery, "UTF-8").split("&")
            assertTrue(query.contains("id=eq.$target"))
            assertTrue(query.contains("patient_id=eq.$patient"))
            assertTrue(query.contains("limit=1"))
            // A previously cached valid entry must not bypass a fresh authoritative lookup.
            for (body in listOf("[]", row(owner = target), row(id = patient))) {
                response.set(body)
                assertNull(repository.loadEntry(target, owner))
            }
            assertEquals(4, requests.size)
            status.set(500); response.set("{}")
            assertTrue(runCatching { repository.loadEntry(target, owner) }.isFailure)
        } finally {
            client.close()
            server.stop(0)
        }
    }
}
