import Foundation

/// Therapist inbox event kinds. Unknown server values decode as `.unknown`
/// so future types cannot crash the client.
enum AppNotificationType: Hashable, Sendable {
    case questionnaireAssigned
    case questionnaireCompleted
    case patientConnected
    case unknown(String)

    init(rawValue: String) {
        switch rawValue {
        case "questionnaire_assigned":
            self = .questionnaireAssigned
        case "questionnaire_completed":
            self = .questionnaireCompleted
        case "patient_connected":
            self = .patientConnected
        default:
            self = .unknown(rawValue)
        }
    }

    var rawValue: String {
        switch self {
        case .questionnaireAssigned: "questionnaire_assigned"
        case .questionnaireCompleted: "questionnaire_completed"
        case .patientConnected: "patient_connected"
        case .unknown(let raw): raw
        }
    }
}

/// Persistent Notification Center record. Identifiers only — never names,
/// scores, or clinical text.
struct AppNotification: Identifiable, Hashable, Sendable {
    let id: UUID
    let type: AppNotificationType
    let patientId: String?
    let sessionId: String?
    let assignmentId: String?
    let resourceType: String?
    let resourceId: String?
    let createdAt: Date
    let seenAt: Date?
    let readAt: Date?

    var isUnseen: Bool { seenAt == nil }
    var isUnread: Bool { readAt == nil }

    func acknowledged(at seenAt: Date) -> AppNotification {
        AppNotification(
            id: id,
            type: type,
            patientId: patientId,
            sessionId: sessionId,
            assignmentId: assignmentId,
            resourceType: resourceType,
            resourceId: resourceId,
            createdAt: createdAt,
            seenAt: self.seenAt ?? seenAt,
            readAt: readAt
        )
    }

    func opened(at readAt: Date) -> AppNotification {
        AppNotification(
            id: id,
            type: type,
            patientId: patientId,
            sessionId: sessionId,
            assignmentId: assignmentId,
            resourceType: resourceType,
            resourceId: resourceId,
            createdAt: createdAt,
            seenAt: seenAt ?? readAt,
            readAt: readAt
        )
    }
}

/// Identifier payload shared by APNs `userInfo` and persisted rows.
struct AppNotificationPayload: Equatable, Sendable {
    let typeRaw: String
    let notificationId: String?
    let patientId: String?
    let sessionId: String?
    let assignmentId: String?
    let resourceType: String?
    let resourceId: String?

    var type: AppNotificationType { AppNotificationType(rawValue: typeRaw) }

    /// Dedupes cold-start + background delivery of the same push.
    var routingFingerprint: String {
        if let notificationId, !notificationId.isEmpty {
            return "notification:\(notificationId)"
        }
        return [
            "type:\(typeRaw)",
            patientId ?? "",
            assignmentId ?? "",
            resourceType ?? "",
            resourceId ?? "",
            sessionId ?? "",
        ].joined(separator: "|")
    }

    static func from(notification: AppNotification) -> AppNotificationPayload {
        AppNotificationPayload(
            typeRaw: notification.type.rawValue,
            notificationId: notification.id.uuidString,
            patientId: notification.patientId,
            sessionId: notification.sessionId,
            assignmentId: notification.assignmentId,
            resourceType: notification.resourceType,
            resourceId: notification.resourceId
        )
    }

    static func from(userInfo: [AnyHashable: Any]) -> AppNotificationPayload? {
        let bag = flattened(userInfo)
        guard let typeRaw = stringValue(bag["type"]) else { return nil }
        return AppNotificationPayload(
            typeRaw: typeRaw,
            notificationId: stringValue(bag["notificationId"] ?? bag["notification_id"]),
            patientId: stringValue(bag["patientId"] ?? bag["patient_id"]),
            sessionId: stringValue(bag["sessionId"] ?? bag["session_id"]),
            assignmentId: stringValue(bag["assignmentId"] ?? bag["assignment_id"]),
            resourceType: stringValue(bag["resourceType"] ?? bag["resource_type"]),
            resourceId: stringValue(bag["resourceId"] ?? bag["resource_id"])
        )
    }

    private static func flattened(_ userInfo: [AnyHashable: Any]) -> [AnyHashable: Any] {
        if let nested = userInfo["data"] as? [AnyHashable: Any] {
            var merged = userInfo
            for (key, value) in nested {
                merged[key] = value
            }
            return merged
        }
        return userInfo
    }

    static func stringValue(_ raw: Any?) -> String? {
        if let value = raw as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let value = raw as? UUID {
            return value.uuidString
        }
        if let value = raw as? NSNumber {
            return value.stringValue
        }
        return nil
    }
}

enum NotificationInboxCopy {
    /// Inbox subtitle. Patient names never come from the notification row.
    static func message(for type: AppNotificationType) -> String {
        switch type {
        case .questionnaireCompleted:
            L10n.notificationQuestionnaireCompleted
        case .patientConnected:
            L10n.notificationPatientConnected
        case .questionnaireAssigned, .unknown:
            L10n.notificationGenericTitle
        }
    }
}

enum NotificationInboxSections {
    static func unread(_ items: [AppNotification]) -> [AppNotification] {
        items.filter { $0.readAt == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    static func read(_ items: [AppNotification]) -> [AppNotification] {
        items.filter { $0.readAt != nil }
            .sorted { $0.createdAt > $1.createdAt }
    }
}

enum NotificationCounts {
    static func unseen(_ items: [AppNotification]) -> Int {
        items.reduce(0) { $0 + ($1.isUnseen ? 1 : 0) }
    }

    static func unread(_ items: [AppNotification]) -> Int {
        items.reduce(0) { $0 + ($1.isUnread ? 1 : 0) }
    }
}

enum NotificationSeenAcknowledgement {
    /// Local result of a successful `mark_notifications_seen` RPC.
    /// Does not change `readAt`.
    static func applying(_ items: [AppNotification], seenAt: Date) -> [AppNotification] {
        items.map { $0.acknowledged(at: seenAt) }
    }
}

enum NotificationInboxSeenPolicy {
    /// Inbox-seen RPC only when the Notifications tab is the visible selection.
    /// Fetch / launch / other tabs never qualify on their own.
    static func shouldMarkSeen(isInboxVisible: Bool, unseenCount: Int) -> Bool {
        isInboxVisible && unseenCount > 0
    }
}

enum QuestionnaireNotificationFocus {
    /// Exact CombinedMood id for `questionnaire_completed`, or nil to stop
    /// at the patient's questionnaire list.
    static func combinedMoodID(resourceType: String?, resourceId: String?) -> DatabaseID? {
        guard resourceType == "questionnaire", let resourceId else { return nil }
        return DatabaseID.parseCombinedMoodID(resourceId)
    }
}

enum NotificationPatientName {
    /// Device-local name only. Never read from a notification record.
    static func resolve(patientId: String?, patients: [Patient]) -> String {
        guard let patientId, !patientId.isEmpty else {
            return L10n.notificationGenericPatient
        }
        if let patient = patients.first(where: { $0.id.matches(patientId) }) {
            let name = patient.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty, name != L10n.unnamedPatient {
                return name
            }
        }
        if let local = PatientNameResolver.displayName(forPatientId: patientId) {
            return local
        }
        return L10n.notificationGenericPatient
    }
}
