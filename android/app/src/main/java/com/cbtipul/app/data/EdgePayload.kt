package com.cbtipul.app.data

import io.github.jan.supabase.exceptions.RestException
import io.ktor.client.plugins.ResponseException
import io.ktor.client.statement.bodyAsText
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

object EdgePayload {
    val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        explicitNulls = true
    }

    fun codeAndMessage(body: String): Pair<String, String> {
        val root = runCatching { json.parseToJsonElement(extractJsonObject(body)).jsonObject }.getOrNull()
            ?: return "" to ""
        val code = when (val error = root["error"]) {
            is JsonPrimitive -> error.content
            is JsonObject -> error["code"]?.jsonPrimitive?.contentOrNull.orEmpty()
            else -> root["code"]?.jsonPrimitive?.contentOrNull
                ?: root["status"]?.jsonPrimitive?.contentOrNull.orEmpty()
        }
        val message = root["message"]?.jsonPrimitive?.contentOrNull
            ?: (root["error"] as? JsonObject)?.get("message")?.jsonPrimitive?.contentOrNull
            ?: ""
        return code to message.trim()
    }

    fun httpStatus(error: Throwable): Int? {
        generateSequence(error) { it.cause }.forEach { current ->
            (current as? RestException)?.statusCode?.let { return it }
            (current as? ResponseException)?.response?.status?.value?.let { return it }
        }
        return null
    }

    suspend fun responseBody(error: Throwable): String {
        generateSequence(error) { it.cause }.forEach { current ->
            if (current is RestException) {
                val fromError = current.error.trim()
                if (fromError.isNotBlank()) return fromError
                val fromDescription = current.description.orEmpty().trim()
                if (fromDescription.isNotBlank()) return fromDescription
            }
            val response = (current as? ResponseException)?.response ?: return@forEach
            val body = runCatching { response.bodyAsText() }.getOrNull().orEmpty()
            if (body.isNotBlank()) return body
        }
        return error.message.orEmpty()
    }

    /** Best-effort, non-suspending body for DEBUG logs when the coroutine already left the catch. */
    fun responseBodyBlocking(error: Throwable): String {
        generateSequence(error) { it.cause }.forEach { current ->
            if (current is RestException && current.error.isNotBlank()) return current.error
            val fromRest = current.javaClass.methods
                .firstOrNull { it.name == "getErrorDescription" && it.parameterCount == 0 }
                ?.let { runCatching { it.invoke(current) as? String }.getOrNull() }
                .orEmpty()
            if (fromRest.isNotBlank()) return fromRest
            val message = current.message.orEmpty()
            if (message.isNotBlank()) return message
        }
        return ""
    }

    internal fun extractJsonObject(raw: String): String {
        val start = raw.indexOf('{')
        val end = raw.lastIndexOf('}')
        if (start >= 0 && end > start) return raw.substring(start, end + 1)
        return raw
    }
}
