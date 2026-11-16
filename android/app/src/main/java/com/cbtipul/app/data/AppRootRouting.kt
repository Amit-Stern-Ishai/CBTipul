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
        context: AppContext? = null,
    ): AppRootDestination {
        if (invitationActive) return AppRootDestination.Invitation
        if (!hasSession) return AppRootDestination.Unauthenticated
        return if (context?.role == AppRole.Therapist) AppRootDestination.Therapist else AppRootDestination.AnonymousPatient
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
