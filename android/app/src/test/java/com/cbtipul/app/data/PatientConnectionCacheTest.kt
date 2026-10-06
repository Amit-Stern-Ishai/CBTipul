package com.cbtipul.app.data

import org.junit.Assert.*
import org.junit.Test

class PatientConnectionCacheTest {
    @Test fun restoresBothConnectedAndDisconnectedAcrossRepositoryRecreation() {
        val disk = mutableMapOf<String, Boolean>()
        fun cache() = PatientConnectionCache(read = { disk[it] }, write = { key, value -> disk[key] = value })
        cache().apply {
            store("account", "connected", true)
            store("account", "disconnected", false)
        }
        val restored = cache()
        assertEquals(true, restored.value("account", "connected"))
        assertEquals(false, restored.value("account", "disconnected"))
        assertNull(restored.value("another-account", "connected"))
        assertNull(restored.value("account", "another-patient"))
        assertNull(restored.value(null, "connected"))
        restored.store("account", "connected", false)
        assertEquals(false, cache().value("account", "connected"))
    }

    @Test fun diskFailureDoesNotDiscardFreshStatus() {
        val cache = PatientConnectionCache(read = { error("unavailable") }, write = { _, _ -> error("unavailable") })
        assertNull(cache.value("account", "patient"))
        cache.store("account", "patient", true)
        assertEquals(true, cache.value("account", "patient"))
    }
}
