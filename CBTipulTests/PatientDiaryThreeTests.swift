import Foundation
import Testing
import Supabase
@testable import CBTipul

@MainActor
@Suite(.serialized)
struct PatientDiaryThreeTests {
    private let patient = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let entryId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private var valid: PatientDiaryThreeDraft {
        var d = PatientDiaryThreeDraft()
        d.entry.situation = " event "
        d.entry.automaticThoughts = [.init(text: " first ", beliefBefore: 100, beliefAfter: 0), .init(text: "second", beliefBefore: 0, beliefAfter: 100)]
        d.entry.feelings = [.init(name: "עצוב", intensityBefore: 100, intensityAfter: 0), .init(name: "מודאג", intensityBefore: 0, intensityAfter: 100)]
        d.entry.thinkingErrors = [.mindReading, .fortuneTelling]
        d.entry.alternativeThoughts = [.init(text: " a ", belief: 100), .init(text: "b", belief: 0)]
        return d
    }
    @Test func everyStageValidatesItsOwnRequiredValuesAndBoundaries() {
        #expect(valid.firstInvalidStep == nil)
        var d = valid; d.entry.situation = " \n"; #expect(d.validationMessage(for: 1) != nil)
        d = valid; d.entry.automaticThoughts = []; #expect(d.validationMessage(for: 2) != nil)
        d = valid; d.entry.automaticThoughts[1].text = " "; #expect(d.validationMessage(for: 2) != nil)
        d = valid; d.entry.feelings = []; #expect(d.validationMessage(for: 3) != nil)
        d = valid; d.entry.feelings.append(d.entry.feelings[0]); #expect(d.validationMessage(for: 3) == L10n.diaryFeelingAlreadySelected)
        d = valid; d.entry.thinkingErrors = []; #expect(d.validationMessage(for: 4) != nil)
        d = valid; d.entry.alternativeThoughts = []; #expect(d.validationMessage(for: 5) != nil)
        d = valid; d.entry.alternativeThoughts[1].text = " "; #expect(d.validationMessage(for: 5) != nil)
        for value in [nil, -1, 101] as [Int?] {
            d = valid; d.entry.automaticThoughts[1].beliefBefore = value; #expect(d.validationMessage(for: 2) != nil)
            d = valid; d.entry.feelings[1].intensityBefore = value; #expect(d.validationMessage(for: 3) != nil)
            d = valid; d.entry.alternativeThoughts[1].belief = value; #expect(d.validationMessage(for: 5) != nil)
            d = valid; d.entry.automaticThoughts[1].beliefAfter = value; #expect(d.validationMessage(for: 6) != nil)
            d = valid; d.entry.feelings[1].intensityAfter = value; #expect(d.validationMessage(for: 7) != nil)
        }
        d = valid; d.entry.automaticThoughts[0].beliefAfter = nil; d.entry.feelings[0].intensityAfter = nil
        for step in 1...5 { #expect(d.validationMessage(for: step) == nil) }
        #expect(d.firstInvalidStep == 6) // no placeholder "after" values needed for earlier stages
    }
    @Test func stableRowsKeepTheirBeforeAfterPairAndOrderingThroughStructuralEdits() {
        var d = valid
        let thoughtIDs = d.entry.automaticThoughts.map(\.id)
        let feelingIDs = d.entry.feelings.map(\.id)
        d.currentStep = 6; d.entry.automaticThoughts[0].beliefAfter = 35
        #expect(d.entry.automaticThoughts.map(\.id) == thoughtIDs)
        #expect(d.entry.automaticThoughts.map(\.beliefBefore) == [100, 0])
        d.currentStep = 7; d.entry.feelings[0].intensityAfter = 40
        #expect(d.entry.feelings.map(\.id) == feelingIDs)
        #expect(d.entry.feelings.map(\.intensityBefore) == [100, 0])
        let remainingThought = d.entry.automaticThoughts[1], remainingFeeling = d.entry.feelings[1]
        d.entry.automaticThoughts.removeFirst(); d.entry.feelings.removeFirst()
        #expect(d.entry.automaticThoughts == [remainingThought]); #expect(d.entry.feelings == [remainingFeeling])
        d.entry.automaticThoughts.append(.init(text: "new", beliefBefore: 80))
        d.entry.feelings.append(.init(name: "כועס", intensityBefore: 50))
        #expect(d.validationMessage(for: 6) != nil); #expect(d.validationMessage(for: 7) != nil)
    }
    @Test func backForwardAndDraftSerializationPreserveAllWork() throws {
        var d = valid; d.currentStep = 5
        let rows = d.entry
        d.back(); #expect(d.currentStep == 4); let advancedFive = d.advance(); #expect(advancedFive); #expect(d.currentStep == 5)
        d.currentStep = 7; d.back(); let advancedSeven = d.advance(); #expect(advancedSeven); #expect(d.currentStep == 7)
        #expect(d.entry == rows)
        let restored = try JSONDecoder().decode(PatientDiaryThreeDraft.self, from: JSONEncoder().encode(d))
        #expect(restored == d)
        var empty = PatientDiaryThreeDraft(); #expect(!empty.hasMeaningfulContent); let advancedEmpty = empty.advance(); #expect(!advancedEmpty)
        empty.entry.automaticThoughts[0].beliefBefore = 0; #expect(empty.hasMeaningfulContent)
    }
    @Test func submissionUsesEdgeOnlyAndExactNestedClinicalKeys() async throws {
        PatientThreeHTTPStub.reset(body: Data("{\"success\":true,\"entryId\":\"\(entryId)\"}".utf8))
        let d = valid.entry
        #expect(try await submit(d) == entryId)
        let requests = PatientThreeHTTPStub.recorded()
        #expect(requests.count == 1) // no direct INSERT, completion, notification or assignment mutation
        let sent = try #require(requests.first)
        #expect(sent.method == "POST"); #expect(sent.url.path == "/functions/v1/submit-diary-three-entry")
        let body = try JSONSerialization.jsonObject(with: sent.body) as! [String: Any]
        #expect(Set(body.keys) == ["situation", "automaticThoughts", "feelings", "thinkingErrors", "alternativeThoughts"])
        #expect(body["situation"] as? String == "event")
        let thoughts = body["automaticThoughts"] as! [[String: Any]]
        #expect(thoughts.count == 2); #expect(Set(thoughts[0].keys) == ["text", "beliefBefore", "beliefAfter"])
        #expect(thoughts[0]["beliefBefore"] as? Int == 100); #expect(thoughts[0]["beliefAfter"] as? Int == 0)
        let feelings = body["feelings"] as! [[String: Any]]
        #expect(Set(feelings[0].keys) == ["name", "intensityBefore", "intensityAfter"])
        let alternatives = body["alternativeThoughts"] as! [[String: Any]]
        #expect(Set(alternatives[0].keys) == ["text", "belief"])
        #expect(body["thinkingErrors"] as? [String] == ["mind_reading", "fortune_telling"])
    }
    @Test func historyUsesPatientSessionReadFiltersAndNewestFirstOrder() async throws {
        PatientThreeHTTPStub.reset(body: Data("[\(row(1, "patient", "2026-01-01")),\(row(2, "therapist", "2026-01-03")),\(row(3, "patient", "2026-01-02")),\(row(4, "patient", "2026-01-04", patientId: UUID()))]".utf8))
        let entries = try await service().loadPatientCreatedEntries(patientId: patient)
        #expect(entries.map(\.situation) == ["3", "1"])
        let entry = try #require(entries.first)
        #expect(entry.automaticThoughts.map(\.beliefBefore) == [100, 0]); #expect(entry.automaticThoughts.map(\.beliefAfter) == [0, 100])
        #expect(entry.feelings[0].intensityBefore == 85); #expect(entry.feelings[0].intensityAfter == 40)
        #expect(entry.alternativeThoughts[0].belief == 80); #expect(entry.thinkingErrors[0].title == "קריאת מחשבות")
        let request = try #require(PatientThreeHTTPStub.recorded().first)
        #expect(request.method == "GET"); #expect(request.url.path == "/rest/v1/diary_three_entries")
        let query = URLComponents(url: request.url, resolvingAgainstBaseURL: false)!.queryItems!
        #expect(query.contains { $0.name == "created_by" && $0.value == "eq.patient" })
        #expect(query.contains { $0.name == "patient_id" && $0.value?.lowercased() == "eq.\(patient.uuidString.lowercased())" })
        #expect(query.contains { $0.name == "order" && $0.value?.hasPrefix("created_at.desc") == true })
    }
    @Test func cancellationAndAccessAndClinicalErrorsHaveLocalizedFeedback() async throws {
        for code in ["invalid_situation", "invalid_automatic_thoughts", "invalid_feelings", "duplicate_feeling", "invalid_thinking_errors", "duplicate_thinking_error", "invalid_alternative_thoughts"] {
            guard case .invalid(let message) = PatientDiaryThreeService.submitError(from: Data("{\"error\":\"\(code)\"}".utf8), statusCode: 400) else { Issue.record("Wrong error for \(code)"); continue }
            #expect(!message.isEmpty && !message.contains(code))
        }
        for code in ["patient_access_not_found", "patient_therapist_mismatch"] {
            guard case .accessDenied = PatientDiaryThreeService.submitError(from: Data("{\"error\":\"\(code)\"}".utf8), statusCode: 403) else { Issue.record("Wrong access error"); continue }
        }
        PatientThreeHTTPStub.reset(body: Data(#"{"error":"diary_three_not_active"}"#.utf8), status: 400)
        do { _ = try await submit(valid.entry); Issue.record("Unexpected success") }
        catch PatientDiaryThreeSubmitError.notActive(let message) { #expect(message == L10n.patientDiaryThreeNotActive) }
    }
    @Test func exactTherapistLookupQueriesBothIdsAndRejectsDeletedMismatchedAndFailedRows() async throws {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [PatientThreeHTTPStub.self]
        let client = SupabaseClient(supabaseURL: URL(string: "https://patient-three.invalid")!, supabaseKey: "test", options: .init(global: .init(session: URLSession(configuration: config))))
        let store = DiaryThreeStore(client: client)
        let target = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let owner = DatabaseID.text(patient.uuidString)
        PatientThreeHTTPStub.reset(body: Data("[\(row(1, "patient", "2026-01-01"))]".utf8))
        let entry = try #require(try await store.loadEntry(id: target, patientId: owner))
        #expect(entry.situation == "1")
        #expect(entry.automaticThoughts[0] == .init(text: "one", beliefBefore: 100, beliefAfter: 0))
        #expect(entry.feelings[0] == .init(name: "עצוב", intensityBefore: 85, intensityAfter: 40))
        #expect(entry.alternativeThoughts[0] == .init(text: "a", belief: 80))
        #expect(entry.thinkingErrors == [.mindReading])
        let request = try #require(PatientThreeHTTPStub.recorded().first)
        let query = URLComponents(url: request.url, resolvingAgainstBaseURL: false)!.queryItems!
        #expect(request.url.path == "/rest/v1/diary_three_entries")
        #expect(query.contains { $0.name == "id" && $0.value?.lowercased() == "eq.\(target.uuidString.lowercased())" })
        #expect(query.contains { $0.name == "patient_id" && $0.value?.lowercased() == "eq.\(patient.uuidString.lowercased())" })
        for body in ["[]", "[\(row(2, "patient", "2026-01-01"))]", "[\(row(1, "patient", "2026-01-01", patientId: UUID()))]"] {
            PatientThreeHTTPStub.reset(body: Data(body.utf8))
            #expect(try await store.loadEntry(id: target, patientId: owner) == nil)
        }
        PatientThreeHTTPStub.reset(body: Data("{}".utf8), status: 500)
        do { _ = try await store.loadEntry(id: target, patientId: owner); Issue.record("Expected lookup failure") }
        catch { /* The caller falls back to history; cached clinical data is never used as the exact result. */ }
    }
    private func submit(_ d: DiaryThreeEntryDraft) async throws -> UUID {
        try await service().submitEntry(situation: d.situation.trimmingCharacters(in: .whitespacesAndNewlines), automaticThoughts: d.persistedAutomaticThoughts, feelings: d.persistedFeelings()!, thinkingErrors: d.thinkingErrors, alternativeThoughts: d.persistedAlternativeThoughts)
    }
    private func service() -> PatientDiaryThreeService {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [PatientThreeHTTPStub.self]
        return PatientDiaryThreeService(client: SupabaseClient(supabaseURL: URL(string: "https://patient-three.invalid")!, supabaseKey: "test", options: .init(global: .init(session: URLSession(configuration: config)))))
    }
    private func row(_ id: Int, _ source: String, _ date: String, patientId: UUID? = nil) -> String {
        """
        {"id":"00000000-0000-0000-0000-00000000000\(id)","patient_id":"\(patientId ?? patient)","therapist_id":"33333333-3333-3333-3333-333333333333","created_by":"\(source)","situation":"\(id)","automatic_thoughts":[{"text":"one","beliefBefore":100,"beliefAfter":0},{"text":"two","beliefBefore":0,"beliefAfter":100}],"feelings":[{"name":"עצוב","intensityBefore":85,"intensityAfter":40}],"thinking_errors":["mind_reading"],"alternative_thoughts":[{"text":"a","belief":80}],"created_at":"\(date)T12:00:00Z","updated_at":"\(date)T12:00:00Z"}
        """
    }
}

private final class PatientThreeHTTPStub: URLProtocol, @unchecked Sendable {
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
