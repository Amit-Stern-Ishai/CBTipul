package com.cbtipul.app.push

enum class OsNotificationAuthorization {
    NotDetermined,
    Denied,
    Allowed,
}

object PushDeliveryPolicy {
    /** Persistent in-app notifications ignore the system-push preference. */
    const val AFFECTS_PERSISTENT_INBOX = false

    fun userPreferenceEnabled(stored: Boolean?): Boolean = stored ?: true

    fun shouldRegisterWithBackend(userPreferenceEnabled: Boolean): Boolean = userPreferenceEnabled

    fun toggleShowsOn(userPreferenceEnabled: Boolean, osAllowed: Boolean): Boolean =
        userPreferenceEnabled && osAllowed

    enum class TurnOnAction {
        PersistOnAndRegister,
        RequestPermission,
        RemainOffAndOfferSettings,
    }

    fun actionForTurningOn(osStatus: OsNotificationAuthorization): TurnOnAction = when (osStatus) {
        OsNotificationAuthorization.Allowed -> TurnOnAction.PersistOnAndRegister
        OsNotificationAuthorization.NotDetermined -> TurnOnAction.RequestPermission
        OsNotificationAuthorization.Denied -> TurnOnAction.RemainOffAndOfferSettings
    }

    sealed class TurnOffAction {
        data class DisableBackend(val token: String) : TurnOffAction()
        data object PersistOffOnly : TurnOffAction()
    }

    fun actionForTurningOff(currentToken: String?): TurnOffAction {
        val token = currentToken?.takeIf { it.isNotBlank() }
        return if (token != null) TurnOffAction.DisableBackend(token) else TurnOffAction.PersistOffOnly
    }
}
