package com.cbtipul.app.data

import com.cbtipul.app.model.AiException
import com.cbtipul.app.model.CBTSessionAnalysis
import com.cbtipul.app.model.ChatTurn
import com.cbtipul.app.model.ConsentDeclinedException
import com.cbtipul.app.model.FormulationSupervision
import com.cbtipul.app.model.LongitudinalCaseReviewResponse
import com.cbtipul.app.model.NextSessionPreparation
import com.cbtipul.app.model.PatientFormulation
import com.cbtipul.app.model.PrepareSessionResponse
import com.cbtipul.app.model.SessionReviewResponse
import com.cbtipul.app.model.WhatAmIMissingResponse
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.net.HttpURLConnection
import java.net.URL

class AiService(
    private val client: SupabaseClient,
    private val consent: AiConsentStore,
) {
    suspend fun analyzeSession(notes: String): CBTSessionAnalysis {
        val trimmed = notes.trim()
        if (trimmed.isEmpty()) throw AiException("invalid_input")
        consent.ensureGranted()
        val token = client.auth.currentSessionOrNull()?.accessToken
            ?: throw AiException("invalid_response")
        val payload = json.encodeToString(AnalyzeRequest.serializer(), AnalyzeRequest(sessionNotes = trimmed))
        return withContext(Dispatchers.IO) {
            try {
                val url = URL("${SupabaseConfig.URL}/functions/v1/analyze-session")
                val connection = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    setRequestProperty("Content-Type", "application/json")
                    setRequestProperty("Authorization", "Bearer $token")
                    doOutput = true
                    connectTimeout = 60_000
                    readTimeout = 120_000
                }
                connection.outputStream.use { it.write(payload.toByteArray(Charsets.UTF_8)) }
                val code = connection.responseCode
                val stream = if (code in 200..299) connection.inputStream else connection.errorStream
                val body = stream?.use { it.readBytes().decodeToString() }.orEmpty()
                connection.disconnect()
                if (code !in 200..299) {
                    val error = runCatching { json.decodeFromString<ApiErrorResponse>(body).error }.getOrNull()
                    throw AiException(error ?: "session_analysis_failed")
                }
                json.decodeFromString<SessionReviewResponse>(body).analysis
            } catch (error: ConsentDeclinedException) {
                throw error
            } catch (error: AiException) {
                throw error
            } catch (error: Exception) {
                throw AiException(error.message ?: "session_analysis_failed")
            }
        }
    }

    suspend fun prepareNextSession(
        context: PatientContext,
        lastSessionAssignments: List<com.cbtipul.app.model.AssignmentForNextWeek>?,
    ): NextSessionPreparation {
        consent.ensureGranted()
        return try {
            val http = client.functions.invoke(
                function = "prepare-session",
                body = PrepareSessionRequest(context, lastSessionAssignments),
                headers = Headers.build {
                    append(HttpHeaders.ContentType, ContentType.Application.Json.toString())
                },
            )
            json.decodeFromString<PrepareSessionResponse>(http.bodyAsText()).preparation
        } catch (error: ConsentDeclinedException) {
            throw error
        } catch (error: Exception) {
            throw AiException(error.message ?: error.toString())
        }
    }

    suspend fun chat(systemPrompt: String, turns: List<ChatTurn>): String {
        consent.ensureGranted()
        return try {
            val http = client.functions.invoke(
                function = "openai-gateway",
                body = GatewayRequest(
                    model = "gpt-4o-mini",
                    messages = listOf(GatewayRequest.Message("system", systemPrompt)) +
                        turns.map { GatewayRequest.Message(it.role, it.content) },
                    temperature = 0.4,
                ),
                headers = Headers.build {
                    append(HttpHeaders.ContentType, ContentType.Application.Json.toString())
                },
            )
            val content = json.decodeFromString<OpenAIResponse>(http.bodyAsText())
                .choices.firstOrNull()?.message?.content.orEmpty()
            if (content.isBlank()) throw AiException("empty_ai_response")
            content
        } catch (error: ConsentDeclinedException) {
            throw error
        } catch (error: AiException) {
            throw error
        } catch (error: Exception) {
            throw AiException(error.message ?: error.toString())
        }
    }

    suspend fun challengeFormulation(
        context: PatientContext,
        formulation: PatientFormulation,
    ): FormulationSupervision {
        consent.ensureGranted()
        return try {
            val http = client.functions.invoke(
                function = "challenge-formulation",
                body = ChallengeFormulationRequest(context, formulation),
                headers = Headers.build {
                    append(HttpHeaders.ContentType, ContentType.Application.Json.toString())
                },
            )
            json.decodeFromString<FormulationSupervision>(http.bodyAsText())
        } catch (error: ConsentDeclinedException) {
            throw error
        } catch (error: Exception) {
            throw AiException(error.message ?: error.toString())
        }
    }

    suspend fun whatAmIMissing(context: PatientContext): WhatAmIMissingResponse {
        consent.ensureGranted()
        return try {
            val http = client.functions.invoke(
                function = "what-am-i-missing",
                body = WhatAmIMissingRequest(context),
                headers = Headers.build {
                    append(HttpHeaders.ContentType, ContentType.Application.Json.toString())
                },
            )
            json.decodeFromString<WhatAmIMissingResponse>(http.bodyAsText())
        } catch (error: ConsentDeclinedException) {
            throw error
        } catch (error: Exception) {
            throw AiException(error.message ?: error.toString())
        }
    }

    suspend fun longitudinalCaseReview(context: PatientContext): LongitudinalCaseReviewResponse {
        consent.ensureGranted()
        return try {
            val http = client.functions.invoke(
                function = "longitudinal-case-review",
                body = LongitudinalRequest(context),
                headers = Headers.build {
                    append(HttpHeaders.ContentType, ContentType.Application.Json.toString())
                },
            )
            json.decodeFromString<LongitudinalCaseReviewResponse>(http.bodyAsText())
        } catch (error: ConsentDeclinedException) {
            throw error
        } catch (error: Exception) {
            throw AiException(error.message ?: error.toString())
        }
    }

    @Serializable
    private data class AnalyzeRequest(val sessionNotes: String)

    @Serializable
    private data class ChallengeFormulationRequest(
        val patientContext: PatientContext,
        val formulation: PatientFormulation,
    )

    @Serializable
    private data class WhatAmIMissingRequest(val patientContext: PatientContext)

    @Serializable
    private data class LongitudinalRequest(val patientContext: PatientContext)

    @Serializable
    private data class PrepareSessionRequest(
        val patientContext: PatientContext,
        val lastSessionAssignments: List<com.cbtipul.app.model.AssignmentForNextWeek>? = null,
    )

    @Serializable
    private data class GatewayRequest(
        val model: String,
        val messages: List<Message>,
        val temperature: Double,
    ) {
        @Serializable
        data class Message(val role: String, val content: String)
    }

    @Serializable
    private data class OpenAIResponse(val choices: List<Choice> = emptyList()) {
        @Serializable
        data class Choice(val message: Message = Message())
        @Serializable
        data class Message(val content: String = "")
    }

    @Serializable
    private data class ApiErrorResponse(val error: String)

    companion object {
        private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    }
}
