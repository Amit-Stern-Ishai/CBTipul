package com.cbtipul.app.data

import org.junit.Assert.*
import org.junit.Test
import java.nio.file.Files

class DiscoveryReminderTest {
    private val day = 86_400_000L
    @Test fun cooldownNeedsActionAndNeverThirdAcrossPatients() {
        var clock = 1000L
        val file = Files.createTempDirectory("reminder").resolve("state.json").toFile()
        val ledger = DiscoveryLedger(file) { clock }
        ledger.enterContext("screen")
        val types = listOf("invite", "voice", "web", "SecondSession", "DiaryOne", "DiaryTwo")
        types.forEach { ledger.enqueue("a", it, "p"); ledger.presented(ledger.pending.value.first { p -> p.feature == it }) }
        clock += 3 * day - 1
        ledger.enqueue("a", "invite", "q")
        assertTrue(ledger.pending.value.isEmpty())
        clock++
        assertTrue(ledger.pending.value.isEmpty())
        assertTrue(ledger.eligible("a", "invite")); assertFalse(ledger.eligible("a", "web"))
        clock += 4 * day
        types.forEach {
            ledger.enqueue("a", it, "q")
            val reminder = ledger.pending.value.first { p -> p.feature == it }
            assertTrue(reminder.reminder)
            ledger.presented(reminder); ledger.presented(reminder)
            clock += 8 * day
            ledger.enqueue("a", it, "third")
            assertFalse(ledger.pending.value.any { p -> p.feature == it })
        }
        assertTrue(ledger.eligible("b", "web"))
        val restored = DiscoveryLedger(file) { clock }
        assertFalse(restored.eligible("a", "web"))
    }
    @Test fun completionSuppressionContextCollisionAndRelaunch() {
        var clock = 1000L
        val file = Files.createTempDirectory("reminder").resolve("state.json").toFile()
        val ledger = DiscoveryLedger(file) { clock }
        ledger.enterContext("p")
        listOf("web", "voice", "DiaryOne", "DiaryTwo").forEach { ledger.mark("a", it) }
        ledger.suppress("a", "web"); ledger.usedVoice("a")
        clock += 8 * day
        assertFalse(ledger.eligible("a", "web")); assertFalse(ledger.eligible("a", "voice"))
        ledger.enqueue("a", "DiaryOne", "p", standalone = true)
        ledger.enqueue("a", "DiaryTwo", "p", session = "session")
        assertEquals(2, ledger.pending.value.size)
        ledger.enterContext("q")
        assertTrue(ledger.pending.value.isEmpty()); assertTrue(ledger.eligible("a", "DiaryOne"))
        ledger.enqueue("a", "DiaryOne", "q")
        val restored = DiscoveryLedger(file) { clock }
        assertTrue(restored.pending.value.isEmpty()); assertTrue(restored.eligible("a", "DiaryOne"))
        assertFalse(restored.eligible("a", "web")); assertFalse(restored.eligible("a", "voice"))
        assertTrue(restored.eligible("b", "voice"))
    }
    @Test fun oldFlagMigratesWithoutImmediateReminderAndDoesNotResetOnRelaunch() {
        var clock = 1000L
        val file = Files.createTempDirectory("reminder").resolve("state.json").toFile()
        file.writeText("""{"shown":["discovery.DiaryOne.a"],"pending":[]}""")
        val ledger = DiscoveryLedger(file) { clock }
        assertTrue(ledger.seen("a", "DiaryOne")); assertFalse(ledger.eligible("a", "DiaryOne"))
        clock += 7 * day
        assertTrue(DiscoveryLedger(file) { clock }.eligible("a", "DiaryOne"))
    }
    @Test fun twoTriggerPathsConsumeOneBudget() {
        var clock = 0L
        val ledger = DiscoveryLedger(Files.createTempDirectory("reminder").resolve("state.json").toFile()) { clock }
        ledger.mark("a", "DiaryOne"); clock += 7 * day; ledger.enterContext("screen")
        ledger.enqueue("a", "DiaryOne", "p", standalone = true)
        ledger.enqueue("a", "DiaryOne", "p", session = "s")
        ledger.presented(ledger.pending.value.first())
        assertTrue(ledger.pending.value.isEmpty())
        assertFalse(ledger.eligible("a", "DiaryOne"))
    }
    @Test fun successfulSaveHandoffButManualNavigationDropsReminder() {
        var clock = 0L
        val ledger = DiscoveryLedger(Files.createTempDirectory("reminder").resolve("state.json").toFile()) { clock }
        ledger.mark("a", "web"); clock += 7 * day; ledger.enterContext("editor")
        ledger.enqueue("a", "web", "p")
        ledger.returnAfterSave("patient"); ledger.enterContext("patient")
        assertEquals(1, ledger.pending.value.size)
        ledger.enterContext("another-patient")
        assertTrue(ledger.pending.value.isEmpty()); assertTrue(ledger.eligible("a", "web"))
    }
    @Test fun reminderRevalidatesAfterFailureAndLaterEntryQualifies() = kotlinx.coroutines.runBlocking {
        var clock = 0L
        val ledger = DiscoveryLedger(Files.createTempDirectory("reminder").resolve("state.json").toFile()) { clock }
        ledger.mark("a", "DiaryOne"); clock += 7 * day; ledger.enterContext("screen")
        ledger.enqueue("a", "DiaryOne", "p", standalone = true)
        val intent = ledger.pending.value.single()
        try { DiscoveryRules.resolve(intent, { false }, { true }, { throw java.io.IOException() }, { false }); fail("Expected failure") } catch (_: java.io.IOException) { }
        assertEquals(1, ledger.pending.value.size)
        assertEquals(false, DiscoveryRules.resolve(intent, { false }, { true }, { true }, { false }))
        assertNull(DiscoveryRules.resolve(intent, { false }, { true }, { true }, { true }))
    }

}
