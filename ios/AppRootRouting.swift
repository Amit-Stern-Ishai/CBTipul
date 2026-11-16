import Foundation

/// Root identity for the signed-in installation. A session is never enough
/// to mean "therapist" — the server context owns the role.
enum AppRootDestination: Equatable {
    case invitation
    case therapist
    case anonymousPatient
    case unauthenticated
}

enum AnonymousPatientDestination: Equatable {
    case loading
    case patientMode
    case incomplete
    case retry
}

enum AppRootRouting {
    static func destination(
        invitationActive: Bool,
        hasSession: Bool,
        isAnonymous: Bool,
        context: AppContext? = nil
    ) -> AppRootDestination {
        if invitationActive { return .invitation }
        guard hasSession else { return .unauthenticated }
        // Auth anonymity is not a role. Unresolved sessions use the existing retry/loading shell.
        return context?.role == .therapist ? .therapist : .anonymousPatient
    }

    static func anonymousDestination(
        context: AppContext?,
        isLoading: Bool
    ) -> AnonymousPatientDestination {
        if let context {
            if context.isActivePatient { return .patientMode }
            if context.role == .patient { return .incomplete }
            return .retry
        }
        if isLoading { return .loading }
        return .retry
    }
}
