package com.cbtipul.app.auth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AuthSessionVisibilityTest {
    @Test
    fun treatAsSignedOutDoesNotHideAnonymousPatientSession() {
        val anonymous = AuthSession.SignedIn(email = null, userId = "anon-1", isAnonymous = true)
        val visible = effectiveAuthSession(anonymous, treatAsSignedOut = true)
        assertEquals(anonymous, visible)
        assertTrue((visible as AuthSession.SignedIn).isAnonymous)
    }

    @Test
    fun treatAsSignedOutHidesTherapistSession() {
        val therapist = AuthSession.SignedIn(email = "a@b.c", userId = "t-1", isAnonymous = false)
        assertEquals(
            AuthSession.SignedOut,
            effectiveAuthSession(therapist, treatAsSignedOut = true),
        )
    }

    @Test
    fun noSessionOnLaunchIsSignedOut() {
        assertEquals(
            AuthSession.SignedOut,
            effectiveAuthSession(AuthSession.SignedOut, treatAsSignedOut = false),
        )
    }

    @Test
    fun anonymousSessionWithoutTreatAsSignedOutStaysSignedIn() {
        val anonymous = AuthSession.SignedIn(email = null, userId = "anon-1", isAnonymous = true)
        assertEquals(anonymous, effectiveAuthSession(anonymous, treatAsSignedOut = false))
    }
}
