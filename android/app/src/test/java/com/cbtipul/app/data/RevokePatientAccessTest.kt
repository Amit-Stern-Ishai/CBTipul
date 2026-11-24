package com.cbtipul.app.data

import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

class RevokePatientAccessTest {
    @Test fun exactPhraseAndAcknowledgements() {
        assertTrue(RevokePatientAccess.matches(" \nהפסקת גישה\t"))
        listOf("", "הפסקת", "הפסקת  גישה", "הפסקת גישה!").forEach { assertFalse(RevokePatientAccess.matches(it)) }
        assertTrue(RevokePatientAccess.confirmed("access_revoked"))
        assertTrue(RevokePatientAccess.confirmed("already_disconnected"))
        assertFalse(RevokePatientAccess.confirmed("ok"))
    }
    @Test fun resumeRechecksWithinCooldownAndKeepsIdentity() = runBlocking {
        var calls = 0
        val repo = AppContextRepository(AppContextDependencies(awaitInitialization = {}, identity = { "patient-account" }, request = {
            calls++
            AppContext(role = AppRole.Patient, activation = if (calls == 1) PatientActivation.Active else PatientActivation.Incomplete, patientId = if (calls == 1) "profile" else null)
        }, refreshSession = {}, retryDelaysMillis = emptyList()))
        repo.getCurrentAppContext()
        assertTrue(repo.current.value!!.isActivePatient)
        PatientHomeCache.read("patient-account:profile")
        PatientHomeCache.save("patient-account:profile", PatientHomeSnapshot(assignments = emptyList()))
        repo.suspendPatientAccess()
        assertNull(repo.current.value)
        assertNull(PatientHomeCache.read("patient-account:profile").assignments)
        repo.refreshOnForeground()
        assertEquals(2, calls)
        assertTrue(repo.current.value!!.isIncompletePatient)
        assertEquals("patient-account", repo.boundIdentity)
        repo.clear()
    }
    @Test fun failedResumeCannotShowCachedProfile() = runBlocking {
        var fails = false
        val repo = AppContextRepository(AppContextDependencies(awaitInitialization = {}, identity = { "patient-account" }, request = {
            if (fails) throw java.io.IOException()
            AppContext(role = AppRole.Patient, activation = PatientActivation.Active, patientId = "profile")
        }, refreshSession = {}, retryDelaysMillis = emptyList()))
        repo.getCurrentAppContext()
        fails = true
        repo.refreshOnForeground()
        assertNull(repo.current.value)
        assertTrue(repo.loadState.value is AppContextLoadState.Failed)
        assertEquals("patient-account", repo.boundIdentity)
        repo.clear()
    }
}
