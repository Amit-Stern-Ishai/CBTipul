package com.cbtipul.app.push

import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

object PushDeviceRpc {
    fun register(token: String, platform: String, environment: String): JsonObject = buildJsonObject {
        put("p_platform", platform)
        put("p_push_token", token)
        put("p_environment", environment)
    }

    fun disable(token: String): JsonObject = buildJsonObject {
        put("p_push_token", token)
    }

    fun unregister(token: String): JsonObject = buildJsonObject {
        put("p_push_token", token)
    }
}
