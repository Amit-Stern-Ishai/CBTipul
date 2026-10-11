package com.cbtipul.app.auth

import java.security.MessageDigest
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.serialization.json.Json
import org.junit.Assert.*
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class GoogleSignInFlowTest {
    @Test fun nonceIsFreshAndSha256Matches() {
        val one = GoogleNonce()
        val two = GoogleNonce()
        assertNotEquals(one.raw, two.raw)
        assertTrue(one.raw.matches(Regex("[0-9a-f]{64}")))
        assertEquals(hash(one.raw), one.hashed)
    }

    @Test fun successPassesHashToGoogleAndRawNonceToExchange() = runTest {
        var googleNonce = ""
        var committed: String? = null
        GoogleSignInFlow().run(
            hasSession = { false },
            credential = { googleNonce = it; "mock-id-token" },
            exchange = { token, raw ->
                assertEquals("mock-id-token", token)
                assertEquals(hash(raw), googleNonce)
                "mock-session"
            },
            commit = { committed = it },
        )
        assertEquals("mock-session", committed)
    }

    @Test fun existingSessionIncludingPatientCannotStartGoogle() = runTest {
        var called = false
        try {
            GoogleSignInFlow().run({ true }, { called = true; "" }, { _, _ -> "" }, {})
            fail("Expected cancellation")
        } catch (_: CancellationException) {}
        assertFalse(called)
    }

    @Test fun failedExchangeAllowsRetryWithFreshNonce() = runTest {
        val flow = GoogleSignInFlow()
        val hashes = mutableListOf<String>()
        var committed = 0
        try {
            flow.run({ false }, { hashes += it; "mock" },
                { _, _ -> error("mock offline") }, { committed++ })
            fail("Expected failure")
        } catch (_: IllegalStateException) {}
        flow.run({ false }, { hashes += it; "mock" }, { _, _ -> Unit }, { committed++ })
        assertNotEquals(hashes[0], hashes[1])
        assertEquals(1, committed)
    }

    @Test fun cancellationDoesNotExchangeAndAllowsRetry() = runTest {
        val flow = GoogleSignInFlow()
        var exchanged = false
        try {
            flow.run({ false }, { throw CancellationException() },
                { _, _ -> exchanged = true }, {})
        } catch (_: CancellationException) {}
        assertFalse(exchanged)
        flow.run({ false }, { "mock" }, { _, _ -> exchanged = true }, {})
        assertTrue(exchanged)
    }

    @Test fun logoutOrScreenDisposalDuringExchangeDiscardsResult() = runTest {
        val flow = GoogleSignInFlow()
        val response = CompletableDeferred<String>()
        var committed = false
        val job = launch {
            flow.run({ false }, { "mock" }, { _, _ -> response.await() }, { committed = true })
        }
        runCurrent()
        flow.invalidate()
        response.complete("old-session")
        job.join()
        assertFalse(committed)
    }

    @Test fun accountChangeDuringPickerPreventsExchange() = runTest {
        var hasSession = false
        var exchanged = false
        try {
            GoogleSignInFlow().run(
                { hasSession },
                { hasSession = true; "mock" },
                { _, _ -> exchanged = true }, {},
            )
        } catch (_: CancellationException) {}
        assertFalse(exchanged)
    }

    @Test fun duplicateAttemptIsIgnoredAndOldFinallyCannotResetNewAttempt() = runTest {
        val flow = GoogleSignInFlow()
        val pending = CompletableDeferred<String>()
        val first = launch { flow.run({ false }, { pending.await() }, { _, _ -> Unit }, {}) }
        runCurrent()
        var secondCalled = false
        try {
            flow.run({ false }, { secondCalled = true; "mock" }, { _, _ -> Unit }, {})
        } catch (_: CancellationException) {}
        assertFalse(secondCalled)
        flow.invalidate()
        first.cancel()
        first.join()
        flow.run({ false }, { secondCalled = true; "fresh" }, { _, _ -> Unit }, {})
        assertTrue(secondCalled)
    }

    @Test fun deletionResponseAcceptsAppleFlagAndAdditionalFieldsWithoutInvokingAnything() {
        val json = Json { ignoreUnknownKeys = true }
        for (manual in listOf(true, false)) {
            val response = json.decodeFromString<AccountDeletionResponse>(
                """{"success":true,"deletedImageCount":0,"appleManualRevocationRequired":$manual}"""
            )
            assertTrue(response.success)
            assertEquals(manual, response.appleManualRevocationRequired)
        }
        assertFalse(json.decodeFromString<AccountDeletionResponse>("""{"success":false}""").success)
    }

    private fun hash(raw: String) = MessageDigest.getInstance("SHA-256")
        .digest(raw.toByteArray()).joinToString("") { "%02x".format(it.toInt() and 0xff) }
}
