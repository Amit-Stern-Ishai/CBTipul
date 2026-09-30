package com.cbtipul.app.push

import android.Manifest
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.core.content.edit
import com.cbtipul.app.BuildConfig
import com.cbtipul.app.MainActivity
import com.cbtipul.app.R
import com.cbtipul.app.auth.AuthRepository
import com.cbtipul.app.auth.AuthSession
import com.cbtipul.app.data.PatientIdentityStore
import com.cbtipul.app.data.SupabaseConfig
import com.cbtipul.app.model.DatabaseId
import com.cbtipul.app.settings.AppPreferences
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.RemoteMessage
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

/**
 * Native FCM registration against `register_push_device` /
 * `unregister_push_device`. Ownership is always `auth.uid()` on the server.
 */
class PushNotificationManager(
    private val appContext: Context,
    private val client: SupabaseClient,
    private val auth: AuthRepository,
    private val identityStore: PatientIdentityStore,
    private val preferences: AppPreferences,
    private val scope: CoroutineScope,
    private val onPushReceived: () -> Unit = {},
) {
    private val prefs: SharedPreferences =
        appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private var lastRegisteredUserId: String? = null

    var persistedToken: String?
        get() = prefs.getString(KEY_TOKEN, null)?.takeIf { it.isNotBlank() }
        private set(value) {
            prefs.edit {
                if (value.isNullOrBlank()) remove(KEY_TOKEN) else putString(KEY_TOKEN, value)
            }
        }

    fun start() {
        ensureChannel()
        scope.launch {
            auth.session
                .map { session -> (session as? AuthSession.SignedIn)?.userId }
                .distinctUntilChanged()
                .collect { userId ->
                    registerPersistedTokenForCurrentIdentity(userId)
                }
        }
    }

    fun startAfterEnteringAuthenticatedMode(
        activity: Activity,
        requestPermission: () -> Unit,
    ) {
        ensureChannel()
        scope.launch {
            if (!PushDeliveryPolicy.shouldRegisterWithBackend(preferences.isNotificationsEnabledByUser())) {
                debug { "Push start skipped: user preference off" }
                return@launch
            }
            startAuthenticatedRegistration(activity, requestPermission)
        }
    }

    private fun startAuthenticatedRegistration(
        activity: Activity,
        requestPermission: () -> Unit,
    ) {
        if (Build.VERSION.SDK_INT >= 33) {
            val granted = ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
            debug { "Notification permission status: ${if (granted) "granted" else "not granted"}" }
            if (granted) {
                scope.launch { fetchAndRegisterToken() }
                return
            }
            if (prefs.getBoolean(KEY_PERMISSION_ASKED, false) &&
                !activity.shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS)
            ) {
                debug { "Notification permission denied; skipping request" }
                scope.launch { fetchAndRegisterToken() }
                return
            }
            prefs.edit { putBoolean(KEY_PERMISSION_ASKED, true) }
            requestPermission()
        } else {
            debug { "Notification permission status: not required (pre-33)" }
            scope.launch { fetchAndRegisterToken() }
        }
    }

    fun onNotificationPermissionResult(granted: Boolean) {
        debug { "Notification permission result: ${if (granted) "granted" else "denied"}" }
        scope.launch {
            if (!PushDeliveryPolicy.shouldRegisterWithBackend(preferences.isNotificationsEnabledByUser())) {
                debug { "Push permission result ignored: user preference off" }
                return@launch
            }
            fetchAndRegisterToken()
        }
    }

    fun osAuthorization(): OsNotificationAuthorization {
        val manager = appContext.getSystemService(NotificationManager::class.java)
        if (manager?.areNotificationsEnabled() == false) return OsNotificationAuthorization.Denied
        if (Build.VERSION.SDK_INT < 33) return OsNotificationAuthorization.Allowed
        val granted = ContextCompat.checkSelfPermission(
            appContext,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) return OsNotificationAuthorization.Allowed
        if (!prefs.getBoolean(KEY_PERMISSION_ASKED, false)) {
            return OsNotificationAuthorization.NotDetermined
        }
        return OsNotificationAuthorization.Denied
    }

    fun osNotificationsAllowed(): Boolean = osAuthorization() == OsNotificationAuthorization.Allowed

    fun markOsPermissionAsked() {
        prefs.edit { putBoolean(KEY_PERMISSION_ASKED, true) }
    }

    fun openSystemNotificationSettings() {
        val intent = Intent().apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                putExtra(Settings.EXTRA_APP_PACKAGE, appContext.packageName)
            } else {
                action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                data = Uri.fromParts("package", appContext.packageName, null)
            }
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        appContext.startActivity(intent)
    }

    suspend fun disableNotifications() {
        val token = persistedToken ?: fetchTokenOrNull()
        when (val action = PushDeliveryPolicy.actionForTurningOff(token)) {
            is PushDeliveryPolicy.TurnOffAction.PersistOffOnly -> {
                preferences.setNotificationsEnabledByUser(false)
                lastRegisteredUserId = null
            }
            is PushDeliveryPolicy.TurnOffAction.DisableBackend -> {
                if (!SupabaseConfig.isConfigured || !auth.hasSession()) {
                    error("disable_push_device_unavailable")
                }
                client.postgrest.rpc(
                    "disable_push_device",
                    PushDeviceRpc.disable(action.token),
                )
                preferences.setNotificationsEnabledByUser(false)
                lastRegisteredUserId = null
            }
        }
    }

    suspend fun enableNotificationsAfterOsAllowed() {
        preferences.setNotificationsEnabledByUser(true)
        lastRegisteredUserId = null
        fetchAndRegisterToken()
    }

    suspend fun registerPersistedTokenForCurrentIdentity(userId: String?) {
        if (userId == null) {
            lastRegisteredUserId = null
            return
        }
        if (!PushDeliveryPolicy.shouldRegisterWithBackend(preferences.isNotificationsEnabledByUser())) {
            return
        }
        if (lastRegisteredUserId == userId && persistedToken != null) return
        registerTokenWithBackend(persistedToken ?: fetchTokenOrNull())
    }

    fun onNewToken(token: String) {
        debug { "[Push] FCM token refresh, length=${token.length}" }
        persistedToken = token
        scope.launch {
            if (auth.hasSession()) {
                registerTokenWithBackend(token)
            }
        }
    }

    fun onMessageReceived(message: RemoteMessage) {
        val payload = com.cbtipul.app.data.NotificationPayload.from(message.data.mapValues { it.value })
        val fallbackTitle = message.notification?.title ?: message.data["title"]
        val fallbackBody = message.notification?.body ?: message.data["body"]
        debug {
            "FCM message messageId=${message.messageId ?: "none"} " +
                "hasNotification=${message.notification != null} dataKeys=${message.data.keys}"
        }
        val personalized = PatientPushPersonalizer.personalize(
            type = payload?.type ?: message.data["type"],
            patientId = payload?.patientId,
            fallbackTitle = fallbackTitle,
            fallbackBody = fallbackBody,
            assignmentId = payload?.assignmentId,
            sessionId = payload?.sessionId,
            resourceType = payload?.resourceType,
            resourceId = payload?.resourceId,
            notificationId = payload?.notificationId,
            nameForPatientId = ::localNameForPatientId,
        )
        onPushReceived()
        if (personalized.title.isBlank() && personalized.body.isBlank()) return
        showVisibleNotification(personalized, message.messageId)
    }

    suspend fun unregisterCurrentToken() {
        val token = persistedToken
        if (token == null) {
            debug { "Push unregister skipped: no persisted FCM token" }
            return
        }
        if (!SupabaseConfig.isConfigured) return
        debug { "Push unregister attempted" }
        try {
            client.postgrest.rpc(
                "unregister_push_device",
                PushDeviceRpc.unregister(token),
            )
            lastRegisteredUserId = null
            debug { "Push unregister succeeded" }
        } catch (error: Exception) {
            debug { "Push unregister failed: ${safeError(error)}" }
        }
    }

    private suspend fun fetchAndRegisterToken() {
        registerTokenWithBackend(fetchTokenOrNull())
    }

    private suspend fun fetchTokenOrNull(): String? {
        return try {
            val token = FirebaseMessaging.getInstance().token.await()
            if (token.isBlank()) {
                debug { "FCM token retrieval returned empty" }
                return null
            }
            persistedToken = token
            debug { "[Push] FCM token obtained length=${token.length}" }
            token
        } catch (error: Exception) {
            debug { "[Push] FCM token retrieval failed: ${safeError(error)}" }
            persistedToken
        }
    }

    private suspend fun registerTokenWithBackend(token: String?) {
        if (token.isNullOrBlank()) return
        persistedToken = token
        if (!PushDeliveryPolicy.shouldRegisterWithBackend(preferences.isNotificationsEnabledByUser())) {
            debug { "Push backend register skipped: user preference off" }
            return
        }
        if (!SupabaseConfig.isConfigured) return
        if (!auth.hasSession()) {
            debug { "Push backend register skipped: no Auth session" }
            return
        }
        try {
            debug {
                "[Push] Registering Android push device for current identity " +
                    "platform=${PushRegistration.PLATFORM} env=${PushRegistration.ENVIRONMENT}"
            }
            client.postgrest.rpc(
                "register_push_device",
                PushDeviceRpc.register(token, PushRegistration.PLATFORM, PushRegistration.ENVIRONMENT),
            )
            lastRegisteredUserId = auth.currentUserId()
            debug { "[Push] register_push_device succeeded" }
        } catch (error: Exception) {
            debug { "[Push] register_push_device failed: ${safeError(error)}" }
        }
    }

    private fun ensureChannel() {
        val manager = appContext.getSystemService(NotificationManager::class.java) ?: return
        val existing = manager.getNotificationChannel(PushRegistration.CHANNEL_ID)
        if (existing != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                PushRegistration.CHANNEL_ID,
                appContext.getString(R.string.notifications_channel_name),
                NotificationManager.IMPORTANCE_DEFAULT,
            ),
        )
    }

    private fun localNameForPatientId(patientId: String): String? {
        val fromText = identityStore.name(DatabaseId.Text(patientId))
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
        if (fromText != null) return fromText
        val intId = patientId.toIntOrNull() ?: return null
        return identityStore.name(DatabaseId.Integer(intId))?.trim()?.takeIf { it.isNotEmpty() }
    }

    private fun showVisibleNotification(
        personalized: PatientPushPersonalizer.Result,
        messageId: String?,
    ) {
        ensureChannel()
        val launch = Intent(appContext, MainActivity::class.java).apply {
            // Intent extras do not participate in PendingIntent identity. A unique URI
            // prevents different entries from overwriting each other's tap destination.
            data = android.net.Uri.Builder().scheme("cbtipul").authority("notification")
                .appendPath(personalized.notificationId ?: messageId ?: java.util.UUID.randomUUID().toString()).build()
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
            personalized.type?.let { putExtra(PatientPushPersonalizer.EXTRA_TYPE, it) }
            personalized.patientId?.let { putExtra(PatientPushPersonalizer.EXTRA_PATIENT_ID, it) }
            personalized.assignmentId?.let { putExtra(PatientPushPersonalizer.EXTRA_ASSIGNMENT_ID, it) }
            personalized.sessionId?.let { putExtra(PatientPushPersonalizer.EXTRA_SESSION_ID, it) }
            personalized.resourceType?.let { putExtra(PatientPushPersonalizer.EXTRA_RESOURCE_TYPE, it) }
            personalized.resourceId?.let { putExtra(PatientPushPersonalizer.EXTRA_RESOURCE_ID, it) }
            personalized.notificationId?.let { putExtra(PatientPushPersonalizer.EXTRA_NOTIFICATION_ID, it) }
        }
        val requestCode = (messageId?.hashCode() ?: System.currentTimeMillis().toInt()) and 0x7fffffff
        val pending = PendingIntent.getActivity(
            appContext,
            requestCode,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(appContext, PushRegistration.CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(
                personalized.title.ifBlank { appContext.getString(R.string.app_name) },
            )
            .setContentText(personalized.body)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
        appContext.getSystemService(NotificationManager::class.java)
            ?.notify(launch.data.toString(), 0, notification)
    }

    private inline fun debug(message: () -> String) {
        if (!BuildConfig.DEBUG) return
        Log.d(TAG, message())
    }

    private fun safeError(error: Exception): String {
        var text = buildString {
            append(error::class.java.simpleName)
            error.message?.let { append(": ").append(it) }
        }
        text = JWT.replace(text, "[redacted]")
        text = HEX.replace(text, "[redacted]")
        return text.take(500)
    }

    companion object {
        private const val TAG = "CBTipulPush"
        private const val PREFS_NAME = "cbtipul_push"
        private const val KEY_TOKEN = "fcm_token"
        private const val KEY_PERMISSION_ASKED = "notification_permission_asked"
        private val JWT = Regex("eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+")
        private val HEX = Regex("\\b[a-fA-F0-9]{32,}\\b")
    }
}
