import Foundation
import Supabase

struct WebWorkspaceSummary: Decodable, Identifiable {
    let id: String
    let started_at: String
    let finished_at: String
    let reference_label: String?
    let item_count: Int
    let has_notes: Bool
}
struct WebWorkspace: Decodable, Identifiable {
    let id: String
    let status: String
    let started_at: String
    let finished_at: String?
    let reference_label: String?
    let payload: WebWorkspacePayload
}
struct WebWorkspacePayload: Decodable {
    let version: Int
    let notes: String
    let items: [WebWorksheet]
    var hasNotes: Bool { !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var hasQuestionnaire: Bool { items.contains { if case .questionnaire = $0.content { true } else { false } } }
}
struct WebQuestionnaire: Decodable {
    let gad7_answers: [Int]
    let phq9_answers: [Int]
    let interference_level: Int
    let notes: String?
    var questionnaire: CombinedMoodQuestionnaire {
        CombinedMoodQuestionnaire(gad7Answers: gad7_answers.map(Optional.some), phq9Answers: phq9_answers.map(Optional.some), interferenceLevel: interference_level)
    }
    var flagsQuestionNine: Bool { phq9_answers.count == 9 && phq9_answers[8] > 0 }
}
struct WebDiary: Decodable {
    let event: String
    let automatic_thoughts: [String]
    let feelings: [DiaryFeeling]
    let behaviour: String?
    let physical_symptoms: String?
    let thinking_errors: [ThinkingError]?
    let alternative_thoughts: [String]?
}
struct WebDiaryThree: Decodable {
    let situation: String
    let automatic_thoughts: [DiaryThreeAutomaticThought]
    let feelings: [DiaryThreeFeeling]
    let thinking_errors: [ThinkingError]
    let alternative_thoughts: [DiaryThreeAlternativeThought]
}
struct WebWorksheet: Decodable, Identifiable {
    enum Content { case questionnaire(WebQuestionnaire), diaryOne(WebDiary), diaryTwo(WebDiary), diaryThree(WebDiaryThree) }
    let id: String
    let completed_at: String
    let measurement_date: String?
    let content: Content
    enum CodingKeys: String, CodingKey { case id, type, completed_at, measurement_date, data }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        guard UUID(uuidString: id) != nil else { throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Invalid worksheet ID") }
        completed_at = try c.decode(String.self, forKey: .completed_at)
        measurement_date = try c.decodeIfPresent(String.self, forKey: .measurement_date)
        switch try c.decode(String.self, forKey: .type) {
        case "questionnaire":
            let q = try c.decode(WebQuestionnaire.self, forKey: .data)
            guard q.gad7_answers.count == 7, q.phq9_answers.count == 9,
                  (q.gad7_answers + q.phq9_answers + [q.interference_level]).allSatisfy({ (0...3).contains($0) }), measurement_date != nil else {
                throw DecodingError.dataCorruptedError(forKey: .data, in: c, debugDescription: "Invalid questionnaire")
            }
            content = .questionnaire(q)
        case "diary_one": content = .diaryOne(try c.decode(WebDiary.self, forKey: .data))
        case "diary_two": content = .diaryTwo(try c.decode(WebDiary.self, forKey: .data))
        case "diary_three": content = .diaryThree(try c.decode(WebDiaryThree.self, forKey: .data))
        default: throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "Unknown worksheet")
        }
    }
    var title: String {
        switch content {
        case .questionnaire: L10n.questionnairesTitle
        case .diaryOne: L10n.diaryOneTitle
        case .diaryTwo: L10n.diaryTwoTitle
        case .diaryThree: L10n.diaryThreeTitle
        }
    }
}

/// Contains identifiers and routing choices only. Never includes local patient names.
struct WebAssociationRequest: Codable, Equatable {
    let p_workspace_id: String
    let p_patient_id: String
    let p_existing_session_id: String?
    let p_create_session: Bool
    let p_link_questionnaire: Bool
    let p_session_date: String?
    let p_session_type: String?

