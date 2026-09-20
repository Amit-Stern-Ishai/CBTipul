package com.cbtipul.app.data

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
        val root = runCatching { json.parseToJsonElement(body).jsonObject }.getOrNull()
            ?: return "" to ""
        val code = when (val error = root["error"]) {
            is JsonPrimitive -> error.content
            is JsonObject -> error["code"]?.jsonPrimitive?.contentOrNull.orEmpty()
            else -> root["code"]?.jsonPrimitive?.contentOrNull.orEmpty()
        }
        val message = root["message"]?.jsonPrimitive?.contentOrNull
            ?: (root["error"] as? JsonObject)?.get("message")?.jsonPrimitive?.contentOrNull
            ?: ""
        return code to message.trim()
    }

    fun httpStatus(error: Throwable): Int? {
        return (error as? ResponseException)?.response?.status?.value
    }

    suspend fun responseBody(error: Throwable): String {
        val response = (error as? ResponseException)?.response ?: return error.message.orEmpty()
        return runCatching { response.bodyAsText() }.getOrNull().orEmpty()
    }
}
