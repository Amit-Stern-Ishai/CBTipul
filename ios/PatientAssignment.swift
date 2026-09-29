import Foundation
import Functions
import OSLog
import Supabase

/// Kinds stored in `patient_assignments.type`. Extra cases are reserved
/// for upcoming diary and Patient Mode work.
enum PatientAssignmentType: String, Codable, Sendable {
    case questionnaire
    case diaryOne = "diary_one"
    case diaryTwo = "diary_two"
}

enum PatientQuestionnaireSubmitError: LocalizedError {
    case alreadyCompleted
    case cancelled
    case accessDenied
    case invalidAnswers
    case failed

    var errorDescription: String? {
        switch self {
        case .alreadyCompleted, .failed, .invalidAnswers:
            L10n.patientQuestionnaireSubmitError
        case .cancelled:
            L10n.patientQuestionnaireCancelledError
        case .accessDenied:
            L10n.patientQuestionnaireAccessDeniedError
        }
    }
}

/// Request body for `submit-patient-questionnaire`. CamelCase only;
/// patient/therapist/session IDs are not sent.
private struct SubmitPatientQuestionnaireRequest: Encodable {
    let assignmentId: UUID
    let gad7Answers: [Int]
    let phq9Answers: [Int]
    let interferenceLevel: Int
}

private struct RequestPatientQuestionnaireRequest: Encodable {
    let patientId: UUID
    let sessionId: UUID?

    enum CodingKeys: String, CodingKey {
        case patientId
        case sessionId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(patientId, forKey: .patientId)
        // Standalone requests must send JSON null, not omit the key. The Edge
        // Function forwards this as RPC `p_session_id`.
        if let sessionId {
            try container.encode(sessionId, forKey: .sessionId)
        } else {
            try container.encodeNil(forKey: .sessionId)
        }
    }
}

private struct RequestPatientQuestionnaireResponse: Decodable {
    let id: UUID
    let patientId: UUID
    let therapistId: UUID?
    let sessionId: UUID?
    let typeValue: String
    let createdAt: String
    let completedAt: String?
    let cancelledAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case therapistId = "therapist_id"
        case sessionId = "session_id"
        case typeValue = "type"
        case createdAt = "created_at"
        case completedAt = "completed_at"
        case cancelledAt = "cancelled_at"
    }
}

/// CamelCase body for `request-patient-diary-one`. IDs besides `patientId`
/// are not sent; the Edge Function infers therapist and assignment state.
private struct RequestPatientDiaryOneRequest: Encodable {
    let patientId: UUID
}

/// Edge Function assignment object. CamelCase keys — not PostgREST rows.
private struct RequestPatientDiaryOneAssignmentDTO: Decodable {
    let id: UUID
    let patientId: UUID
    let therapistId: UUID?
    let sessionId: UUID?
    let typeValue: String
    let createdAt: String
    let completedAt: String?
    let cancelledAt: String?

    enum CodingKeys: String, CodingKey {
        case id, patientId, therapistId, sessionId, createdAt, completedAt, cancelledAt
        case typeValue = "type"
    }
}

private struct RequestPatientDiaryOneResponse: Decodable {
    let success: Bool
    let assignment: RequestPatientDiaryOneAssignmentDTO
    let createdNew: Bool
}

/// Diary 1 activation via `request-patient-diary-one`. Decode/error helpers
/// stay off `PatientAssignment` so PostgREST snake_case decoding is unchanged.
enum PatientDiaryOneActivation {
    static let functionName = "request-patient-diary-one"

    static func usesEdgeFunction(_ type: PatientAssignmentType) -> Bool {
        type == .diaryOne
    }

    static func usesDirectInsert(_ type: PatientAssignmentType) -> Bool {
        switch type {
        case .diaryTwo:
            true
        case .diaryOne, .questionnaire:
            false
        }
    }

    static func requestJSON(patientId: UUID) throws -> Data {
        try JSONEncoder().encode(RequestPatientDiaryOneRequest(patientId: patientId))
    }

