package com.cbtipul.app.telemetry

import android.app.Application
import com.posthog.PersonProfiles
import com.posthog.PostHog
import com.posthog.android.PostHogAndroid
import com.posthog.android.PostHogAndroidConfig
import java.util.Date
import java.time.Instant

object PostHogSDKConfiguration {
    fun make(settings:PostHogSettings):PostHogAndroidConfig? {
        if(!settings.valid) return null
        return PostHogAndroidConfig(projectToken=settings.token,host=settings.host).apply {
            debug=false
            captureApplicationLifecycleEvents=false;captureDeepLinks=false;captureScreenViews=false
            captureElementInteractions=false;captureRageClicks=false;captureDeadClicks=false
            capturePushNotificationSubscriptions=false;capturePushNotificationOpened=false
            sessionReplay=false;preloadFeatureFlags=false;sendFeatureFlagEvent=false
            setDefaultPersonProperties=false;personProfiles=PersonProfiles.NEVER;surveys=false
            errorTrackingConfig.autoCapture=false;errorTrackingConfig.captureNativeCrashes=false
            addBeforeSend { event -> PostHogPrivacyGuard.filter(event.event,event.properties)?.let { event.copy(properties=it) } }
            logs.addBeforeSend {null}
            // SDK defaults own queues, flushes, retries, sessions and anonymous identity.
        }
    }
}
object PostHogSDKCapture:TelemetryCapture {
    override fun capture(event:Event) {
        val mapped=PostHogEventMapper.map(event) ?: return
        PostHog.capture(mapped.name,properties=mapped.properties,timestamp=Date.from(Instant.parse(mapped.timestamp)))
    }
    override fun reset() {PostHog.reset()}
}
object PostHogTelemetryBootstrap {
    private var initialized=false
    @Synchronized fun configure(app:Application,client:TelemetryClient,settings:PostHogSettings=PostHogSettings.production) {
        val config=PostHogSDKConfiguration.make(settings)
        if(!settings.enabled || config==null) {client.configure(DisabledTelemetryCapture);return}
        if(!initialized) {PostHogAndroid.setup(app,config);initialized=true}
        client.configure(PostHogSDKCapture)
    }
}
