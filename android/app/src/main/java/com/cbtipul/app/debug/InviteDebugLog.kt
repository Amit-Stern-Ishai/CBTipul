package com.cbtipul.app.debug

import android.util.Log
import com.cbtipul.app.BuildConfig
import com.cbtipul.app.data.EdgePayload
import io.github.jan.supabase.exceptions.RestException

/**
 * DEBUG-only invitation-activation logs. No-op in release. Never log tokens or JWTs.
 */
object InviteDebugLog {
    const val TAG = "CBTipulPatientInvite"
    private const val PREFIX = "[Invite]"

    fun d(message: String) {
        if (!BuildConfig.DEBUG) return
        Log.d(TAG, "$PREFIX $message")
    }

    suspend fun e(step: String, error: Throwable) {
        if (!BuildConfig.DEBUG) return
        val status = httpStatus(error)
        val body = EdgePayload.responseBody(error)
        val (code, serverMessage) = EdgePayload.codeAndMessage(body)
        val safeBody = sanitize(
            when {
                serverMessage.isNotBlank() -> serverMessage
                body.isNotBlank() -> body
                else -> EdgePayload.responseBodyBlocking(error)
            },
        )
        val builder = StringBuilder()
        builder.append("$PREFIX[ERROR] $step failed\n")
        builder.append("exception type/class: ${error::class.java.name}\n")
        builder.append("HTTP status: ${status ?: "unavailable"}\n")
        builder.append("Supabase/Edge Function error code: ${code.ifBlank { "unavailable" }}\n")
        builder.append("safe server error message/body: ${safeBody.ifBlank { "unavailable" }}\n")
        builder.append("exception message: ${sanitize(error.message.orEmpty()).ifBlank { "unavailable" }}\n")
        builder.append("cause: ${error.cause?.let { "${it::class.java.name}: ${sanitize(it.message.orEmpty())}" } ?: "none"}")
        Log.e(TAG, builder.toString(), error)
    }

    fun present(value: String?): Boolean = !value.isNullOrBlank()

    fun shortId(value: String?): String {
        if (value.isNullOrBlank()) return "absent"
        return value.take(8) + "…"
    }

    fun httpStatus(error: Throwable): Int? {
        generateSequence(error) { it.cause }.forEach { current ->
            EdgePayload.httpStatus(current)?.let { return it }
            if (current is RestException) return current.statusCode
        }
        return null
    }

    fun sanitize(raw: String): String {
        if (raw.isBlank()) return raw
        var text = raw
        text = JWT.replace(text, "[jwt-redacted]")
        text = BEARER.replace(text, "bearer [redacted]")
        text = SECRET_KEYS.replace(text, "$1=[redacted]")
        text = EMAIL.replace(text, "[email]")
        text = UUID.replace(text) { match -> match.value.take(8) + "…" }
        return text.take(2000)
    }

    private val JWT = Regex("eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+")
    private val BEARER = Regex("(?i)bearer\\s+\\S+")
    private val SECRET_KEYS = Regex(
        "(?i)(authorization|access[_-]?token|refresh[_-]?token|apikey|anon[_-]?key|service[_-]?role)\\s*[:=]\\s*\\S+",
    )
    private val EMAIL = Regex("[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}", RegexOption.IGNORE_CASE)
    private val UUID = Regex("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
}
