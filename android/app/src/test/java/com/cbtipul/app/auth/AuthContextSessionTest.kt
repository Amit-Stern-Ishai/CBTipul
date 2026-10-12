package com.cbtipul.app.auth

import android.content.SharedPreferences
import com.cbtipul.app.data.Entitlements
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.MemoryCodeVerifierCache
import io.github.jan.supabase.auth.MemorySessionManager
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.providers.Apple
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.auth.status.SessionSource
import io.github.jan.supabase.auth.status.SessionStatus
import io.github.jan.supabase.auth.status.RefreshFailureCause
import io.github.jan.supabase.auth.user.UserInfo
import io.github.jan.supabase.auth.user.UserSession
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import java.io.IOException
import java.lang.reflect.Proxy
import org.junit.Assert.*
import org.junit.After
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class, kotlin.time.ExperimentalTime::class)
class AuthContextSessionTest {
    @After fun reset() = Entitlements.clear()
    private fun preferences(): SharedPreferences = Proxy.newProxyInstance(
        SharedPreferences::class.java.classLoader, arrayOf(SharedPreferences::class.java),
    ) { _, method, _ -> when (method.name) {
        "getString" -> null
        "contains", "getBoolean" -> false
        "getAll" -> emptyMap<String, Any>()
        else -> null
    } } as SharedPreferences
    private fun client() = createSupabaseClient("http://127.0.0.1:1", "mock-public") {
        install(Auth) {
            enableLifecycleCallbacks = false
            autoLoadFromStorage = false; autoSaveToStorage = false; alwaysAutoRefresh = false
            sessionManager = MemorySessionManager(); codeVerifierCache = MemoryCodeVerifierCache()
        }
    }
    private fun stored(token: String = "mock", id: String = "same-user") = UserSession(
        token, "mock-refresh", expiresIn = 3600, tokenType = "bearer", user = UserInfo(aud = "authenticated", id = id),
    )

    @Test fun googleAppleAndEmailAuthenticationEmitRevisionsWithoutGrantingAccess() = runTest {
        val client = client()
        try {
            val auth = AuthRepository(client, preferences())
            val changes = mutableListOf<AuthContextSession?>()
            backgroundScope.launch { auth.contextSessionChanges.collect { changes += it } }
            runCurrent()
            for ((index, source) in listOf(SessionSource.SignIn(Google), SessionSource.SignIn(Apple), SessionSource.SignIn(Email)).withIndex()) {
                client.auth.importSession(stored("mock-$index"), autoRefresh = false, source = source)
                runCurrent()
                assertFalse(Entitlements.canWrite)
            }
            val signedIn = changes.filterNotNull()
            assertEquals(listOf(1L, 2L, 3L), signedIn.map { it.revision })
            assertEquals(setOf("same-user"), signedIn.map { it.userId }.toSet())
        } finally { client.close() }
    }

    @Test fun failedRestorationCannotStartANewPatientIdentity() = runTest {
        val client = client()
        try {
            val saved = stored(id = "preserved-anonymous")
            client.auth.sessionManager.saveSession(saved)
            client.auth.setSessionStatus(SessionStatus.RefreshFailure(RefreshFailureCause.NetworkError(IOException("mock offline"))))
            val auth = AuthRepository(client, preferences())
            var denied = false
            try { auth.awaitInvitationSessionInitialization() } catch (_: IllegalStateException) { denied = true }
            assertTrue(denied)
            assertEquals(saved, client.auth.sessionManager.loadSession())
            assertNull(client.auth.currentSessionOrNull())
            val observed = mutableListOf<AuthSession>()
            backgroundScope.launch { auth.session.collect { observed += it } }
            runCurrent()
            assertEquals(AuthSession.Unavailable, observed.last())
            assertFalse(Entitlements.canWrite)
        } finally { client.close() }
    }

    @Test fun explicitRestorationRetryLoadsOnlyTheExistingStoredIdentity() = runTest {
        val client = client()
        try {
            val saved = stored(id = "preserved-user")
            client.auth.sessionManager.saveSession(saved)
            client.auth.setSessionStatus(SessionStatus.RefreshFailure(RefreshFailureCause.NetworkError(IOException("mock offline"))))
            val auth = AuthRepository(client, preferences())
            auth.retrySessionRestoration()
            assertEquals("preserved-user", auth.currentUserId())
            assertEquals(saved, client.auth.sessionManager.loadSession())
            assertFalse(Entitlements.canWrite) // Authentication alone grants no entitlement.
        } finally { client.close() }
    }
}
