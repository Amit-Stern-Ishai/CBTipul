package com.cbtipul.app.data

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first

private val Context.onboardingDataStore by preferencesDataStore(name = "cbtipul_onboarding")

/**
 * Device-local first-run / Getting Started flags, namespaced by account email.
 */
class OnboardingStore(context: Context) {
    private val appContext = context.applicationContext
    private var activeEmail: String? = null

    private val _welcomeDismissed = MutableStateFlow(false)
    val welcomeDismissed: StateFlow<Boolean> = _welcomeDismissed.asStateFlow()

    private val _checklistDismissed = MutableStateFlow(false)
    val checklistDismissed: StateFlow<Boolean> = _checklistDismissed.asStateFlow()

    private val _hasSeenFirstPreparationTip = MutableStateFlow(false)
    val hasSeenFirstPreparationTip: StateFlow<Boolean> = _hasSeenFirstPreparationTip.asStateFlow()

    private val _hasSeenFirstQuestionnaireTip = MutableStateFlow(false)
    val hasSeenFirstQuestionnaireTip: StateFlow<Boolean> = _hasSeenFirstQuestionnaireTip.asStateFlow()

    private val _hasCompletedDemoTour = MutableStateFlow(false)
    val hasCompletedDemoTour: StateFlow<Boolean> = _hasCompletedDemoTour.asStateFlow()

    private val _wantsDemoConsent = MutableStateFlow(false)
    val wantsDemoConsent: StateFlow<Boolean> = _wantsDemoConsent.asStateFlow()

    /** True after flags for the active email have been loaded from DataStore. */
    private val _isHydrated = MutableStateFlow(false)
    val isHydrated: StateFlow<Boolean> = _isHydrated.asStateFlow()

    suspend fun setActiveUser(email: String?) {
        _isHydrated.value = false
        activeEmail = email
        reloadFromStore()
        _isHydrated.value = email != null
    }

    suspend fun dismissWelcome() {
        _welcomeDismissed.value = true
        persist()
    }

    suspend fun dismissChecklist() {
        _checklistDismissed.value = true
        persist()
    }

    suspend fun showChecklistAgain() {
        _checklistDismissed.value = false
        persist()
    }

    fun requestDemoConsent() {
        _wantsDemoConsent.value = true
    }

    fun clearDemoConsentRequest() {
        _wantsDemoConsent.value = false
    }

    suspend fun markFirstPreparationTipSeen() {
        _hasSeenFirstPreparationTip.value = true
        persist()
    }

    suspend fun markFirstQuestionnaireTipSeen() {
        _hasSeenFirstQuestionnaireTip.value = true
        persist()
    }

    suspend fun markDemoTourCompleted() {
        _hasCompletedDemoTour.value = true
        persist()
    }

    suspend fun clearPersistedState(forEmail: String) {
        appContext.onboardingDataStore.edit { prefs ->
            prefs.remove(booleanPreferencesKey(welcomeKey(forEmail)))
            prefs.remove(booleanPreferencesKey(checklistKey(forEmail)))
            prefs.remove(booleanPreferencesKey(firstPrepTipKey(forEmail)))
            prefs.remove(booleanPreferencesKey(firstQuestionnaireTipKey(forEmail)))
            prefs.remove(booleanPreferencesKey(demoTourKey(forEmail)))
        }
        if (activeEmail == forEmail) {
            _welcomeDismissed.value = false
            _checklistDismissed.value = false
            _hasSeenFirstPreparationTip.value = false
            _hasSeenFirstQuestionnaireTip.value = false
            _hasCompletedDemoTour.value = false
        }
    }

    suspend fun clearPersistedStateForActiveUser() {
        val email = activeEmail ?: return
        clearPersistedState(email)
    }

    private suspend fun reloadFromStore() {
        val email = activeEmail
        if (email == null) {
            _welcomeDismissed.value = false
            _checklistDismissed.value = false
            _hasSeenFirstPreparationTip.value = false
            _hasSeenFirstQuestionnaireTip.value = false
            _hasCompletedDemoTour.value = false
            return
        }
        val prefs = appContext.onboardingDataStore.data.first()
        _welcomeDismissed.value = prefs[booleanPreferencesKey(welcomeKey(email))] == true
        _checklistDismissed.value = prefs[booleanPreferencesKey(checklistKey(email))] == true
        _hasSeenFirstPreparationTip.value = prefs[booleanPreferencesKey(firstPrepTipKey(email))] == true
        _hasSeenFirstQuestionnaireTip.value =
            prefs[booleanPreferencesKey(firstQuestionnaireTipKey(email))] == true
        _hasCompletedDemoTour.value = prefs[booleanPreferencesKey(demoTourKey(email))] == true
    }

    private suspend fun persist() {
        val email = activeEmail ?: return
        appContext.onboardingDataStore.edit { prefs ->
            prefs[booleanPreferencesKey(welcomeKey(email))] = _welcomeDismissed.value
            prefs[booleanPreferencesKey(checklistKey(email))] = _checklistDismissed.value
            prefs[booleanPreferencesKey(firstPrepTipKey(email))] = _hasSeenFirstPreparationTip.value
            prefs[booleanPreferencesKey(firstQuestionnaireTipKey(email))] =
                _hasSeenFirstQuestionnaireTip.value
            prefs[booleanPreferencesKey(demoTourKey(email))] = _hasCompletedDemoTour.value
        }
    }

    companion object {
        fun welcomeKey(email: String) = "onboarding.welcomeDismissed-$email"
        fun checklistKey(email: String) = "onboarding.checklistDismissed-$email"
        fun firstPrepTipKey(email: String) = "onboarding.firstPreparationTipSeen-$email"
        fun firstQuestionnaireTipKey(email: String) = "onboarding.firstQuestionnaireTipSeen-$email"
        fun demoTourKey(email: String) = "onboarding.demoTourCompleted-$email"
    }
}
