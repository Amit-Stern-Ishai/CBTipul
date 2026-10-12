import Foundation
@preconcurrency import PostHog

@MainActor enum PostHogSDKConfiguration {
    static func make(settings: PostHogSettings) -> PostHogConfig? {
        guard settings.valid else { return nil }
        let config = PostHogConfig(projectToken: settings.token, host: settings.host)
        config.debug = false
        config.captureApplicationLifecycleEvents = false; config.captureScreenViews = false; config.enableSwizzling = false
        config.preloadFeatureFlags = false; config.sendFeatureFlagEvent = false
        config.setDefaultPersonProperties = false; config.personProfiles = .never; config.disableGeoIp = true
        config.errorTrackingConfig.autoCapture = false
        #if os(iOS)
        config.surveys = false
        config.sessionReplay = false; config.captureElementInteractions = false; config.captureSwiftUIElementInteractions = false
        config.captureAutocaptureElementText = false; config.capturePushNotificationSubscriptions = false; config.capturePushNotificationOpened = false
        config.tracingHeaders = []
        #endif
        config.setBeforeSend { event in
            guard let properties = PostHogPrivacyGuard.filter(name: event.event, properties: event.properties) else { return nil }
            event.properties = properties
            return event
        }
        config.logs.setBeforeSend { _ in nil }
        // Queue, flush, retry, session and anonymous-identity settings retain SDK defaults.
        return config
    }
}
nonisolated struct PostHogSDKCapture: TelemetryCapture {
    func capture(_ event: TelemetryEvent) {
        guard let mapped = PostHogEventMapper.map(event) else { return }
        PostHogSDK.shared.capture(mapped.name, properties: mapped.properties, timestamp: mapped.timestamp)
    }
    func reset() { PostHogSDK.shared.reset() }
}
@MainActor enum PostHogTelemetryBootstrap {
    private static var initialized = false
    static func configure(_ client: TelemetryClient, settings: PostHogSettings = .production) {
        guard settings.enabled, let config = PostHogSDKConfiguration.make(settings: settings) else {
            client.configure(capture: DisabledTelemetryCapture()); return
        }
        if !initialized { PostHogSDK.shared.setup(config); initialized = true }
        client.configure(capture: PostHogSDKCapture())
    }
}
