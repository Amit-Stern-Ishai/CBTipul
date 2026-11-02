import Foundation
import Supabase
import Testing
@testable import CBTipul

/// Exercises the real repository and Supabase transport, with synthetic HTTP only.
@MainActor @Suite(.serialized)
struct ClinicalRepositoryIntegrationTests {
    @Test func newAPIsPreserveOriginalTextAndNeverUseLegacyWrites() async throws {
        await EntitlementTestIsolation.acquire()
        defer { EntitlementTestIsolation.release() }
        ClinicalRepositoryHTTP.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ClinicalRepositoryHTTP.self]
        let client = SupabaseClient(supabaseURL: URL(string: "https://clinical-test.invalid")!, supabaseKey: "synthetic",
            options: .init(auth: .init(storage: ClinicalTestAuthStorage(), autoRefreshToken: false),
                           global: .init(session: URLSession(configuration: configuration))))
        _ = try await client.auth.signIn(email: "synthetic@example.invalid", password: "unused")
        EntitlementState.shared.setLocalDemo(false)
        EntitlementState.shared.apply(AppContext(version: 1, role: .therapist, activation: nil, patientId: nil, entitlement: .init(access: .full)))
        let store = PatientStore(client: client, persistPatientCache: false, anonymizeText: { text in
            Issue.record("Storage must not call the anonymizer")
            return text
        })
        try await store.loadPatients()
        let patient = try #require(store.patients.first)
        #expect(patient.loadedClinicalRecord?.version == "patient-v1")
        #expect(patient.sessions.first?.loadedClinicalRecord?.version == "session-v1")
        _ = try await store.loadQuestionnaires(for: patient)
        let session = CBTipul.Session()
        session.type = .intake
        session.notes = "synthetic original text"
        try await store.addSession(session, for: patient)
        #expect(session.notes == "synthetic original text")
        #expect(session.databaseID?.queryValue == ClinicalRepositoryHTTP.savedID)
        let failed = CBTipul.Session()
        failed.type = .intake
        failed.notes = "synthetic failure"
        await #expect(throws: ClientFailure.conflict) { try await store.addSession(failed, for: patient) }
        #expect(failed.notes == "synthetic failure" && failed.databaseID == nil)
        patient.notes = "synthetic patient note"
        try await store.updatePatientNotes(patient)
        #expect(patient.notes == "synthetic patient note")
        var questionnaire = CombinedMoodQuestionnaire()
        questionnaire.gad7Answers = Array(repeating: 1, count: 7)
        questionnaire.phq9Answers = Array(repeating: 0, count: 9)
        questionnaire.gad7Notes[0] = "synthetic questionnaire note"
        try await store.saveQuestionnaire(questionnaire, for: patient, answeredDate: .now, sessionID: nil)
        let requests = ClinicalRepositoryHTTP.snapshot()
        for endpoint in ["load-patients", "load-sessions", "load-questionnaires"] {
            #expect(requests.contains { $0.path == "/functions/v1/" + endpoint })
        }
        let saves = requests.filter { $0.path == "/functions/v1/save-session" }
        #expect(saves.count == 2)
        #expect((saves.first?.body["changes"] as? [String: Any])?["notes"] as? String == "synthetic original text")
        #expect(!requests.contains { $0.path.hasPrefix("/rest/v1/") })
        #expect(!requests.contains { $0.body["operation"] != nil })
        #expect(patient.loadedClinicalRecord?.version == "saved-v2")
        #expect(session.loadedClinicalRecord?.version == "saved-v2")

    }
}

final class ClinicalTestAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    func store(key: String, value: Data) throws { lock.lock(); defer { lock.unlock() }; values[key] = value }
    func retrieve(key: String) throws -> Data? { lock.lock(); defer { lock.unlock() }; return values[key] }
    func remove(key: String) throws { lock.lock(); defer { lock.unlock() }; values.removeValue(forKey: key) }
}

private final class ClinicalRepositoryHTTP: URLProtocol, @unchecked Sendable {
    struct Captured { let path: String; let method: String; let body: [String: Any] }
    static let patientID = "11111111-1111-4111-8111-111111111111"
    static let savedID = "33333333-3333-4333-8333-333333333333"
    private static let lock = NSLock()
    private static var requests: [Captured] = []
    static func reset() { lock.lock(); defer { lock.unlock() }; requests = [] }
    static func snapshot() -> [Captured] { lock.lock(); defer { lock.unlock() }; return requests }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var data = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }; data.append(buffer, count: count)
            }
        }
        let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let path = request.url!.path
        Self.lock.lock(); Self.requests.append(.init(path: path, method: request.httpMethod ?? "", body: body)); Self.lock.unlock()
        let response: String
        switch path {
        case "/auth/v1/token":
            response = """
            {"access_token":"synthetic","refresh_token":"synthetic","token_type":"bearer","expires_in":3600,"expires_at":4102444800,"user":{"id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","aud":"authenticated","app_metadata":{},"user_metadata":{},"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}}
            """
        case "/functions/v1/load-patients":
            response = "{\"records\":[{\"id\":\"\(Self.patientID)\",\"_version\":\"patient-v1\",\"notes\":null,\"active\":true}],\"next_cursor\":null}"
        case "/functions/v1/load-sessions":
            response = "{\"records\":[{\"id\":\"22222222-2222-4222-8222-222222222222\",\"patient_id\":\"\(Self.patientID)\",\"_version\":\"session-v1\",\"session_date\":\"2026-01-01\",\"notes\":\"\"}],\"next_cursor\":null}"
        case "/functions/v1/load-questionnaires": response = "{\"records\":[],\"next_cursor\":null}"
        case "/functions/v1/save-session", "/functions/v1/save-patient", "/functions/v1/save-questionnaire":
            var record = body["changes"] as? [String: Any] ?? [:]
            if record["notes"] as? String == "synthetic failure" {
                client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 409, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: Data(#"{"error":"record_changed"}"#.utf8))
                client?.urlProtocolDidFinishLoading(self); return
            }
            record["id"] = body["id"] ?? (path.hasSuffix("questionnaire") ? "9223372036854775807" : Self.savedID)
            record["_version"] = "saved-v2"
            record["patient_id"] = Self.patientID
            response = String(data: try! JSONSerialization.data(withJSONObject: ["record":record]), encoding: .utf8)!
        default:
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL)); return
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(response.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
