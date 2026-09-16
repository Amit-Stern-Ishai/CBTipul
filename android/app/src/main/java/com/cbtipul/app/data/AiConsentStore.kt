package com.cbtipul.app.data

import com.cbtipul.app.model.ConsentDeclinedException
import com.cbtipul.app.settings.AppPreferences
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class AiConsentStore(private val preferences: AppPreferences) {
    private val mutex = Mutex()
    private var activeEmail: String? = null
    private var waiter: CompletableDeferred<Boolean>? = null
    @Volatile
    private var bypassForDemo: Boolean = false

    private val _promptVisible = MutableStateFlow(false)
    val promptVisible: StateFlow<Boolean> = _promptVisible.asStateFlow()

    fun setActiveUser(email: String?) {
        activeEmail = email
        if (email == null) {
            waiter?.complete(false)
            waiter = null
            _promptVisible.value = false
        }
    }

    suspend fun ensureGranted() {
        if (bypassForDemo) return
        val email = activeEmail ?: throw ConsentDeclinedException()
        if (preferences.isAiConsentAccepted(email)) return
        val deferred = mutex.withLock {
            if (preferences.isAiConsentAccepted(email)) return@withLock null
            waiter ?: CompletableDeferred<Boolean>().also {
                waiter = it
                _promptVisible.value = true
            }
        } ?: return
        val granted = deferred.await()
        if (!granted) throw ConsentDeclinedException()
    }

    /** Local demo clinic never prompts for AI data-sharing consent. */
    fun setDemoBypass(enabled: Boolean) {
        bypassForDemo = enabled
        if (enabled) {
            waiter?.complete(true)
            waiter = null
            _promptVisible.value = false
        }
    }

    suspend fun accept() {
        val email = activeEmail ?: return
        preferences.setAiConsentAccepted(email)
        finish(true)
    }

    suspend fun decline() {
        val email = activeEmail
        if (email != null) preferences.setAiConsentDeclined(email)
        finish(false)
    }

    private fun finish(granted: Boolean) {
        val current = waiter
        waiter = null
        _promptVisible.value = false
        current?.complete(granted)
    }
}
