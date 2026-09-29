package com.cbtipul.app.data

import org.junit.Assert.*
import org.junit.Test

class AssignmentStatusCacheTest {
    @Test fun inactiveIsKnownAndSeparateFromNeverLoaded() {
        val cache = AssignmentStatusCache()
        assertNull(cache.value("therapist", "diary/patient"))
        cache.store(null, "therapist", "diary/patient")
        assertNotNull(cache.value("therapist", "diary/patient"))
        assertNull(cache.value("therapist", "diary/patient")?.assignmentId)
    }

    @Test fun cacheIsScopedToAccountPatientAndAssignmentKind() {
        val cache = AssignmentStatusCache()
        cache.store("active", "first", "patient/a/diary_one")
        assertNull(cache.value("second", "patient/a/diary_one"))
        assertNull(cache.value(null, "patient/a/diary_one"))
        assertNull(cache.value("first", "patient/b/diary_one"))
        assertNull(cache.value("first", "patient/a/diary_two"))
        cache.store("signed-out", null, "patient/a/diary_one")
        assertEquals("active", cache.value("first", "patient/a/diary_one")?.assignmentId)
    }

    @Test fun olderRefreshCannotUndoActivationOrCancellation() {
        val cache = AssignmentStatusCache()
        val beforeActivation = cache.revision("therapist", "diary")
        cache.store("new", "therapist", "diary")
        cache.store(null, "therapist", "diary", beforeActivation)
        assertEquals("new", cache.value("therapist", "diary")?.assignmentId)
        val beforeCancellation = cache.revision("therapist", "diary")
        cache.store(null, "therapist", "diary")
        cache.store("new", "therapist", "diary", beforeCancellation)
        assertNotNull(cache.value("therapist", "diary"))
        assertNull(cache.value("therapist", "diary")?.assignmentId)
    }

    @Test fun freshRefreshReplacesLastKnownState() {
        val cache = AssignmentStatusCache()
        cache.store("active", "therapist", "diary")
        val revision = cache.revision("therapist", "diary")
        cache.store(null, "therapist", "diary", revision)
        assertNull(cache.value("therapist", "diary")?.assignmentId)
    }
}
