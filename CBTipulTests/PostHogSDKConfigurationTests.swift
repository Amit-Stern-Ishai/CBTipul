import Foundation
import Testing
import PostHog
@testable import CBTipul

@MainActor struct PostHogSDKConfigurationTests {
    private var settings: PostHogSettings {PostHogSettings(token:"phc_synthetic_test",host:"https://eu.i.posthog.com",enabled:true)}
    @Test func missingConfigurationLeavesFunctionalClient() {
        #expect(PostHogSDKConfiguration.make(settings:PostHogSettings(token:"",host:settings.host,enabled:true))==nil)
        let recorder=RecordingCapture();let c=TelemetryClient(metadata: testMetadata,capture:recorder)
        c.configure(capture:DisabledTelemetryCapture());c.begin(.access);#expect(recorder.events.isEmpty)
    }
    @Test func supportedControlsAndSDKQueueIdentityDefaults() {
        let config=PostHogSDKConfiguration.make(settings:settings)!
        let defaults=PostHogConfig(projectToken:settings.token,host:settings.host)
        #expect(config.maxQueueSize==defaults.maxQueueSize);#expect(config.maxBatchSize==defaults.maxBatchSize)
        #expect(config.flushAt==defaults.flushAt);#expect(config.flushIntervalSeconds==defaults.flushIntervalSeconds)
        #expect(config.reuseAnonymousId==defaults.reuseAnonymousId)
        let id=UUID();#expect(config.getAnonymousId(id)==id)
        #expect(config.personProfiles == .never);#expect(!config.setDefaultPersonProperties);#expect(config.disableGeoIp)
        #expect(!config.captureApplicationLifecycleEvents);#expect(!config.captureScreenViews);#expect(!config.enableSwizzling)
        #expect(!config.preloadFeatureFlags);#expect(!config.sendFeatureFlagEvent);#expect(!config.errorTrackingConfig.autoCapture)
        #if os(iOS)
        #expect(!config.surveys);#expect(!config.sessionReplay);#expect(!config.captureElementInteractions)
        #expect(!config.captureSwiftUIElementInteractions);#expect(!config.captureAutocaptureElementText)
        #expect(!config.capturePushNotificationOpened);#expect(!config.capturePushNotificationSubscriptions)
        #expect(config.tracingHeaders?.isEmpty == true)
        #endif
    }
}
nonisolated private func testMetadata() -> TelemetryMetadata {
    TelemetryMetadata(platform:"ios",deviceModel:"unknown",manufacturer:nil,osVersion:"unknown",apiLevel:nil,appVersion:"unknown",build:"unknown",buildChannel:"debug",distribution:"unknown",role:.unknown,network:.unknown,lifecycle:.unknown,locale:"unknown",timezone:"unknown")
}
