package com.cbtipul.app.ui.patients
import com.cbtipul.app.R
import kotlinx.coroutines.*
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.junit.Assert.*

class EmailInvitationFormTest {
    @Test fun addressIsOnlyFromConfirmedSaveAndNeverReconstructedOnReopen() = runTest {
        val form = EmailInvitationFormState()
        form.load({ true }) { "no_invitation" }
        form.edit("first@example.invalid")
        form.submit({ true }) { "waiting_for_sign_in" }
        assertEquals("first@example.invalid", form.confirmedEmail)
        form.correct(); form.edit("replacement@example.invalid")
        form.submit({ true }) { throw java.io.IOException() }
        assertEquals("first@example.invalid", form.confirmedEmail)
        form.submit({ true }) { "waiting_for_confirmation" }
        assertEquals("replacement@example.invalid", form.confirmedEmail)
        form.load({ true }) { "pending" }
        assertNull(form.confirmedEmail)
        form.correct(); form.edit("unrelated@example.invalid")
        form.submit({ true }) { "already_connected" }
        assertNull(form.confirmedEmail)
    }

    @Test fun genericShareOnlyForConfirmedPending() = runTest {
        assertEquals("הוזמנת להשתמש ב־CBTipul. פתחו את האפליקציה והירשמו או התחברו עם כתובת המייל שמסרתם למטפל/ת.\n\nhttps://cbtipul.com/", EmailInvitationShare.text)
        val form = EmailInvitationFormState()
        assertFalse(form.canShare)
        form.load({ true }) { "pending" }; assertTrue(form.canShare)
        val before = form.pendingStatus
        val payload = EmailInvitationShare.text
        assertTrue(payload.endsWith("https://cbtipul.com/"))
        assertEquals(before, form.pendingStatus); assertTrue(form.canShare)
        for (status in listOf("waiting_for_sign_in", "waiting_for_confirmation")) {
            form.correct(); assertFalse(form.canShare)
            form.edit("synthetic@example.invalid")
            form.submit({ true }) { status }; assertTrue(form.canShare)
        }
        form.correct(); form.edit("synthetic@example.invalid")
        form.submit({ true }) { throw java.io.IOException() }; assertFalse(form.canShare)
        form.load({ true }) { "connected" }; assertFalse(form.canShare)
        form.load({ true }) { throw java.io.IOException() }; assertFalse(form.canShare)
    }