    func validate(hasNotes: Bool, hasQuestionnaire: Bool) throws {
        let hasTarget = p_create_session || p_existing_session_id != nil
        guard UUID(uuidString: p_patient_id) != nil,
              !(p_create_session && p_existing_session_id != nil),
              !p_link_questionnaire || hasQuestionnaire,
              hasTarget == (hasNotes || p_link_questionnaire),
              p_create_session ? (p_session_date != nil && p_session_type?.isEmpty == false) : (p_session_date == nil && p_session_type == nil)
        else { throw WebWorkspaceFailure.invalidSelection }
    }
}
struct WebAssociationResult: Decodable {
    struct Resource: Decodable { let item_id: String; let type: String; let id: String }
    let workspace_id: String
    let patient_id: String
    let session_id: String?
    let resources: [Resource]
}
enum WebWorkspaceFailure: Error { case invalidSelection, unavailable, conflict, patientMissing, sessionMissing, readOnly, uncertain }
extension WebWorkspaceFailure {
    static func classify(_ error: Error) -> WebWorkspaceFailure {
        guard let error = error as? PostgrestError else { return .uncertain }
        switch error.message {
        case "session_already_has_questionnaire": return .conflict
        case "workspace_not_found", "workspace_not_pending", "already_associated": return .unavailable
        case "patient_not_found": return .patientMissing
        case "session_not_found": return .sessionMissing
        case "read_only", "unauthorized", "therapist_access_required": return .readOnly
        case "invalid_association", "session_required", "unused_session_target", "new_session_details_required", "unexpected_session_details", "no_questionnaire": return .invalidSelection
        default: return .uncertain
        }
    }
    var message: String {
        switch self {
        case .invalidSelection: L10n.wwSelectionRequired
        case .unavailable: L10n.wwUnavailable
        case .conflict: L10n.wwConflict
        case .patientMissing: L10n.wwPatientMissing
        case .sessionMissing: L10n.wwSessionMissing
        case .readOnly: L10n.entitlementReadOnlyExplanation
        case .uncertain: L10n.wwUncertain
        }
    }
}

