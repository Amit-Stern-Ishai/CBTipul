import Foundation
import Testing
import Supabase
@testable import CBTipul

@MainActor @Suite(.serialized)
struct DiaryThreeTests {
    private let patient = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private var raw: String { """
    {"id":"\(id)","patient_id":"\(patient)","therapist_id":"33333333-3333-3333-3333-333333333333","created_by":"patient",
    "situation":"situation","automatic_thoughts":[{"text":"first","beliefBefore":100,"beliefAfter":0},{"text":"second","beliefBefore":90,"beliefAfter":35}],
    "feelings":[{"name":"עצוב","intensityBefore":100,"intensityAfter":0},{"name":"מודאג","intensityBefore":85,"intensityAfter":40}],
    "thinking_errors":["mind_reading","fortune_telling"],"alternative_thoughts":[{"text":"a","belief":0},{"text":"b","belief":100}],
    "created_at":"2026-09-01T12:00:00Z","updated_at":"2026-09-02T12:00:00Z"}
    """ }
    private func entry() throws -> DiaryThreeEntry {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DiaryThreeEntry.self, from: Data(raw.utf8))
    }
    @Test func nestedModelsDecodeAndRestoreAllRatingsAndOrder() throws {
        let value = try entry()
        #expect(value.createdBy == .patient && value.patientId.uuidValue == patient)
        #expect(value.automaticThoughts.map(\.text) == ["first", "second"])
        #expect(value.automaticThoughts.map(\.beliefBefore) == [100, 90])
        #expect(value.automaticThoughts.map(\.beliefAfter) == [0, 35])
        #expect(value.feelings.map(\.intensityBefore) == [100, 85])
        #expect(value.feelings.map(\.intensityAfter) == [0, 40])
        #expect(value.alternativeThoughts.map(\.belief) == [0, 100])
        #expect(value.thinkingErrors == [.mindReading, .fortuneTelling])
        #expect(value.thinkingErrors.first?.title == "קריאת מחשבות")
        let draft = DiaryThreeEntryDraft.from(value)
        #expect(draft.validationMessage() == nil)
        #expect(draft.persistedAutomaticThoughts == value.automaticThoughts)
        #expect(draft.persistedFeelings() == value.feelings)
        #expect(draft.persistedAlternativeThoughts == value.alternativeThoughts)
    }
    @Test func exactNestedCamelCaseKeysAndClinicalOnlyUpdate() throws {
        let e = try entry()
        let payload = NewDiaryThreeEntry(patientId: patient, therapistId: e.therapistId, createdBy: .therapist,
            situation: e.situation, automaticThoughts: e.automaticThoughts, feelings: e.feelings, thinkingErrors: e.thinkingErrors, alternativeThoughts: e.alternativeThoughts)
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as! [String: Any]
        #expect(json["created_by"] as? String == "therapist")
        #expect(Set(json.keys) == ["patient_id", "therapist_id", "created_by", "situation", "automatic_thoughts", "feelings", "thinking_errors", "alternative_thoughts"])
        #expect(Set((json["automatic_thoughts"] as! [[String: Any]])[0].keys) == ["text", "beliefBefore", "beliefAfter"])
        #expect(Set((json["feelings"] as! [[String: Any]])[0].keys) == ["name", "intensityBefore", "intensityAfter"])
        #expect(Set((json["alternative_thoughts"] as! [[String: Any]])[0].keys) == ["text", "belief"])
        #expect(json["thinking_errors"] as? [String] == ["mind_reading", "fortune_telling"])
        let update = DiaryThreeEntryClinicalUpdate(situation: e.situation, automaticThoughts: e.automaticThoughts, feelings: e.feelings, thinkingErrors: e.thinkingErrors, alternativeThoughts: e.alternativeThoughts, updatedAt: "2026-09-02T12:00:00Z")
        let edited = try JSONSerialization.jsonObject(with: JSONEncoder().encode(update)) as! [String: Any]
        #expect(Set(edited.keys) == ["situation", "automatic_thoughts", "feelings", "thinking_errors", "alternative_thoughts", "updated_at"])
    }
    @Test func validatesAllFieldsBoundariesMissingRatingsAndDuplicates() throws {
        let valid = DiaryThreeEntryDraft.from(try entry())
        for rating in [0, 100] {
            var d = valid; d.automaticThoughts[0].beliefBefore = rating; d.automaticThoughts[0].beliefAfter = rating
            d.feelings[0].intensityBefore = rating; d.feelings[0].intensityAfter = rating; d.alternativeThoughts[0].belief = rating
            #expect(d.validationMessage() == nil)
        }
        for rating in [nil, -1, 101] as [Int?] {
            var d = valid; d.automaticThoughts[0].beliefBefore = rating; #expect(d.validationMessage() != nil)
            d = valid; d.automaticThoughts[0].beliefAfter = rating; #expect(d.validationMessage() != nil)
            d = valid; d.feelings[0].intensityBefore = rating; #expect(d.validationMessage() != nil)
            d = valid; d.feelings[0].intensityAfter = rating; #expect(d.validationMessage() != nil)
            d = valid; d.alternativeThoughts[0].belief = rating; #expect(d.validationMessage() != nil)
        }
        var d = valid; d.situation = " \n"; #expect(d.validationMessage() != nil)
        d = valid; d.automaticThoughts = []; #expect(d.validationMessage() != nil)
        d = valid; d.automaticThoughts[0].text = " "; #expect(d.validationMessage() != nil)
        d = valid; d.feelings = []; #expect(d.validationMessage() != nil)
        d = valid; d.feelings.append(d.feelings[0]); #expect(d.validationMessage() == L10n.diaryFeelingAlreadySelected)
        d = valid; d.thinkingErrors = []; #expect(d.validationMessage() != nil)
        d = valid; d.thinkingErrors.append(d.thinkingErrors[0]); #expect(d.validationMessage() != nil)
        d = valid; d.alternativeThoughts = []; #expect(d.validationMessage() != nil)
        d = valid; d.alternativeThoughts[0].text = " "; #expect(d.validationMessage() != nil)
    }
    @Test func stableDraftIdentityPreservesOtherRatingsOnRemoval() throws {
        var draft = DiaryThreeEntryDraft.from(try entry())
        let thought = draft.automaticThoughts[1]; let feeling = draft.feelings[1]
        draft.automaticThoughts.removeFirst(); draft.feelings.removeFirst()
        #expect(draft.automaticThoughts == [thought])
        #expect(draft.feelings == [feeling])
        #expect(try JSONDecoder().decode(DiaryThreeEntryDraft.self, from: JSONEncoder().encode(draft)) == draft)
    }
    @Test func activationUsesEdgeAcceptsBothIdempotentResultsAndRejectsWrongType() throws {
        #expect(PatientDiaryThreeActivation.functionName == "request-patient-diary-three")
        #expect(PatientDiaryThreeActivation.usesEdgeFunction(.diaryThree))
        #expect(!PatientDiaryThreeActivation.usesDirectInsert(.diaryThree))
        let body = try JSONSerialization.jsonObject(with: PatientDiaryThreeActivation.requestJSON(patientId: patient)) as! [String: String]
        #expect(body == ["patientId": patient.uuidString])
        for created in [true, false] {
            let response = """
            {"success":true,"createdNew":\(created),"assignment":{"id":"\(id)","patientId":"\(patient)","therapistId":null,"sessionId":null,"type":"diary_three","createdAt":"2026-09-01T12:00:00Z","completedAt":null,"cancelledAt":null}}
            """
            #expect(try PatientDiaryThreeActivation.assignment(fromResponseData: Data(response.utf8)).type == .diaryThree)
            #expect(throws: PatientAssignmentError.self) { try PatientDiaryThreeActivation.assignment(fromResponseData: Data(response.replacingOccurrences(of: "diary_three", with: "diary_two").utf8)) }
        }
    }
    @Test func therapistCRUDSortsPreservesSourceAndDoesNotChangeAssignments() async throws {
        let store = DiaryThreeStore(client: SupabaseClient(supabaseURL: URL(string: "https://example.invalid")!, supabaseKey: "test"))
        let patient = DatabaseID.text("demo-diary-three")
        let e = try entry()
        let first = try await store.createEntry(patientId: patient, situation: "first", automaticThoughts: e.automaticThoughts, feelings: e.feelings, thinkingErrors: e.thinkingErrors, alternativeThoughts: e.alternativeThoughts)
        let second = try await store.createEntry(patientId: patient, situation: "second", automaticThoughts: e.automaticThoughts, feelings: e.feelings, thinkingErrors: e.thinkingErrors, alternativeThoughts: e.alternativeThoughts)
        #expect(try await store.loadEntries(for: patient).map(\.id) == [second.id, first.id])
        let edited = try await store.updateEntry(id: first.id, patientId: patient, situation: "edited", automaticThoughts: Array(e.automaticThoughts.reversed()), feelings: e.feelings, thinkingErrors: e.thinkingErrors, alternativeThoughts: e.alternativeThoughts)
        #expect(edited.createdBy == .therapist && edited.createdAt == first.createdAt && edited.therapistId == first.therapistId)
        #expect(edited.automaticThoughts.first?.text == "second")
        try await store.deleteEntry(id: first.id, patientId: patient)
        #expect(store.entries(for: patient).map(\.id) == [second.id])
    }
    private func client() -> SupabaseClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DiaryThreeHTTPStub.self]
        return SupabaseClient(supabaseURL: URL(string: "https://diary-three.invalid")!, supabaseKey: "test",
            options: .init(global: .init(session: URLSession(configuration: config))))
    }
    @Test func actualActivationRequestsOnlyConnectionRPCAndDiaryThreeEdge() async throws {
        let service = PatientAssignmentService(client: client())
        for created in [true, false] {
            DiaryThreeHTTPStub.reset(body: Data("""
            {"success":true,"createdNew":\(created),"assignment":{"id":"\(id)","patientId":"\(patient)","therapistId":null,"sessionId":null,"type":"diary_three","createdAt":"2026-09-01T12:00:00Z","completedAt":null,"cancelledAt":null}}
            """.utf8))
            #expect(try await service.activateOngoingAssignment(patientId: patient, type: .diaryThree).id == id)
            let requests = DiaryThreeHTTPStub.recorded()
            #expect(requests.map { $0.url.path } == ["/rest/v1/rpc/is_patient_connected", "/functions/v1/request-patient-diary-three"])
            let body = try JSONSerialization.jsonObject(with: requests[1].body) as! [String: String]
            #expect(body == ["patientId": patient.uuidString])
        }
    }
    @Test func cancellationPreservesHistoryAndEntryEditDeleteNeverMutateAssignment() async throws {
        let client = client()
        let store = DiaryThreeStore(client: client)
        let service = PatientAssignmentService(client: client)
        let owner = DatabaseID.text(patient.uuidString)
        DiaryThreeHTTPStub.reset(body: Data("[\(raw)]".utf8))
        let loaded = try await store.loadEntries(for: owner)
        #expect(loaded.count == 1)
        let get = try #require(DiaryThreeHTTPStub.recorded().first)
        let query = URLComponents(url: get.url, resolvingAgainstBaseURL: false)!.queryItems!
        #expect(query.contains { $0.name == "order" && $0.value?.hasPrefix("created_at.desc") == true })
        DiaryThreeHTTPStub.reset(body: Data("""
        [{"id":"\(id)","patient_id":"\(patient)","therapist_id":null,"session_id":null,"type":"diary_three","created_at":"2026-09-01T12:00:00Z","completed_at":null,"cancelled_at":"2026-09-02T12:00:00Z"}]
        """.utf8))
        try await service.cancelOngoingAssignment(id: id)
        #expect(store.entries(for: owner) == loaded)
        let cancellation = try #require(DiaryThreeHTTPStub.recorded().first)
        #expect(DiaryThreeHTTPStub.recorded().count == 1)
        #expect(cancellation.method == "PATCH" && cancellation.url.path == "/rest/v1/patient_assignments")
        #expect(Set((try JSONSerialization.jsonObject(with: cancellation.body) as! [String: Any]).keys) == ["cancelled_at"])
        let e = loaded[0]
        DiaryThreeHTTPStub.reset(body: Data(raw.utf8))
        let edited = try await store.updateEntry(id: id, patientId: owner, situation: e.situation,
            automaticThoughts: e.automaticThoughts, feelings: e.feelings, thinkingErrors: e.thinkingErrors, alternativeThoughts: e.alternativeThoughts)
        #expect(edited.createdBy == .patient && edited.createdAt == e.createdAt)
        let update = try #require(DiaryThreeHTTPStub.recorded().first)
        #expect(update.method == "PATCH" && update.url.path == "/rest/v1/diary_three_entries")
        #expect(Set((try JSONSerialization.jsonObject(with: update.body) as! [String: Any]).keys) == ["situation", "automatic_thoughts", "feelings", "thinking_errors", "alternative_thoughts", "updated_at"])
        DiaryThreeHTTPStub.reset(body: Data("[{\"id\":\"\(id)\"}]".utf8))
        try await store.deleteEntry(id: id, patientId: owner)
        #expect(store.entries(for: owner).isEmpty)
        let deletion = try #require(DiaryThreeHTTPStub.recorded().first)
        #expect(DiaryThreeHTTPStub.recorded().count == 1)
        #expect(deletion.method == "DELETE" && deletion.url.path == "/rest/v1/diary_three_entries")
        let filters = URLComponents(url: deletion.url, resolvingAgainstBaseURL: false)!.queryItems!
        #expect(filters.contains { $0.name == "id" && $0.value?.lowercased() == "eq.\(id.uuidString.lowercased())" })
        #expect(filters.contains { $0.name == "patient_id" && $0.value?.lowercased() == "eq.\(patient.uuidString.lowercased())" })
    }

}

private final class DiaryThreeHTTPStub: URLProtocol, @unchecked Sendable {
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
        let body = request.url!.path.hasSuffix("is_patient_connected") ? Data("true".utf8) : Self.response; let status = Self.status
        Self.lock.unlock()
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
