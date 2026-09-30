import Foundation
import OSLog
import Supabase
import UIKit
import UserNotifications

/// Native APNs registration against the existing `register_push_device` /
/// `unregister_push_device` RPCs. Ownership is always `auth.uid()` on the
/// server — this type never sends a user, patient, or therapist id.
@MainActor
final class PushNotificationManager {
    static let shared = PushNotificationManager()

    private static let tokenDefaultsKey = "cbtipul.apnsDeviceToken"

    private var client: SupabaseClient?
    private var lastRegisteredUserId: String?

    private var persistedToken: String? {
        get { UserDefaults.standard.string(forKey: Self.tokenDefaultsKey) }
        set {
            if let newValue, !newValue.isEmpty {
                UserDefaults.standard.set(newValue, forKey: Self.tokenDefaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.tokenDefaultsKey)
            }
        }
    }

    private var pushEnvironment: String {
        #if DEBUG
        "development"
        #else
        "production"
        #endif
    }

    private init() {}

    func attach(client: SupabaseClient) {
        self.client = client
    }

    func currentPushToken() -> String? { persistedToken }

    func osAuthorizationStatus() async -> OsNotificationAuthorization {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized, .provisional, .ephemeral: return .allowed
        @unknown default: return .denied
        }
    }

    func openSystemNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func setUserNotificationsEnabled(_ enabled: Bool) async throws {
        if enabled {
            try await enableFromSettings()
        } else {
            try await disableFromSettings()
        }
    }

    private func enableFromSettings() async throws {
        let status = await osAuthorizationStatus()
        switch PushDeliveryPolicy.actionForTurningOn(osStatus: status) {
        case .remainOffAndOfferSettings:
            throw PushNotificationSettingsError.needsSystemSettings
        case .requestPermission:
            let granted: Bool
            do {
                granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                throw PushNotificationSettingsError.enableFailed
            }
            if !granted {
                throw PushNotificationSettingsError.permissionDenied
            }
            PushNotificationPreference.setEnabled(true)
            UIApplication.shared.registerForRemoteNotifications()
            do {
                try await registerPersistedTokenWithBackendThrowing()
            } catch {
                throw PushNotificationSettingsError.enableFailed
            }
        case .persistOnAndRegister:
            PushNotificationPreference.setEnabled(true)
            UIApplication.shared.registerForRemoteNotifications()
            do {
                try await registerPersistedTokenWithBackendThrowing()
            } catch {
                throw PushNotificationSettingsError.enableFailed
            }
        }
    }

    private func disableFromSettings() async throws {
        guard !AuthManager.isUITesting else {
            PushNotificationPreference.setEnabled(false)
            lastRegisteredUserId = nil
            return
        }
        switch PushDeliveryPolicy.actionForTurningOff(currentToken: persistedToken) {
        case .persistOffOnly:
            PushNotificationPreference.setEnabled(false)
            lastRegisteredUserId = nil
        case .disableBackend(let token):
            guard let client, SupabaseConfig.isConfigured else {
                throw PushNotificationSettingsError.disableFailed
            }
            do {
                _ = try await client.auth.session
                try await client.rpc(
                    "disable_push_device",
                    params: DisablePushDeviceParams(p_push_token: token)
                )
                .execute()
            } catch {
                #if DEBUG
                AppLog.push.error(
                    "disable_push_device failed: \(error.localizedDescription, privacy: .public)"
                )
                #endif
                throw PushNotificationSettingsError.disableFailed
            }
            PushNotificationPreference.setEnabled(false)
            lastRegisteredUserId = nil
        }
    }

    /// System permission + APNs registration after the user is in therapist
    /// home or active Patient Mode. Does not present a custom prompt.
    func startAfterEnteringAuthenticatedMode() async {
        guard !AuthManager.isUITesting else { return }
        guard PushDeliveryPolicy.shouldRegisterWithBackend(userPreferenceEnabled: PushNotificationPreference.isEnabled()) else {
            #if DEBUG
            AppLog.push.debug("Push start skipped: user preference off")
            #endif
            return
        }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        #if DEBUG
        AppLog.push.debug(
            "Notification permission status: \(Self.statusLabel(settings.authorizationStatus), privacy: .public)"
        )
        #endif
        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                #if DEBUG
                AppLog.push.debug("Notification authorization granted: \(granted)")
                #endif
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } catch {
                #if DEBUG
                AppLog.push.error(
                    "Notification authorization request failed: \(error.localizedDescription, privacy: .public)"
                )
                #endif
            }
        case .authorized, .provisional, .ephemeral:
            UIApplication.shared.registerForRemoteNotifications()
            await registerPersistedTokenWithBackend()
        case .denied:
            #if DEBUG
            AppLog.push.debug("Notification permission denied; skipping APNs registration")
            #endif
        @unknown default:
            break
        }
    }

    /// Re-sends the stored APNs token for the current `auth.uid()` after a
    /// successful identity change (therapist ↔ Patient Mode).
    func registerPersistedTokenForCurrentIdentity(userId: String?) async {
        guard !AuthManager.isUITesting else { return }
        guard let userId else {
            lastRegisteredUserId = nil
            return
        }
        guard PushDeliveryPolicy.shouldRegisterWithBackend(
            userPreferenceEnabled: PushNotificationPreference.isEnabled()
        ) else { return }
        if lastRegisteredUserId == userId { return }
        await registerPersistedTokenWithBackend()
    }

    func handleDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        persistedToken = token
        #if DEBUG
        AppLog.push.debug(
            "APNs registration succeeded, token length: \(token.count)"
        )
        #endif
        Task { await registerPersistedTokenWithBackend() }
    }

    func handleRegistrationFailure(_ error: Error) {
        #if DEBUG
        AppLog.push.error(
            "APNs registration failed: \(error.localizedDescription, privacy: .public)"
        )
        #endif
    }

    /// Best-effort; logout continues even if this RPC fails.
    func unregisterCurrentToken() async {
        guard !AuthManager.isUITesting else { return }
        guard let token = persistedToken else {
            #if DEBUG
            AppLog.push.debug("Push unregister skipped: no persisted APNs token")
            #endif
            return
        }
        guard let client, SupabaseConfig.isConfigured else { return }
        #if DEBUG
        AppLog.push.debug("Push unregister attempted")
        #endif
        do {
            try await client.rpc(
                "unregister_push_device",
                params: UnregisterPushDeviceParams(pPushToken: token)
            )
            .execute()
            lastRegisteredUserId = nil
            #if DEBUG
            AppLog.push.debug("Push unregister succeeded")
            #endif
        } catch {
            #if DEBUG
            AppLog.push.error(
                "Push unregister failed: \(error.localizedDescription, privacy: .public)"
            )
            #endif
        }
    }

    private func registerPersistedTokenWithBackend() async {
        do {
            try await registerPersistedTokenWithBackendThrowing()
        } catch {
            #if DEBUG
            AppLog.push.error(
                "Backend push token registration failed: \(error.localizedDescription, privacy: .public)"
            )
            #endif
        }
    }

    private func registerPersistedTokenWithBackendThrowing() async throws {
        guard !AuthManager.isUITesting else { return }
        guard PushDeliveryPolicy.shouldRegisterWithBackend(
            userPreferenceEnabled: PushNotificationPreference.isEnabled()
        ) else {
            #if DEBUG
            AppLog.push.debug("Push backend register skipped: user preference off")
            #endif
            return
        }
        guard let token = persistedToken else { return }
        guard let client, SupabaseConfig.isConfigured else { return }
        do {
            _ = try await client.auth.session
        } catch {
            #if DEBUG
            AppLog.push.debug("Push backend register skipped: no Auth session")
            #endif
            return
        }
        try await client.rpc(
            "register_push_device",
            params: RegisterPushDeviceParams(
                pPlatform: "ios",
                pPushToken: token,
                pEnvironment: pushEnvironment
            )
        )
        .execute()
        if let uid = try? await client.auth.session.user.id.uuidString {
            lastRegisteredUserId = uid
        }
        #if DEBUG
        AppLog.push.debug(
            "Backend push token registration succeeded (\(self.pushEnvironment, privacy: .public))"
        )
        #endif
    }

    private static func statusLabel(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "notDetermined"
        case .denied: "denied"
        case .authorized: "authorized"
        case .provisional: "provisional"
        case .ephemeral: "ephemeral"
        @unknown default: "unknown"
        }
    }
}

