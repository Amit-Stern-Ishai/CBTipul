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

class DiaryTwoEntryLookupTest {
    @Test fun repositoryQueriesBothIdentifiersAndNeverTrustsCachedOrMismatchedEntry() = runTest {
        val patient = "22222222-2222-2222-2222-222222222222"
        val target = "11111111-1111-1111-1111-111111111111"
        fun row(id: String = target, owner: String = patient) = """[{"id":"$id","patient_id":"$owner",
            "therapist_id":"33333333-3333-3333-3333-333333333333","created_by":"patient","event":"private",
            "automatic_thoughts":["private"],"feelings":[{"name":"עצוב","intensity":20}],
            "thinking_errors":["mind_reading"],"alternative_thoughts":["private"],
            "created_at":"2026-09-01T12:00:00Z","updated_at":"2026-09-01T12:00:00Z"}]"""
        val response = AtomicReference(row())
        val requests = CopyOnWriteArrayList<URI>()
        val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        server.createContext("/rest/v1/diary_two_entries") { exchange ->
            requests += exchange.requestURI
            val bytes = response.get().toByteArray(Charsets.UTF_8)
            exchange.responseHeaders.add("Content-Type", "application/json")
            exchange.sendResponseHeaders(200, bytes.size.toLong())
            exchange.responseBody.use { it.write(bytes) }
        }
        server.start()
        val client = createSupabaseClient("http://127.0.0.1:${server.address.port}", "test") { install(Postgrest) }
        try {
            val repository = DiaryTwoRepository(client)
            val owner = DatabaseId.Text(patient)
            assertEquals(target, repository.loadEntry(target, owner)?.id)
            val request = requests.single()
            assertEquals("/rest/v1/diary_two_entries", request.path)
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
        } finally {
            client.close()
            server.stop(0)
        }
    }
}
