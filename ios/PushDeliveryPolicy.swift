import Foundation

enum OsNotificationAuthorization: Equatable {
    case notDetermined
    case denied
    case allowed
}

enum PushNotificationPreference {
    static let defaultsKey = "cbtipul.notificationsEnabledByUser"

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: defaultsKey) == nil { return true }
        return defaults.bool(forKey: defaultsKey)
    }

    static func setEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: defaultsKey)
    }
}

enum PushDeliveryPolicy {
    /// Persistent in-app notifications ignore the system-push preference.
    static let affectsPersistentInbox = false

    static func shouldRegisterWithBackend(userPreferenceEnabled: Bool) -> Bool {
        userPreferenceEnabled
    }

    static func toggleShowsOn(userPreferenceEnabled: Bool, osAllowed: Bool) -> Bool {
        userPreferenceEnabled && osAllowed
    }

    enum TurnOnAction: Equatable {
        case persistOnAndRegister
        case requestPermission
        case remainOffAndOfferSettings
    }

    static func actionForTurningOn(osStatus: OsNotificationAuthorization) -> TurnOnAction {
        switch osStatus {
        case .allowed: return .persistOnAndRegister
        case .notDetermined: return .requestPermission
        case .denied: return .remainOffAndOfferSettings
        }
    }

    enum TurnOffAction: Equatable {
        case disableBackend(token: String)
        case persistOffOnly
    }

    static func actionForTurningOff(currentToken: String?) -> TurnOffAction {
        if let currentToken, !currentToken.isEmpty {
            return .disableBackend(token: currentToken)
        }
        return .persistOffOnly
    }
}
