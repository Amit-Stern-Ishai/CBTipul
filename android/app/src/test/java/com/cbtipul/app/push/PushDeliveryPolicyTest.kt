package com.cbtipul.app.push

import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PushDeliveryPolicyTest {
    @Test
    fun existingUserDefaultsToNotificationsEnabled() {
        assertTrue(PushDeliveryPolicy.userPreferenceEnabled(null))
        assertTrue(PushDeliveryPolicy.userPreferenceEnabled(true))
        assertFalse(PushDeliveryPolicy.userPreferenceEnabled(false))
    }

    @Test
    fun offPersistsAsStoredFalse() {
        assertFalse(PushDeliveryPolicy.userPreferenceEnabled(false))
        assertTrue(PushDeliveryPolicy.shouldRegisterWithBackend(PushDeliveryPolicy.userPreferenceEnabled(true)))
        assertFalse(PushDeliveryPolicy.shouldRegisterWithBackend(PushDeliveryPolicy.userPreferenceEnabled(false)))
    }

    @Test
    fun offDoesNotRegisterOnStartupTokenRefreshOrIdentityChange() {
        assertFalse(PushDeliveryPolicy.shouldRegisterWithBackend(false))
        assertTrue(PushDeliveryPolicy.shouldRegisterWithBackend(true))
    }

    @Test
    fun turningOffCallsDisableWithCurrentToken() {
        val action = PushDeliveryPolicy.actionForTurningOff("fcm-token")
        assertEquals(PushDeliveryPolicy.TurnOffAction.DisableBackend("fcm-token"), action)
        assertEquals(
            PushDeliveryPolicy.TurnOffAction.PersistOffOnly,
            PushDeliveryPolicy.actionForTurningOff(null),
        )
        val body = PushDeviceRpc.disable("fcm-token")
        assertEquals("fcm-token", body["p_push_token"]?.jsonPrimitive?.content)
        assertEquals(setOf("p_push_token"), body.keys)
    }

    @Test
    fun turningOnWithPermissionGrantedRegisters() {
        assertEquals(
            PushDeliveryPolicy.TurnOnAction.PersistOnAndRegister,
            PushDeliveryPolicy.actionForTurningOn(OsNotificationAuthorization.Allowed),
        )
        val register = PushDeviceRpc.register("tok", "android", "production")
        assertEquals("android", register["p_platform"]?.jsonPrimitive?.content)
        assertEquals("tok", register["p_push_token"]?.jsonPrimitive?.content)
        assertEquals("production", register["p_environment"]?.jsonPrimitive?.content)
    }

    @Test
    fun firstTimeOnRequestsOsPermission() {
        assertEquals(
            PushDeliveryPolicy.TurnOnAction.RequestPermission,
            PushDeliveryPolicy.actionForTurningOn(OsNotificationAuthorization.NotDetermined),
        )
    }

    @Test
    fun deniedPermissionLeavesEffectiveOff() {
        assertEquals(
            PushDeliveryPolicy.TurnOnAction.RemainOffAndOfferSettings,
            PushDeliveryPolicy.actionForTurningOn(OsNotificationAuthorization.Denied),
        )
        assertFalse(PushDeliveryPolicy.toggleShowsOn(true, false))
        assertFalse(PushDeliveryPolicy.toggleShowsOn(false, true))
    }

    @Test
    fun systemPermissionDisabledIsReflectedAsEffectiveOff() {
        assertTrue(PushDeliveryPolicy.toggleShowsOn(true, true))
        assertFalse(PushDeliveryPolicy.toggleShowsOn(true, false))
    }

    @Test
    fun persistentInboxIsIndependentOfPushPreference() {
        assertFalse(PushDeliveryPolicy.AFFECTS_PERSISTENT_INBOX)
        assertFalse(PushDeliveryPolicy.shouldRegisterWithBackend(false))
    }

    @Test
    fun enabledToggleKeepsExistingRegistrationPath() {
        assertTrue(PushDeliveryPolicy.shouldRegisterWithBackend(true))
        assertEquals(
            PushDeliveryPolicy.TurnOnAction.PersistOnAndRegister,
            PushDeliveryPolicy.actionForTurningOn(OsNotificationAuthorization.Allowed),
        )
    }
}