    static func assignment(fromResponseData data: Data) throws -> PatientAssignment {
        let response = try JSONDecoder().decode(RequestPatientDiaryOneResponse.self, from: data)
        guard response.success else { throw PatientAssignmentError.invalidIdentifier }
        return try assignment(from: response.assignment)
    }

    static func mapError(from data: Data, statusCode: Int) -> PatientAssignmentError {
        let parsed = PatientAssignmentService.edgeErrorFields(from: data)
        switch parsed.code {
        case "patient_not_connected":
            return .patientNotConnected
        case "unauthorized", "therapist_mode_required":
            return .notSignedIn
        case "patient_not_found", "invalid_request":
            return .invalidIdentifier
        default:
            if statusCode == 401 || statusCode == 403 {
                return .notSignedIn
            }
            AppLog.store.error(
                "request-patient-diary-one mapped to invalidIdentifier code=\(parsed.code, privacy: .public) message=\(parsed.message, privacy: .public)"
            )
            return .invalidIdentifier
        }
    }

    fileprivate static func assignment(
        from dto: RequestPatientDiaryOneAssignmentDTO
    ) throws -> PatientAssignment {
        guard let createdAt = PatientAssignmentService.parseEdgeTimestamp(dto.createdAt) else {
            throw PatientAssignmentError.invalidIdentifier
        }
        return PatientAssignment(
            id: dto.id,
            patientId: dto.patientId,
            therapistId: dto.therapistId,
            sessionId: dto.sessionId,
            typeValue: dto.typeValue,
            createdAt: createdAt,
            completedAt: try optionalEdgeDate(dto.completedAt),
            cancelledAt: try optionalEdgeDate(dto.cancelledAt)
        )
    }

    private static func optionalEdgeDate(_ raw: String?) throws -> Date? {
        guard let raw else { return nil }
        guard let parsed = PatientAssignmentService.parseEdgeTimestamp(raw) else {
            throw PatientAssignmentError.invalidIdentifier
        }
        return parsed
    }
}

private struct SubmitPatientQuestionnaireResponse: Decodable, Sendable {
    let success: Bool?
    let combinedMoodId: Int?
    let sessionId: UUID?
}

enum PatientAssignmentError: LocalizedError, Equatable {
    case notConfigured
    case notSignedIn
    case invalidIdentifier
    case patientNotConnected

    var errorDescription: String? {
        switch self {
        case .notConfigured: AuthError.notConfigured.localizedDescription
        case .notSignedIn: L10n.therapistDisplayNameNotSignedInError
        case .invalidIdentifier: L10n.questionnaireAssignmentSendError
        case .patientNotConnected: L10n.patientNotConnectedTitle
        }
    }
}

/// A row in `public.patient_assignments`. Identifiers are not shown in UI.
nonisolated struct PatientAssignment: Decodable, Sendable {
    let id: UUID
    let patientId: UUID
    let therapistId: UUID?
    let sessionId: UUID?
    /// Raw `type` column. Unknown future values must not fail decoding.
    let typeValue: String
    let createdAt: Date
    let completedAt: Date?
    let cancelledAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case therapistId = "therapist_id"
        case sessionId = "session_id"
        case typeValue = "type"
        case createdAt = "created_at"
        case completedAt = "completed_at"
        case cancelledAt = "cancelled_at"
    }

    var type: PatientAssignmentType? { PatientAssignmentType(rawValue: typeValue) }

    var isOpen: Bool { completedAt == nil && cancelledAt == nil }
}

/// Ongoing diary assignment. `session_id` and completion timestamps stay NULL
/// until the therapist cancels (`cancelled_at` only).
private struct NewOngoingPatientAssignment: Encodable {
    let patientId: UUID
    let therapistId: UUID
    let type: PatientAssignmentType

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case therapistId = "therapist_id"
        case sessionId = "session_id"
        case type
        case completedAt = "completed_at"
        case cancelledAt = "cancelled_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(patientId, forKey: .patientId)
        try container.encode(therapistId, forKey: .therapistId)
        try container.encodeNil(forKey: .sessionId)
        try container.encode(type, forKey: .type)
        try container.encodeNil(forKey: .completedAt)
        try container.encodeNil(forKey: .cancelledAt)
    }
}

