package com.cbtipul.app.data

import org.junit.Test
import org.junit.Assert.*
import java.nio.file.Files

class DiscoveryLedgerTest {
    private fun file() = Files.createTempDirectory("discovery-test").resolve("state.json").toFile()
    @Test fun sixPromptsAreOncePerAccountAcrossPatientsAndRelaunch() {
        val file = file(); val state = DiscoveryLedger(file)
        for (feature in listOf("invite", "voice", "web", "SecondSession", "DiaryOne", "DiaryTwo")) {
            state.enqueue("A", feature, "first")
            state.enqueue("a", feature, "second")
            assertFalse(state.seen("a", feature))
            state.mark("A", feature)
            state.enqueue("a", feature, "third")
            assertTrue(state.pending.value.none { it.feature == feature })
            assertFalse(state.seen("b", feature))
        }
        assertTrue(DiscoveryLedger(file).seen("a", "voice"))
        assertFalse(DiscoveryLedger(file()).seen("a", "voice")) // Another device.
    }
    @Test fun saveFailureAndEligibilityFailureDoNotConsumeQueue() {
        val file = file(); val state = DiscoveryLedger(file)
        state.enqueue("a", "web", "p") // Valid manual save; response can fail.
        state.enqueue("a", "DiaryOne", "p", standalone = true)
        // No mark on failed lookup or account switch; disk recovery keeps both.
        val restored = DiscoveryLedger(file)
        assertEquals(listOf("web", "DiaryOne"), restored.pending.value.map { it.feature })
        assertTrue(restored.pending.value.none { it.account == "b" })
        restored.mark("a", "web")
        assertEquals(listOf("DiaryOne"), restored.pending.value.map { it.feature })
    }
    @Test fun bothDiaryPathsAndVariantsShareFlag() {
        for (kind in listOf("DiaryOne", "DiaryTwo")) {
            val state = DiscoveryLedger(file())
            state.enqueue("a", kind, "p", standalone = false)
            state.enqueue("a", kind, "q", standalone = true)
            state.mark("a", kind) // Connect shown. Dismiss also counts.
            state.enqueue("a", kind, "new-connected-patient")
            assertTrue(state.pending.value.isEmpty())
            assertFalse(state.seen("b", kind))
        }
    }
    @Test fun legacyPatientKeyMapsToAccountType() {
        val state = DiscoveryLedger(file())
        state.mark("A", DiscoveryRules.patientFeature("p", "DiaryOne"))
        assertTrue(state.seen("a", "DiaryOne"))
        assertTrue(state.seen("a", DiscoveryRules.patientFeature("q", "DiaryOne")))
        assertFalse(state.seen("b", "DiaryOne"))
        assertFalse(state.seen("a", "DiaryTwo"))
    }
    @Test fun failedPersistenceReportsFailureWithoutBlockingCurrentHint() {
        val directory = file().parentFile!!
        directory.delete(); directory.writeText("blocks directory creation")
        val state = DiscoveryLedger(java.io.File(directory, "state.json"))
        assertFalse(state.mark("a", "voice")) // Migration must retain its legacy flag.
        assertTrue(state.seen("a", "voice"))
    }
    @Test fun failedLookupRetriesSameIntentAndNeverMarksShown() = kotlinx.coroutines.runBlocking {
        val state = DiscoveryLedger(file())
        state.enqueue("a", "DiaryTwo", "p", standalone = true)
        val pending = state.pending.value.single()
        var calls = 0
        val connected: suspend () -> Boolean = { calls++; if (calls == 1) throw java.io.IOException(); true }
        try {
            DiscoveryRules.resolve(pending, { true }, { true }, connected, { false })
            fail("Expected lookup failure")
        } catch (_: java.io.IOException) { }
        assertEquals(pending, state.pending.value.single())
        assertFalse(state.seen("a", "DiaryTwo"))
        assertEquals(false, DiscoveryRules.resolve(pending, { true }, { true }, connected, { assertEquals(PatientMilestone.DiaryTwo, it); false }))
        assertEquals(2, calls)
        state.mark("a", pending.feature)
        assertTrue(state.pending.value.isEmpty())
    }
    @Test fun failedSaveWebDoesNotNeedSessionOrConnection() = kotlinx.coroutines.runBlocking {
        assertEquals(false, DiscoveryRules.resolve(DiscoveryIntent("a", "web", "p", session = "unsaved"),
            { false }, { false }, { throw java.io.IOException() }, { false }))
    }
    @Test fun collisionsSurviveAlreadyEnabledAndUnshownRemoval() {
        val state = DiscoveryLedger(file())
        val kinds = DiscoveryRules.sessionMilestones(com.cbtipul.app.model.SessionType.DiaryOne, 1, 2)
        assertEquals(listOf(PatientMilestone.DiaryOne, PatientMilestone.SecondSession), kinds)
        state.enqueue("a", "web", "p")
        kinds.forEach { state.enqueue("a", it.name, "p") }
        state.remove(state.pending.value.first { it.feature == "DiaryOne" }) // Already enabled.
        assertEquals(listOf("web", "SecondSession"), state.pending.value.map { it.feature })
        assertFalse(state.seen("a", "DiaryOne"))
        state.mark("a", "web")
        assertEquals("SecondSession", state.pending.value.single().feature)
    }
}
