package com.cbtipul.app.data

import kotlinx.serialization.json.*

/** Versioned encrypted writes; failures never select a legacy writer. */
internal class ClinicalRecordSave {
    companion object {
        suspend fun save(previous: JsonObject?, proposed: JsonObject, checkpoint: () -> Unit,
            invoke: suspend (JsonObject) -> JsonObject): JsonObject {
            val body = request(previous, proposed)
            checkpoint()
            val response = invoke(body) // Exactly one attempt. Transport errors propagate to existing recovery.
            checkpoint()
            return record(response, previous, proposed)
        }
        fun request(previous: JsonObject?, proposed: JsonObject): JsonObject {
            fun string(key: String) = (previous?.get(key) as? JsonPrimitive)?.takeIf { it.isString }?.content
            if (previous != null) require(!string("id").isNullOrEmpty() && !string("_version").isNullOrEmpty()) { "record_changed" }
            return buildJsonObject {
                put("mode", if(previous == null) "create" else "update")
                if(previous != null) { put("id", string("id")!!); put("expected_version", string("_version")!!) }
                put("changes", JsonObject(proposed.filter { (key,value) -> !(previous != null && key == "patient_id") && previous?.get(key) != value }))
            }
        }
        fun record(response: JsonObject, previous: JsonObject?, proposed: JsonObject): JsonObject {
            val row = response["record"] as? JsonObject ?: error("save_not_confirmed")
            fun string(key: String) = (row[key] as? JsonPrimitive)?.takeIf { it.isString }?.content
            require(!string("id").isNullOrEmpty() && !string("_version").isNullOrEmpty() && (previous == null || row["id"] == previous["id"]) && (proposed["patient_id"] == null || row["patient_id"] == proposed["patient_id"])) { "save_not_confirmed" }
            return row
        }
    }
}
