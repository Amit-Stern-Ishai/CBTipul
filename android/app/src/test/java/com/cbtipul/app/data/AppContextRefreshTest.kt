package com.cbtipul.app.data

import com.sun.net.httpserver.HttpServer
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.user.UserInfo
import io.github.jan.supabase.auth.user.UserSession
import io.github.jan.supabase.functions.Functions
import kotlinx.coroutines.*
import org.junit.Assert.*
import org.junit.After
import org.junit.Test
import java.net.InetSocketAddress
import java.util.concurrent.atomic.AtomicInteger

@OptIn(kotlin.time.ExperimentalTime::class)
class AppContextRefreshTest {
    @After fun reset() = Entitlements.clear()

    private fun client(port: Int) = createSupabaseClient("http://127.0.0.1:$port", "test") {
        install(Functions)
        install(Auth) {
            enableLifecycleCallbacks = false
            codeVerifierCache = io.github.jan.supabase.auth.MemoryCodeVerifierCache()
            sessionManager = io.github.jan.supabase.auth.MemorySessionManager()
            autoLoadFromStorage = false; autoSaveToStorage = false; alwaysAutoRefresh = false
        }
    }
    private val user = "11111111-1111-1111-1111-111111111111"
    private val full = """{"role":"therapist","entitlement":{"access":"full"}}"""
    private val sessionResponse get() = """{"access_token":"refreshed-test-token","refresh_token":"refresh-test-token","token_type":"bearer","expires_in":3600,"user":{"id":"$user","aud":"authenticated"}}"""

    @Test fun unauthorizedContextRefreshesSessionOnceThenAppliesFullAccess() = runBlocking {
        val requests = AtomicInteger()
        val refreshes = AtomicInteger()
        val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        server.createContext("/") { exchange ->
            val refresh = exchange.requestURI.path == "/auth/v1/token"
            val rejected = !refresh && requests.incrementAndGet() == 1
            val body = if (refresh) { refreshes.incrementAndGet(); sessionResponse } else if (rejected) """{"error":"Unauthorized"}""" else full
            val bytes = body.toByteArray()
            exchange.responseHeaders.add("Content-Type", "application/json")
            exchange.sendResponseHeaders(if (rejected) 401 else 200, bytes.size.toLong())
            exchange.responseBody.use { it.write(bytes) }
        }
        server.start()
        val client = client(server.address.port)
        try {
            client.auth.importSession(UserSession("old-test-token", "refresh-test-token", expiresIn = 3600, tokenType = "bearer", user = UserInfo(aud = "authenticated", id = user)))
            val repository = AppContextRepository(client)
            assertEquals(EntitlementAccess.Full, repository.getCurrentAppContext().entitlement?.access)
            assertTrue(Entitlements.canWrite)
            assertEquals(2, requests.get())
            assertEquals(1, refreshes.get())
            assertFalse(repository.isLoading.value)
        } finally { client.close(); server.stop(0) }
    }

    @Test fun cancellingRefreshDoesNotRevokeConfirmedFullAccess() = runBlocking {
        val entered = CompletableDeferred<Unit>()
        val release = java.util.concurrent.CountDownLatch(1)
        val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        server.createContext("/") { exchange ->
            entered.complete(Unit)
            release.await(5, java.util.concurrent.TimeUnit.SECONDS)
            runCatching {
                val bytes = full.toByteArray()
                exchange.sendResponseHeaders(200, bytes.size.toLong())
                exchange.responseBody.use { it.write(bytes) }
            }
        }
        server.start()
        val client = client(server.address.port)
        try {
            client.auth.importSession(UserSession("test-token", "test-refresh", expiresIn = 3600, tokenType = "bearer", user = UserInfo(aud = "authenticated", id = user)))
            Entitlements.setIdentity(user)
            Entitlements.apply(AppContext(role = AppRole.Therapist, entitlement = AppEntitlement(EntitlementAccess.Full)))
            val repository = AppContextRepository(client)
            val job = launch { repository.getCurrentAppContext() }
            withTimeout(5_000) { entered.await() }
            job.cancelAndJoin()
            assertTrue(Entitlements.canWrite)
            assertFalse(repository.isLoading.value)
        } finally { release.countDown(); client.close(); server.stop(0) }
    }
}
