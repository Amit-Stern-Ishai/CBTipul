package com.cbtipul.app.data

class ClinicalTextAnonymizerError : Exception()

class ClinicalTextGate(
    private val anonymize: suspend (String) -> String,
) {
    private val safeTexts = mutableSetOf<String>()

    fun markSafe(text: String?) {
        val trimmed = text?.trim().orEmpty()
        if (trimmed.isNotEmpty()) safeTexts.add(trimmed)
    }

    suspend fun prepare(text: String): String? {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return null
        if (safeTexts.contains(trimmed)) return trimmed
        val anonymized = anonymize(trimmed).trim()
        if (anonymized.isEmpty()) throw ClinicalTextAnonymizerError()
        safeTexts.add(anonymized)
        return anonymized
    }

    suspend fun prepare(notes: List<String>): List<String> =
        notes.map { prepare(it) ?: "" }
}
