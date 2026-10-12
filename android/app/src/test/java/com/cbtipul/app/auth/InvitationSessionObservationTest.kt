package com.cbtipul.app.auth

import org.junit.Assert.*
import org.junit.Test

class InvitationSessionObservationTest {
    @Test fun staleTherapistSnapshotCannotOverrideCurrentAnonymousPatient() {
        val therapist = AuthSession.SignedIn("mock@invalid", "therapist", false)
        val patient = AuthSession.SignedIn(null, "patient", true)
        assertEquals(patient, reconcileSessionObservation(therapist, patient))
        assertEquals(AuthSession.Loading, reconcileSessionObservation(therapist, null))
        assertEquals(therapist, reconcileSessionObservation(therapist, therapist))
    }
    @Test fun explicitLogoutAndInitializationStayIntact() {
        val patient = AuthSession.SignedIn(null, "patient", true)
        assertEquals(AuthSession.SignedOut, reconcileSessionObservation(AuthSession.SignedOut, patient))
        assertEquals(AuthSession.Loading, reconcileSessionObservation(AuthSession.Loading, patient))
    }
}
