package com.cbtipul.app.data

import com.cbtipul.app.model.ConsentDeclinedException
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.ktor.client.request.header
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.contentType
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File

class WhisperException(val detail: String, val readFailed: Boolean = false) : Exception(detail)

class WhisperService(
    private val client: SupabaseClient,
    private val consent: AiConsentStore,
) {
    suspend fun transcribe(file: File, language: String = "he"): String {
        consent.ensureGranted()
        val audioData = try {
            file.readBytes()
        } catch (error: Exception) {
            throw WhisperException(error.message ?: error.toString(), readFailed = true)
        }
        return try {
            val http = client.functions.invoke("whisper-transcribe") {
                contentType(ContentType.parse("audio/m4a"))
                header("x-language", language)
                setBody(audioData)
            }
            json.decodeFromString<TranscriptionResponse>(http.bodyAsText()).text
        } catch (error: ConsentDeclinedException) {
            throw error
        } catch (error: WhisperException) {
            throw error
        } catch (error: Exception) {
            throw WhisperException(error.message ?: error.toString())
        }
    }

    @Serializable
    private data class TranscriptionResponse(val text: String)

    companion object {
        private val json = Json { ignoreUnknownKeys = true }
    }
}
