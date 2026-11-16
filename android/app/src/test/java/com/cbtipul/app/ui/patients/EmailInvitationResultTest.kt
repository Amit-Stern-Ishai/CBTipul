package com.cbtipul.app.ui.patients
import com.cbtipul.app.R
import org.junit.Test
import org.junit.Assert.assertEquals
class EmailInvitationResultTest {
 @Test fun serverStatusesAndUnknownResult() {
  assertEquals(R.string.email_invitation_waiting_sign_in, emailInvitationResult("waiting_for_sign_in"))
  assertEquals(R.string.email_invitation_waiting_confirmation, emailInvitationResult("waiting_for_confirmation"))
  assertEquals(R.string.email_invitation_connected, emailInvitationResult("already_connected"))
  assertEquals(R.string.email_invitation_unavailable, emailInvitationResult("email_unavailable"))
  assertEquals(R.string.email_invitation_failed, emailInvitationResult("unknown"))
 }
}
