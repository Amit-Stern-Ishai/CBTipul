package com.cbtipul.app.ui.patient
import org.junit.Test
import org.junit.Assert.*
import kotlinx.coroutines.test.runTest
class PatientAccountDeletionTest {
 @Test fun strictReceipt() {
  fun validate(status: Int, body: String) = com.cbtipul.app.auth.validatePatientDeletionReceipt(status, kotlinx.serialization.json.Json.parseToJsonElement(body) as kotlinx.serialization.json.JsonObject)
  validate(200, "{\"deleted\":true}")
  for (body in listOf("{\"deleted\":false}", "{\"deleted\":\"true\"}", "{}")) assertTrue(runCatching { validate(200, body) }.isFailure)
  assertTrue(runCatching { validate(202, "{\"deleted\":true}") }.isFailure)
 }
 @Test fun rejectionAndUnauthorizedDoNotReset() = runTest {
  for (code in listOf(401, 403, 422)) {
   var resets = 0
   val m = PatientAccountDeletion({ "patient" }, { throw java.io.IOException() }, {}, { resets++ }, { code })
   m.ask(); m.confirm(); assertEquals(0, resets)
   assertEquals(if (code == 401) PatientAccountDeletion.State.SessionUnverified else PatientAccountDeletion.State.Rejected, m.state)
  }
 }
 @Test fun cancellationAndSuccess() = runTest {
  var calls = 0; var resets = 0
  val m = PatientAccountDeletion({ "patient" }, { calls++ }, {}, { resets++ })
  m.ask(); m.cancel(); m.confirm(); assertEquals(0, calls)
  m.ask(); m.confirm(); m.confirm(); assertEquals(1, calls); assertEquals(1, resets)
  assertEquals(PatientAccountDeletion.State.Deleted, m.state)
 }
 @Test fun uncertaintyRequiresCheck() = runTest {
  var calls = 0; var resets = 0
  val m = PatientAccountDeletion({ "patient" }, { calls++; throw java.io.IOException() }, {}, { resets++ })
  m.ask(); m.confirm(); m.ask(); m.confirm(); assertEquals(1, calls); assertEquals(0, resets)
  m.recheck(); assertEquals(PatientAccountDeletion.State.Retryable, m.state)
  m.ask(); m.confirm(); assertEquals(2, calls)
 }
 @Test fun failedCheckDoesNotEnableRetry() = runTest {
  val m = PatientAccountDeletion({ "patient" }, { throw java.io.IOException() }, { throw java.io.IOException() }, { error("must not clear") })
  m.ask(); m.confirm(); m.recheck(); m.ask(); assertEquals(PatientAccountDeletion.State.SessionUnverified, m.state)
 }
 @Test fun accountSwitchIgnoresResponse() = runTest {
  var owner = "first"; var resets = 0
  val m = PatientAccountDeletion({ owner }, { owner = "second" }, {}, { resets++ })
  m.ask(); m.confirm(); assertEquals(0, resets)
 }
}
