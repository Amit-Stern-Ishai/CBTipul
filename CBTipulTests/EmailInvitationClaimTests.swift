import Foundation
import Testing
import Supabase
@testable import CBTipul

@MainActor @Suite(.serialized) struct EmailInvitationClaimTests {
    let revision = "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA"
    let therapist = AppContext(version: 1, role: .therapist, activation: nil, patientId: nil)
    let patient = AppContext(version: 1, role: .patient, activation: .active, patientId: UUID())
    @Test func changedInvitationRequiresNewDeliberateConfirmation() async throws {
        let next = "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB"
        var sent: [String?] = []
        let gate = EmailInvitationClaim(eligible: { true }) { value in
            sent.append(value)
            switch sent.count {
            case 1: return .init("confirmation_required", revision: revision)
            case 2: return .init("invitation_changed")
            case 3: return .init("confirmation_required", revision: next)
            default: return .init("connected")
            }
        }
        _ = try await gate.resolve(therapist) { patient }
        gate.retry(confirmSwitch: true)
        _ = try await gate.resolve(therapist) { patient }
        #expect(gate.state == .confirmation && sent == [nil, revision, nil])
        gate.retry(confirmSwitch: true)
        _ = try await gate.resolve(therapist) { patient }
        #expect(sent == [nil, revision, nil, next])
    }
    @Test func restoredAnonymousPatientBypassesClaimWithoutChangingIdentity() async throws {
        var identity: String? = "existing-anonymous-account"
        var calls = 0
        let service = AppContextService(identity: { identity }, request: { patient })
        service.emailClaim = EmailInvitationClaim(eligible: { false }) { _ in calls += 1; return .init("no_match") }
        _ = try await service.getCurrentAppContext()
        #expect(service.current == patient && identity == "existing-anonymous-account" && calls == 0)
        // A later restore/reset still keeps the existing server-linked patient.
        service.clear(); _ = try await service.getCurrentAppContext()
        #expect(service.current == patient && calls == 0)
        identity = nil; service.clear(); #expect(service.current == nil)
    }
    @Test func missingRevisionFailsClosed() async {
        let gate = EmailInvitationClaim(eligible: { true }) { _ in .init("confirmation_required") }
        _ = try? await gate.resolve(therapist) { therapist }
        #expect(gate.state == .failed)
        gate.retry(confirmSwitch: true)
        #expect(gate.state == .failed)
    }
    @Test func transportUsesAuthenticatedPostWithExactBodies() async throws {
        ClaimHTTP.requests = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ClaimHTTP.self]
        let client = SupabaseClient(supabaseURL: URL(string: "https://claim-test.invalid")!, supabaseKey: "synthetic",
            options: .init(auth: .init(storage: ClinicalTestAuthStorage(), autoRefreshToken: false), global: .init(session: URLSession(configuration: configuration))))
        _ = try await client.auth.signIn(email: "synthetic@example.invalid", password: "unused")
        let gate = EmailInvitationClaim(client: client)
        let first = try await gate.resolve(therapist) { therapist }
        #expect(first == nil)
        gate.retry(confirmSwitch: true)
        _ = try await gate.resolve(therapist) { therapist }
        let requests = ClaimHTTP.requests
        #expect(requests.count == 2)
        #expect(requests.allSatisfy { $0.httpMethod == "POST" && $0.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer ") == true })
        let bodies = try requests.map { try JSONSerialization.jsonObject(with: $0.httpBody ?? Data()) as! [String: Any] }
        #expect(bodies.count == 2)
        #expect(bodies.allSatisfy { ($0["version"] as? Int) == 2 && $0["confirm_switch"] == nil })
        #expect(bodies[0]["invitation_revision"] == nil)
        #expect(bodies[1]["invitation_revision"] as? String == revision)
    }
    @Test func inviteFirstWaitsForServerRole() async throws {
        var calls = 0
        let gate = EmailInvitationClaim(eligible: { true }) { confirm in #expect(confirm == nil); calls += 1; return .init("connected") }
        let result = try await gate.resolve(therapist) { patient }
        #expect(result == patient)
        _ = try await gate.resolve(patient) { therapist }
        #expect(calls == 1)
    }
    @Test func signupFirstNeedsConfirmationAndNoMatchReloads() async throws {
        var arguments: [String?] = []
        let gate = EmailInvitationClaim(eligible: { true }) { confirm in arguments.append(confirm); return .init(confirm != nil ? "no_match" : "confirmation_required", revision: revision) }
        let initial = try await gate.resolve(therapist) { therapist }
        #expect(initial == nil)
        _ = try await gate.resolve(therapist) { therapist }
        #expect(arguments == [nil])
        gate.retry(confirmSwitch: true)
        let result = try await gate.resolve(therapist) { patient }
        #expect(result == patient); #expect(arguments == [nil, revision])
    }
    @Test func declineNoMatchAndUnavailableDoNotRepeat() async throws {
        for status in ["confirmation_required", "no_match", "connection_unavailable"] {
            var calls = 0
            let gate = EmailInvitationClaim(eligible: { true }) { _ in calls += 1; return .init(status, revision: revision) }
            _ = try await gate.resolve(therapist) { therapist }
            gate.decline()
            let result = try await gate.resolve(therapist) { therapist }
            #expect(result == therapist); #expect(calls == 1)
        }
    }
    @Test func lostResponseRetriesContextBeforeClaim() async throws {
        var context = therapist
        var calls = 0
        let gate = EmailInvitationClaim(eligible: { true }) { _ in calls += 1; context = patient; throw URLError(.timedOut) }
        let service = AppContextService(identity: { "synthetic" }, request: { context })
        service.emailClaim = gate
        _ = try? await service.getCurrentAppContext()
        #expect(service.current == nil); #expect(gate.state == .failed)
        gate.retry()
        let result = try await service.getCurrentAppContext()
        #expect(result == patient); #expect(calls == 1)
    }
    @Test func failureBeforeServerRetriesAndRefreshDoesNotReclaim() async throws {
        var calls = 0
        let gate = EmailInvitationClaim(eligible: { true }) { _ in calls += 1; if calls == 1 { throw URLError(.timedOut) }; return .init("no_match") }
        let service = AppContextService(identity: { "synthetic" }, request: { therapist })
        service.emailClaim = gate
        _ = try? await service.getCurrentAppContext(); gate.retry()
        _ = try await service.getCurrentAppContext()
        _ = try await service.getCurrentAppContext(); #expect(calls == 2)
        service.clear()
        _ = try await service.getCurrentAppContext(); #expect(calls == 3)
    }
    @Test func patientAndIneligibleBypassClaim() async throws {
        let gate = EmailInvitationClaim(eligible: { false }) { _ in Issue.record("Unexpected claim"); return .init("no_match") }
        let result = try await gate.resolve(therapist) { therapist }
        #expect(result == therapist)
        let active = EmailInvitationClaim(eligible: { true }) { _ in Issue.record("Unexpected claim"); return .init("no_match") }
        let existing = try await active.resolve(patient) { therapist }
        #expect(existing == patient)
    }
    @Test func connectedWithoutPatientRoleNeverOpensClinic() async {
        let gate = EmailInvitationClaim(eligible: { true }) { _ in .init("connected") }
        _ = try? await gate.resolve(therapist) { therapist }
        #expect(gate.state == .failed)
        gate.retry()
        _ = try? await gate.resolve(therapist) { therapist }
        #expect(gate.state == .failed)
    }
    @Test func verificationRequiredBlocksAndResetDropsOldResult() async throws {
        let gate = EmailInvitationClaim(eligible: { true }) { _ in .init("email_not_verified") }
        let result = try await gate.resolve(therapist) { therapist }
        #expect(result == nil); #expect(gate.state == .verification)
        let stale = EmailInvitationClaim(eligible: { true }) { _ in
            try await Task.sleep(for: .milliseconds(30)); return .init("connected")
        }
        let task = Task { try? await stale.resolve(therapist) { patient } }
        await Task.yield(); stale.reset(); _ = await task.value
        #expect(stale.state == .idle)
    }
}
private final class ClaimHTTP: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requests: [URLRequest] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let body: String
        if request.url!.path.hasSuffix("/token") {
            body = """
            {"access_token":"synthetic","refresh_token":"synthetic","token_type":"bearer","expires_in":3600,"expires_at":4102444800,"user":{"id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","aud":"authenticated","email":"synthetic@example.invalid","email_confirmed_at":"2026-01-01T00:00:00Z","app_metadata":{},"user_metadata":{},"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}}
            """
        } else {
            var copy = request
            if copy.httpBody == nil, let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var bytes = [UInt8](repeating: 0, count: 1024); var data = Data()
                while stream.hasBytesAvailable { let count = stream.read(&bytes, maxLength: bytes.count); if count <= 0 { break }; data.append(bytes, count: count) }
                copy.httpBody = data
            }
            Self.requests.append(copy)
            body = Self.requests.count == 1 ? "{\"status\":\"confirmation_required\",\"invitation_revision\":\"AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA\"}" : "{\"status\":\"no_match\"}"
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8)); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
