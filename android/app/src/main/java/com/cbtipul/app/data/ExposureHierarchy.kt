package com.cbtipul.app.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import io.ktor.client.statement.bodyAsText
import kotlinx.coroutines.CancellationException
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.*
import java.util.UUID

@Serializable data class ExposureItem(val id: String = UUID.randomUUID().toString(), val situation: String = "", val difficulty: Int? = null)
@Serializable data class ExposureDocument(val items: List<ExposureItem> = emptyList()) {
    fun valid() = items.size <= 100 && items.map { it.id.lowercase() }.distinct().size == items.size && items.all {
        it.id.matches(Regex("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")) && it.situation.isNotBlank() && it.situation.codePointCount(0,it.situation.length)<=1000 && (it.difficulty == null || it.difficulty in 0..100)
    }
    fun move(id: String, to: Int): ExposureDocument { val from=items.indexOfFirst { it.id==id }; if(from<0 || to !in items.indices)return this; return copy(items=items.toMutableList().apply { add(to,removeAt(from)) }) }
}
@Serializable data class ExposureRecord(val patient_id:String, val document:ExposureDocument?, val revision:String?, val updated_at:String?=null)
class ExposureFailure(val kind:Kind): Exception() { enum class Kind { Conflict, Access, Failed } }
object ExposureContract {
    val json=Json { ignoreUnknownKeys=true; encodeDefaults=true; explicitNulls=true }
    fun body(action:String,patientId:String?,revision:String?,document:ExposureDocument)=buildJsonObject {
        require(action=="load"||action=="save");put("action",action);if(patientId!=null)put("patient_id",patientId)
        if(action=="save") { require(document.valid());put("expected_revision",revision?.let(::JsonPrimitive)?:JsonNull);put("document",json.encodeToJsonElement(document)) }
    }
}
class ExposureService(private val client:SupabaseClient) {
    suspend fun request(action:String,patientId:String?,revision:String?,document:ExposureDocument):ExposureRecord {
        val owner=client.auth.currentUserOrNull()?.id?:throw ExposureFailure(ExposureFailure.Kind.Access)
        if(action=="save")Entitlements.requireWrite()
        try {
            val response=client.functions.invoke("patient-exposure-hierarchy",body=ExposureContract.body(action,patientId,revision,document),headers=PatientNameSync.jsonHeaders())
            val record=ExposureContract.json.decodeFromString<ExposureRecord>(response.bodyAsText())
            if(client.auth.currentUserOrNull()?.id!=owner)throw CancellationException()
            require(patientId==null||record.patient_id.equals(patientId,true));require(record.document==null||(record.document.valid()&&!record.revision.isNullOrEmpty()))
            return record
        } catch(e:CancellationException){throw e} catch(e:Exception){
            val status=EdgePayload.httpStatus(e);val code=EdgePayload.codeAndMessage(EdgePayload.responseBody(e)).first
            throw ExposureFailure(when{status==409&&code=="revision_conflict"->ExposureFailure.Kind.Conflict;status==401||status==403->ExposureFailure.Kind.Access;else->ExposureFailure.Kind.Failed})
        }
    }
    suspend fun enabled(patientId:String):Boolean {
        val result=client.from("patient_assignments").select(Columns.raw("id")){ filter {eq("patient_id",patientId);eq("type","exposure_hierarchy");exact("cancelled_at",null)};limit(1) }
        return Json.parseToJsonElement(result.data).jsonArray.isNotEmpty()
    }
    suspend fun setEnabled(patientId:String,value:Boolean){
        Entitlements.requireWrite()
        client.postgrest.rpc("set_patient_exposure_hierarchy_enabled",buildJsonObject{put("p_patient_id",patientId);put("p_enabled",value)})
        check(enabled(patientId)==value)
    }
}
