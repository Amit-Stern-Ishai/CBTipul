import Foundation
import OSLog
import UIKit
import UserNotifications

/// Single writer for the home-screen app-icon badge.
/// Deployment target is iOS 18, so `setBadgeCount` is the only API used.
enum ApplicationIconBadge {
    @MainActor
    static func sync(count: Int) async {
        let requested = max(0, count)
        let app = UIApplication.shared
        let before = app.applicationIconBadgeNumber
        let state = Self.applicationStateLabel(app.applicationState)
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        #if DEBUG
        AppLog.push.debug(
            "icon badge sync request=\(requested) state=\(state, privacy: .public) authorization=\(Self.authorizationLabel(settings.authorizationStatus), privacy: .public) badgeSetting=\(Self.badgeSettingLabel(settings.badgeSetting), privacy: .public) iconBefore=\(before) api=setBadgeCount"
        )
        #endif
        if settings.badgeSetting == .disabled {
            #if DEBUG
            AppLog.push.debug("icon badge skipped: badgeSetting disabled")
            #endif
            return
        }
        do {
            try await UNUserNotificationCenter.current().setBadgeCount(requested)
            #if DEBUG
            AppLog.push.debug(
                "icon badge setBadgeCount succeeded request=\(requested) iconAfter=\(app.applicationIconBadgeNumber)"
            )
            #endif
        } catch {
            #if DEBUG
            AppLog.push.debug(
                "icon badge setBadgeCount threw: \(error.localizedDescription, privacy: .public)"
            )
            #endif
        }
    }

    #if DEBUG
    /// Reaches the OS badge API with count 1. Not shown in production UI.
    @MainActor
    static func debugRequestOne() async {
        AppLog.push.debug("BADGE TEST: requesting 1")
        await sync(count: 1)
    }
    #endif

    private static func applicationStateLabel(_ state: UIApplication.State) -> String {
        switch state {
        case .active: "active"
        case .inactive: "inactive"
        case .background: "background"
        @unknown default: "unknown"
        }
    }

    private static func authorizationLabel(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "notDetermined"
        case .denied: "denied"
        case .authorized: "authorized"
        case .provisional: "provisional"
        case .ephemeral: "ephemeral"
        @unknown default: "unknown"
        }
    }

    private static func badgeSettingLabel(_ setting: UNNotificationSetting) -> String {
        switch setting {
        case .notSupported: "notSupported"
        case .disabled: "disabled"
        case .enabled: "enabled"
        @unknown default: "unknown"
        }
    }
}
