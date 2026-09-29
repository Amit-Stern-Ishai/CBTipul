import Foundation
import Testing
import Supabase
@testable import CBTipul

@MainActor
@Suite(.serialized)
struct PatientDiaryTwoTests {
    private let patient = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let entryId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private var valid: DiaryTwoEntryDraft {
        var draft = DiaryTwoEntryDraft.empty
        draft.event = " event "
        draft.automaticThoughts = [.init(text: " first "), .init(text: "second"), .init(text: " \n ")]
        draft.feelings = [.init(name: "עצוב", intensity: 0), .init(name: "מודאג", intensity: 100)]
        draft.thinkingErrors = [.mindReading, .fortuneTelling]
        draft.alternativeThoughts = [.init(text: " a "), .init(text: " "), .init(text: "b")]
        return draft
    }
    @Test func allRequiredFieldsAndOrderedArraysAreValidated() {
        let value = valid
        #expect(value.validationMessage() == nil)
        #expect(value.persistedAutomaticThoughts == ["first", "second"])
        #expect(value.persistedAlternativeThoughts == ["a", "b"])
        var draft = value; draft.event = " \n"; #expect(draft.validationMessage() != nil)
        draft = value; draft.automaticThoughts = []; #expect(draft.validationMessage() != nil)
        draft = value; draft.automaticThoughts = [.init(text: "one")]; #expect(draft.validationMessage() == nil)
        draft = value; draft.feelings = []; #expect(draft.validationMessage() != nil)
        for intensity in [nil, -1, 101] as [Int?] {
            draft = value; draft.feelings[0].intensity = intensity; #expect(draft.validationMessage() != nil)
        }
        draft = value; draft.feelings.append(draft.feelings[0]); #expect(draft.validationMessage() != nil)
        draft = value; draft.thinkingErrors = []; #expect(draft.validationMessage() != nil)
        draft = value; draft.alternativeThoughts = [.init(text: " ")]; #expect(draft.validationMessage() != nil)
    }
    @Test func submissionUsesOnlyEdgeFunctionAndExactClinicalBody() async throws {
        DiaryTwoHTTPStub.reset(body: Data("{\"success\":true,\"entryId\":\"\(entryId)\"}".utf8))
        let service = makeService()
        let draft = valid
        let returned = try await service.submitEntry(event: draft.event.trimmingCharacters(in: .whitespacesAndNewlines),
            automaticThoughts: draft.persistedAutomaticThoughts, feelings: draft.persistedFeelings()!,
            thinkingErrors: draft.thinkingErrors, alternativeThoughts: draft.persistedAlternativeThoughts)
        #expect(returned == entryId)
        let requests = DiaryTwoHTTPStub.recorded()
        #expect(requests.count == 1)
        let sent = try #require(requests.first)
        #expect(sent.method == "POST")
        #expect(sent.url.path == "/functions/v1/submit-diary-two-entry")
        let body = try JSONSerialization.jsonObject(with: sent.body) as! [String: Any]
        #expect(Set(body.keys) == ["event", "automaticThoughts", "feelings", "thinkingErrors", "alternativeThoughts"])
        #expect(body["event"] as? String == "event")
        #expect(body["automaticThoughts"] as? [String] == ["first", "second"])
        #expect(body["alternativeThoughts"] as? [String] == ["a", "b"])
        #expect(body["thinkingErrors"] as? [String] == ["mind_reading", "fortune_telling"])
        #expect((body["feelings"] as? [[String: Any]])?.count == 2)
        // No assignment completion/cancellation or table INSERT request is made.
    }
    @Test func patientHistoryQueryFiltersIdentityAndSourceAndSortsNewestFirst() async throws {
        let rows = "[\(row(id: 1, createdBy: "patient", date: "2026-01-01")),\(row(id: 2, createdBy: "therapist", date: "2026-01-03")),\(row(id: 3, createdBy: "patient", date: "2026-01-02")),\(row(id: 4, createdBy: "patient", date: "2026-01-04", patientId: UUID()))]"
        DiaryTwoHTTPStub.reset(body: Data(rows.utf8))
        let entries = try await makeService().loadPatientCreatedEntries(patientId: patient)
        #expect(entries.map(\.event) == ["3", "1"])
        #expect(entries.allSatisfy { $0.createdBy == .patient && $0.patientId.uuidValue == patient })
        #expect(entries.first?.automaticThoughts == ["one", "two"])
        #expect(entries.first?.thinkingErrors.first?.title == "קריאת מחשבות")
        let request = try #require(DiaryTwoHTTPStub.recorded().first)
        #expect(request.method == "GET")
        #expect(request.url.path == "/rest/v1/diary_two_entries")
        let query = URLComponents(url: request.url, resolvingAgainstBaseURL: false)!.queryItems!
        #expect(query.contains { $0.name == "created_by" && $0.value == "eq.patient" })
        #expect(query.contains { $0.name == "patient_id" && $0.value?.lowercased() == "eq.\(patient.uuidString.lowercased())" })
        #expect(query.contains { $0.name == "order" && $0.value?.split(separator: ".").prefix(2).joined(separator: ".") == "created_at.desc" })
    }
    @Test func inactiveResponseIsTypedAndLocalized() async throws {
        DiaryTwoHTTPStub.reset(body: Data(#"{"error":"diary_two_not_active","message":"internal English"}"#.utf8), status: 400)
        do {
            _ = try await makeService().submitEntry(event: "e", automaticThoughts: ["a"], feelings: [.init(name: "עצוב", intensity: 30)], thinkingErrors: [.blame], alternativeThoughts: ["b"])
            Issue.record("Inactive assignment unexpectedly accepted")
        } catch PatientDiaryTwoSubmitError.notActive(let message) {
            #expect(message == L10n.patientDiaryTwoNotActive)
        }
    }
    @Test func allSpecifiedErrorsHavePatientSafeHebrewFeedback() {
        for code in ["invalid_event", "invalid_automatic_thoughts", "invalid_feelings", "duplicate_feeling", "invalid_thinking_errors", "duplicate_thinking_error", "invalid_alternative_thoughts"] {
            let error = PatientDiaryTwoService.submitError(from: Data("{\"error\":\"\(code)\"}".utf8), statusCode: 400)
            guard case .invalid(let message) = error else { Issue.record("Wrong error kind for \(code)"); continue }
            #expect(!message.isEmpty && !message.contains(code))
        }
        for code in ["patient_access_not_found", "patient_therapist_mismatch"] {
            guard case .accessDenied = PatientDiaryTwoService.submitError(from: Data("{\"error\":\"\(code)\"}".utf8), statusCode: 403) else {
                Issue.record("Access error was not recognized"); continue
            }
        }
    }
    @Test func therapistExactLookupQueriesBothIdsAndRejectsMissingWrongPatientAndWrongEntry() async throws {
        let exactId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let patientId = DatabaseID.text(patient.uuidString)
        let store = DiaryTwoStore(client: makeClient())
        DiaryTwoHTTPStub.reset(body: Data("[\(row(id: 1, createdBy: "patient", date: "2026-01-01"))]".utf8))
        let entry = try await store.loadEntry(id: exactId, patientId: patientId)
        #expect(entry?.id == exactId)
        let request = try #require(DiaryTwoHTTPStub.recorded().first)
        let query = URLComponents(url: request.url, resolvingAgainstBaseURL: false)!.queryItems!
        #expect(request.url.path == "/rest/v1/diary_two_entries")
        #expect(query.contains { $0.name == "id" && $0.value?.lowercased() == "eq.\(exactId.uuidString.lowercased())" })
        #expect(query.contains { $0.name == "patient_id" && $0.value?.lowercased() == "eq.\(patient.uuidString.lowercased())" })
        for body in ["[]", "[\(row(id: 1, createdBy: "patient", date: "2026-01-01", patientId: UUID()))]", "[\(row(id: 2, createdBy: "patient", date: "2026-01-01"))]"] {
            DiaryTwoHTTPStub.reset(body: Data(body.utf8))
            #expect(try await store.loadEntry(id: exactId, patientId: patientId) == nil)
        }
        DiaryTwoHTTPStub.reset(body: Data("{}".utf8), status: 500)
        do {
            _ = try await store.loadEntry(id: exactId, patientId: patientId)
            Issue.record("Expected lookup failure")
        } catch { /* caller falls back to history, never a previously cached entry */ }
    }
    private func makeService() -> PatientDiaryTwoService { PatientDiaryTwoService(client: makeClient()) }
    private func makeClient() -> SupabaseClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DiaryTwoHTTPStub.self]
        let client = SupabaseClient(supabaseURL: URL(string: "https://diary-two.invalid")!, supabaseKey: "test", options: .init(global: .init(session: URLSession(configuration: config))))
        return client
    }
    private func row(id: Int, createdBy: String, date: String, patientId: UUID? = nil) -> String {
        """
        {"id":"00000000-0000-0000-0000-00000000000\(id)","patient_id":"\(patientId ?? patient)","therapist_id":"33333333-3333-3333-3333-333333333333","created_by":"\(createdBy)","event":"\(id)","automatic_thoughts":["one","two"],"feelings":[{"name":"עצוב","intensity":20}],"thinking_errors":["mind_reading"],"alternative_thoughts":["a","b"],"created_at":"\(date)T12:00:00Z","updated_at":"\(date)T12:00:00Z"}
        """
    }
}

private final class DiaryTwoHTTPStub: URLProtocol, @unchecked Sendable {
    struct Recorded: Sendable { let url: URL; let method: String; let body: Data }
    private static let lock = NSLock()
    nonisolated(unsafe) private static var response = Data()
    nonisolated(unsafe) private static var status = 200
    nonisolated(unsafe) private static var requests: [Recorded] = []
    static func reset(body: Data, status: Int = 200) {
        lock.lock(); defer { lock.unlock() }
        response = body; self.status = status; requests = []
    }
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
        let body = Self.response; let status = Self.status
        Self.lock.unlock()
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
