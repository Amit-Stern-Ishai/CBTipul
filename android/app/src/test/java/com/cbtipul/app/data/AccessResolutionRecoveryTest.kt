package com.cbtipul.app.data

import com.cbtipul.app.auth.AuthContextSession
import java.io.IOException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.After
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AccessResolutionRecoveryTest {
    @After fun reset() = Entitlements.clear()
    private val full = AppContext(role = AppRole.Therapist, entitlement = AppEntitlement(EntitlementAccess.Full))
    private val readOnly = AppContext(role = AppRole.Therapist, entitlement = AppEntitlement(EntitlementAccess.ReadOnly))

    @Test fun unresolvedLoadingAndFailedNeverMeanReadOnlyOrAllowRemoteWrites() {
        Entitlements.setIdentity("user")
        for (state in listOf(AppContextLoadState.Unresolved, AppContextLoadState.Loading(1),
                AppContextLoadState.Failed(AppContextFailure.Connection), AppContextLoadState.Failed(AppContextFailure.MissingEntitlement))) {
            val presentation = accessResolutionPresentation("user", Entitlements.state.value, state)
            assertNotEquals(AccessResolutionPresentation.ReadOnly, presentation)
            assertNotEquals(AccessResolutionPresentation.Full, presentation)
            assertFalse(Entitlements.canUseAI); assertFalse(Entitlements.canPatientWrite)
            assertFalse(Entitlements.allowMutation(allowLocalDemo = false))
        }
        Entitlements.apply(readOnly)
        assertEquals(AccessResolutionPresentation.ReadOnly, accessResolutionPresentation("user", Entitlements.state.value, AppContextLoadState.Ready))
        assertFalse(Entitlements.canWrite)
        assertEquals(AccessResolutionPresentation.Loading, accessResolutionPresentation("other", Entitlements.state.value, AppContextLoadState.Ready))
    }

    @Test fun transientFailureRetriesAutomaticallyAndRecoversWithoutRestart() = runTest {
        var calls = 0
        val repo = AppContextRepository(AppContextDependencies({}, { "user" }, {
            calls++; if (calls < 3) throw IOException("mock network unavailable")
            full
        }, {}))
        val task = launch { repo.getCurrentAppContext() }
        runCurrent()
        assertEquals(1, calls); assertFalse(Entitlements.canWrite)
        assertTrue(repo.loadState.value is AppContextLoadState.Loading)
        advanceUntilIdle(); task.join()
        assertEquals(3, calls); assertTrue(Entitlements.canWrite)
        assertEquals(AppContextLoadState.Ready, repo.loadState.value)
    }

    @Test fun retryBudgetIsBoundedAndExplicitRetryGetsAFreshBudget() = runTest {
        var calls = 0; var available = false
        val repo = AppContextRepository(AppContextDependencies({}, { "user" }, {
            calls++; if (!available) throw IOException("mock offline")
            full
        }, {}))
        val task = launch { runCatching { repo.getCurrentAppContext() } }
        advanceUntilIdle(); task.join()
        assertEquals(3, calls)
        assertEquals(AppContextLoadState.Failed(AppContextFailure.Connection), repo.loadState.value)
        assertFalse(Entitlements.canWrite); assertFalse(repo.isLoading.value)
        available = true; repo.getCurrentAppContext()
        assertEquals(4, calls); assertTrue(Entitlements.canWrite)
    }

    @Test fun requestTimeoutIsBoundedAndRecoverable() = runTest {
        var calls = 0
        val repo = AppContextRepository(AppContextDependencies({}, { "user" }, {
            calls++; CompletableDeferred<AppContext>().await()
        }, {}, timeoutMillis = 100, retryDelaysMillis = listOf(10, 20)))
        val task = launch { runCatching { repo.getCurrentAppContext() } }
        advanceUntilIdle(); task.join()
        assertEquals(3, calls)
        assertEquals(AppContextLoadState.Failed(AppContextFailure.Connection), repo.loadState.value)
        assertFalse(repo.isLoading.value); assertFalse(Entitlements.canWrite)
    }

    @Test fun sessionInitializationTimeoutDoesNotBecomeEmailUnverifiedOrReadOnly() = runTest {
        var calls = 0
        val repo = AppContextRepository(AppContextDependencies({ CompletableDeferred<Unit>().await() }, { "user" }, {
            calls++; full
        }, {}, timeoutMillis = 100))
        val task = launch { runCatching { repo.getCurrentAppContext() } }
        advanceUntilIdle(); task.join()
        assertEquals(0, calls)
        assertEquals(AppContextLoadState.Failed(AppContextFailure.SessionInitialization), repo.loadState.value)
        assertFalse(Entitlements.canWrite)
    }

    @Test fun missingEntitlementIsRecoverableAndNeverInventsAPlan() = runTest {
        var calls = 0
        val repo = AppContextRepository(AppContextDependencies({}, { "user" }, {
            calls++; if (calls == 1) full.copy(entitlement = null) else full
        }, {}))
        repo.getCurrentAppContext()
        assertEquals(AppContextLoadState.Failed(AppContextFailure.MissingEntitlement), repo.loadState.value)
        assertFalse(Entitlements.canWrite)
        repo.getCurrentAppContext()
        assertTrue(Entitlements.canWrite)
    }

    @Test fun failedRefreshBypassesSixtySecondForegroundCooldown() = runTest {
        var calls = 0; var failing = false
        val repo = AppContextRepository(AppContextDependencies({}, { "user" }, {
            calls++; if (failing) throw IOException("mock offline")
            full
        }, {}, nowMillis = { 100_000 }))
        repo.getCurrentAppContext()
        failing = true
        val failed = launch { runCatching { repo.getCurrentAppContext() } }
        advanceUntilIdle(); failed.join()
        assertEquals(4, calls); assertFalse(Entitlements.canWrite)
        failing = false; repo.refreshOnForeground()
        assertEquals(5, calls); assertTrue(Entitlements.canWrite)
    }

    @Test fun confirmedReadOnlyStaysReadOnlyAcrossRecovery() = runTest {
        var calls = 0
        val repo = AppContextRepository(AppContextDependencies({}, { "user" }, {
            calls++; if (calls == 1) throw IOException("mock transient")
            readOnly
        }, {}))
        val task = launch { repo.getCurrentAppContext() }
        advanceUntilIdle(); task.join()
        assertEquals(EntitlementAccess.ReadOnly, Entitlements.state.value.access)
        assertEquals(AppContextLoadState.Ready, repo.loadState.value)
        assertEquals(AccessResolutionPresentation.ReadOnly, accessResolutionPresentation("user", Entitlements.state.value, repo.loadState.value))
        assertFalse(Entitlements.canWrite)
    }

    @Test fun identityChangeDuringBackoffCannotRetryOrPublishOldAccount() = runTest {
        var identity = "old"; var calls = 0
        val repo = AppContextRepository(AppContextDependencies({}, { identity }, {
            calls++; if (identity == "old") throw IOException("mock transient")
            full
        }, {}))
        val old = launch { runCatching { repo.getCurrentAppContext() } }
        runCurrent(); assertEquals(1, calls)
        identity = "new"; repo.authenticationChanged(identity)
        val new = launch { repo.getCurrentAppContext() }
        advanceUntilIdle(); old.join(); new.join()
        assertEquals(2, calls); assertEquals("new", Entitlements.state.value.identity)
        assertTrue(Entitlements.canWrite)
    }

    @Test fun sameAccountReauthenticationTriggersRecoveryDespiteEqualUiIdentity() = runTest {
        var calls = 0
        val repo = AppContextRepository(AppContextDependencies({}, { "user" }, { calls++; full }, {}))
        val sessions = MutableStateFlow<AuthContextSession?>(AuthContextSession("user", 1))
        val invitation = MutableStateFlow(false)
        repo.bindAuthentication(backgroundScope, sessions, invitation)
        runCurrent(); assertEquals(1, calls)
        sessions.value = AuthContextSession("user", 2)
        runCurrent(); assertEquals(2, calls); assertTrue(Entitlements.canWrite)
    }

    @Test fun coordinatorDefersToInvitationAndKeepsItsFreshActivationContext() = runTest {
        var identity = "therapist"; var calls = 0
        val active = AppContext(role = AppRole.Patient, activation = PatientActivation.Active,
            patientId = "patient", entitlement = AppEntitlement(EntitlementAccess.Full))
        val repo = AppContextRepository(AppContextDependencies({}, { identity }, { calls++; if (identity == "therapist") full else active }, {}))
        val sessions = MutableStateFlow<AuthContextSession?>(AuthContextSession(identity, 1))
        val invitation = MutableStateFlow(true)
        repo.bindAuthentication(backgroundScope, sessions, invitation)
        runCurrent(); assertEquals(0, calls)
        identity = "anonymous"; sessions.value = AuthContextSession(identity, 2)
        runCurrent(); repo.clear(); repo.getCurrentAppContext()
        assertEquals(active, repo.current.value)
        invitation.value = false; runCurrent()
        assertEquals(1, calls); assertEquals(active, repo.current.value)
        assertTrue(Entitlements.canPatientWrite)
    }

    @Test fun tokenRefreshDuringRequestDoesNotResetRetryBudgetOrCancelRecovery() = runTest {
        val pending = CompletableDeferred<AppContext>(); var calls = 0
        val repo = AppContextRepository(AppContextDependencies({}, { "user" }, { calls++; pending.await() }, {}))
        val sessions = MutableStateFlow<AuthContextSession?>(AuthContextSession("user", 1))
        repo.bindAuthentication(backgroundScope, sessions, MutableStateFlow(false))
        runCurrent(); assertEquals(1, calls)
        sessions.value = AuthContextSession("user", 2, true)
        runCurrent(); assertEquals(1, calls)
        pending.complete(full); runCurrent()
        assertTrue(Entitlements.canWrite); assertEquals(AppContextLoadState.Ready, repo.loadState.value)
    }

    @Test fun coordinatorRejectsLateOldAccountResults() = runTest {
        val oldResponse = CompletableDeferred<AppContext>(); var identity = "old"; var calls = 0
        val repo = AppContextRepository(AppContextDependencies({}, { identity }, {
            calls++; if (identity == "old") oldResponse.await() else readOnly
        }, {}))
        val sessions = MutableStateFlow<AuthContextSession?>(AuthContextSession("old", 1))
        repo.bindAuthentication(backgroundScope, sessions, MutableStateFlow(false))
        runCurrent(); identity = "new"; sessions.value = AuthContextSession("new", 2)
        runCurrent(); oldResponse.complete(full); runCurrent()
        assertEquals("new", Entitlements.state.value.identity)
        assertEquals(EntitlementAccess.ReadOnly, Entitlements.state.value.access)
        assertFalse(Entitlements.canWrite)
    }

    @Test fun transientClassifierDoesNotRetryBusinessFailuresOrCancellation() {
        assertTrue(transientContextFailure(IOException("fixture")))
        assertFalse(transientContextFailure(IllegalArgumentException("fixture bad contract")))
        assertFalse(transientContextFailure(kotlinx.coroutines.CancellationException()))
    }
}
