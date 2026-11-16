import Foundation
import Testing
@testable import CBTipul

struct AppRootRoutingTests {
    @Test func noSessionShowsAuthenticationEntry() {
        #expect(
            AppRootRouting.destination(
                invitationActive: false,
                hasSession: false,
                isAnonymous: false
            ) == .unauthenticated
        )
    }

    @Test func invitationOverridesSession() {
        #expect(AppRootRouting.destination(invitationActive: true, hasSession: false,
                                          isAnonymous: false) == .invitation)
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

    @Test func serverTherapistContextOpensClinic() {
        #expect(
            AppRootRouting.destination(
                invitationActive: false,
                hasSession: true,
                isAnonymous: false,
                context: AppContext(version: 1, role: .therapist, activation: nil, patientId: nil)
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

@MainActor struct ServerRoleSessionTests {
    @Test func roleMatrix() {
        for anonymous in [true, false] {
            let patient = AppContext(version: 1, role: .patient, activation: .active, patientId: UUID())
            #expect(AppRootRouting.destination(invitationActive: false, hasSession: true, isAnonymous: anonymous, context: patient) == .anonymousPatient)
            #expect(AppRootRouting.anonymousDestination(context: patient, isLoading: false) == .patientMode)
            #expect(AppRootRouting.destination(invitationActive: false, hasSession: true, isAnonymous: anonymous) != .therapist)
        }
    }
    @Test func switchLogoutFailureAndRetry() async throws {
        await EntitlementTestIsolation.acquire()
        defer { EntitlementTestIsolation.release() }
        var identity: String? = "therapist"
        var fail = false
        let service = AppContextService(identity: { identity }, request: {
            if fail { throw URLError(.notConnectedToInternet) }
            return AppContext(version: 1, role: identity == "therapist" ? .therapist : .patient,
                activation: identity == "therapist" ? nil : .active, patientId: identity == "therapist" ? nil : UUID())
        })
        _ = try await service.getCurrentAppContext()
        #expect(service.current?.role == .therapist)
        identity = "patient"
        #expect(service.current == nil)
        service.clear()
        _ = try await service.getCurrentAppContext()
        #expect(service.current?.isActivePatient == true)
        fail = true
        do { _ = try await service.getCurrentAppContext() } catch {}
        #expect(service.current == nil)
        #expect(service.loadError != nil)
        fail = false
        _ = try await service.getCurrentAppContext()
        #expect(service.current?.isActivePatient == true)
        identity = nil; service.clear()
        #expect(service.current == nil)
        identity = "therapist"
        _ = try await service.getCurrentAppContext()
        #expect(service.current?.role == .therapist)
    }
    @Test func latePreviousAccountResponseIsIgnored() async {
        await EntitlementTestIsolation.acquire()
        defer { EntitlementTestIsolation.release() }
        var identity: String? = "old"
        var continuation: CheckedContinuation<AppContext, Never>?
        let service = AppContextService(identity: { identity }, request: {
            await withCheckedContinuation { continuation = $0 }
        })
        let task = Task { try? await service.getCurrentAppContext() }
        while continuation == nil { await Task.yield() }
        identity = "new"; service.clear()
        continuation?.resume(returning: AppContext(version: 1, role: .therapist, activation: nil, patientId: nil))
        _ = await task.value
        #expect(service.current == nil)
    }
}
