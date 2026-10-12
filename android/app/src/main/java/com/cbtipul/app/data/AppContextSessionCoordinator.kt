package com.cbtipul.app.data

import com.cbtipul.app.auth.AuthContextSession
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.launch

/** Application-owned recovery survives screen replacement; invitation activation owns its own requests. */
fun AppContextRepository.bindAuthentication(
    scope: CoroutineScope,
    sessions: Flow<AuthContextSession?>,
    invitationActive: Flow<Boolean>,
): Job = scope.launch {
    var accepted: AuthContextSession? = null
    combine(sessions, invitationActive) { session, active -> session to active }
        .distinctUntilChanged()
        .filter { (session, invitation) ->
            // The 401 recovery below refreshes auth itself. Don't recursively cancel
            // that request and reset its bounded retry budget on its own refresh event.
            !(session?.isTokenRefresh == true && session.userId == boundIdentity && isLoading.value && !invitation)
        }
        .collectLatest { (session, invitation) ->
            // The invitation transaction validates identity and clears context
            // itself. Never invalidate its post-claim context due to a delayed
            // auth notification from its confirmed anonymous sign-in.
            if (invitation) { accepted = session; return@collectLatest }
            val changed = accepted != session || boundIdentity != session?.userId
            if (changed) { authenticationChanged(session?.userId); accepted = session }
            if (session != null && !invitation && (changed || current.value == null || loadState.value is AppContextLoadState.Failed)) {
                runCatching { getCurrentAppContext() }
            }
        }
}
