package com.cbtipul.app.auth
import org.junit.Test
import org.junit.Assert.*
class AuthFailureCopyTest {
 @Test fun knownCodesAndSafeFallback() {
  assertTrue(authFailureCopy("invalid_credentials").contains("הסיסמה"))
  assertTrue(authFailureCopy("email_not_confirmed").contains("אומתה"))
  assertTrue(authFailureCopy("over_request_rate_limit").contains("המתינו"))
  assertTrue(authFailureCopy(null, true).contains("לאינטרנט"))
  assertEquals(authFailureCopy(null), authFailureCopy("raw-server-secret"))
  assertEquals(authFailureCopy(null), authFailureMessage(IllegalStateException("raw-server-secret")))
  assertFalse(authFailureMessage(java.io.IOException("private response")).contains("private"))
 }
}
