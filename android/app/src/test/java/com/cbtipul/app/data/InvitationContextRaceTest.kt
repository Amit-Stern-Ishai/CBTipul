package com.cbtipul.app.data

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class InvitationContextRaceTest {
    @Test fun clearInvalidatesStaleContextIncludingSameIdentity() = runTest {
        for (sameIdentity in listOf(false, true)) {
            val gate = CompletableDeferred<Unit>()
            var identity = if (sameIdentity) "patient" else "therapist"
            var calls = 0
            val active = AppContext(role = AppRole.Patient, activation = PatientActivation.Active, patientId = "patient")
            val context = AppContextRepository(AppContextDependencies({}, { identity }, {
                calls++
                if (calls == 1) {
                    gate.await()
                    AppContext(role = if (sameIdentity) AppRole.Patient else AppRole.Therapist, activation = PatientActivation.Incomplete)
                } else active
            }, {}))
            val old = launch { runCatching { context.getCurrentAppContext() } }
            runCurrent(); context.clear(); identity = "patient"
            val new = launch { context.getCurrentAppContext() }
            gate.complete(Unit); runCurrent(); old.join(); new.join()
            assertEquals(active, context.current.value); assertFalse(context.isLoading.value)
            Entitlements.clear()
        }
    }
}
