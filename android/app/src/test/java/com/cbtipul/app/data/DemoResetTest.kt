package com.cbtipul.app.data

import com.cbtipul.app.model.DatabaseId
import io.github.jan.supabase.createSupabaseClient
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

class DemoResetTest {
    @org.junit.Before fun enableDemo() { Entitlements.setLocalDemo(true) }
    @org.junit.After fun leaveDemo() { Entitlements.clear() }
    @Test fun diaryResetRemovesDemoEntriesFromBothCaches() = runTest {
        val client = createSupabaseClient("https://example.invalid", "test") {}
        val patient = DatabaseId.Text("demo-reset-test")
        val one = DiaryOneRepository(client)
        val two = DiaryTwoRepository(client)
        val three = DiaryThreeRepository(client)
        one.createEntry(patient, "event", listOf("thought"), emptyList(), "behavior", null)
        two.createEntry(patient, "event", listOf("thought"), emptyList(), emptyList(), listOf("alternative"))
        three.createEntry(patient, "event", emptyList(), emptyList(), emptyList(), emptyList())
        assertEquals(1, one.entriesFor(patient).size)
        assertEquals(1, two.entriesFor(patient).size)
        assertEquals(1, three.entriesFor(patient).size)
        one.clearDemoContent(); two.clearDemoContent(); three.clearDemoContent()
        assertTrue(one.entriesFor(patient).isEmpty())
        assertTrue(two.entriesFor(patient).isEmpty())
        assertTrue(three.entriesFor(patient).isEmpty())
        // Reloading must not restore the backing demo map.
        assertTrue(one.loadEntries(patient).isEmpty())
        assertTrue(two.loadEntries(patient).isEmpty())
        assertTrue(three.loadEntries(patient).isEmpty())
        client.close()
    }
}
