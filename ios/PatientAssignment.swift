import Foundation
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

private struct SubmitPatientQuestionnaireResponse: Decodable, Sendable {
    let success: Bool?
    let combinedMoodId: Int?
    let sessionId: UUID?
}

enum PatientAssignmentError: LocalizedError {
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

private struct NewPatientAssignment: Encodable {
    let patientId: UUID
    let therapistId: UUID
    let sessionId: UUID
    let type: PatientAssignmentType

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case therapistId = "therapist_id"
        case sessionId = "session_id"
        case type
    }
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

/// Therapist-side patient assignments. Connection is decided only by the
/// `is_patient_connected` RPC — never by reading `patient_access`.
@MainActor
final class PatientAssignmentService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    /// Active Patient Mode connection for this patient. Boolean only.
    func isPatientConnected(patientId: UUID) async throws -> Bool {
        try ensureConfigured()
        do {
            let connected: Bool = try await client.rpc(
                "is_patient_connected",
                params: IsPatientConnectedParams(pPatientId: patientId)
            )
            .execute()
            .value
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
            return rows.first
        } catch {
            AppLog.store.error(
                "Questionnaire assignment fetch failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    /// Creates a one-time questionnaire assignment after a connection and
    /// duplicate check. Does not write CombinedMood / questionnaire answers.
    func sendQuestionnaireAssignment(
        patientId: UUID,
        sessionId: UUID
    ) async throws -> PatientAssignment {
        try ensureConfigured()
        let connected = try await isPatientConnected(patientId: patientId)
        guard connected else { throw PatientAssignmentError.patientNotConnected }

        if let existing = try await openQuestionnaireAssignment(sessionId: sessionId) {
            return existing
        }

        let therapistId = try await requireTherapistId()
        do {
            let created: PatientAssignment = try await client.from("patient_assignments")
                .insert(
                    NewPatientAssignment(
                        patientId: patientId,
                        therapistId: therapistId,
                        sessionId: sessionId,
                        type: .questionnaire
                    )
                )
                .select(
                    "id, patient_id, therapist_id, session_id, type, created_at, completed_at, cancelled_at"
                )
                .single()
                .execute()
                .value
            AppLog.store.info("Questionnaire assignment created")
            return created
        } catch {
            AppLog.store.error(
                "Questionnaire assignment create failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
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
            return rows.first
        } catch {
            AppLog.store.error(
                "Ongoing assignment fetch failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    /// Inserts a new ongoing assignment. Never reopens a cancelled row.
    func activateOngoingAssignment(
        patientId: UUID,
        type: PatientAssignmentType
    ) async throws -> PatientAssignment {
        try ensureConfigured()
        try Self.requireOngoingType(type)
        let connected = try await isPatientConnected(patientId: patientId)
        guard connected else { throw PatientAssignmentError.patientNotConnected }

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
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ""
        }
        if let error = json["error"] as? String { return error }
        if let code = json["code"] as? String { return code }
        if let nested = json["error"] as? [String: Any],
           let code = nested["code"] as? String {
            return code
        }
        if let status = json["status"] as? String { return status }
        return ""
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
}

extension DatabaseID {
    var uuidValue: UUID? {
        UUID(uuidString: queryValue)
    }
}
