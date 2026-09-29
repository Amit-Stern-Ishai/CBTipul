package com.cbtipul.app.data

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/** Process-level one-shot destination from FCM/inbox. Consumed once. */
class PendingDestinationStore {
    private val recentDiaryThreeTaps = LinkedHashSet<NotificationPayload>()
    private val _pending = MutableStateFlow<AppDestination?>(null)
    val pending: StateFlow<AppDestination?> = _pending.asStateFlow()

    fun offer(destination: AppDestination) {
        _pending.value = destination
    }

    fun offer(payload: NotificationPayload) {
        if (payload.type == AppNotificationTypes.DIARY_THREE_ASSIGNED || payload.type == AppNotificationTypes.DIARY_THREE_ENTRY_ADDED) {
            // Activity recreation/re-delivery must not reopen a consumed notification.
            if (!recentDiaryThreeTaps.add(payload)) return
            if (recentDiaryThreeTaps.size > 64) recentDiaryThreeTaps.remove(recentDiaryThreeTaps.first())
        }
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
