package com.cbtipul.app.data

enum class AppRootDestination {
    Invitation,
    Therapist,
    AnonymousPatient,
    Unauthenticated,
}

enum class AnonymousPatientDestination {
    Loading,
    PatientMode,
    Incomplete,
    Retry,
}

object AppRootRouting {
    fun destination(
        invitationActive: Boolean,
        hasSession: Boolean,
        isAnonymous: Boolean,
    ): AppRootDestination {
        if (invitationActive) return AppRootDestination.Invitation
        if (!hasSession) return AppRootDestination.Unauthenticated
        return if (isAnonymous) AppRootDestination.AnonymousPatient else AppRootDestination.Therapist
    }

    fun anonymousDestination(
        context: AppContext?,
        isLoading: Boolean,
    ): AnonymousPatientDestination {
        if (context != null) {
            if (context.isActivePatient) return AnonymousPatientDestination.PatientMode
            if (context.role == AppRole.Patient) return AnonymousPatientDestination.Incomplete
            return AnonymousPatientDestination.Retry
        }
        return if (isLoading) AnonymousPatientDestination.Loading else AnonymousPatientDestination.Retry
    }
}
