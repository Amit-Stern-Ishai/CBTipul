package com.cbtipul.app.telemetry

object PostHogTelemetryConfiguration {
    const val PROJECT_TOKEN = "phc_zizZLMjDQtJRcuLR6TQPdohGFhDFQXGvmLBqPeYY3KiE"
    const val HOST = "https://eu.i.posthog.com"
    // Collection enabled. Local build checks must not launch the app.
    const val ENABLED = true
    fun valid(token: String = PROJECT_TOKEN, host: String = HOST) =
        host == "https://eu.i.posthog.com" && token.matches(Regex("phc_[A-Za-z0-9_]{5,195}"))
}
