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

    private fun termsKey(email: String) = "hasAcceptedTerms-$email"

    private fun aiAcceptedKey(email: String) = "aiDataSharingConsentAccepted-$email"

    private fun aiDeclinedKey(email: String) = "aiDataSharingConsentDeclined-$email"

    private object Keys {
        val APPEARANCE = stringPreferencesKey("appAppearance")
        val TEXT_SIZE = stringPreferencesKey("appTextSize")
        val AI_RESPONSE_STYLE = stringPreferencesKey("aiResponseStyle")
    }
}
