package com.cbtipul.app.settings

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.dataStore by preferencesDataStore(name = "cbtipul_settings")

class AppPreferences(private val context: Context) {
    val discovery = com.cbtipul.app.data.DiscoveryLedger(java.io.File(context.noBackupFilesDir, "discovery.json"))

    val notificationsEnabledByUser: Flow<Boolean> = context.dataStore.data.map { prefs ->
        prefs[Keys.NOTIFICATIONS_ENABLED] ?: true
    }

    val appearance: Flow<AppAppearance> = context.dataStore.data.map { prefs ->
        AppAppearance.fromStorage(prefs[Keys.APPEARANCE])
    }

    val textSize: Flow<AppTextSize> = context.dataStore.data.map { prefs ->
        AppTextSize.fromStorage(prefs[Keys.TEXT_SIZE])
    }

    val aiResponseStyle: Flow<AIResponseStyle> = context.dataStore.data.map { prefs ->
        AIResponseStyle.fromStorage(prefs[Keys.AI_RESPONSE_STYLE])
    }

    fun hasAcceptedTerms(email: String): Flow<Boolean> =
        context.dataStore.data.map { prefs ->
            prefs[booleanPreferencesKey(termsKey(email))] == true
        }

    suspend fun setAppearance(value: AppAppearance) {
        context.dataStore.edit { it[Keys.APPEARANCE] = value.storageValue }
    }

    suspend fun isNotificationsEnabledByUser(): Boolean =
        context.dataStore.data.map { prefs ->
            prefs[Keys.NOTIFICATIONS_ENABLED] ?: true
        }.first()

    suspend fun setNotificationsEnabledByUser(enabled: Boolean) {
        context.dataStore.edit { it[Keys.NOTIFICATIONS_ENABLED] = enabled }
    }

    suspend fun setTextSize(value: AppTextSize) {
        context.dataStore.edit { it[Keys.TEXT_SIZE] = value.storageValue }
    }

    suspend fun setAiResponseStyle(value: AIResponseStyle) {
        context.dataStore.edit { it[Keys.AI_RESPONSE_STYLE] = value.storageValue }
    }

    suspend fun setAcceptedTerms(email: String) {
        context.dataStore.edit {
            it[booleanPreferencesKey(termsKey(email))] = true
        }
    }

    fun hasAcceptedAiConsent(email: String): Flow<Boolean> =
        context.dataStore.data.map { prefs ->
            prefs[booleanPreferencesKey(aiAcceptedKey(email))] == true
        }

    suspend fun isAiConsentAccepted(email: String): Boolean =
        context.dataStore.data.map { prefs ->
            prefs[booleanPreferencesKey(aiAcceptedKey(email))] == true
        }.first()

    suspend fun setAiConsentAccepted(email: String) {
        context.dataStore.edit {
            it[booleanPreferencesKey(aiAcceptedKey(email))] = true
            it[booleanPreferencesKey(aiDeclinedKey(email))] = false
        }
    }

    suspend fun setAiConsentDeclined(email: String) {
        context.dataStore.edit {
            it[booleanPreferencesKey(aiDeclinedKey(email))] = true
        }
    }

    suspend fun discoverySeen(account: String, feature: String): Boolean = try {
        if (feature.endsWith("recentVisit")) {
            context.dataStore.data.first()[booleanPreferencesKey(com.cbtipul.app.data.DiscoveryRules.key(account, feature))] == true
        } else {
            val suffix = ".${feature.substringAfterLast('.')}.${account.lowercase(java.util.Locale.ROOT)}"
            val legacy = context.dataStore.data.first().asMap().filter { (key, value) ->
                key.name.startsWith("discovery.") && key.name.endsWith(suffix) && value == true
            }
            if (legacy.isNotEmpty() && discovery.mark(account, feature)) {
                context.dataStore.edit { prefs -> legacy.keys.forEach { prefs.remove(booleanPreferencesKey(it.name)) } }
            }
            discovery.seen(account, feature)
        }
    } catch (_: java.io.IOException) { true }

    suspend fun markDiscovery(account: String, feature: String) {
        if (!feature.endsWith("recentVisit")) { discovery.mark(account, feature); return }
        try { context.dataStore.edit { it[booleanPreferencesKey(com.cbtipul.app.data.DiscoveryRules.key(account, feature))] = true } }
        catch (_: java.io.IOException) { }
    }
    suspend fun enqueueDiscovery(account: String, feature: String, patient: String, standalone: Boolean = false, session: String? = null, reminderOnly: Boolean = false, initialOnly: Boolean = false) {
        val context = discovery.activeContext
        val alreadyShown = discoverySeen(account, feature) // Migrate before determining the reminder budget.
        if (alreadyShown && (!discovery.seen(account, feature) || context != discovery.activeContext)) return
        discovery.enqueue(account, feature, patient, standalone, session, reminderOnly, initialOnly)
    }

    private fun termsKey(email: String) = "hasAcceptedTerms-$email"

    private fun aiAcceptedKey(email: String) = "aiDataSharingConsentAccepted-$email"

    private fun aiDeclinedKey(email: String) = "aiDataSharingConsentDeclined-$email"

    private object Keys {
        val APPEARANCE = stringPreferencesKey("appAppearance")
        val TEXT_SIZE = stringPreferencesKey("appTextSize")
        val AI_RESPONSE_STYLE = stringPreferencesKey("aiResponseStyle")
        val NOTIFICATIONS_ENABLED = booleanPreferencesKey("notificationsEnabledByUser")
    }
}
