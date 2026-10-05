import Foundation
import Supabase
import Testing
@testable import CBTipul

@MainActor @Suite(.serialized)
struct OngoingQuestionnaireTests {
    private let patient = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let assignment = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private func client() -> SupabaseClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [QuestionnaireHTTPStub.self]
        return SupabaseClient(supabaseURL: URL(string: "https://questionnaire.invalid")!, supabaseKey: "test",
            options: .init(global: .init(session: URLSession(configuration: config))))
    }
    private func row(cancelled: Bool = false) -> String {
        """
        {"id":"\(assignment)","patient_id":"\(patient)","type":"questionnaire","created_at":"2026-09-01T12:00:00Z",
        "completed_at":"2026-09-02T12:00:00Z","cancelled_at":\(cancelled ? "\"2026-09-03T12:00:00Z\"" : "null"),"session_id":null}
        """
    }
    private func result(_ id: Int, date: String, owner: UUID? = nil, source: String = "patient") -> String {
        """
        {"id":\(id),"patient_id":"\(owner ?? patient)","created_by":"\(source)","assignment_id":"\(assignment)","answered_date":"\(date)",
        "gad7_answers":[1,1,1,1,1,1,1],"phq9_answers":[0,0,0,0,0,0,0,0,3],"interference_level":2,
        "combined_notes":{"gad7":["private therapist note"]}}
        """
    }
    @Test func activationOnlySendsPatientAndCompletedTimestampDoesNotCloseAccess() async throws {
        await EntitlementTestIsolation.acquire()
        defer { EntitlementTestIsolation.release() }
        let service = PatientAssignmentService(client: client())
        QuestionnaireHTTPStub.reset(body: Data(row().utf8))
        let active = try await service.sendQuestionnaireAssignment(patientId: patient)
        #expect(active.isOpen && active.completedAt != nil && active.sessionId == nil)
        let request = try #require(QuestionnaireHTTPStub.recorded().first)
        #expect(request.url.path == "/functions/v1/request-patient-questionnaire")
        let body = try JSONSerialization.jsonObject(with: request.body) as! [String: Any]
        #expect(Set(body.keys) == ["patientId"])
        #expect(body["patientId"] as? String == patient.uuidString)
        QuestionnaireHTTPStub.reset(body: Data("[\(row())]".utf8))
        #expect(try await service.activeOngoingAssignment(patientId: patient, type: .questionnaire)?.isOpen == true)
        let query = try #require(QuestionnaireHTTPStub.recorded().first?.url.query)
        #expect(!query.contains("completed_at="))
        #expect(query.lowercased().contains("cancelled_at=is.null"))
    }
    @Test func wrappedActivationResponseIsAlsoAccepted() async throws {
        await EntitlementTestIsolation.acquire()
        defer { EntitlementTestIsolation.release() }
        let camel = row().replacingOccurrences(of: "patient_id", with: "patientId")
            .replacingOccurrences(of: "created_at", with: "createdAt").replacingOccurrences(of: "completed_at", with: "completedAt")
            .replacingOccurrences(of: "cancelled_at", with: "cancelledAt").replacingOccurrences(of: "session_id", with: "sessionId")
        QuestionnaireHTTPStub.reset(body: Data("{\"success\":true,\"createdNew\":false,\"assignment\":\(camel)}".utf8))
        #expect(try await PatientAssignmentService(client: client()).sendQuestionnaireAssignment(patientId: patient).id == assignment)
    }
    @Test func repeatedSubmissionsUseSameAssignmentAndKeepQ9AndInterference() async throws {
        await EntitlementTestIsolation.acquire()
        defer { EntitlementTestIsolation.release() }
        let service = PatientAssignmentService(client: client())
        QuestionnaireHTTPStub.reset(body: Data(#"{"success":true,"combinedMoodId":41,"sessionId":null}"#.utf8))
        for _ in 0..<2 {
            try await service.submitPatientQuestionnaire(assignmentId: assignment, gad7Answers: Array(repeating: 1, count: 7),
                phq9Answers: [0,0,0,0,0,0,0,0,3], interferenceLevel: 2)
        }
        let requests = QuestionnaireHTTPStub.recorded()
        #expect(requests.count == 2)
        for request in requests {
            #expect(request.method == "POST" && request.url.path == "/functions/v1/submit-patient-questionnaire")
            let body = try JSONSerialization.jsonObject(with: request.body) as! [String: Any]
            #expect(Set(body.keys) == ["assignmentId", "gad7Answers", "phq9Answers", "interferenceLevel"])
            #expect(body["assignmentId"] as? String == assignment.uuidString)
            #expect((body["phq9Answers"] as? [Int])?.last == 3)
            #expect(body["interferenceLevel"] as? Int == 2)
        }
    }
    @Test func historyKeepsTwoResultsFromOneAssignmentAndExcludesTherapistContent() async throws {
        await EntitlementTestIsolation.acquire()
        defer { EntitlementTestIsolation.release() }
        QuestionnaireHTTPStub.reset(body: Data("[\(result(41, date: "2026-09-02T12:00:00Z")),\(result(42, date: "2026-09-02T12:00:00Z")),\(result(43, date: "2026-09-03", source: "therapist")),\(result(44, date: "2026-09-04", owner: UUID()))]".utf8))
        let history = try await PatientQuestionnaireHistoryService(client: client()).history(patientId: patient)
        #expect(history.allSatisfy { $0.isPatientSubmitted })
        #expect(history.map(\.databaseID) == [.integer(42), .integer(41)])
        #expect(history.allSatisfy { $0.sessionID == nil && $0.questionnaire.gad7Notes.allSatisfy(\.isEmpty) })
        #expect(history[0].questionnaire.gad7Score == 7 && history[0].questionnaire.phq9Score == 3)
        #expect(history[0].questionnaire.phq9Answers[8] == 3)
        let query = try #require(QuestionnaireHTTPStub.recorded().first?.url.query)
        #expect(query.contains("created_by=eq.patient") && query.contains("patient_id=eq."))
        #expect(!query.contains("combined_notes") && !query.contains("session_id="))
        #expect(query.contains("answered_date.desc"))
    }
    @Test func cancellationOnlyUpdatesAccessAndSubmissionFailureDoesNotTouchHistory() async throws {
        await EntitlementTestIsolation.acquire()
        defer { EntitlementTestIsolation.release() }
        let service = PatientAssignmentService(client: client())
        QuestionnaireHTTPStub.reset(body: Data("[\(row(cancelled: true))]".utf8))
        try await service.cancelOngoingAssignment(id: assignment)
        let request = try #require(QuestionnaireHTTPStub.recorded().first)
        #expect(request.method == "PATCH" && request.url.path == "/rest/v1/patient_assignments")
        let patch = try JSONSerialization.jsonObject(with: request.body) as! [String: Any]
        #expect(Set(patch.keys) == ["cancelled_at"])
        QuestionnaireHTTPStub.reset(body: Data(#"{"error":"assignment_cancelled"}"#.utf8), status: 400)
        do {
            try await service.submitPatientQuestionnaire(assignmentId: assignment, gad7Answers: Array(repeating: 0, count: 7), phq9Answers: Array(repeating: 0, count: 9), interferenceLevel: 0)
            Issue.record("Cancelled submission must fail")
        } catch PatientQuestionnaireSubmitError.cancelled { }
        #expect(QuestionnaireHTTPStub.recorded().allSatisfy { $0.method == "POST" })
        QuestionnaireHTTPStub.reset(body: Data("[\(result(42, date: "2026-09-02")),\(result(41, date: "2026-09-01"))]".utf8))
        #expect(try await PatientQuestionnaireHistoryService(client: client()).history(patientId: patient).count == 2)
    }
    @Test func assignedNotificationRefreshesAndRoutesCompletedButActiveAssignment() async throws {
        await EntitlementTestIsolation.acquire()
        defer { EntitlementTestIsolation.release() }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let active = try decoder.decode(PatientAssignment.self, from: Data(row().utf8))
        let cancelled = try decoder.decode(PatientAssignment.self, from: Data(row(cancelled: true).utf8))
        let payload = try #require(AppNotificationPayload.from(userInfo: ["type":"questionnaire_assigned", "patientId":patient.uuidString,
            "assignmentId":assignment.uuidString,"resourceType":"assignment","resourceId":assignment.uuidString]))
        var loads = 0
        let resolved = await PatientQuestionnaireAssignedRouter.resolve(payload: payload, patientId: patient) { loads += 1; return [active] }
        #expect(resolved?.id == assignment && loads == 1)
        #expect(PatientQuestionnaireAssignedRouter.matchingAssignment(in: [cancelled], payload: payload, patientId: patient) == nil)
        #expect(PatientQuestionnaireAssignedRouter.matchingAssignment(in: [active], payload: payload, patientId: UUID()) == nil)
        let coordinator = PatientModeMessageCoordinator.shared
        coordinator.markReady()
        coordinator.handlePushTap(userInfo: ["type":"questionnaire_assigned", "notificationId":UUID().uuidString,
            "patientId":patient.uuidString,"assignmentId":assignment.uuidString,"resourceType":"assignment","resourceId":assignment.uuidString])
        guard case .questionnaireAssigned = coordinator.consumePending() else { Issue.record("Missing questionnaire form route"); return }
        coordinator.markNotReady()
    }
    @Test func twoCompletedNotificationsKeepExactResourceIdentities() throws {
        func payload(_ id: Int) throws -> AppNotificationPayload {
            try #require(AppNotificationPayload.from(userInfo: ["type":"questionnaire_completed", "patientId":patient.uuidString,
                "assignmentId":assignment.uuidString,"resourceType":"questionnaire","resourceId":String(id)]))
        }
        let first = try payload(41), second = try payload(42)
        #expect(first.routingFingerprint != second.routingFingerprint)
        #expect(NotificationRouter.destination(from: first) != NotificationRouter.destination(from: second))
        #expect(QuestionnaireNotificationFocus.combinedMoodID(resourceType: first.resourceType, resourceId: first.resourceId) == .integer(41))
        #expect(QuestionnaireNotificationFocus.combinedMoodID(resourceType: second.resourceType, resourceId: second.resourceId) == .integer(42))
    }
    @Test func therapistSaveStillWritesTheSessionID() async throws {
        await EntitlementTestIsolation.acquire()
        defer { EntitlementTestIsolation.release() }
        let store = PatientStore(client: client(), anonymizeText: { $0 })
        let sessionID = DatabaseID.text(UUID().uuidString)
        let session = Session(databaseID: sessionID)
        let person = Patient(id: .text(patient.uuidString))
        QuestionnaireHTTPStub.reset(body: Data(#"{"id":92}"#.utf8))
        var answers = CombinedMoodQuestionnaire()
        answers.gad7Answers = Array(repeating: 1, count: 7)
        answers.phq9Answers = Array(repeating: 1, count: 9)
        answers.interferenceLevel = 0
        try await store.saveQuestionnaire(answers, for: person, session: session)
        let request = try #require(QuestionnaireHTTPStub.recorded().first)
        #expect(request.url.path == "/rest/v1/CombinedMood" && request.method == "POST")
        let body = try JSONSerialization.jsonObject(with: request.body) as! [String: Any]
        #expect(body["session_id"] as? String == sessionID.queryValue)
        #expect(body["assignment_id"] == nil && body["created_by"] == nil)
        #expect(store.cachedQuestionnaires(for: person)?.first?.sessionID == sessionID)
    }
    @Test func therapistSessionAssociationAndScoringSurviveRoundTrip() throws {
        var answers = CombinedMoodQuestionnaire()
        answers.gad7Answers = Array(repeating: 3, count: 7)
        answers.phq9Answers = Array(repeating: 3, count: 9)
        answers.interferenceLevel = 3
        let session = DatabaseID.text(UUID().uuidString)
        let record = CompletedQuestionnaire(databaseID: .integer(91), sessionID: session, answeredDate: .now, questionnaire: answers)
        let restored = try JSONDecoder().decode(CompletedQuestionnaire.self, from: JSONEncoder().encode(record))
        #expect(restored.sessionID == session && restored.questionnaire == answers)
        #expect(restored.questionnaire.gad7Score == 21 && restored.questionnaire.phq9Score == 27)
        #expect(restored.questionnaire.phq9Answers[8] == 3)
    }
}

private final class QuestionnaireHTTPStub: URLProtocol, @unchecked Sendable {
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