private struct RegisterPushDeviceParams: Encodable {
    let pPlatform: String
    let pPushToken: String
    let pEnvironment: String

    enum CodingKeys: String, CodingKey {
        case pPlatform = "p_platform"
        case pPushToken = "p_push_token"
        case pEnvironment = "p_environment"
    }
}

struct DisablePushDeviceParams: Encodable {
    let p_push_token: String
}

private struct UnregisterPushDeviceParams: Encodable {
    let pPushToken: String

    enum CodingKeys: String, CodingKey {
        case pPushToken = "p_push_token"
    }
}

enum PushNotificationSettingsError: LocalizedError {
    case disableFailed
    case enableFailed
    case permissionDenied
    case needsSystemSettings

    var errorDescription: String? {
        switch self {
        case .disableFailed: L10n.settingsNotificationsDisableFailed
        case .enableFailed: L10n.settingsNotificationsEnableFailed
        case .permissionDenied, .needsSystemSettings:
            L10n.settingsNotificationsPermissionDeniedMessage
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.handleDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.handleRegistrationFailure(error)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let original = notification.request.content
        // APNs sets `aps.badge` while backgrounded/terminated. Foreground
        // presentation must not apply that badge: the in-app icon follows
        // `NotificationStore.unseenCount` after refresh.
        defer {
            Task { await NotificationStore.shared?.refresh() }
        }
        guard let personalized = original.mutableCopy() as? UNMutableNotificationContent else {
            return [.banner, .list, .sound]
        }
        PatientPushPersonalizer.apply(to: personalized)
        if personalized.body == original.body, personalized.title == original.title, personalized.subtitle == original.subtitle {
            return [.banner, .list, .sound]
        }
        let request = UNNotificationRequest(
            identifier: notification.request.identifier,
            content: personalized,
            trigger: nil
        )
        do {
            try await center.add(request)
        } catch {
            return [.banner, .list, .sound]
        }
        return []
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            await MainActor.run {
                if AppNotificationPayload.from(userInfo: userInfo)?.type.routesInPatientMode == true {
                    PatientModeMessageCoordinator.shared.handlePushTap(userInfo: userInfo)
                } else {
                    TherapistNotificationCoordinator.shared.handlePushTap(userInfo: userInfo)
                }
            }
        }
        await NotificationStore.shared?.refresh()
    }
}
