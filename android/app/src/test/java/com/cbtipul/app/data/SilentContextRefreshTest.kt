package com.cbtipul.app.data
import org.junit.Test
import org.junit.Assert.*
import kotlinx.coroutines.test.runTest
class SilentContextRefreshTest {
 @Test fun tokenRefreshKeepsRouteAndFailureBlocksWrites() = runTest {
  var owner: String? = "first"; var fail = false
  val context = AppContext(role = AppRole.Therapist, entitlement = AppEntitlement(EntitlementAccess.Full))
  val repo = AppContextRepository(AppContextDependencies(awaitInitialization = {}, identity = { owner }, request = { if (fail) error("synthetic failure"); context }, refreshSession = {}, retryDelaysMillis = emptyList()))
  repo.getCurrentAppContext()
  repo.authenticationChanged("first", tokenRefresh = true)
  assertEquals(context, repo.current.value)
  fail = true
  runCatching { repo.getCurrentAppContext() }
  assertEquals(context, repo.current.value)
  assertFalse(Entitlements.canWrite)
  assertTrue(repo.loadState.value is AppContextLoadState.Failed)
  fail = false; repo.getCurrentAppContext(); assertTrue(Entitlements.canWrite)
  owner = "second"; repo.authenticationChanged(owner)
  assertNull(repo.current.value); assertFalse(Entitlements.canWrite)
  owner = null; repo.authenticationChanged(null)
  assertNull(repo.current.value)
  Entitlements.clear()
 }
}
