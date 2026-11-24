import Foundation
import Testing
@testable import CBTipul

@MainActor struct RevokePatientAccessTests {
    @Test func exactPhraseAndAcknowledgements() {
        #expect(RevokePatientAccess.matches(" \nהפסקת גישה\t"))
        for value in ["", "הפסקת", "הפסקת  גישה", "הפסקת גישה!"] { #expect(!RevokePatientAccess.matches(value)) }
        #expect(RevokePatientAccess.confirmed("access_revoked"))
        #expect(RevokePatientAccess.confirmed("already_disconnected"))
        #expect(!RevokePatientAccess.confirmed("ok"))
    }
    @Test func resumeRechecksPatientWithinCooldownAndKeepsIdentity() async throws {
        let patient = UUID()
        var calls = 0
        let service = AppContextService(identity: { "patient-account" }, request: {
            calls += 1
            return AppContext(version: 1, role: .patient, activation: calls == 1 ? .active : .incomplete, patientId: calls == 1 ? patient : nil)
        })
        _ = try await service.getCurrentAppContext()
        #expect(service.current?.isActivePatient == true)
        let key = "patient-account:\(patient)"
        _ = PatientHomeCache.read(key: key)
        PatientHomeCache.save(PatientHomeSnapshot(assignments: []), key: key)
        service.suspendPatientAccess()
        #expect(service.current == nil)
        #expect(PatientHomeCache.read(key: key).assignments == nil)
        await service.refreshOnForeground()
        #expect(calls == 2)
        #expect(service.current?.isIncompletePatient == true)
        #expect(EntitlementState.shared.identity == "patient-account")
        service.clear()
    }
    @Test func failedResumeDoesNotRestoreCachedPatientRoute() async throws {
        var fails = false
        let service = AppContextService(identity: { "patient-account" }, request: {
            if fails { throw URLError(.notConnectedToInternet) }
            return AppContext(version: 1, role: .patient, activation: .active, patientId: UUID())
        })
        _ = try await service.getCurrentAppContext()
        fails = true
        await service.refreshOnForeground()
        #expect(service.current == nil)
        #expect(service.loadError != nil)
        #expect(EntitlementState.shared.identity == "patient-account")
        service.clear()
    }
}
