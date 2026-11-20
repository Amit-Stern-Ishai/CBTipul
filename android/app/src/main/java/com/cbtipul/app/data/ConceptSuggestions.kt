package com.cbtipul.app.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.serialization.json.*

object ConceptSuggestions {
    fun body(patient: String, section: ConceptSection, document: ConceptDocument, context: String) = buildJsonObject {
        put("patient_id", patient); put("section", section.key)
        put("document", buildJsonObject { ConceptSection.entries.forEach { put(it.key, JsonArray(document.getValue(it).map(::JsonPrimitive))) } })
        put("patient_context", context)
    }
    fun decode(root: JsonObject): List<String> {
        val rows=(root["suggestions"] as? JsonArray) ?: error("invalid_response")
        require(rows.size<=4)
        return rows.map { (it as? JsonPrimitive)?.takeIf { p->p.isString }?.content?.takeIf { t->t.isNotBlank()&&t.codePointCount(0,t.length)<=1500 } ?: error("invalid_response") }.distinct()
    }
    fun append(existing: List<String>, selected: List<String>): List<String> {
        val result=existing.toMutableList();selected.forEach { text->if(result.size<30&&result.none { it.trim()==text.trim() })result.add(text) };return result
    }
    suspend fun request(client: SupabaseClient, owner:String, patient:String, section:ConceptSection, draft:ConceptDocument, context:String):List<String> {
        currentCoroutineContext().ensureActive()
        if(client.auth.currentUserOrNull()?.id!=owner)throw CancellationException()
        Entitlements.requireWrite()
        val response=client.functions.invoke("suggest-conceptualization-section",body=body(patient,section,draft,context),headers=PatientNameSync.jsonHeaders())
        currentCoroutineContext().ensureActive()
        if(client.auth.currentUserOrNull()?.id!=owner)throw CancellationException()
        return decode(EdgePayload.json.parseToJsonElement(response.bodyAsText()).jsonObject)
    }
    suspend fun message(error:Exception):String {
        val status=EdgePayload.httpStatus(error);val body=EdgePayload.responseBody(error)
        val code=EdgePayload.codeAndMessage(body).first
        val remaining=runCatching { EdgePayload.json.parseToJsonElement(body).jsonObject["remainingTokens"]?.jsonPrimitive?.intOrNull }.getOrNull()
        return when {
            status==403||status==401 -> "אין הרשאה להצעות עבור המטופל/ת. חזרו לתיק ונסו שוב."
            status==413||code in listOf("input_too_large","context_too_large","payload_too_large") -> "המידע ארוך מדי לעיבוד. קצרו את הטיוטה ונסו שוב."
            remaining==0||code in listOf("AI_LIMIT_REACHED","ai_quota_exceeded","quota_exceeded","monthly_limit_exceeded","chat_tokens_exhausted","AI_QUOTA_EXCEEDED","THERAPIST_AI_QUOTA_EXCEEDED") -> "מכסת ה־AI נוצלה. אפשר להמשיך לערוך ידנית ולנסות לאחר חידוש המכסה."
            status==429 -> "נשלחו בקשות רבות. המתינו מעט ונסו שוב."
            else -> "לא הצלחנו לקבל הצעות. הטיוטה לא השתנתה. נסו שוב."
        }
    }
}
