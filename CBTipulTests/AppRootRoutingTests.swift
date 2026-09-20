import Foundation
import Testing
@testable import CBTipul

struct AppRootRoutingTests {
    @Test func noSessionShowsTherapistLogin() {
        #expect(
            AppRootRouting.destination(
                invitationActive: false,
                hasSession: false,
                isAnonymous: false
            ) == .unauthenticated
        )
    }

    @Test func invitationOverridesSession() {
        #expect(
            AppRootRouting.destination(
                invitationActive: true,
                hasSession: true,
                isAnonymous: true
            ) == .invitation
        )
        #expect(
            AppRootRouting.destination(
                invitationActive: true,
                hasSession: true,
                isAnonymous: false
            ) == .invitation
        )
    }

    @Test func nonAnonymousSessionIsTherapist() {
        #expect(
            AppRootRouting.destination(
                invitationActive: false,
                hasSession: true,
                isAnonymous: false
            ) == .therapist
        )
    }

    @Test func anonymousSessionNeverTherapist() {
        #expect(
            AppRootRouting.destination(
                invitationActive: false,
                hasSession: true,
                isAnonymous: true
            ) == .anonymousPatient
        )
    }

    @Test func anonymousActiveContextIsPatientMode() {
        let context = AppContext(
            version: 1,
            role: .patient,
            activation: .active,
            patientId: UUID()
        )
        #expect(
            AppRootRouting.anonymousDestination(context: context, isLoading: false)
                == .patientMode
        )
    }

    @Test func anonymousIncompleteContextIsRecovery() {
        let context = AppContext(
            version: 1,
            role: .patient,
            activation: .incomplete,
            patientId: nil
        )
        #expect(
            AppRootRouting.anonymousDestination(context: context, isLoading: false)
                == .incomplete
        )
    }

    @Test func anonymousContextErrorNeverTherapist() {
        #expect(
            AppRootRouting.anonymousDestination(context: nil, isLoading: false)
                == .retry
        )
        #expect(
            AppRootRouting.anonymousDestination(context: nil, isLoading: true)
                == .loading
        )
        let therapistShaped = AppContext(
            version: 1,
            role: .therapist,
            activation: nil,
            patientId: nil
        )
        #expect(
            AppRootRouting.anonymousDestination(context: therapistShaped, isLoading: false)
                == .retry
        )
    }
}
