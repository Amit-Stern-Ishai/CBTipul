package com.cbtipul.app.data

import com.sun.net.httpserver.HttpServer
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test
import java.net.InetSocketAddress
import java.util.concurrent.atomic.AtomicInteger

class NotificationRepositoryTest {
    @Test fun clearsTrayOnlyAfterSuccessfulAcknowledgement() = runBlocking {
        val markStatus = AtomicInteger(500)
        val loadStatus = AtomicInteger(200)
        val markRequests = AtomicInteger(0)
        val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        server.createContext("/") { exchange ->
            val path = exchange.requestURI.path
            val isMark = path.endsWith("mark_notifications_seen")
            if (isMark) markRequests.incrementAndGet()
            val status = if (isMark) markStatus.get() else loadStatus.get()
            val body = when {
                status != 200 -> """{"message":"acknowledgement failed","code":"XX000"}"""
                isMark -> "null"
                path.endsWith("get_unseen_notification_count") -> "1"
                else -> """[{"id":"11111111-1111-1111-1111-111111111111","type":"patient_connected","created_at":"2026-09-30T12:00:00Z","seen_at":null,"read_at":null}]"""
            }.toByteArray()
            exchange.responseHeaders.add("Content-Type", "application/json")
            exchange.sendResponseHeaders(status, body.size.toLong())
            exchange.responseBody.use { it.write(body) }
        }
        server.start()
        val client = createSupabaseClient("http://127.0.0.1:${server.address.port}", "test") { install(Postgrest) }
        try {
            var trayClears = 0
            lateinit var repository: NotificationRepository
            repository = NotificationRepository(client, onInboxSeen = {
                assertEquals(0, repository.unseenCount.value)
                assertTrue(repository.items.value.none { it.isUnseen })
                trayClears++
            })
            repository.refresh(silently = true)
            assertEquals(1, repository.unseenCount.value)
            assertFalse(repository.isLoading.value)
            assertEquals(0, markRequests.get())
            loadStatus.set(500)
            repository.refresh(silently = true)
            assertEquals(1, repository.unseenCount.value)
            assertFalse(repository.failed.value)
            assertEquals(0, trayClears)
            loadStatus.set(200)

            repository.markInboxSeen()
            assertEquals(0, trayClears)
            assertEquals(1, repository.unseenCount.value)
            assertTrue(repository.items.value.single().isUnseen)

            markStatus.set(200)
            repository.markInboxSeen()
            assertEquals(1, trayClears)
            assertEquals(0, repository.unseenCount.value)
            assertFalse(repository.items.value.single().isUnseen)

            // Already-seen rows do not imply that the Android tray is empty.
            repository.markInboxSeen()
            assertEquals(2, trayClears)
            assertEquals(3, markRequests.get())

            repository.isDemoInbox = true
            repository.markInboxSeen()
            assertEquals(2, trayClears)
            assertEquals(3, markRequests.get())
        } finally {
            client.close()
            server.stop(0)
        }
    }
}
