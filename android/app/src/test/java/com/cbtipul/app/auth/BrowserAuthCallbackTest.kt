package com.cbtipul.app.auth

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class BrowserAuthCallbackTest {
    @Test fun parsesPkceAndBothRecoveryHosts() {
        val login = BrowserAuthCallback.parse("cbtipul://auth-callback?code=mock-code")!!
        assertEquals("mock-code", login.code)
        assertFalse(login.recovery)
        assertTrue(BrowserAuthCallback.parse("cbtipul://password-reset?code=mock")!!.recovery)
        assertTrue(BrowserAuthCallback.parse("cbtipul://auth-callback?code=mock&type=recovery")!!.recovery)
    }

    @Test fun preservesLegacyEmailAndRecoveryFormats() {
        val fragment = "access_token=mock&refresh_token=mock&expires_in=3600&token_type=bearer"
        assertEquals(fragment, BrowserAuthCallback.parse("cbtipul://auth-callback#$fragment")!!.legacyFragment)
        assertTrue(BrowserAuthCallback.parse("cbtipul://password-reset#$fragment")!!.recovery)
        assertEquals(fragment, BrowserAuthCallback.parse("cbtipul://password-reset?$fragment")!!.legacyFragment)
        assertTrue(BrowserAuthCallback.parse("cbtipul://auth-callback#$fragment&type=recovery")!!.recovery)
    }

    @Test fun rejectsInvitationsWrongOriginsAndUnexpectedPaths() {
        listOf("https://cbtipul.com/invite/mock", "cbtipul://invite?code=mock",
            "https://auth-callback?code=mock", "cbtipul://user@auth-callback?code=mock",
            "cbtipul://auth-callback:123?code=mock", "cbtipul://auth-callback/wrong?code=mock").forEach {
            assertNull(BrowserAuthCallback.parse(it))
        }
    }

    @Test fun distinguishesCancellationAndErrorsWithoutShowingProviderText() {
        val cancelled = BrowserAuthCallback.parse("cbtipul://auth-callback?error=access_denied")!!
        assertTrue(cancelled.error)
        assertTrue(cancelled.cancelled)
        val failed = BrowserAuthCallback.parse("cbtipul://auth-callback#error_code=bad&error_description=sensitive")!!
        assertTrue(failed.error)
        assertFalse(failed.cancelled)
    }

    @Test fun duplicateCallbacksIncludingRecreatedCoordinatorCommitOnce() = runTest {
        var stored: String? = null
        fun gate() = BrowserCallbackGate({ stored }, { stored = it })
        val callback = BrowserAuthCallback.parse("cbtipul://auth-callback?code=mock")!!
        var exchanges = 0
        var commits = 0
        val first = gate()
        first.handle(callback, { exchanges++; "session" }, { commits++ })
        first.handle(callback, { exchanges++; "session" }, { commits++ })
        gate().handle(callback, { exchanges++; "session" }, { commits++ })
        assertEquals(1, exchanges)
        assertEquals(1, commits)
        assertFalse(stored!!.contains("mock"))
    }

    @Test fun duplicateDuringExchangeIsIgnored() = runTest {
        val gate = BrowserCallbackGate({ null }, {})
        val response = CompletableDeferred<String>()
        val callback = BrowserAuthCallback.parse("cbtipul://auth-callback?code=mock")!!
        var commits = 0
        val job = launch { gate.handle(callback, { response.await() }, { commits++ }) }
        runCurrent()
        gate.handle(callback, { error("must not exchange twice") }, {})
        response.complete("session")
        job.join()
        assertEquals(1, commits)
    }

    @Test fun logoutOrAccountChangeDiscardsPendingResult() = runTest {
        val gate = BrowserCallbackGate({ null }, {})
        val response = CompletableDeferred<String>()
        var committed = false
        val job = launch {
            gate.handle(BrowserAuthCallback.parse("cbtipul://auth-callback?code=mock")!!,
                { response.await() }, { committed = true })
        }
        runCurrent()
        gate.invalidate()
        response.complete("old-session")
        job.join()
        assertFalse(committed)
        assertFalse(gate.isBusy)
    }

    @Test fun failedExchangeResetsBusyAndAllowsFreshRetry() = runTest {
        val gate = BrowserCallbackGate({ null }, {})
        try {
            gate.handle(BrowserAuthCallback.parse("cbtipul://auth-callback?code=first")!!,
                { error("offline") }, {})
            fail("Expected failure")
        } catch (_: IllegalStateException) {}
        assertFalse(gate.isBusy)
        var committed = false
        gate.handle(BrowserAuthCallback.parse("cbtipul://auth-callback?code=fresh")!!,
            { "session" }, { committed = true })
        assertTrue(committed)
    }
}
