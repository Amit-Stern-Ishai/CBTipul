package com.cbtipul.app.data

import kotlinx.serialization.Serializable
import kotlinx.serialization.SerialName
import kotlinx.serialization.json.*

/** Safe UI messages: never expose response bodies or clinical values. */
class SummaryFailure(val kind: Kind) : Exception(kind.message) {
    enum class Kind(val message: String) {
        Tokens("מכסת ה־AI לחודש זה נוצלה\nסיכום חדש והקלטה יהיו זמינים לאחר חידוש המכסה. אפשר להמשיך לערוך טיוטה קיימת."),
        Transcription("מכסת התמלול לחודש זה נוצלה\nאפשר לנסות לתמלל שוב לאחר חידוש המכסה."),
        Duration("אין מספיק זמן תמלול להקלטה הזו\nמשך ההקלטה גדול מהיתרה החודשית. אפשר לנסות לאחר חידוש המכסה."),
        Lookup("לא הצלחנו לבדוק את המכסה\nאין כרגע מידע על היתרה. בדקו שוב לפני העיבוד."),
        Local("לא ניתן לשמור את הטיוטה במכשיר. אין לצאת לפני ניסיון שמירה נוסף."),
        Connection("לא ניתן להתחבר כרגע. בדקו את החיבור ונסו שוב."),
        Login("הכניסה לחשבון פגה. יש להתחבר מחדש ולנסות שוב."),
        Restricted("אין הרשאה לבצע פעולה זו בחשבון הנוכחי."),
        Rate("נדרשת הפסקה קצרה\nהמתינו מעט ונסו שוב. זו מגבלה זמנית, ולא הודעה על סיום המכסה החודשית."),
        Validation("לא ניתן לשמור את הנתונים. בדקו את הפרטים ונסו שוב."),
        Conflict("הנתונים השתנו. יש לבדוק את המידע המעודכן לפני ניסיון נוסף."),
        Service("השירות אינו זמין כרגע. נסו שוב מאוחר יותר."),
        Unknown("הפעולה לא הושלמה. התוכן נשאר במסך; אפשר לנסות שוב.")
    }
    companion object {
        fun classify(status: Int?, body: String = ""): Kind {
            if (status == 401) return Kind.Login
            val obj = runCatching { Json.parseToJsonElement(body).jsonObject }.getOrNull()
            val code = obj?.get("code")?.jsonPrimitive?.contentOrNull
                ?: (obj?.get("error") as? JsonObject)?.get("code")?.jsonPrimitive?.contentOrNull
            if (code in setOf("monthly_ai_limit_exceeded", "monthly_quota_exceeded", "monthly_allowance_exhausted")) return Kind.Tokens
            val values = listOf("monthlyLimit", "usedTokens", "remainingTokens").map { key ->
                (obj?.get(key) as? JsonPrimitive)?.takeUnless { it.isString }?.longOrNull
            }
            if (values.all { it != null && it in 0..9_007_199_254_740_991L } && values[2] == 0L && values[1]!! >= values[0]!!) return Kind.Tokens
            return when (status) {
                403 -> Kind.Restricted; 408 -> Kind.Connection; 409 -> Kind.Conflict
                400, 422 -> Kind.Validation; 429 -> Kind.Rate
                in 500..599 -> Kind.Service; else -> Kind.Unknown
            }
        }
        suspend fun from(error: Throwable): SummaryFailure {
            if (error is kotlinx.coroutines.CancellationException) throw error
            if (error is SummaryFailure) return error
            val status = EdgePayload.httpStatus(error)
            return SummaryFailure(if (status == null && error is java.io.IOException) Kind.Connection
                else classify(status, EdgePayload.responseBody(error)))
        }
    }
}

@Serializable
data class SummaryAllowance(
    @SerialName("checked_at") val checkedAt: String,
    @SerialName("usage_month") val usageMonth: String,
    @SerialName("resets_at") val resetsAt: String,
    @SerialName("chat_tokens") val tokens: Balance,
    @SerialName("transcription_seconds") val transcription: Balance,
) {
    @Serializable data class Balance(val limit: Double, val used: Double, val remaining: Double, val exhausted: Boolean, val code: String? = null) {
        fun valid() = listOf(limit, used, remaining).all { it.isFinite() && it >= 0 && it <= 9_007_199_254_740_991.0 } &&
            remaining == maxOf(0.0, limit - used) && exhausted == (remaining == 0.0) && (exhausted || code == null)
    }
    fun validate() {
        if (!tokens.valid() || !transcription.valid() || !Regex("\\d{4}-(0[1-9]|1[0-2])(-01)?").matches(usageMonth) ||
            runCatching { java.time.Instant.parse(checkedAt); java.time.Instant.parse(resetsAt) }.isFailure) throw SummaryFailure(SummaryFailure.Kind.Lookup)
    }
    fun assess(needsTokens: Boolean = true, seconds: Double? = null): Boolean {
        validate()
        if (needsTokens && tokens.exhausted) throw SummaryFailure(SummaryFailure.Kind.Tokens)
        if (seconds != null) {
            if (!seconds.isFinite() || seconds < 0) throw SummaryFailure(SummaryFailure.Kind.Lookup)
            if (transcription.exhausted) throw SummaryFailure(SummaryFailure.Kind.Transcription)
            if (seconds > transcription.remaining) throw SummaryFailure(SummaryFailure.Kind.Duration)
        }
        return (needsTokens && tokens.remaining <= tokens.limit * 0.10) || (seconds != null && transcription.remaining <= transcription.limit * 0.10)
    }
}
