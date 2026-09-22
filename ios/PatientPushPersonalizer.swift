import Foundation
import UserNotifications

/// User-facing copy for locally personalized patient push notifications.
enum PatientPushCopy {
    static let appTitle = "CBTipul"

    static func patientConnectedBody(name: String) -> String {
        "\(name) התחבר/ה בהצלחה ל-CBTipul"
    }

    static let genericQuestionnaireCompleted = "מטופל/ת מילא/ה שאלון חדש"

    static func questionnaireCompletedBody(name: String) -> String {
        "\(name) מילא/ה שאלון חדש"
    }
}

/// Applies device-only patient-name substitution to a notification.
/// Unknown types and missing names leave the payload unchanged.
enum PatientPushPersonalizer: Sendable {
    enum NotificationType: String {
        case patientConnected = "patient_connected"
        case questionnaireCompleted = "questionnaire_completed"
    }

    nonisolated static func apply(to content: UNMutableNotificationContent) {
        apply(to: content, nameForPatientId: PatientNameResolver.displayName(forPatientId:))
    }

    nonisolated static func apply(
        to content: UNMutableNotificationContent,
        nameForPatientId: (String) -> String?
    ) {
        let typeRaw = stringValue(content.userInfo["type"])
        guard let typeRaw, let type = NotificationType(rawValue: typeRaw) else { return }
        switch type {
        case .patientConnected:
            applyNamedBody(
                to: content,
                namedBody: PatientPushCopy.patientConnectedBody,
                nameForPatientId: nameForPatientId
            )
        case .questionnaireCompleted:
            applyNamedBody(
                to: content,
                namedBody: PatientPushCopy.questionnaireCompletedBody,
                nameForPatientId: nameForPatientId
            )
        }
    }

    nonisolated static func patientId(from userInfo: [AnyHashable: Any]) -> String? {
        stringValue(userInfo["patientId"] ?? userInfo["patient_id"])
    }

    nonisolated static func assignmentId(from userInfo: [AnyHashable: Any]) -> String? {
        stringValue(userInfo["assignmentId"] ?? userInfo["assignment_id"])
    }

    nonisolated static func sessionId(from userInfo: [AnyHashable: Any]) -> String? {
        stringValue(userInfo["sessionId"] ?? userInfo["session_id"])
    }

    private nonisolated static func applyNamedBody(
        to content: UNMutableNotificationContent,
        namedBody: (String) -> String,
        nameForPatientId: (String) -> String?
    ) {
        guard let patientId = patientId(from: content.userInfo) else { return }
        guard let name = nameForPatientId(patientId)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty
        else { return }
        if content.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            content.title = PatientPushCopy.appTitle
        }
        content.body = namedBody(name)
    }

    private nonisolated static func stringValue(_ raw: Any?) -> String? {
        if let value = raw as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let value = raw as? NSNumber {
            return value.stringValue
        }
        return nil
    }
}
