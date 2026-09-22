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

    /// System permission + APNs registration after the user is in therapist
    /// home or active Patient Mode. Does not present a custom prompt.
    func startAfterEnteringAuthenticatedMode() async {
        guard !AuthManager.isUITesting else { return }
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
        guard !AuthManager.isUITesting else { return }
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
        do {
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
        } catch {
            #if DEBUG
            AppLog.push.error(
                "Backend push token registration failed: \(error.localizedDescription, privacy: .public)"
            )
            #endif
        }
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

private struct UnregisterPushDeviceParams: Encodable {
    let pPushToken: String

    enum CodingKeys: String, CodingKey {
        case pPushToken = "p_push_token"
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
        guard let personalized = original.mutableCopy() as? UNMutableNotificationContent else {
            return [.banner, .list, .sound, .badge]
        }
        PatientPushPersonalizer.apply(to: personalized)
        if personalized.body == original.body {
            return [.banner, .list, .sound, .badge]
        }
        let request = UNNotificationRequest(
            identifier: notification.request.identifier,
            content: personalized,
            trigger: nil
        )
        do {
            try await center.add(request)
        } catch {
            return [.banner, .list, .sound, .badge]
        }
        return []
    }
}
