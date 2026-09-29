import Foundation
import Functions
import OSLog
import Supabase

/// One therapist → patient message. Body lives only in `patient_messages`.
struct PatientMessage: Identifiable, Hashable, Sendable, Decodable {
    let id: UUID
    let patientId: UUID
    let body: String
    let createdAt: Date
    let readAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case body
        case createdAt = "created_at"
        case readAt = "read_at"
    }

    var isUnread: Bool { readAt == nil }

    func markedRead(at date: Date) -> PatientMessage {
        PatientMessage(
            id: id,
            patientId: patientId,
            body: body,
            createdAt: createdAt,
            readAt: readAt ?? date
        )
    }

    static func preview(_ body: String, limit: Int = 80) -> String {
        let collapsed = body
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if collapsed.count <= limit { return collapsed }
        return String(collapsed.prefix(limit)) + "…"
    }
}

enum PatientMessageDraft {
    static let maxLength = 4000

    static func normalizedBody(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func canSend(_ raw: String) -> Bool {
        let body = normalizedBody(raw)
        return !body.isEmpty && body.count <= maxLength
    }
}

struct SendPatientMessageRequest: Encodable, Equatable, Sendable {
    let patientId: UUID
    let body: String
}

enum SendPatientMessageRequestFactory {
    static func make(patientId: UUID, rawBody: String) -> SendPatientMessageRequest? {
        let body = PatientMessageDraft.normalizedBody(rawBody)
        guard !body.isEmpty, body.count <= PatientMessageDraft.maxLength else { return nil }
        return SendPatientMessageRequest(patientId: patientId, body: body)
    }
}

enum PatientMessageSendError: LocalizedError {
    case empty
    case tooLong
    case patientNotFound
    case patientNotConnected
    case notSignedIn
    case failed

    var errorDescription: String? {
        switch self {
        case .empty:
            L10n.sendPatientMessageEmpty
        case .tooLong:
            L10n.sendPatientMessageTooLong
        case .patientNotFound:
            L10n.sendPatientMessagePatientNotFound
        case .patientNotConnected:
            L10n.patientNotConnectedBody
        case .notSignedIn:
            L10n.patientQuestionnaireAccessDeniedError
        case .failed:
            L10n.sendPatientMessageFailed
        }
    }
}

enum PatientMessageDestination: Equatable {
    case exact(UUID)
    case list
    case none
}

enum PatientMessageRouter {
    static func destination(from payload: AppNotificationPayload) -> PatientMessageDestination {
        guard payload.type == .messageReceived else { return .none }
        if payload.resourceType == "message",
           let id = Self.messageID(resourceId: payload.resourceId) {
            return .exact(id)
        }
        return .list
    }

    static func messageID(resourceId: String?) -> UUID? {
        guard let resourceId else { return nil }
        let trimmed = resourceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return UUID(uuidString: trimmed)
    }
}

enum PatientDiaryOneAssignedRouter {
    static func destination(from payload: AppNotificationPayload) -> PatientDiaryOneAssignedDestination {
        guard payload.type == .diaryOneAssigned else { return .none }
        return .entryForm(assignmentId: assignmentID(from: payload))
    }

    static func assignmentID(from payload: AppNotificationPayload) -> UUID? {
        if let raw = payload.assignmentId {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if let id = UUID(uuidString: trimmed) { return id }
        }
        if payload.resourceType == "assignment", let raw = payload.resourceId {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if let id = UUID(uuidString: trimmed) { return id }
        }
        return nil
    }

    static func matchingAssignment(
        in assignments: [PatientAssignment],
        assignmentId: UUID
    ) -> PatientAssignment? {
        assignments.first {
            $0.id == assignmentId && $0.type == .diaryOne && $0.isOpen
        }
    }
}

enum PatientDiaryOneAssignedDestination: Equatable {
    case none
    case entryForm(assignmentId: UUID?)
}

enum PatientModePushDestination: Equatable {
    case none
    case messages(PatientMessageDestination)
    case diaryOneAssigned(PatientDiaryOneAssignedDestination)
    case diaryTwoAssigned(AppNotificationPayload)
}

/// Patient Mode pending message and diary-assignment routes. Therapist
/// routing stays on `TherapistNotificationCoordinator`.
@Observable
@MainActor
final class PatientModeMessageCoordinator {
    static let shared = PatientModeMessageCoordinator()

    private(set) var pendingRevision = 0
    private var isReady = false
    private var pendingPayload: AppNotificationPayload?
    private var lastConsumedFingerprint: String?

    private init() {}

    func handlePushTap(userInfo: [AnyHashable: Any]) {
        guard let payload = AppNotificationPayload.from(userInfo: userInfo),
              payload.type.routesInPatientMode
        else { return }
        if lastConsumedFingerprint == payload.routingFingerprint { return }
        pendingPayload = payload
        pendingRevision += 1
        #if DEBUG
        AppLog.push.debug(
            "patient mode push queued type=\(payload.typeRaw, privacy: .public) resourceId=\(payload.resourceId ?? "nil", privacy: .public)"
        )
        #endif
    }

    func markReady() {
        isReady = true
    }

    func markNotReady() {
        isReady = false
    }

    func consumePending() -> PatientModePushDestination? {
        guard isReady, let payload = pendingPayload else { return nil }
        if lastConsumedFingerprint == payload.routingFingerprint {
            pendingPayload = nil
            return nil
        }
        lastConsumedFingerprint = payload.routingFingerprint
        pendingPayload = nil
        switch payload.type {
        case .messageReceived:
            return .messages(PatientMessageRouter.destination(from: payload))
        case .diaryTwoAssigned:
            return .diaryTwoAssigned(payload)
        case .diaryOneAssigned:
            return .diaryOneAssigned(PatientDiaryOneAssignedRouter.destination(from: payload))
        default:
            return .none
        }
    }
}

/// Intended Patient Mode message stack. Home/push open detail at the root;
/// list-row taps push detail on top of the list.
enum PatientModeMessageStack {
    enum Entry: Equatable {
        case homeLatest
        case allMessagesThenMessage
        case pushExact
    }

