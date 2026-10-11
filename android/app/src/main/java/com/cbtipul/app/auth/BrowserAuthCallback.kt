package com.cbtipul.app.auth

import java.net.URI
import java.net.URLDecoder
import java.security.MessageDigest
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive

/** Contains credentials: deliberately not a data class and never logged. */
internal class BrowserAuthCallback private constructor(
    val code: String?,
    val legacyFragment: String?,
    val recovery: Boolean,
    val error: Boolean,
    val cancelled: Boolean,
    val fingerprint: String,
) {
    companion object {
        fun parse(raw: String): BrowserAuthCallback? {
            val uri = runCatching { URI(raw) }.getOrNull() ?: return null
            if (uri.scheme != "cbtipul" || uri.host !in setOf("auth-callback", "password-reset") ||
                uri.userInfo != null || uri.port != -1 || uri.path.orEmpty() !in setOf("", "/")) return null
            fun parameters(raw: String?) = raw.orEmpty().split("&").filter { it.isNotEmpty() }.associate {
                val pair = it.split("=", limit = 2)
                URLDecoder.decode(pair[0], "UTF-8") to URLDecoder.decode(pair.getOrElse(1) { "" }, "UTF-8")
            }
            val query = parameters(uri.rawQuery)
            val fragment = parameters(uri.rawFragment)
            val values = query + fragment
            val code = query["code"]?.takeIf { it.isNotBlank() }
            val legacy = when {
                fragment.containsKey("access_token") -> uri.rawFragment
                query.containsKey("access_token") -> uri.rawQuery
                else -> null
            }
            val error = values.containsKey("error") || values.containsKey("error_code")
            return BrowserAuthCallback(
                code, legacy, uri.host == "password-reset" || values["type"] == "recovery",
                error, values["error"] == "access_denied",
                MessageDigest.getInstance("SHA-256").digest(raw.toByteArray())
                    .joinToString("") { "%02x".format(it.toInt() and 255) },
            )
        }
    }
}

/** Main-thread gate; only fingerprints are persisted, never callback URLs or codes. */
internal class BrowserCallbackGate(
    private val lastConsumed: () -> String?,
    private val saveConsumed: (String) -> Unit,
) {
    private var generation = 0
    val revision get() = generation
    private var active: String? = null
    val isBusy get() = active != null
    fun invalidate() { generation++ }

    suspend fun <T> handle(
        callback: BrowserAuthCallback,
        resolve: suspend () -> T,
        commit: suspend (T) -> Unit,
    ) {
        if (active != null || lastConsumed() == callback.fingerprint) return
        val attempt = generation
        active = callback.fingerprint
        try {
            val result = resolve()
            currentCoroutineContext().ensureActive()
            if (generation != attempt) throw CancellationException()
            commit(result)
            saveConsumed(callback.fingerprint)
        } finally {
            active = null
        }
    }
}
