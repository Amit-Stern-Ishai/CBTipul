package com.cbtipul.app.data

import com.cbtipul.app.model.ConsentDeclinedException
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

class ClinicalTextAnonymizer(
    private val client: SupabaseClient,
    private val consent: AiConsentStore,
) {
    suspend fun anonymize(text: String): String {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return ""
        consent.ensureGranted()
        val response = try {
            val http = client.functions.invoke(
                function = "anonymize-clinical-text",
                body = Request(text = trimmed, therapistIdentifiers = emptyList()),
                headers = Headers.build {
                    append(HttpHeaders.ContentType, ContentType.Application.Json.toString())
                },
            )
            json.decodeFromString<Response>(http.bodyAsText())
        } catch (error: ConsentDeclinedException) {
            throw error
        } catch (_: Exception) {
            throw ClinicalTextAnonymizerError()
        }
        val anonymized = response.anonymizedText.trim()
        if (anonymized.isEmpty()) throw ClinicalTextAnonymizerError()
        return anonymized
    }

    @Serializable
    private data class Request(val text: String, val therapistIdentifiers: List<String>)

    @Serializable
    private data class Response(val anonymizedText: String)

    companion object {
        private val json = Json { ignoreUnknownKeys = true }
    }
}

