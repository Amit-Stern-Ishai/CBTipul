package com.cbtipul.app.data

import kotlinx.serialization.json.*

/** Fixed read-only pagination for the three clinical record endpoints. */
internal object ClinicalRecordLoad {
    suspend fun pages(endpoint: String, parameters: JsonObject = buildJsonObject {},
        checkpoint: () -> Unit, invoke: suspend (String, JsonObject) -> JsonObject): List<JsonObject> {
        require(endpoint in setOf("load-patients", "load-sessions", "load-questionnaires"))
        val records = mutableListOf<JsonObject>()
        val seen = mutableSetOf<String>()
        val ids = mutableSetOf<String>()
        var cursor: String? = null
        do {
            checkpoint()
            val body = buildJsonObject { parameters.forEach { (k,v) -> put(k,v) }; put("limit",100); cursor?.let { put("cursor",it) } }
            val page = invoke(endpoint, body)
            checkpoint()
            val rows = page["records"] as? JsonArray ?: error("invalid_clinical_response")
            rows.forEach { value ->
                val row = value as? JsonObject ?: error("invalid_clinical_record")
                fun string(key: String) = (row[key] as? JsonPrimitive)?.takeIf { it.isString }?.content
                val id = string("id") ?: error("invalid_clinical_record")
                require(ids.add(id) && !string("_version").isNullOrEmpty()) { "invalid_clinical_record" }
                for (key in listOf("patient_id","session_id","therapist_id","assignment_id")) {
                    if (row[key] != null && row[key] != JsonNull) require(string(key) != null) { "invalid_clinical_record" }
                }
                for (key in listOf("id","patient_id")) if (parameters[key] != null) require(parameters[key] == row[key]) { "invalid_clinical_record" }
                records += row
            }
            val next = page["next_cursor"] ?: error("invalid_clinical_cursor")
            cursor = if(next == JsonNull) null else (next as? JsonPrimitive)?.takeIf { it.isString && it.content.isNotEmpty() }?.content ?: error("invalid_clinical_cursor")
            if(cursor != null) require(parameters["id"] == null && seen.add(cursor!!)) { "invalid_clinical_cursor" }
        } while(cursor != null)
        return records
    }
}

internal object ClinicalStringId : kotlinx.serialization.KSerializer<com.cbtipul.app.model.DatabaseId> {
    override val descriptor = kotlinx.serialization.descriptors.PrimitiveSerialDescriptor("ClinicalStringId", kotlinx.serialization.descriptors.PrimitiveKind.STRING)
    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder) = com.cbtipul.app.model.DatabaseId.Text(decoder.decodeString())
    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: com.cbtipul.app.model.DatabaseId) = encoder.encodeString(value.queryValue)
}
