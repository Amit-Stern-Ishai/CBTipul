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
    var p_questionnaire_choice: WebQuestionnaireChoice? = nil
    var p_preview_token: String? = nil
    var p_acknowledge_existing_notes = false

    func validate(hasNotes: Bool, hasQuestionnaire _: Bool) throws {
        let hasTarget = p_create_session || p_existing_session_id != nil
        guard UUID(uuidString: p_patient_id) != nil,
              !(p_create_session && p_existing_session_id != nil),
              p_link_questionnaire || p_questionnaire_choice == nil,
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
    let linked_questionnaire_id: String?
    let notes_appended: Bool
}
enum WebWorkspaceFailure: Error { case invalidSelection, unavailable, conflict, patientMissing, sessionMissing, readOnly, uncertain, previewChanged, rejected, serviceUnavailable, questionnaireChanged }
extension WebWorkspaceFailure {
    static func classify(_ error: Error) -> WebWorkspaceFailure {
        if let failure = error as? WebWorkspaceFailure { return failure }
        guard let error = error as? PostgrestError else { return .uncertain }
        if ["PGRST202", "42883"].contains(error.code ?? "") { return .serviceUnavailable }
        switch error.message {
        case "association_preview_changed", "notes_append_confirmation_required": return .previewChanged
        case "questionnaire_choice_required", "invalid_questionnaire_choice", "unexpected_questionnaire_choice", "questionnaire_not_selectable", "questionnaire_ownership_mismatch": return .questionnaireChanged
        case "session_already_has_questionnaire": return .conflict
        case "workspace_not_found", "workspace_not_pending", "already_associated": return .unavailable
        case "patient_not_found": return .patientMissing
        case "session_not_found": return .sessionMissing
        case "read_only", "unauthorized", "therapist_access_required": return .readOnly
        case "invalid_association", "session_required", "unused_session_target", "new_session_details_required", "unexpected_session_details", "no_questionnaire": return .invalidSelection
        default:
            let code = error.code ?? ""
            return code.hasPrefix("PGRST") || code.range(of: "^[0-9A-Z]{5}$", options: .regularExpression) != nil ? .rejected : .uncertain
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
        case .previewChanged: L10n.wwPreviewChanged
        case .rejected: L10n.wwSaveRejected
        case .serviceUnavailable: L10n.wwSaveServiceUnavailable
        case .questionnaireChanged: L10n.wwChoiceChanged
        }
    }
}

