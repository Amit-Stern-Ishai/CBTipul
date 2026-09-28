package com.cbtipul.app.data

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/** Process-level one-shot destination from FCM/inbox. Consumed once. */
class PendingDestinationStore {
    private val _pending = MutableStateFlow<AppDestination?>(null)
    val pending: StateFlow<AppDestination?> = _pending.asStateFlow()

    fun offer(destination: AppDestination) {
        _pending.value = destination
    }

    fun offer(payload: NotificationPayload) {
        NotificationRouting.destination(payload)?.let(::offer)
    }

    fun consume(): AppDestination? {
        var taken: AppDestination? = null
        _pending.update { current ->
            taken = current
            null
        }
        return taken
    }
}
