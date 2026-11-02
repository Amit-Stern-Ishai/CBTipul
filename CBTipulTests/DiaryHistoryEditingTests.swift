import Foundation
import Testing
import Supabase
@testable import CBTipul

@MainActor @Suite(.serialized) struct DiaryHistoryEditingTests {
    let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let patient = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    func client() -> SupabaseClient {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [DiaryEditHTTPStub.self]
        return SupabaseClient(supabaseURL: URL(string: "https://diary-edit.invalid")!, supabaseKey: "test",
            options: .init(global: .init(session: URLSession(configuration: config))))
    }
    func row(_ number: Int, author: String) -> String {
        let content: String
        switch number {
        case 1: content =  #""event":"test","automatic_thoughts":["one","two"],"feelings":[{"name":"עצוב","intensity":0}],"behaviour":"test","physical_symptoms":null"#
        case 2: content =  #""event":"test","automatic_thoughts":["one","two"],"feelings":[{"name":"עצוב","intensity":100}],"thinking_errors":["mind_reading"],"alternative_thoughts":["other"]"#
        default: content =  #""situation":"test","automatic_thoughts":[{"text":"one","beliefBefore":100,"beliefAfter":0}],"feelings":[{"name":"עצוב","intensityBefore":100,"intensityAfter":0}],"thinking_errors":["mind_reading"],"alternative_thoughts":[{"text":"other","belief":50}]"#
        }
        return """
        {"id":"\(id)","patient_id":"\(patient)","therapist_id":"33333333-3333-3333-3333-333333333333","created_by":"\(author)",\(content),"created_at":"2026-01-01T12:00:00Z","updated_at":"2026-11-01T12:00:00Z"}
        """
    }
    @Test func diaryOneBothRolesAuthorsFailureAndExactRetry() async throws {
        await EntitlementTestIsolation.acquire(); defer { EntitlementTestIsolation.release() }
        for role in [AppRole.patient, .therapist] {
            EntitlementState.shared.apply(AppContext(version: 1, role: role, activation: .active, patientId: patient, entitlement: .init(access: .full)))
            for author in ["patient", "therapist"] {
                let store = DiaryOneStore(client: client())
                let body = row(1, author: author)
                for failure in [(403, #"{"code":"42501","message":"denied"}"#), (200, "[]"), (200, body.replacingOccurrences(of: id.uuidString, with: UUID().uuidString)), (200, body.replacingOccurrences(of: patient.uuidString, with: UUID().uuidString)), (503, #"{"message":"unavailable"}"#)] {
                    DiaryEditHTTPStub.reset(body: Data(failure.1.utf8), status: failure.0)
                    do {
                        _ = try await store.updateEntry(id: id, patientId: .text(patient.uuidString), event: "test", automaticThoughts: ["one", "two"], feelings: [.init(name: "עצוב", intensity: 0)], behaviour: "test", physicalSymptoms: nil)
                        Issue.record("Unconfirmed update accepted")
                    } catch { }
                    #expect(store.entries(for: .text(patient.uuidString)).isEmpty)
                }
                DiaryEditHTTPStub.reset(body: Data(body.utf8))
                for _ in 0..<2 {
                    let saved = try await store.updateEntry(id: id, patientId: .text(patient.uuidString), event: "test", automaticThoughts: ["one", "two"], feelings: [.init(name: "עצוב", intensity: 0)], behaviour: "test", physicalSymptoms: nil)
                    #expect(saved.id == id && saved.createdBy.rawValue == author)
                    #expect(saved.createdAt < saved.updatedAt)
                    #expect(store.entries(for: .text(patient.uuidString)).count == 1)
                }
                let requests = DiaryEditHTTPStub.recorded()
                #expect(requests.count == 2 && requests[0].body == requests[1].body)
                for request in requests {
                    #expect(request.method == "PATCH" && request.url.path == "/rest/v1/diary_one_entries")
                    let query = URLComponents(url: request.url, resolvingAgainstBaseURL: false)!.queryItems!
                    #expect(!query.contains { $0.name == "created_by" })
                    #expect(query.contains { $0.name == "id" && $0.value?.lowercased() == "eq.\(id.uuidString.lowercased())" })
                    #expect(query.contains { $0.name == "patient_id" && $0.value?.lowercased() == "eq.\(patient.uuidString.lowercased())" })
                    let payload = try JSONSerialization.jsonObject(with: request.body) as! [String: Any]
                    #expect(Set(payload.keys).isDisjoint(with: ["id", "patient_id", "therapist_id", "created_by", "created_at", "updated_at"]))
                }
            }
        }
    }
    @Test func diaryTwoBothRolesAuthorsFailureAndExactRetry() async throws {
        await EntitlementTestIsolation.acquire(); defer { EntitlementTestIsolation.release() }
        for role in [AppRole.patient, .therapist] {
            EntitlementState.shared.apply(AppContext(version: 1, role: role, activation: .active, patientId: patient, entitlement: .init(access: .full)))
            for author in ["patient", "therapist"] {
                let store = DiaryTwoStore(client: client())
                let body = row(2, author: author)
                for failure in [(403, #"{"code":"42501","message":"denied"}"#), (200, "[]"), (200, body.replacingOccurrences(of: id.uuidString, with: UUID().uuidString)), (200, body.replacingOccurrences(of: patient.uuidString, with: UUID().uuidString)), (503, #"{"message":"unavailable"}"#)] {
                    DiaryEditHTTPStub.reset(body: Data(failure.1.utf8), status: failure.0)
                    do {
                        _ = try await store.updateEntry(id: id, patientId: .text(patient.uuidString), event: "test", automaticThoughts: ["one", "two"], feelings: [.init(name: "עצוב", intensity: 100)], thinkingErrors: [.mindReading], alternativeThoughts: ["other"])
                        Issue.record("Unconfirmed update accepted")
                    } catch { }
                    #expect(store.entries(for: .text(patient.uuidString)).isEmpty)
                }
                DiaryEditHTTPStub.reset(body: Data(body.utf8))
                for _ in 0..<2 {
                    let saved = try await store.updateEntry(id: id, patientId: .text(patient.uuidString), event: "test", automaticThoughts: ["one", "two"], feelings: [.init(name: "עצוב", intensity: 100)], thinkingErrors: [.mindReading], alternativeThoughts: ["other"])
                    #expect(saved.id == id && saved.createdBy.rawValue == author)
                    #expect(saved.createdAt < saved.updatedAt)
                    #expect(store.entries(for: .text(patient.uuidString)).count == 1)
                }
                let requests = DiaryEditHTTPStub.recorded()
                #expect(requests.count == 2 && requests[0].body == requests[1].body)
                for request in requests {
                    #expect(request.method == "PATCH" && request.url.path == "/rest/v1/diary_two_entries")
                    let query = URLComponents(url: request.url, resolvingAgainstBaseURL: false)!.queryItems!
                    #expect(!query.contains { $0.name == "created_by" })
                    #expect(query.contains { $0.name == "id" && $0.value?.lowercased() == "eq.\(id.uuidString.lowercased())" })
                    #expect(query.contains { $0.name == "patient_id" && $0.value?.lowercased() == "eq.\(patient.uuidString.lowercased())" })
                    let payload = try JSONSerialization.jsonObject(with: request.body) as! [String: Any]
                    #expect(Set(payload.keys).isDisjoint(with: ["id", "patient_id", "therapist_id", "created_by", "created_at", "updated_at"]))
                }
            }
        }
    }
    @Test func diaryThreeBothRolesAuthorsFailureAndExactRetry() async throws {
        await EntitlementTestIsolation.acquire(); defer { EntitlementTestIsolation.release() }
        for role in [AppRole.patient, .therapist] {
            EntitlementState.shared.apply(AppContext(version: 1, role: role, activation: .active, patientId: patient, entitlement: .init(access: .full)))
            for author in ["patient", "therapist"] {
                let store = DiaryThreeStore(client: client())
                let body = row(3, author: author)
                for failure in [(403, #"{"code":"42501","message":"denied"}"#), (200, "[]"), (200, body.replacingOccurrences(of: id.uuidString, with: UUID().uuidString)), (200, body.replacingOccurrences(of: patient.uuidString, with: UUID().uuidString)), (503, #"{"message":"unavailable"}"#)] {
                    DiaryEditHTTPStub.reset(body: Data(failure.1.utf8), status: failure.0)
                    do {
                        _ = try await store.updateEntry(id: id, patientId: .text(patient.uuidString), situation: "test", automaticThoughts: [.init(text: "one", beliefBefore: 100, beliefAfter: 0)], feelings: [.init(name: "עצוב", intensityBefore: 100, intensityAfter: 0)], thinkingErrors: [.mindReading], alternativeThoughts: [.init(text: "other", belief: 50)])
                        Issue.record("Unconfirmed update accepted")
                    } catch { }
                    #expect(store.entries(for: .text(patient.uuidString)).isEmpty)
                }
                DiaryEditHTTPStub.reset(body: Data(body.utf8))
                for _ in 0..<2 {
                    let saved = try await store.updateEntry(id: id, patientId: .text(patient.uuidString), situation: "test", automaticThoughts: [.init(text: "one", beliefBefore: 100, beliefAfter: 0)], feelings: [.init(name: "עצוב", intensityBefore: 100, intensityAfter: 0)], thinkingErrors: [.mindReading], alternativeThoughts: [.init(text: "other", belief: 50)])
                    #expect(saved.id == id && saved.createdBy.rawValue == author)
                    #expect(saved.createdAt < saved.updatedAt)
                    #expect(store.entries(for: .text(patient.uuidString)).count == 1)
                }
                let requests = DiaryEditHTTPStub.recorded()
                #expect(requests.count == 2 && requests[0].body == requests[1].body)
                for request in requests {
                    #expect(request.method == "PATCH" && request.url.path == "/rest/v1/diary_three_entries")
                    let query = URLComponents(url: request.url, resolvingAgainstBaseURL: false)!.queryItems!
                    #expect(!query.contains { $0.name == "created_by" })
                    #expect(query.contains { $0.name == "id" && $0.value?.lowercased() == "eq.\(id.uuidString.lowercased())" })
                    #expect(query.contains { $0.name == "patient_id" && $0.value?.lowercased() == "eq.\(patient.uuidString.lowercased())" })
                    let payload = try JSONSerialization.jsonObject(with: request.body) as! [String: Any]
                    #expect(Set(payload.keys).isDisjoint(with: ["id", "patient_id", "therapist_id", "created_by", "created_at", "updated_at"]))
                }
            }
        }
    }
    @Test func populatedDraftsKeepSavedEntryUnchangedWhenEditsAreCancelled() throws {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        for author in ["patient", "therapist"] {
            let one = try decoder.decode(DiaryOneEntry.self, from: Data(row(1, author: author).utf8))
            let two = try decoder.decode(DiaryTwoEntry.self, from: Data(row(2, author: author).utf8))
            let three = try decoder.decode(DiaryThreeEntry.self, from: Data(row(3, author: author).utf8))
            let a = DiaryOneEntryDraft.from(one); var editedA = a; editedA.event = "cancelled"
            let b = DiaryTwoEntryDraft.from(two); var editedB = b; editedB.event = "cancelled"
            let c = DiaryThreeEntryDraft.from(three); var editedC = c; editedC.situation = "cancelled"
            #expect(a.comparableSnapshot != editedA.comparableSnapshot)
            #expect(b.comparableSnapshot != editedB.comparableSnapshot)
            #expect(c.comparableSnapshot != editedC.comparableSnapshot)
            #expect(DiaryOneEntryDraft.from(one).comparableSnapshot == a.comparableSnapshot)
            #expect(DiaryTwoEntryDraft.from(two).comparableSnapshot == b.comparableSnapshot)
            #expect(three.situation == c.situation && three.automaticThoughts == c.persistedAutomaticThoughts)
            #expect(a.persistedAutomaticThoughts == one.automaticThoughts && a.persistedFeelings() == one.feelings)
            #expect(b.persistedAlternativeThoughts == two.alternativeThoughts && b.thinkingErrors == two.thinkingErrors)
            #expect(c.persistedAutomaticThoughts == three.automaticThoughts && c.persistedFeelings() == three.feelings)
            #expect(c.persistedAlternativeThoughts == three.alternativeThoughts)
        }
    }
    @Test func fullHistoryPagesBothAuthorsWithoutAssignmentLookup() async throws {
        await EntitlementTestIsolation.acquire(); defer { EntitlementTestIsolation.release() }
        for n in 1...3 {
            let first = (0..<250).map { index in
                row(n, author: index.isMultiple(of: 2) ? "patient" : "therapist")
                    .replacingOccurrences(of: id.uuidString, with: String(format: "00000000-0000-0000-0000-%012d", index))
            }.joined(separator: ",")
            DiaryEditHTTPStub.resetPages([Data("[\(first)]".utf8), Data("[\(row(n, author: "therapist"))]".utf8)])
            switch n {
            case 1: #expect(try await PatientDiaryOneService(client: client()).loadPatientCreatedEntries(patientId: patient).count == 251)
            case 2: #expect(try await PatientDiaryTwoService(client: client()).loadPatientCreatedEntries(patientId: patient).count == 251)
            default: #expect(try await PatientDiaryThreeService(client: client()).loadPatientCreatedEntries(patientId: patient).count == 251)
            }
            let requests = DiaryEditHTTPStub.recorded()
            #expect(requests.count == 2 && requests.allSatisfy { $0.method == "GET" && $0.url.path.contains("_entries") })
            let second = URLComponents(url: requests[1].url, resolvingAgainstBaseURL: false)!.queryItems!
            #expect(second.contains { $0.name == "offset" && $0.value == "250" })
            #expect(!second.contains { $0.name == "created_by" })
        }
    }

}
private final class DiaryEditHTTPStub: URLProtocol, @unchecked Sendable {
    struct Recorded: Sendable { let url: URL; let method: String; let body: Data }
    private static let lock = NSLock()
    nonisolated(unsafe) private static var response = Data()
    nonisolated(unsafe) private static var status = 200
    nonisolated(unsafe) private static var pages: [Data] = []
    nonisolated(unsafe) private static var requests: [Recorded] = []
    static func reset(body: Data, status: Int = 200) {
        lock.lock(); defer { lock.unlock() }
        response = body; self.status = status; requests = []; pages = []
    }
    static func resetPages(_ values: [Data]) { reset(body: Data("[]".utf8)); lock.lock(); pages = values; lock.unlock() }
    static func recorded() -> [Recorded] { lock.lock(); defer { lock.unlock() }; return requests }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var data = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var bytes = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&bytes, maxLength: bytes.count)
                if count <= 0 { break }
                data.append(contentsOf: bytes.prefix(count))
            }
        }
        Self.lock.lock()
        Self.requests.append(.init(url: request.url!, method: request.httpMethod ?? "", body: data))
        let body = Self.pages.isEmpty ? Self.response : Self.pages.removeFirst(); let status = Self.status
        Self.lock.unlock()
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