@MainActor @Observable final class WebWorkspaceStore {
    private let rpc: (String, Data) async throws -> Data
    private let currentUser: () async throws -> String
    private let canWrite: () -> Bool
    private var lastPatient: String?
    private let defaults: UserDefaults
    private(set) var items: [WebWorkspaceSummary] = []
    private(set) var isLoading = false
    private(set) var failed = false
    private(set) var busyIDs: Set<String> = []
    private(set) var closedIDs: Set<String> = []
    private(set) var requests: [String: WebAssociationRequest] = [:]
    private var owner: String?
    private var generation = 0
    var refreshRecords: ((String) async -> Bool)?
    private(set) var refreshFailed = false
    init(client: SupabaseClient, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.currentUser = { try await client.auth.session.user.id.uuidString }
        self.canWrite = { EntitlementState.shared.access == .full }
        self.rpc = { name, data in
            let params = try JSONDecoder().decode([String: AnyJSON].self, from: data)
            return try await client.rpc(name, params: params).execute().data
        }
    }
    init(defaults: UserDefaults, currentUser: @escaping () async throws -> String,
         canWrite: @escaping () -> Bool, rpc: @escaping (String, Data) async throws -> Data) {
        self.defaults = defaults; self.currentUser = currentUser; self.canWrite = canWrite; self.rpc = rpc
    }
    private func call<P: Encodable, T: Decodable>(_ name: String, _ params: P) async throws -> T {
        let data = try await rpc(name, JSONEncoder().encode(params))
        return try JSONDecoder().decode(T.self, from: data)
    }
    func clear() { generation += 1; owner = nil; lastPatient = nil; items = []; requests = [:]; failed = false; refreshFailed = false; isLoading = false; busyIDs = []; closedIDs = [] }
    private func identify() async throws -> String {
        let id = try await currentUser()
        if owner != id {
            clear(); owner = id
            if let data = defaults.data(forKey: "webWorkspace.requests.\(id)") { requests = (try? JSONDecoder().decode([String: WebAssociationRequest].self, from: data)) ?? [:] }
        }
        return id
    }
    private func persist() {
        guard let owner, let data = try? JSONEncoder().encode(requests) else { return }
        defaults.set(data, forKey: "webWorkspace.requests.\(owner)")
    }
    func refresh() async {
        guard !isLoading else { return }
        do {
            let user = try await identify()
            let revision = generation
            isLoading = true
            defer { if generation == revision { isLoading = false } }
            var loaded: [WebWorkspaceSummary] = []
            while true {
                struct Page: Encodable { let p_limit: Int; let p_offset: Int }
                let page: [WebWorkspaceSummary] = try await call("list_pending_web_workspaces", Page(p_limit: 100, p_offset: loaded.count))
                loaded += page
                if page.count < 100 { break }
            }
            guard owner == user, generation == revision else { return }
            var seen = Set<String>()
            items = loaded.filter { seen.insert($0.id).inserted }; failed = false
        } catch { if !Task.isCancelled, owner != nil { failed = true } }
    }
    func load(_ id: String) async throws -> WebWorkspace {
        _ = try await identify()
        struct ID: Encodable { let p_workspace_id: String }
        let user = owner
        let workspace: WebWorkspace = try await call("get_pending_web_workspace", ID(p_workspace_id: id))
        guard owner == user, workspace.payload.version == 1, workspace.status == "pending" else { throw WebWorkspaceFailure.unavailable }
        return workspace
    }
    func associate(_ proposed: WebAssociationRequest) async throws {
        let user = try await identify()
        let id = proposed.p_workspace_id
        guard !closedIDs.contains(id) else { throw WebWorkspaceFailure.unavailable }
        guard !busyIDs.contains(id) else { throw WebWorkspaceFailure.uncertain }
        guard canWrite() else { throw WebWorkspaceFailure.readOnly }
        let request = requests[id] ?? proposed
        requests[id] = request; persist()
        busyIDs.insert(id)
        defer { busyIDs.remove(id) }
        do {
            let result: WebAssociationResult = try await call("associate_web_workspace", request)
            guard owner == user else { return }
            requests[id] = nil; persist()
            items.removeAll { $0.id == id }
            lastPatient = result.patient_id
            await refreshAfterSuccess()
        } catch {
            let failure = WebWorkspaceFailure.classify(error)
            if owner == user, failure != .uncertain { requests[id] = nil; persist() }
            if failure == .unavailable { markUnavailable(id); await refresh() }
            throw failure
        }
    }
    func markUnavailable(_ id: String) { closedIDs.insert(id); items.removeAll { $0.id == id } }
    func refreshAfterSuccess() async {
        if let lastPatient { refreshFailed = !(await refreshRecords?(lastPatient) ?? true) }
        await refresh()
    }
    func discard(_ id: String) async throws {
        let user = try await identify()
        guard canWrite() else { throw WebWorkspaceFailure.readOnly }
        guard !busyIDs.contains(id), requests[id] == nil else { throw WebWorkspaceFailure.uncertain }
        busyIDs.insert(id); defer { busyIDs.remove(id) }
        struct ID: Encodable { let p_workspace_id: String }
        do { _ = try await rpc("discard_web_workspace", JSONEncoder().encode(ID(p_workspace_id: id))) }
        catch {
            let failure = WebWorkspaceFailure.classify(error)
            if failure == .unavailable { markUnavailable(id); await refresh() }
            throw failure
        }
        guard owner == user else { return }
        items.removeAll { $0.id == id }
        await NotificationStore.shared?.refresh()
        await refresh()
    }
}
