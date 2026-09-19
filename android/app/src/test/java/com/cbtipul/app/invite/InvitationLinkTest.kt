package com.cbtipul.app.invite

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class InvitationLinkTest {
    @Test
    fun extractsTokenFromCanonicalUrl() {
        assertEquals(
            "opaque-token",
            InvitationLink.tokenFrom("https", "cbtipul.com", "/invite/opaque-token"),
        )
    }

    @Test
    fun rejectsEmptyToken() {
        assertNull(InvitationLink.tokenFrom("https", "cbtipul.com", "/invite/"))
        assertNull(InvitationLink.tokenFrom("https", "cbtipul.com", "/invite"))
    }

    @Test
    fun rejectsNonHttpsOrWrongHost() {
        assertNull(InvitationLink.tokenFrom("http", "cbtipul.com", "/invite/abc"))
        assertNull(InvitationLink.tokenFrom("https", "www.cbtipul.com", "/invite/abc"))
        assertNull(InvitationLink.tokenFrom("cbtipul", "auth-callback", "/invite/abc"))
    }
}