    enum Screen: Equatable {
        case home
        case list
        case detail
    }

    static func screens(afterOpening entry: Entry) -> [Screen] {
        switch entry {
        case .homeLatest, .pushExact:
            [.home, .detail]
        case .allMessagesThenMessage:
            [.home, .list, .detail]
        }
    }

    static func screensAfterBack(from stack: [Screen]) -> [Screen] {
        guard stack.count > 1 else { return stack }
        return Array(stack.dropLast())
    }
}

enum PatientModeHomeMessages {
    static let previewLimit = 2

    static func unread(in messages: [PatientMessage]) -> [PatientMessage] {
        messages.filter(\.isUnread).sorted { $0.createdAt > $1.createdAt }
    }

    static func previews(in messages: [PatientMessage]) -> [PatientMessage] {
        Array(unread(in: messages).prefix(previewLimit))
    }

    static func remainingUnreadCount(in messages: [PatientMessage]) -> Int {
        max(0, unread(in: messages).count - previewLimit)
    }
}

struct PatientMessageService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func messages(patientId: UUID) async throws -> [PatientMessage] {
        let rows: [PatientMessage] = try await client.from("patient_messages")
            .select("id, patient_id, body, created_at, read_at")
            .eq("patient_id", value: patientId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows
    }

    func message(id: UUID) async throws -> PatientMessage? {
        let rows: [PatientMessage] = try await client.from("patient_messages")
            .select("id, patient_id, body, created_at, read_at")
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func send(patientId: UUID, rawBody: String) async throws {
        guard let request = SendPatientMessageRequestFactory.make(
            patientId: patientId,
            rawBody: rawBody
        ) else {
            let body = PatientMessageDraft.normalizedBody(rawBody)
            throw body.isEmpty ? PatientMessageSendError.empty : PatientMessageSendError.tooLong
        }
        do {
            let response: SendPatientMessageResponse = try await client.functions.invoke(
                "send-patient-message",
                options: FunctionInvokeOptions(body: request)
            )
            if response.success == false {
                throw PatientMessageSendError.failed
            }
        } catch let error as PatientMessageSendError {
            throw error
        } catch let FunctionsError.httpError(code, data) {
            throw Self.sendError(from: data, statusCode: code)
        } catch {
            #if DEBUG
            AppLog.store.error(
                "send-patient-message failed: \(error.localizedDescription, privacy: .public)"
            )
            #endif
            throw PatientMessageSendError.failed
        }
    }

    func markRead(id: UUID) async throws {
        try await client.rpc(
            "mark_patient_message_read",
            params: MarkPatientMessageReadParams(pMessageId: id)
        )
        .execute()
    }

    private static func sendError(from data: Data, statusCode: Int) -> PatientMessageSendError {
        let code = edgeErrorCode(from: data).uppercased()
        switch code {
        case "PATIENT_NOT_FOUND":
            return .patientNotFound
        case "PATIENT_NOT_CONNECTED":
            return .patientNotConnected
        case "MESSAGE_EMPTY":
            return .empty
        case "MESSAGE_TOO_LONG":
            return .tooLong
        case "UNAUTHORIZED", "FORBIDDEN":
            return .notSignedIn
        default:
            if statusCode == 401 || statusCode == 403 {
                return .notSignedIn
            }
            #if DEBUG
            AppLog.store.error(
                "send-patient-message mapped failed code=\(code, privacy: .public)"
            )
            #endif
            return .failed
        }
    }

    private static func edgeErrorCode(from data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ""
        }
        if let error = json["error"] as? String { return error }
        if let code = json["code"] as? String { return code }
        if let nested = json["error"] as? [String: Any], let code = nested["code"] as? String {
            return code
        }
        if let status = json["status"] as? String { return status }
        return ""
    }
}

private nonisolated struct SendPatientMessageResponse: Decodable {
    let success: Bool?
    let messageId: UUID?
    let createdAt: String?
}

private nonisolated struct MarkPatientMessageReadParams: Encodable {
    let pMessageId: UUID

    enum CodingKeys: String, CodingKey {
        case pMessageId = "p_message_id"
    }
}


/// Resolve only server-loaded assignments for the current Patient Mode identity.
enum PatientDiaryTwoAssignedRouter {
    static func matchingAssignment(in assignments: [PatientAssignment], payload: AppNotificationPayload, patientId: UUID) -> PatientAssignment? {
        guard payload.type == .diaryTwoAssigned, payload.resourceType == "assignment",
              let raw = payload.assignmentId, let assignmentId = UUID(uuidString: raw),
              payload.resourceId.flatMap(UUID.init(uuidString:)) == assignmentId,
              payload.patientId.flatMap(UUID.init(uuidString:)) == patientId else { return nil }
        return assignments.first {
            $0.id == assignmentId && $0.type == .diaryTwo && $0.cancelledAt == nil && $0.patientId == patientId
        }
    }

    @MainActor static func resolve(payload: AppNotificationPayload, patientId: UUID,
        load: () async throws -> [PatientAssignment]) async -> PatientAssignment? {
        guard let assignments = try? await load() else { return nil }
        return matchingAssignment(in: assignments, payload: payload, patientId: patientId)
    }
}