    @Test fun reopenedStatusComesFromServerAndReadFailuresBlockForm() = runTest {
        val form = EmailInvitationFormState()
        form.load({ true }) { "pending" }
        assertTrue(form.canCorrect); assertTrue(form.confirmed)
        assertEquals("", form.email); assertFalse(form.loadFailed)
        form.correct(); assertEquals("", form.email)
        form.load({ true }) { throw java.io.IOException() }
        assertTrue(form.loadFailed); assertEquals("pending", form.pendingStatus)
        form.load({ true }) { "connected" }
        assertFalse(form.canCorrect); assertTrue(form.confirmed)
        form.load({ true }) { "no_invitation" }
        assertNull(form.pendingStatus); assertFalse(form.confirmed)
        form.load({ true }) { "unknown" }
        assertTrue(form.loadFailed)
    }
    @Test fun lateStatusCannotPublishIntoAnotherAccount() = runTest {
        val form = EmailInvitationFormState()
        var current = true
        form.load({ current }) { current = false; "pending" }
        assertNull(form.pendingStatus); assertFalse(form.confirmed)
    }
    @Test fun everyOutcomeVisibleAndSuccessCannotResubmitUntilEdited() = runTest {
        for (outcome in listOf("waiting_for_confirmation", "waiting_for_sign_in", "already_connected", "email_unavailable", "unknown")) {
            val form = EmailInvitationFormState(); form.edit("synthetic@example.invalid")
            var calls = 0
            form.submit({ true }) { calls++; outcome }
            assertEquals(emailInvitationResult(outcome), form.message)
            assertFalse(form.saving)
            assertEquals("synthetic@example.invalid", form.email)
            val success = outcome.startsWith("waiting_") || outcome == "already_connected"
            assertEquals(success, form.confirmed)
            if (success) { form.submit({ true }) { calls++; outcome }; assertEquals(1,calls) }
            form.edit("corrected@example.invalid")
            assertNull(form.message); assertFalse(form.confirmed)
        }
    }
    @Test fun pendingDisablesDuplicatesAndRetainsInputAfterNetworkFailure() = runTest {
        val form = EmailInvitationFormState(); form.edit("synthetic@example.invalid")
        val pending = CompletableDeferred<Unit>(); var calls = 0
        val job = launch { form.submit({ true }) { calls++; pending.await(); throw java.io.IOException() } }
        yield(); assertTrue(form.saving)
        form.submit({ true }) { calls++; "waiting_for_sign_in" }
        assertEquals(1,calls)
        pending.complete(Unit); job.join()
        assertFalse(form.saving); assertEquals(R.string.email_invitation_network_failed,form.message)
        assertEquals("synthetic@example.invalid",form.email)
        form.submit({ true }) { "waiting_for_sign_in" }
        assertTrue(form.confirmed)
    }
    @Test fun emptyValidationSendsNothingAndOldAccountCannotPublish() = runTest {
        val form=EmailInvitationFormState()
        form.submit({true}) { error("must not send") }
        assertEquals(R.string.email_invitation_invalid,form.message)
        form.edit("synthetic@example.invalid")
        var current=true
        form.submit({current}) { current=false; "waiting_for_confirmation" }
        assertNull(form.message); assertFalse(form.confirmed); assertFalse(form.saving)
    }
    @Test fun cancellationExitsBusyStateWithoutInventingSuccess() = runTest {
        val form=EmailInvitationFormState(); form.edit("synthetic@example.invalid")
        try { form.submit({true}) { throw CancellationException() } } catch (_: CancellationException) {}
        assertFalse(form.saving); assertFalse(form.confirmed)
        assertEquals("synthetic@example.invalid",form.email)
    }
    @Test fun correctionStartsEmptyAndPreservesPendingUntilConfirmed() = runTest {
        for (original in listOf("waiting_for_sign_in", "waiting_for_confirmation")) {
            val form = EmailInvitationFormState(); form.edit("old@example.invalid")
            form.submit({true}) { original }
            assertTrue(form.canCorrect)
            form.correct(); assertEquals("", form.email); assertFalse(form.confirmed)
            assertEquals(original, form.pendingStatus)
            form.edit("new@example.invalid")
            form.submit({true}) { "email_unavailable" }
            assertEquals(original, form.pendingStatus); assertEquals("new@example.invalid", form.email)
            assertFalse(form.confirmed)
            form.submit({true}) { throw java.io.IOException() }
            assertEquals(original, form.pendingStatus); assertEquals("new@example.invalid", form.email)
            form.submit({true}) { "waiting_for_sign_in" }
            assertTrue(form.confirmed); assertEquals("waiting_for_sign_in", form.pendingStatus)
            form.correct(); form.edit("other@example.invalid")
            form.submit({true}) { "already_connected" }
            assertFalse(form.canCorrect); assertTrue(form.confirmed)
        }
    }
    @Test fun conflictUsesResponseCodeNotJustStatus() {
        val code = com.cbtipul.app.data.EdgePayload.codeAndMessage("""{"error":"patient_profile_already_connected"}""").first
        assertEquals(R.string.email_invitation_profile_connected, emailInvitationFailure(409, code, false))
        assertEquals(R.string.email_invitation_failed, emailInvitationFailure(409, "other", false))
        assertEquals(R.string.email_invitation_unavailable, emailInvitationFailure(409, "email_unavailable", false))
        assertEquals(R.string.email_invitation_connected, emailInvitationResult("already_connected"))
        assertEquals(R.string.email_invitation_waiting_sign_in, emailInvitationResult("waiting_for_sign_in"))
    }
    @Test fun errorsUseActionableMessages() {
        assertEquals(R.string.email_invitation_auth_failed,emailInvitationFailure(401,"",false))
        assertEquals(R.string.email_invitation_forbidden,emailInvitationFailure(403,"",false))
        assertEquals(R.string.email_invitation_invalid,emailInvitationFailure(422,"",false))
        assertEquals(R.string.email_invitation_unavailable,emailInvitationFailure(400,"email_unavailable",false))
        assertEquals(R.string.email_invitation_failed,emailInvitationFailure(500,"",false))
    }
}
