package com.cbtipul.app.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import kotlinx.coroutines.CancellationException
import kotlinx.serialization.json.*

class CoreBeliefFailure(val kind: Kind): Exception() { enum class Kind { Conflict, Access, Invalid, Failed } }
object CoreBeliefContract {
    fun body(action: String, patientId: String?, revision: String?, document: CoreBeliefWorksheet): JsonObject = buildJsonObject {
        require(action in setOf("load_published", "load_draft", "save", "publish"))
        put("action", action)
        if (action == "load_published") return@buildJsonObject
        require(!patientId.isNullOrEmpty()); put("patient_id", patientId)
        if (action != "load_draft") put("expected_revision", revision?.let(::JsonPrimitive) ?: JsonNull)
        if (action == "publish") require(!revision.isNullOrEmpty())
        if (action == "save") {
            put("document", Json.parseToJsonElement(CoreBeliefWorksheetCodec.encodeDocument(document)))
        }
    }
    fun decode(value: String, patientId: String?): CoreBeliefWorksheetRecord {
        val record = CoreBeliefWorksheetCodec.decodeRecord(value)
        require(patientId == null || record.patientId.equals(patientId, true))
        require(record.document == null || !record.revision.isNullOrEmpty())
        return record
    }
}

class CoreBeliefService(private val client: SupabaseClient) {
    suspend fun request(action: String, patientId: String?, revision: String?, document: CoreBeliefWorksheet): CoreBeliefWorksheetRecord {
        val owner = client.auth.currentUserOrNull()?.id ?: throw CoreBeliefFailure(CoreBeliefFailure.Kind.Access)
        if (action == "save" || action == "publish") Entitlements.requireWrite()
        val body = CoreBeliefContract.body(action, patientId, revision, document)
        try {
            val response = client.functions.invoke("core-belief-restructuring", body = body, headers = PatientNameSync.jsonHeaders())
            if (client.auth.currentUserOrNull()?.id != owner) throw CancellationException()
            return CoreBeliefContract.decode(response.bodyAsText(), patientId)
        } catch (e: CancellationException) { throw e }
        catch (e: Exception) {
            val status = EdgePayload.httpStatus(e)
            val code = EdgePayload.codeAndMessage(EdgePayload.responseBody(e)).first
            throw CoreBeliefFailure(when { status == 409 && code == "revision_conflict" -> CoreBeliefFailure.Kind.Conflict; status == 401 || status == 403 -> CoreBeliefFailure.Kind.Access; else -> CoreBeliefFailure.Kind.Failed })
        }
    }
}
