package com.cbtipul.app.telemetry

import com.posthog.PostHogEvent
import com.posthog.PersonProfiles
import com.posthog.android.PostHogAndroidConfig
import org.junit.Assert.*
import org.junit.Test
import java.util.Date
import java.util.UUID

class PostHogTelemetryTest {
    private val settings=PostHogSettings("phc_synthetic_test","https://eu.i.posthog.com",true)
    @Test fun missingConfigurationAndDisabledDefault() {
        assertNull(PostHogSDKConfiguration.make(settings.copy(token="")))
        assertFalse(PostHogTelemetryConfiguration.valid("phx_personal",settings.host))
        assertFalse(PostHogTelemetryConfiguration.valid(settings.token,"https://us.i.posthog.com"))
    }
    @Test fun actualSDKConfigurationUsesQueueAndIdentityDefaults() {
        val config=PostHogSDKConfiguration.make(settings)!!;val defaults=PostHogAndroidConfig(settings.token,settings.host)
        assertEquals(defaults.maxQueueSize,config.maxQueueSize);assertEquals(defaults.flushAt,config.flushAt);assertEquals(defaults.maxBatchSize,config.maxBatchSize)
        assertEquals(defaults.flushIntervalSeconds,config.flushIntervalSeconds);assertEquals(defaults.reuseAnonymousId,config.reuseAnonymousId)
        assertEquals(PersonProfiles.NEVER,config.personProfiles);assertFalse(config.setDefaultPersonProperties)
        assertFalse(config.captureApplicationLifecycleEvents);assertFalse(config.captureScreenViews);assertFalse(config.captureDeepLinks)
        assertFalse(config.captureElementInteractions);assertFalse(config.captureRageClicks);assertFalse(config.captureDeadClicks)
        assertFalse(config.sessionReplay);assertFalse(config.surveys);assertFalse(config.preloadFeatureFlags);assertFalse(config.sendFeatureFlagEvent)
        assertFalse(config.errorTrackingConfig.autoCapture);assertFalse(config.errorTrackingConfig.captureNativeCrashes)
        assertFalse(config.capturePushNotificationOpened);assertFalse(config.capturePushNotificationSubscriptions)
    }
    @Test fun supportedBeforeSendPreservesSDKIdentityTimestampUUIDAndFiltersProperties() {
        val config=PostHogSDKConfiguration.make(settings)!!
        val session=UUID.randomUUID().toString();val id=UUID.randomUUID();val timestamp=Date(10_000)
        val e=PostHogEvent(event="cbtipul_access_failed",distinctId="sdk-anonymous",uuid=id,timestamp=timestamp,properties=mutableMapOf("flow" to "access","stage" to "failed","role" to "therapist","safe_error_code" to "unresolved","\$session_id" to session,"\$lib" to "posthog-android","\$lib_version" to "3.72.2","email" to "private@example.com","patient_id" to "clinical","note" to "private clinical text","\$device_name" to "private phone","\$set" to mapOf("email" to "secret"),"\$exception_list" to listOf("raw")))
        var filtered:PostHogEvent?=e
        config.beforeSendList.forEach {filtered=filtered?.let(it::run)}
        val result=filtered!!;assertEquals(e.distinctId,result.distinctId);assertEquals(id,result.uuid);assertEquals(timestamp,result.timestamp)
        assertEquals(session,result.properties!!["\$session_id"]);assertEquals(false,result.properties!!["\$process_person_profile"]);assertEquals(true,result.properties!!["\$geoip_disable"])
        for(key in listOf("email","patient_id","note","\$device_name","\$set","\$exception_list")) assertFalse(result.properties!!.containsKey(key))
        assertNull(PostHogPrivacyGuard.filter("\$screen",e.properties))
        assertNull(PostHogPrivacyGuard.filter(e.event,mapOf("flow" to "access","stage" to "failed","safe_error_code" to "raw clinical error"))!!["safe_error_code"])
    }
    @Test fun explicitTypedMapperDoesNotProvideIdentity() {
        val sink=RecordingCapture();val c=TelemetryClient({Metadata()},sink)
        c.begin(Flow.authentication,method=Method.google).event(Stage.succeeded)
        val mapped=PostHogEventMapper.map(sink.events.last())!!
        assertEquals("cbtipul_authentication_succeeded",mapped.name)
        for(key in listOf("distinct_id","installation_id","app_session_id","event_id")) assertFalse(mapped.properties.containsKey(key))
    }
}
