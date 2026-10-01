package com.cbtipul.app.data

import kotlinx.coroutines.delay
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import org.junit.Assert.*
import org.junit.Test
import java.io.IOException

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class AppVersionManagerTest {
    private fun policy(latest: Long = 5, minimum: Long = 3, platform: String = "android", url: String = "https://play.google.com/store/apps/details?id=test") =
        AppVersionPolicy(platform, latest, minimum, "1.0.10", url)
    @Test fun buildDecisions() {
        assertEquals(AppVersionDecision.Current, AppVersionDecision.evaluate(5, policy(minimum = 5), "android"))
        assertEquals(AppVersionDecision.Optional, AppVersionDecision.evaluate(4, policy(), "android"))
        assertEquals(AppVersionDecision.Required, AppVersionDecision.evaluate(2, policy(), "android"))
        assertEquals(AppVersionDecision.Current, AppVersionDecision.evaluate(6, policy(), "android"))
        assertEquals(AppVersionDecision.Current, AppVersionDecision.evaluate(0, policy(), "android"))
    }
    @Test fun malformedPolicyFailsOpen() = runTest {
        listOf(policy(latest = 0), policy(minimum = 0), policy(minimum = 6), policy(platform = "ios"),
            policy(url = "http://example.com"), policy(url = "https:///"), policy(url = "bad url")).forEach { bad ->
            val manager = AppVersionManager(1, { bad }, { 0 }, {})
            manager.check(true)
            assertEquals(AppVersionDecision.Current, manager.state.value.decision)
            assertFalse(manager.state.value.checkingInitially)
        }
    }
    @Test fun networkAndDecodingFailureFailOpen() = runTest {
        for (fetch in listOf<suspend (String) -> AppVersionPolicy>(
            { throw IOException("offline") }, { Json.decodeFromString<AppVersionPolicy>("{}") })) {
            val manager = AppVersionManager(1, fetch, { 0 }, {})
            manager.check(true)
            assertEquals(AppVersionDecision.Current, manager.state.value.decision)
            assertFalse(manager.state.value.checkingInitially)
        }
    }
    @Test fun timeoutIsBoundedAndFailsOpen() = runTest {
        val manager = AppVersionManager(1, { delay(20_000); policy() }, { 0 }, {})
        manager.check(true)
        assertEquals(4_000, testScheduler.currentTime)
        assertEquals(AppVersionDecision.Current, manager.state.value.decision)
        assertFalse(manager.state.value.checkingInitially)
    }
    @Test fun failureClearsRequiredGate() = runTest {
        var fail = false
        val manager = AppVersionManager(1, { if (fail) throw IOException(); policy() }, { 0 }, {})
        manager.check(true)
        assertEquals(AppVersionDecision.Required, manager.state.value.decision)
        fail = true
        manager.check()
        assertEquals(AppVersionDecision.Current, manager.state.value.decision)
        assertNull(manager.state.value.policy)
    }
    @Test fun dismissalSurvivesOwnerRecreationNewBuildPromptsAndRequiredOverrides() = runTest {
        var saved = 0L
        var remote = policy()
        fun manager() = AppVersionManager(4, { remote }, { saved }, { saved = it })
        val first = manager()
        first.check(true)
        assertTrue(first.state.value.optionalVisible)
        first.dismissOptional()
        assertEquals(5L, saved)
        val next = manager()
        next.check(true)
        assertFalse(next.state.value.optionalVisible)
        remote = policy(latest = 6)
        next.check(true)
        assertTrue(next.state.value.optionalVisible)
        next.dismissOptional()
        remote = policy(latest = 6, minimum = 5)
        next.check(true)
        assertEquals(AppVersionDecision.Required, next.state.value.decision)
    }
    @Test fun foregroundTimingRequiredBypassAndCorrectPlatform() = runTest {
        var now = 100_000L
        var calls = 0
        var remote = policy()
        val manager = AppVersionManager(5, { platform -> assertEquals("android", platform); calls++; remote }, { 0 }, {}, { now })
        manager.check(true)
        now += 60_000
        manager.check()
        assertEquals(1, calls)
        now += AppVersionManager.REFRESH_MS
        manager.check()
        assertEquals(2, calls)
        remote = policy(latest = 8, minimum = 7)
        manager.check(true)
        manager.check()
        assertEquals(4, calls)
        remote = policy()
        manager.check()
        assertEquals(AppVersionDecision.Current, manager.state.value.decision)
    }
    @Test fun backendURLAndPublicPlatformBody() = runTest {
        val supplied = "https://play.google.com/custom-backend-listing"
        val manager = AppVersionManager(1, { policy(url = supplied) }, { 0 }, {})
        manager.check(true)
        assertEquals(supplied, manager.state.value.policy?.storeUrl)
        assertEquals("{\"platform\":\"android\"}", AppVersionService.requestBody("android"))
    }
}
