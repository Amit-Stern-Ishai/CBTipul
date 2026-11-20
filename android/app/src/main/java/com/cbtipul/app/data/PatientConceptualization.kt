package com.cbtipul.app.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import kotlinx.coroutines.CancellationException
import kotlinx.serialization.json.*

enum class ConceptSection(val key: String, val title: String) {
    Childhood("childhood_experiences", "חוויות ילדות"), Core("core_beliefs", "אמונת יסוד"),
    Assumptions("assumptions", "הנחות בסיס"), Rules("rules", "חוקים וכללים"), Expectations("biased_expectations", "ציפיות מוטות")
}
typealias ConceptDocument = Map<ConceptSection, List<String>>
fun emptyConcept(): ConceptDocument = ConceptSection.entries.associateWith { emptyList() }
fun validConcept(value: ConceptDocument): Boolean = ConceptSection.entries.all { section ->
    val rows = value[section] ?: return@all false
    rows.size <= 30 && rows.all { it.isNotBlank() && it.codePointCount(0, it.length) <= 1500 }
}
data class ConceptRecord(val patientId: String, val document: ConceptDocument?, val revision: String?, val publishedAt: String?, val publishedRevision: String?)
class ConceptFailure(val kind: Kind): Exception() { enum class Kind { Conflict, Access, Invalid, Failed } }
object ConceptContract {
    fun body(action: String, patientId: String?, revision: String?, document: ConceptDocument): JsonObject = buildJsonObject {
        require(action in setOf("load_published", "load_draft", "save", "publish"))
        put("action", action)
        if (action == "load_published") return@buildJsonObject
        require(!patientId.isNullOrEmpty()); put("patient_id", patientId)
        if (action != "load_draft") put("expected_revision", revision?.let(::JsonPrimitive) ?: JsonNull)
        if (action == "publish") require(!revision.isNullOrEmpty())
        if (action == "save") {
            require(validConcept(document))
            put("document", buildJsonObject { ConceptSection.entries.forEach { put(it.key, JsonArray(document.getValue(it).map(::JsonPrimitive))) } })
        }
    }
    fun decode(root: JsonObject, patientId: String?): ConceptRecord {
        fun text(key: String): String? = (root[key] as? JsonPrimitive)?.takeIf { it.isString }?.content
        val id = text("patient_id") ?: throw ConceptFailure(ConceptFailure.Kind.Failed)
        require(patientId == null || id.equals(patientId, true))
        val document = when (val value = root["document"]) {
            JsonNull -> null
            is JsonObject -> ConceptSection.entries.associateWith { section ->
                (value[section.key] as? JsonArray)?.map { (it as? JsonPrimitive)?.takeIf { it.isString }?.content ?: throw ConceptFailure(ConceptFailure.Kind.Failed) } ?: throw ConceptFailure(ConceptFailure.Kind.Failed)
            }
            else -> throw ConceptFailure(ConceptFailure.Kind.Failed)
        }
        val revision = text("revision")
        require(document == null || validConcept(document) && !revision.isNullOrEmpty())
        return ConceptRecord(id, document, revision, text("published_at"), text("published_revision"))
    }
}
class PatientConceptualization(private val client: SupabaseClient) {
    suspend fun request(action: String, patientId: String?, revision: String?, document: ConceptDocument): ConceptRecord {
        val owner = client.auth.currentUserOrNull()?.id ?: throw ConceptFailure(ConceptFailure.Kind.Access)
        if (action == "save" || action == "publish") Entitlements.requireWrite()
        val body = ConceptContract.body(action, patientId, revision, document)
        try {
            val response = client.functions.invoke("patient-conceptualization", body = body, headers = PatientNameSync.jsonHeaders())
            if (client.auth.currentUserOrNull()?.id != owner) throw CancellationException()
            return ConceptContract.decode(EdgePayload.json.parseToJsonElement(response.bodyAsText()).jsonObject, patientId)
        } catch (e: CancellationException) { throw e }
        catch (e: Exception) {
            val status = EdgePayload.httpStatus(e)
            val code = EdgePayload.codeAndMessage(EdgePayload.responseBody(e)).first
            throw ConceptFailure(when { status == 409 && code == "revision_conflict" -> ConceptFailure.Kind.Conflict; status == 401 || status == 403 -> ConceptFailure.Kind.Access; else -> ConceptFailure.Kind.Failed })
        }
    }
}
