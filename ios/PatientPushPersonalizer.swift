import Foundation
import UserNotifications

/// User-facing copy for locally personalized patient push notifications.
enum PatientPushCopy {
    static let appTitle = "CBTipul"

    static func patientConnectedBody(name: String) -> String {
        "\(name) התחבר/ה בהצלחה ל-CBTipul"
    }
}

/// Applies device-only patient-name substitution to a notification.
/// Unknown types and missing names leave the payload unchanged.
enum PatientPushPersonalizer: Sendable {
    enum NotificationType: String {
        case patientConnected = "patient_connected"
    }

    nonisolated static func apply(to content: UNMutableNotificationContent) {
        let typeRaw = stringValue(content.userInfo["type"])
        guard let typeRaw, let type = NotificationType(rawValue: typeRaw) else { return }
        switch type {
        case .patientConnected:
            applyPatientConnected(to: content)
        }
    }

    nonisolated static func patientId(from userInfo: [AnyHashable: Any]) -> String? {
        let raw = userInfo["patientId"] ?? userInfo["patient_id"]
        return stringValue(raw)
    }

    private nonisolated static func applyPatientConnected(to content: UNMutableNotificationContent) {
        guard let patientId = patientId(from: content.userInfo) else { return }
        guard let name = PatientNameResolver.displayName(forPatientId: patientId) else { return }
        if content.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            content.title = PatientPushCopy.appTitle
        }
        content.body = PatientPushCopy.patientConnectedBody(name: name)
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
