import Foundation

/// Root identity for the signed-in installation. A session is never enough
/// to mean "therapist" — anonymous Auth users are Patient Mode.
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
        isAnonymous: Bool
    ) -> AppRootDestination {
        if invitationActive { return .invitation }
        guard hasSession else { return .unauthenticated }
        if isAnonymous { return .anonymousPatient }
        return .therapist
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
