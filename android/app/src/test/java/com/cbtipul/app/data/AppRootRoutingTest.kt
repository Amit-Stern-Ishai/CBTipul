package com.cbtipul.app.data

import org.junit.Assert.assertEquals
import org.junit.Test

class AppRootRoutingTest {
    @Test
    fun invitationTakesPriorityOverSessions() {
        assertEquals(
            AppRootDestination.Invitation,
            AppRootRouting.destination(
                invitationActive = true,
                hasSession = true,
                isAnonymous = false,
            ),
        )
        assertEquals(
            AppRootDestination.Invitation,
            AppRootRouting.destination(
                invitationActive = true,
                hasSession = true,
                isAnonymous = true,
            ),
        )
        assertEquals(
            AppRootDestination.Invitation,
            AppRootRouting.destination(
                invitationActive = true,
                hasSession = false,
                isAnonymous = false,
            ),
        )
    }

    @Test
    fun anonymousSessionIsPatientModeNotTherapist() {
        assertEquals(
            AppRootDestination.AnonymousPatient,
            AppRootRouting.destination(
                invitationActive = false,
                hasSession = true,
                isAnonymous = true,
            ),
        )
        assertEquals(
            AppRootDestination.Therapist,
            AppRootRouting.destination(
                invitationActive = false,
                hasSession = true,
                isAnonymous = false,
            ),
        )
        assertEquals(
            AppRootDestination.Unauthenticated,
            AppRootRouting.destination(
                invitationActive = false,
                hasSession = false,
                isAnonymous = false,
            ),
        )
    }

    @Test
    fun loadingContextIsNotTreatedAsDisconnected() {
        assertEquals(
            AnonymousPatientDestination.Loading,
            AppRootRouting.anonymousDestination(context = null, isLoading = true),
        )
        assertEquals(
            AnonymousPatientDestination.Retry,
            AppRootRouting.anonymousDestination(context = null, isLoading = false),
        )
        assertEquals(
            AnonymousPatientDestination.PatientMode,
            AppRootRouting.anonymousDestination(
                context = AppContext(
                    role = AppRole.Patient,
                    activation = PatientActivation.Active,
                    patientId = "patient-1",
                ),
                isLoading = true,
            ),
        )
        assertEquals(
            AnonymousPatientDestination.Incomplete,
            AppRootRouting.anonymousDestination(
                context = AppContext(
                    role = AppRole.Patient,
                    activation = PatientActivation.Incomplete,
                ),
                isLoading = false,
            ),
        )
    }
}