private struct CancelPatientAssignment: Encodable {
    let cancelledAt: String

    enum CodingKeys: String, CodingKey {
        case cancelledAt = "cancelled_at"
    }
}

private struct IsPatientConnectedParams: Encodable {
    let pPatientId: UUID

    enum CodingKeys: String, CodingKey {
        case pPatientId = "p_patient_id"
    }
}

/// A known empty assignment is different from an assignment that has not loaded yet.
@MainActor
final class AssignmentStatusCache {
    struct Snapshot { let assignmentId: UUID? }
    private struct Entry { let snapshot: Snapshot; let revision: Int }
    private var entries: [String: Entry] = [:]
    private func key(_ account: UUID, _ resource: String) -> String { "\(account.uuidString)/\(resource)" }
    func value(account: UUID?, resource: String) -> Snapshot? {
        guard let account else { return nil }
        return entries[key(account, resource)]?.snapshot
    }
    func revision(account: UUID?, resource: String) -> Int {
        guard let account else { return 0 }
        return entries[key(account, resource)]?.revision ?? 0
    }
    func store(_ id: UUID?, account: UUID?, resource: String, ifRevision: Int? = nil) {
        guard let account else { return }
        let current = revision(account: account, resource: resource)
        guard ifRevision == nil || ifRevision == current else { return }
        entries[key(account, resource)] = Entry(snapshot: Snapshot(assignmentId: id), revision: current + 1)
    }
}

/// Therapist-side patient assignments. Connection is decided only by the
/// `is_patient_connected` RPC — never by reading `patient_access`.
@MainActor
final class PatientAssignmentService {
    private let client: SupabaseClient
    private static var connectionCache: [UUID: [UUID: Bool]] = [:]
    private static let assignmentCache = AssignmentStatusCache()

    func cachedOngoingAssignment(patientId: UUID, type: PatientAssignmentType) -> AssignmentStatusCache.Snapshot? {
        Self.assignmentCache.value(account: client.auth.currentUser?.id, resource: "patient/\(patientId)/\(type.rawValue)")
    }

    func cachedQuestionnaireAssignment(sessionId: UUID) -> AssignmentStatusCache.Snapshot? {
        Self.assignmentCache.value(account: client.auth.currentUser?.id, resource: "session/\(sessionId)")
    }

    private func cacheAssignment(_ assignment: PatientAssignment, account: UUID?) {
        guard account == client.auth.currentUser?.id else { return }
        if assignment.type == .questionnaire, let sessionId = assignment.sessionId {
            Self.assignmentCache.store(assignment.isOpen ? assignment.id : nil, account: account, resource: "session/\(sessionId)")
        } else if let type = assignment.type {
            Self.assignmentCache.store(assignment.cancelledAt == nil ? assignment.id : nil, account: account, resource: "patient/\(assignment.patientId)/\(type.rawValue)")
        }
    }

    func cachedPatientConnection(patientId: UUID) -> Bool? {
        guard let userId = client.auth.currentUser?.id else { return nil }
        return Self.connectionCache[userId]?[patientId]
    }

    init(client: SupabaseClient) {
        self.client = client
    }

