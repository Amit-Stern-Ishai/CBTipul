package com.cbtipul.app.data

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.util.Locale

/** Only submission IDs are persisted; never clinical text or notification receipts. */
class RecentActivityDismissals(
    private val read: (String) -> Set<String>,
    private val write: (String, Set<String>) -> Unit,
) {
    private val changes = MutableStateFlow(0)
    val revision = changes.asStateFlow()
    private fun scope(owner: String?, patient: String): String? = owner?.takeIf { it.isNotBlank() }?.let {
        Json.encodeToString(listOf(it.lowercase(Locale.ROOT), patient.lowercase(Locale.ROOT)))
    }
    fun contains(id: String, owner: String?, patient: String): Boolean =
        scope(owner, patient)?.let { id.lowercase(Locale.ROOT) in read(it) } ?: false
    fun dismiss(ids: List<String>, owner: String?, patient: String) {
        val key = scope(owner, patient) ?: return
        if (ids.isEmpty()) return
        write(key, read(key) + ids.map { it.lowercase(Locale.ROOT) })
        changes.value++
    }
}