@MainActor @Observable final class WebWorkspaceStore {
    private let rpc: (String, Data) async throws -> Data
    private let currentUser: () async throws -> String
    private let canWrite: () -> Bool
    private var lastPatient: String?
    private(set) var linkedQuestionnaireID: String?
    private let defaults: UserDefaults
    private(set) var items: [WebWorkspaceSummary] = []
    /// Include uncertain retries without counting the same pending workspace twice.
    var associationCount: Int { Set(items.map(\.id)).union(requests.keys).count }
    private(set) var isLoading = false
    private(set) var failed = false
    private(set) var busyIDs: Set<String> = []
    private(set) var closedIDs: Set<String> = []
    private(set) var requests: [String: WebAssociationRequest] = [:]
    private var owner: String?
    private var generation = 0
    var refreshRecords: ((String) async -> Bool)?
    private(set) var refreshFailed = false
    var associationSaved = false
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
    func clear() { associationSaved = false; linkedQuestionnaireID = nil; generation += 1; owner = nil; lastPatient = nil; items = []; requests = [:]; failed = false; refreshFailed = false; isLoading = false; busyIDs = []; closedIDs = [] }
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
            items = loaded.filter { !closedIDs.contains($0.id) && seen.insert($0.id).inserted }; failed = false
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
    func preview(_ target: WebAssociationTarget) async throws -> WebAssociationPreview {
        let user = try await identify()
        guard target.isValid else { throw WebWorkspaceFailure.invalidSelection }
        let result: WebAssociationPreview = try await call("preview_web_workspace_association", target)
        guard owner == user, result.workspace_id.lowercased() == target.p_workspace_id.lowercased(), result.patient_id.lowercased() == target.p_patient_id.lowercased(), result.session_id?.lowercased() == target.p_existing_session_id?.lowercased() else { throw WebWorkspaceFailure.previewChanged }
        return result
    }
    func associate(_ proposed: WebAssociationRequest) async throws {
        let user = try await identify()
        let id = proposed.p_workspace_id
        guard !closedIDs.contains(id) else { throw WebWorkspaceFailure.unavailable }
        guard !busyIDs.contains(id) else { throw WebWorkspaceFailure.uncertain }
        guard canWrite() else { throw WebWorkspaceFailure.readOnly }
        let request = requests[id] ?? proposed
        guard request.p_preview_token?.isEmpty == false else { requests[id] = nil; persist(); throw WebWorkspaceFailure.previewChanged }
        requests[id] = request; persist()
        busyIDs.insert(id)
        defer { busyIDs.remove(id) }
        do {
            let result: WebAssociationResult = try await call("associate_web_workspace_v2", request)
            guard owner == user else { return }
            requests[id] = nil; persist()
            items.removeAll { $0.id == id }
            closedIDs.insert(id)
            associationSaved = true
            lastPatient = result.patient_id
            linkedQuestionnaireID = result.linked_questionnaire_id
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

/// Preview target parameters are deliberately separate from mutation-only choices.
struct WebAssociationTarget: Codable, Equatable, Hashable {
    let p_workspace_id: String
    let p_patient_id: String
    let p_existing_session_id: String?
    let p_create_session: Bool
    let p_session_date: String?
    let p_session_type: String?
    var isValid: Bool {
        UUID(uuidString: p_workspace_id) != nil && UUID(uuidString: p_patient_id) != nil
        && !(p_create_session && p_existing_session_id != nil)
        && (p_existing_session_id == nil || UUID(uuidString: p_existing_session_id!) != nil)
        && (p_create_session ? (p_session_date != nil && p_session_type?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) : (p_session_date == nil && p_session_type == nil))
    }
}

/// Encode only the two keys permitted by the SQL choice contract.
struct WebQuestionnaireChoice: Codable, Equatable {
    let source: String
    let item_id: String?
    let id: String?
    static func incoming(_ item: String) -> Self { .init(source: "incoming", item_id: item, id: nil) }
    static func existing(_ id: String) -> Self { .init(source: "existing", item_id: nil, id: id) }
    enum CodingKeys: String, CodingKey { case source, item_id, id }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(source, forKey: .source)
        if source == "incoming" { try c.encode(item_id, forKey: .item_id) }
        else { try c.encode(id, forKey: .id) }
    }
}
struct WebAssociationCandidate: Decodable, Identifiable {
    let source: String
    let recordID: String?
    let item_id: String?
    let measurement_date: String?
    let recorded_at: String?
    let time_kind: String?
    let session_id: String?
    let selectable: Bool
    let is_current_session_questionnaire: Bool
    let gad7_answers: [Int?]?
    let phq9_answers: [Int?]?
    let interference_level: Int?
    let gad7_score: Int?
    let phq9_score: Int?
    enum CodingKeys: String, CodingKey { case source, recordID = "id", item_id, measurement_date, recorded_at, time_kind, session_id, selectable, is_current_session_questionnaire, gad7_answers, phq9_answers, interference_level, gad7_score, phq9_score }
    var id: String { source + ":" + (recordID ?? item_id ?? "missing") }
    var choice: WebQuestionnaireChoice? {
        if source == "incoming", let item_id, UUID(uuidString: item_id) != nil { return .incoming(item_id) }
        if source == "existing", let recordID, !recordID.isEmpty, recordID.allSatisfy(\.isNumber) { return .existing(recordID) }
        return nil
    }
    var flagsQuestionNine: Bool {
        guard let values = phq9_answers, values.indices.contains(8), let value = values[8] else { return false }
        return value > 0
    }
    var hasCompleteAnswers: Bool { Self.valid(gad7_answers, 7) && Self.valid(phq9_answers, 9) }
    private static func valid(_ values: [Int?]?, _ count: Int) -> Bool { values?.count == count && values?.allSatisfy { (0...3).contains($0 ?? -1) } == true }
    var questionnaire: CombinedMoodQuestionnaire {
        CombinedMoodQuestionnaire(gad7Answers: (0..<7).map { i in gad7_answers?.indices.contains(i) == true ? gad7_answers![i] : nil }, phq9Answers: (0..<9).map { i in phq9_answers?.indices.contains(i) == true ? phq9_answers![i] : nil }, interferenceLevel: interference_level)
    }
}
struct WebAssociationPreview: Decodable {
    let workspace_id: String
    let patient_id: String
    let session_id: String?
    let preview_token: String
    let has_notes: Bool
    let session_has_notes: Bool
    let notes_will_append: Bool
    let candidate_measurement_date: String?
    let questionnaires: [WebAssociationCandidate]
    let selectable_questionnaire_count: Int
    let requires_questionnaire_choice: Bool
    let current_session_questionnaire_id: String?
    var eligibleQuestionnaires: [WebAssociationCandidate] { questionnaires.filter { $0.selectable && $0.choice != nil } }
    func resolvedChoice(_ explicitChoice: WebQuestionnaireChoice?) -> WebQuestionnaireChoice? {
        let eligible = eligibleQuestionnaires
        guard eligible.count == selectable_questionnaire_count else { return nil }
        if eligible.count == 1 { return eligible[0].choice }
        return explicitChoice.flatMap { selected in eligible.contains { $0.choice == selected } ? selected : nil }
    }
    func canContinueSaving(_ request: WebAssociationRequest, choice: WebQuestionnaireChoice?, appendWasVisible: Bool) -> Bool {
        (try? request.validate(hasNotes: has_notes, hasQuestionnaire: true)) != nil && (!notes_will_append || appendWasVisible) && (!request.p_link_questionnaire || choice == request.p_questionnaire_choice) && (try? prepare(request, choice: choice)) != nil
    }
    func confirmed(_ request: WebAssociationRequest) throws -> WebAssociationRequest {
        guard request.p_preview_token == preview_token else { throw WebWorkspaceFailure.previewChanged }
        var result = try prepare(request, choice: request.p_questionnaire_choice)
        result.p_acknowledge_existing_notes = notes_will_append
        return result
    }
    func prepare(_ base: WebAssociationRequest, choice: WebQuestionnaireChoice?) throws -> WebAssociationRequest {
        guard workspace_id.lowercased() == base.p_workspace_id.lowercased(), patient_id.lowercased() == base.p_patient_id.lowercased(), session_id?.lowercased() == base.p_existing_session_id?.lowercased(), !preview_token.isEmpty else { throw WebWorkspaceFailure.previewChanged }
        if base.p_link_questionnaire {
            if let choice {
                guard questionnaires.contains(where: { $0.selectable && $0.choice == choice }) else { throw WebWorkspaceFailure.invalidSelection }
            } else if selectable_questionnaire_count != 1 { throw WebWorkspaceFailure.invalidSelection }
        }
        var r = base
        r.p_questionnaire_choice = base.p_link_questionnaire ? choice : nil
        r.p_preview_token = preview_token
        r.p_acknowledge_existing_notes = false
        return r
    }
}
extension WebAssociationRequest {
    var target: WebAssociationTarget { .init(p_workspace_id: p_workspace_id, p_patient_id: p_patient_id, p_existing_session_id: p_existing_session_id, p_create_session: p_create_session, p_session_date: p_session_date, p_session_type: p_session_type) }
    enum CodingKeys: String, CodingKey { case p_workspace_id, p_patient_id, p_existing_session_id, p_create_session, p_link_questionnaire, p_session_date, p_session_type, p_questionnaire_choice, p_preview_token, p_acknowledge_existing_notes }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        p_workspace_id = try c.decode(String.self, forKey: .p_workspace_id); p_patient_id = try c.decode(String.self, forKey: .p_patient_id)
        p_existing_session_id = try c.decodeIfPresent(String.self, forKey: .p_existing_session_id); p_create_session = try c.decode(Bool.self, forKey: .p_create_session)
        p_link_questionnaire = try c.decode(Bool.self, forKey: .p_link_questionnaire); p_session_date = try c.decodeIfPresent(String.self, forKey: .p_session_date); p_session_type = try c.decodeIfPresent(String.self, forKey: .p_session_type)
        p_questionnaire_choice = try c.decodeIfPresent(WebQuestionnaireChoice.self, forKey: .p_questionnaire_choice); p_preview_token = try c.decodeIfPresent(String.self, forKey: .p_preview_token)
        p_acknowledge_existing_notes = try c.decodeIfPresent(Bool.self, forKey: .p_acknowledge_existing_notes) ?? false
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_workspace_id, forKey: .p_workspace_id); try c.encode(p_patient_id, forKey: .p_patient_id)
        try c.encode(p_existing_session_id, forKey: .p_existing_session_id); try c.encode(p_create_session, forKey: .p_create_session)
        try c.encode(p_link_questionnaire, forKey: .p_link_questionnaire); try c.encode(p_session_date, forKey: .p_session_date); try c.encode(p_session_type, forKey: .p_session_type)
        try c.encode(p_questionnaire_choice, forKey: .p_questionnaire_choice); try c.encode(p_preview_token, forKey: .p_preview_token); try c.encode(p_acknowledge_existing_notes, forKey: .p_acknowledge_existing_notes)
    }
}