    /// Active Patient Mode connection for this patient. Boolean only.
    func isPatientConnected(patientId: UUID) async throws -> Bool {
        try ensureConfigured()
        let userId = client.auth.currentUser?.id
        do {
            let connected: Bool = try await client.rpc(
                "is_patient_connected",
                params: IsPatientConnectedParams(pPatientId: patientId)
            )
            .execute()
            .value
            if let userId, userId == client.auth.currentUser?.id {
                Self.connectionCache[userId, default: [:]][patientId] = connected
            }
            return connected
        } catch {
            AppLog.store.error(
                "Patient connection check failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    /// Open questionnaire assignment for this session, if one exists.
    func openQuestionnaireAssignment(sessionId: UUID) async throws -> PatientAssignment? {
        try ensureConfigured()
        let account = client.auth.currentUser?.id
        let resource = "session/\(sessionId)"
        let revision = Self.assignmentCache.revision(account: account, resource: resource)
        do {
            let rows: [PatientAssignment] = try await client.from("patient_assignments")
                .select(
                    "id, patient_id, therapist_id, session_id, type, created_at, completed_at, cancelled_at"
                )
                .eq("session_id", value: sessionId)
                .eq("type", value: PatientAssignmentType.questionnaire.rawValue)
                .is("completed_at", value: nil)
                .is("cancelled_at", value: nil)
                .limit(1)
                .execute()
                .value
            if account == client.auth.currentUser?.id {
                Self.assignmentCache.store(rows.first?.id, account: account, resource: resource, ifRevision: revision)
            }
            return rows.first
        } catch {
            AppLog.store.error(
                "Questionnaire assignment fetch failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    /// Creates a one-time questionnaire assignment via `request-patient-questionnaire`.
    /// Pass `sessionId` to keep the assignment tied to a session, or `nil` for a
    /// patient-level request. Duplicate/open handling and connection checks are
    /// performed by the Edge Function.
    func sendQuestionnaireAssignment(
        patientId: UUID,
        sessionId: UUID? = nil
    ) async throws -> PatientAssignment {
        try ensureConfigured()
        let account = client.auth.currentUser?.id
        let request = RequestPatientQuestionnaireRequest(
            patientId: patientId,
            sessionId: sessionId
        )
        Self.logQuestionnaireRequest(request)
        do {
            let response: RequestPatientQuestionnaireResponse = try await client.functions.invoke(
                "request-patient-questionnaire",
                options: FunctionInvokeOptions(body: request)
            )
            guard let createdAt = Self.parseEdgeTimestamp(response.createdAt) else {
                throw PatientAssignmentError.invalidIdentifier
            }
            let completedAt: Date?
            if let raw = response.completedAt {
                guard let parsed = Self.parseEdgeTimestamp(raw) else {
                    throw PatientAssignmentError.invalidIdentifier
                }
                completedAt = parsed
            } else {
                completedAt = nil
            }
            let cancelledAt: Date?
            if let raw = response.cancelledAt {
                guard let parsed = Self.parseEdgeTimestamp(raw) else {
                    throw PatientAssignmentError.invalidIdentifier
                }
                cancelledAt = parsed
            } else {
                cancelledAt = nil
            }
            AppLog.store.info("Questionnaire assignment created")
            let assignment = PatientAssignment(
                id: response.id,
                patientId: response.patientId,
                therapistId: response.therapistId,
                sessionId: response.sessionId,
                typeValue: response.typeValue,
                createdAt: createdAt,
                completedAt: completedAt,
                cancelledAt: cancelledAt
            )
            cacheAssignment(assignment, account: account)
            return assignment
        } catch let error as PatientAssignmentError {
            throw error
        } catch let FunctionsError.httpError(code, data) {
            Self.logQuestionnaireFailure(statusCode: code, data: data)
            throw Self.requestQuestionnaireError(from: data, statusCode: code)
        } catch {
            AppLog.store.error(
                "request-patient-questionnaire failed type=\(String(describing: type(of: error)), privacy: .public) \(error.localizedDescription, privacy: .public) \(String(describing: error), privacy: .public)"
            )
            throw PatientAssignmentError.invalidIdentifier
        }
    }

    /// Active ongoing diary assignment (`cancelled_at` is NULL). `completed_at`
    /// is not part of diary active-state.
    func activeOngoingAssignment(
        patientId: UUID,
        type: PatientAssignmentType
    ) async throws -> PatientAssignment? {
        try ensureConfigured()
        try Self.requireOngoingType(type)
        let account = client.auth.currentUser?.id
        let resource = "patient/\(patientId)/\(type.rawValue)"
        let revision = Self.assignmentCache.revision(account: account, resource: resource)
        do {
            let rows: [PatientAssignment] = try await client.from("patient_assignments")
                .select(
                    "id, patient_id, therapist_id, session_id, type, created_at, completed_at, cancelled_at"
                )
                .eq("patient_id", value: patientId)
                .eq("type", value: type.rawValue)
                .is("cancelled_at", value: nil)
                .limit(1)
                .execute()
                .value
            if account == client.auth.currentUser?.id {
                Self.assignmentCache.store(rows.first?.id, account: account, resource: resource, ifRevision: revision)
            }
            return rows.first
        } catch {
            AppLog.store.error(
                "Ongoing assignment fetch failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    /// Activates an ongoing assignment. Diary 1 goes through
    /// `request-patient-diary-one`; other ongoing types insert a row.
    /// Never reopens a cancelled row.
    func activateOngoingAssignment(
        patientId: UUID,
        type: PatientAssignmentType
    ) async throws -> PatientAssignment {
        try ensureConfigured()
        try Self.requireOngoingType(type)
        let connected = try await isPatientConnected(patientId: patientId)
        guard connected else { throw PatientAssignmentError.patientNotConnected }

        let account = client.auth.currentUser?.id
        let assignment: PatientAssignment
        if PatientDiaryOneActivation.usesEdgeFunction(type) {
            assignment = try await requestPatientDiaryOne(patientId: patientId)
        } else {
            assignment = try await insertOngoingAssignment(patientId: patientId, type: type)
        }
        cacheAssignment(assignment, account: account)
        return assignment
    }

    /// Creates Diary 1 via Edge Function. Reuse, connection, notification,
    /// and push are handled on the server. `createdNew == false` is success.
    private func requestPatientDiaryOne(patientId: UUID) async throws -> PatientAssignment {
        do {
            let response: RequestPatientDiaryOneResponse = try await client.functions.invoke(
                PatientDiaryOneActivation.functionName,
                options: FunctionInvokeOptions(
                    body: RequestPatientDiaryOneRequest(patientId: patientId)
                )
            )
            guard response.success else {
                throw PatientAssignmentError.invalidIdentifier
            }
            let assignment = try PatientDiaryOneActivation.assignment(from: response.assignment)
            AppLog.store.info("Diary 1 assignment requested")
            return assignment
        } catch let error as PatientAssignmentError {
            throw error
        } catch let FunctionsError.httpError(code, data) {
            throw PatientDiaryOneActivation.mapError(from: data, statusCode: code)
        } catch {
            AppLog.store.error(
                "request-patient-diary-one failed type=\(String(describing: type(of: error)), privacy: .public) \(error.localizedDescription, privacy: .public)"
            )
            throw PatientAssignmentError.invalidIdentifier
        }
    }

    /// Direct insert for non-Diary-1 ongoing types. Never reopens a cancelled row.
    private func insertOngoingAssignment(
        patientId: UUID,
        type: PatientAssignmentType
    ) async throws -> PatientAssignment {
        if let existing = try await activeOngoingAssignment(patientId: patientId, type: type) {
            return existing
        }

        let therapistId = try await requireTherapistId()
        do {
            let created: PatientAssignment = try await client.from("patient_assignments")
                .insert(
                    NewOngoingPatientAssignment(
                        patientId: patientId,
                        therapistId: therapistId,
                        type: type
                    )
                )
                .select(
                    "id, patient_id, therapist_id, session_id, type, created_at, completed_at, cancelled_at"
                )
                .single()
                .execute()
                .value
            AppLog.store.info("Ongoing assignment created")
            return created
        } catch {
            if Self.isUniqueViolation(error),
               let existing = try? await activeOngoingAssignment(patientId: patientId, type: type) {
                AppLog.store.info("Ongoing assignment already active")
                return existing
            }
            AppLog.store.error(
                "Ongoing assignment create failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    /// Stops an ongoing assignment by setting `cancelled_at` only.
    func cancelOngoingAssignment(id: UUID) async throws {
        try ensureConfigured()
        let account = client.auth.currentUser?.id
        do {
            let updated: [PatientAssignment] = try await client.from("patient_assignments")
                .update(
                    CancelPatientAssignment(cancelledAt: Self.timestampString(from: Date()))
                )
                .eq("id", value: id)
                .is("cancelled_at", value: nil)
                .select(
                    "id, patient_id, therapist_id, session_id, type, created_at, completed_at, cancelled_at"
                )
                .execute()
                .value
            guard !updated.isEmpty else {
                throw PatientAssignmentError.invalidIdentifier
            }
            updated.forEach { cacheAssignment($0, account: account) }
            AppLog.store.info("Ongoing assignment cancelled")
        } catch {
            AppLog.store.error(
                "Ongoing assignment cancel failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    /// Patient Mode list. RLS limits rows to this auth user's Patient;
    /// `patientId` is an optional extra filter, not authorization.
    func patientAssignments(patientId: UUID? = nil) async throws -> [PatientAssignment] {
        try ensureConfigured()
        do {
            let filter = client.from("patient_assignments")
                .select(
                    "id, patient_id, session_id, type, created_at, completed_at, cancelled_at"
                )
                .is("cancelled_at", value: nil)
            let rows: [PatientAssignment]
            if let patientId {
                rows = try await filter
                    .eq("patient_id", value: patientId)
                    .order("created_at", ascending: false)
                    .execute()
                    .value
            } else {
                rows = try await filter
                    .order("created_at", ascending: false)
                    .execute()
                    .value
            }
            AppLog.store.info("Patient assignments loaded")
            return rows
        } catch {
            AppLog.store.error(
                "Patient assignments fetch failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    /// Submits GAD-7 / PHQ-9 answers for an open assignment. CombinedMood is
    /// created only by the Edge Function — never from this client.
    func submitPatientQuestionnaire(
        assignmentId: UUID,
        gad7Answers: [Int],
        phq9Answers: [Int],
        interferenceLevel: Int
    ) async throws {
        try ensureConfigured()
        try Self.validatePatientAnswers(
            gad7Answers: gad7Answers,
            phq9Answers: phq9Answers,
            interferenceLevel: interferenceLevel
        )
        do {
            let response: SubmitPatientQuestionnaireResponse = try await client.functions.invoke(
                "submit-patient-questionnaire",
                options: FunctionInvokeOptions(
                    body: SubmitPatientQuestionnaireRequest(
                        assignmentId: assignmentId,
                        gad7Answers: gad7Answers,
                        phq9Answers: phq9Answers,
                        interferenceLevel: interferenceLevel
                    )
                )
            )
            guard response.success != false else {
                throw PatientQuestionnaireSubmitError.failed
            }
            AppLog.store.info("Patient questionnaire submitted")
        } catch let error as PatientQuestionnaireSubmitError {
            throw error
        } catch let FunctionsError.httpError(code, data) {
            throw Self.submitError(from: data, statusCode: code)
        } catch {
            AppLog.store.error(
                "Patient questionnaire submit failed: \(error.localizedDescription, privacy: .public)"
            )
            throw PatientQuestionnaireSubmitError.failed
        }
    }

    private static func validatePatientAnswers(
        gad7Answers: [Int],
        phq9Answers: [Int],
        interferenceLevel: Int
    ) throws {
        let valid = CombinedMoodQuestionnaire.answerValues
        guard gad7Answers.count == L10n.gad7Questions.count,
              phq9Answers.count == L10n.phq9Questions.count,
              gad7Answers.allSatisfy({ valid.contains($0) }),
              phq9Answers.allSatisfy({ valid.contains($0) }),
              valid.contains(interferenceLevel)
        else {
            throw PatientQuestionnaireSubmitError.invalidAnswers
        }
    }

    private static func requestQuestionnaireError(from data: Data, statusCode: Int) -> PatientAssignmentError {
        let parsed = edgeErrorFields(from: data)
        switch parsed.code {
        case "patient_not_connected":
            return .patientNotConnected
        case "unauthorized":
            return .notSignedIn
        default:
            if statusCode == 401 || statusCode == 403 {
                return .notSignedIn
            }
            AppLog.store.error(
                "request-patient-questionnaire mapped to invalidIdentifier code=\(parsed.code, privacy: .public) message=\(parsed.message, privacy: .public) details=\(parsed.details, privacy: .public) hint=\(parsed.hint, privacy: .public)"
            )
            return .invalidIdentifier
        }
    }

    private static func submitError(from data: Data, statusCode: Int) -> PatientQuestionnaireSubmitError {
        let code = edgeErrorCode(from: data)
        switch code {
        case "assignment_already_completed", "already_completed":
            return .alreadyCompleted
        case "assignment_cancelled", "cancelled":
            return .cancelled
        case "access_denied", "forbidden", "unauthorized":
            return .accessDenied
        default:
            if statusCode == 401 || statusCode == 403 {
                return .accessDenied
            }
            AppLog.store.error("Patient questionnaire submit failed")
            return .failed
        }
    }

    private static func edgeErrorCode(from data: Data) -> String {
        edgeErrorFields(from: data).code
    }

    struct EdgeErrorFields: Sendable {
        var code: String = ""
        var message: String = ""
        var details: String = ""
        var hint: String = ""
    }

    nonisolated static func edgeErrorFields(from data: Data) -> EdgeErrorFields {
        var fields = EdgeErrorFields()
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return fields
        }
        fields.message = stringValue(json["message"])
        fields.details = stringValue(json["details"])
        fields.hint = stringValue(json["hint"])
        if let error = json["error"] as? String {
            fields.code = error
        } else if let code = json["code"] as? String {
            fields.code = code
        } else if let nested = json["error"] as? [String: Any] {
            if fields.code.isEmpty { fields.code = stringValue(nested["code"]) }
            if fields.message.isEmpty { fields.message = stringValue(nested["message"]) }
            if fields.details.isEmpty { fields.details = stringValue(nested["details"]) }
            if fields.hint.isEmpty { fields.hint = stringValue(nested["hint"]) }
        } else if let status = json["status"] as? String {
            fields.code = status
        }
        return fields
    }

    private nonisolated static func stringValue(_ value: Any?) -> String {
        switch value {
        case let text as String: text
        case let number as NSNumber: number.stringValue
        default: ""
        }
    }

    private static func logQuestionnaireRequest(_ request: RequestPatientQuestionnaireRequest) {
        let encoder = JSONEncoder()
        let json = (try? encoder.encode(request)).flatMap { String(data: $0, encoding: .utf8) } ?? "<encode-failed>"
        let session: String = request.sessionId?.uuidString ?? "null"
        AppLog.store.error(
            "request-patient-questionnaire sending function=request-patient-questionnaire patientId=\(request.patientId.uuidString, privacy: .public) sessionId=\(session, privacy: .public) json=\(json, privacy: .public)"
        )
    }

    private static func logQuestionnaireFailure(statusCode: Int, data: Data) {
        let body = String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>"
        let parsed = edgeErrorFields(from: data)
        AppLog.store.error(
            "request-patient-questionnaire HTTP \(statusCode) code=\(parsed.code, privacy: .public) message=\(parsed.message, privacy: .public) details=\(parsed.details, privacy: .public) hint=\(parsed.hint, privacy: .public) body=\(body, privacy: .public)"
        )
    }

    private func requireTherapistId() async throws -> UUID {
        do {
            return try await client.auth.session.user.id
        } catch {
            throw PatientAssignmentError.notSignedIn
        }
    }

    private func ensureConfigured() throws {
        guard SupabaseConfig.isConfigured else { throw PatientAssignmentError.notConfigured }
    }

    private static func requireOngoingType(_ type: PatientAssignmentType) throws {
        switch type {
        case .diaryOne, .diaryTwo:
            return
        case .questionnaire:
            throw PatientAssignmentError.invalidIdentifier
        }
    }

    private static func isUniqueViolation(_ error: Error) -> Bool {
        if let postgrest = error as? PostgrestError, postgrest.code == "23505" {
            return true
        }
        let nsError = error as NSError
        if nsError.code == 23505 { return true }
        if let nested = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return isUniqueViolation(nested)
        }
        return false
    }

    private static func timestampString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    nonisolated static func parseEdgeTimestamp(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: trimmed) { return date }
        let withoutFraction = ISO8601DateFormatter()
        withoutFraction.formatOptions = [.withInternetDateTime]
        return withoutFraction.date(from: trimmed)
    }
}

extension DatabaseID {
    var uuidValue: UUID? {
        UUID(uuidString: queryValue)
    }
}
