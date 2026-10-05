import Foundation
import Testing
import Supabase
@testable import CBTipul

@MainActor @Suite(.serialized)
struct EntitlementTests {
    private func context(_ access: EntitlementAccess, patient: Bool = false) -> AppContext {
        AppContext(version: 1, role: patient ? .patient : .therapist, activation: patient ? .active : nil,
                   patientId: patient ? UUID() : nil, entitlement: .init(access: access))
    }
    @Test func decodingPreservesRoutingAndRejectsUnknownPermissions() throws {
        for value in ["full", "read_only", "unexpected"] {
            let decoded = try JSONDecoder().decode(AppContext.self, from: Data("{\"version\":1,\"role\":\"therapist\",\"entitlement\":{\"access\":\"\(value)\"}}".utf8))
            #expect(decoded.role == .therapist)
            #expect(decoded.entitlement?.canWrite == (value == "unexpected" ? nil : value == "full"))
        }
        for value in ["null", "42", "{}", "{\"access\":false}"] {
            let decoded = try JSONDecoder().decode(AppContext.self, from: Data("{\"version\":1,\"role\":\"patient\",\"activation\":\"active\",\"patientId\":\"22222222-2222-2222-2222-222222222222\",\"entitlement\":\(value)}".utf8))
            #expect(decoded.isActivePatient && decoded.entitlement == nil)
        }
        let incomplete = try JSONDecoder().decode(AppContext.self, from: Data(#"{"version":1,"role":"patient","activation":"incomplete"}"#.utf8))
        #expect(incomplete.isIncompletePatient && incomplete.entitlement == nil)
    }
    @Test func refreshAndIdentityTransitions() throws {
        let state = EntitlementState()
        state.setIdentity("one")
        state.apply(context(.full)); #expect(state.canWrite && state.canUseAI && state.canPatientWrite)
        state.apply(context(.readOnly)); #expect(!state.canWrite && !state.canUseAI)
        #expect(!state.allowMutation() && state.showExplanation)
        state.apply(context(.full)); try state.requireWrite()
        state.setIdentity("two"); #expect(!state.canWrite && state.role == nil && !state.showExplanation)
        state.apply(context(.readOnly, patient: true)); #expect(state.role == .patient && !state.canPatientWrite)
        state.invalidate(); #expect(!state.canWrite)
        state.apply(AppContext(version: 1, role: .patient, activation: .incomplete, patientId: nil))
        #expect(state.access == nil)
    }
    @Test func readOnlyDemoAllowsLocalEditsButNeverRemoteWrites() async throws {
        await EntitlementTestIsolation.acquire()
        defer { EntitlementTestIsolation.release() }
        let state = EntitlementState.shared
        state.apply(context(.readOnly))
        let client = SupabaseClient(supabaseURL: URL(string: "https://example.invalid")!, supabaseKey: "test")
        let store = PatientStore(client: client)
        store.enterDemoMode()
        #expect(state.canWrite && !state.canUseAI && !state.canPatientWrite)
        #expect(throws: EntitlementDenied.self) { try state.requireWrite() }
        try await store.addPatient(firstName: "Sample", lastName: "Test")
        let patient = try #require(store.patients.last)
        let session = Session()
        session.notes = "Locally written sample summary"
        try await store.addSession(session, for: patient)
        #expect(patient.sessions.contains { $0.id == session.id })
        try await store.updateSession(session)
        let localOnly = Session()
        localOnly.notes = "Local-only sample session"
        patient.sessions.append(localOnly)
        try await store.updateSession(localOnly)
        #expect(state.allowMutation())
        #expect(!state.allowMutation(allowLocalDemo: false))
        try await store.deleteSession(session, for: patient)
        try await store.deletePatient(patient)
        state.apply(context(.readOnly))
        #expect(state.canWrite) // A context refresh does not end the demo.
        state.setLocalDemo(false)
        #expect(!state.canWrite)
        #expect(throws: EntitlementDenied.self) { try state.requireWrite(localDemo: true) }
        state.setLocalDemo(true)
        state.setIdentity("another-account")
        #expect(!state.canWrite && !state.isLocalDemo)
    }
    @Test func mutationsDeniedBeforeNetworkAndHistoryRetained() async throws {
        await EntitlementTestIsolation.acquire()
        defer { EntitlementTestIsolation.release() }
        let state = EntitlementState.shared
        let client = SupabaseClient(supabaseURL: URL(string: "https://example.invalid")!, supabaseKey: "test")
        let diary = DiaryOneStore(client: client)
        let patient = DatabaseID.text("demo-entitlement")
        state.apply(context(.full))
        let entry = try await diary.createEntry(patientId: patient, event: "existing", automaticThoughts: ["thought"], feelings: [.init(name: "עצוב", intensity: 80)], behaviour: "existing", physicalSymptoms: nil)
        state.apply(context(.readOnly))
        let store = PatientStore(client: client)
        let assignments = PatientAssignmentService(client: client)
        func denied(_ operation: () async throws -> Void) async {
            do { try await operation(); Issue.record("Mutation unexpectedly succeeded") }
            catch { #expect(error is EntitlementDenied) }
        }
        await denied { _ = try await SupabaseChatService(client: client).complete(systemPrompt: "", userMessage: "") }
        await denied { _ = try await WhisperService(client: client).analyzeSession(sessionNotes: "") }
        await denied { _ = try await WhisperService(client: client).transcribe(fileURL: URL(fileURLWithPath: "/missing")) }
        await denied { _ = try await ClinicalTextAnonymizer(client: client).anonymize("test") }
        await denied { try await store.addPatient(firstName: "test", lastName: "test") }
        await denied { try await store.addSession(Session(), for: Patient(id: patient)) }
        await denied { try await store.updateSession(Session()) }
        await denied { try await store.deleteSession(Session(), for: Patient(id: patient)) }
        for type: PatientAssignmentType in [.questionnaire, .diaryOne, .diaryTwo, .diaryThree] {
            await denied { _ = try await assignments.activateOngoingAssignment(patientId: UUID(), type: type) }
        }
        await denied { try await diary.deleteEntry(id: entry.id, patientId: patient) }
        #expect(try await diary.loadEntries(for: patient).map(\.id) == [entry.id])
        state.apply(context(.readOnly, patient: true))
        await denied { try await assignments.submitPatientQuestionnaire(assignmentId: UUID(), gad7Answers: [], phq9Answers: [], interferenceLevel: 0) }
        await denied { try await PatientDiaryOneService(client: client).submitEntry(event: "", automaticThoughts: [], feelings: [], behaviour: "", physicalSymptoms: nil) }
        await denied { _ = try await PatientDiaryTwoService(client: client).submitEntry(event: "", automaticThoughts: [], feelings: [], thinkingErrors: [], alternativeThoughts: []) }
        await denied { _ = try await PatientDiaryThreeService(client: client).submitEntry(situation: "", automaticThoughts: [], feelings: [], thinkingErrors: [], alternativeThoughts: []) }
    }
}

/// Shared production permission state must not leak between concurrently scheduled integration tests.
@MainActor enum EntitlementTestIsolation {
    private static var locked = false
    private static var waiting: [CheckedContinuation<Void, Never>] = []
    static func acquire() async {
        if locked { await withCheckedContinuation { waiting.append($0) } }
        else { locked = true }
        EntitlementState.shared.clear()
        EntitlementState.shared.apply(AppContext(version: 1, role: .therapist, activation: nil, patientId: nil, entitlement: .init(access: .full)))
    }
    static func release() {
        EntitlementState.shared.clear()
        if waiting.isEmpty { locked = false }
        else { waiting.removeFirst().resume() }
    }
}
