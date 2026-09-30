import Foundation
import Testing
@testable import CBTipul

struct PushNotificationPreferenceTests {
    @Test func existingUserDefaultsToNotificationsEnabled() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        #expect(PushNotificationPreference.isEnabled(defaults: defaults))
    }

    @Test func offPersistsAcrossReread() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        PushNotificationPreference.setEnabled(false, defaults: defaults)
        #expect(!PushNotificationPreference.isEnabled(defaults: defaults))
        PushNotificationPreference.setEnabled(true, defaults: defaults)
        #expect(PushNotificationPreference.isEnabled(defaults: defaults))
    }

    @Test func offDoesNotRegisterOnStartupTokenRefreshOrIdentityChange() {
        #expect(!PushDeliveryPolicy.shouldRegisterWithBackend(userPreferenceEnabled: false))
        #expect(PushDeliveryPolicy.shouldRegisterWithBackend(userPreferenceEnabled: true))
    }

    @Test func turningOffCallsDisableWithCurrentToken() {
        #expect(
            PushDeliveryPolicy.actionForTurningOff(currentToken: "apns-token")
                == .disableBackend(token: "apns-token")
        )
        #expect(PushDeliveryPolicy.actionForTurningOff(currentToken: nil) == .persistOffOnly)
        #expect(PushDeliveryPolicy.actionForTurningOff(currentToken: "") == .persistOffOnly)
    }

    @Test func disableRpcEncodesPushToken() throws {
        let data = try JSONEncoder().encode(DisablePushDeviceParams(p_push_token: "current-token"))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: String]
        #expect(json?["p_push_token"] == "current-token")
        #expect(json?.count == 1)
    }

    @Test func turningOnWithPermissionGrantedRegisters() {
        #expect(
            PushDeliveryPolicy.actionForTurningOn(osStatus: .allowed) == .persistOnAndRegister
        )
    }

    @Test func firstTimeOnRequestsOsPermission() {
        #expect(
            PushDeliveryPolicy.actionForTurningOn(osStatus: .notDetermined) == .requestPermission
        )
    }

    @Test func deniedPermissionLeavesEffectiveOff() {
        #expect(
            PushDeliveryPolicy.actionForTurningOn(osStatus: .denied) == .remainOffAndOfferSettings
        )
        #expect(
            !PushDeliveryPolicy.toggleShowsOn(userPreferenceEnabled: true, osAllowed: false)
        )
        #expect(
            !PushDeliveryPolicy.toggleShowsOn(userPreferenceEnabled: false, osAllowed: true)
        )
    }

    @Test func systemPermissionDisabledIsReflectedAsEffectiveOff() {
        #expect(PushDeliveryPolicy.toggleShowsOn(userPreferenceEnabled: true, osAllowed: true))
        #expect(!PushDeliveryPolicy.toggleShowsOn(userPreferenceEnabled: true, osAllowed: false))
    }

    @Test func persistentInboxIsIndependentOfPushPreference() {
        #expect(!PushDeliveryPolicy.affectsPersistentInbox)
        #expect(!PushDeliveryPolicy.shouldRegisterWithBackend(userPreferenceEnabled: false))
    }

    @Test func enabledToggleKeepsExistingRegistrationPath() {
        #expect(PushDeliveryPolicy.shouldRegisterWithBackend(userPreferenceEnabled: true))
        #expect(PushDeliveryPolicy.actionForTurningOn(osStatus: .allowed) == .persistOnAndRegister)
    }
}
