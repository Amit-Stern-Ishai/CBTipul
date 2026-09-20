package com.cbtipul.app.data

import com.cbtipul.app.model.DatabaseId
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

enum class DiaryOneEntryCreator(val raw: String) {
    Therapist("therapist"),
    Patient("patient"),
    ;

    companion object {
        fun fromRaw(value: String): DiaryOneEntryCreator =
            entries.find { it.raw == value } ?: Therapist
    }
}

data class DiaryOneEntry(
    val id: String,
    val patientId: DatabaseId,
    val therapistId: String,
    val createdBy: DiaryOneEntryCreator,
    val event: String,
    val thought: String,
    val feelings: List<DiaryFeeling>,
    val behaviour: String,
    val physicalSymptoms: String?,
    val createdAt: Date,
    val updatedAt: Date,
)

@Serializable
private data class DiaryOneEntryRow(
    val id: String,
    @SerialName("patient_id") val patientId: String,
    @SerialName("therapist_id") val therapistId: String,
    @SerialName("created_by") val createdBy: String,
    val event: String,
    val thought: String,
    val feelings: List<DiaryFeeling> = emptyList(),
    val behaviour: String,
    @SerialName("physical_symptoms") val physicalSymptoms: String? = null,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String,
)

class DiaryOneRepository(private val client: SupabaseClient) {
    private val _entries = MutableStateFlow<Map<String, List<DiaryOneEntry>>>(emptyMap())
    val entries: StateFlow<Map<String, List<DiaryOneEntry>>> = _entries.asStateFlow()
    private val demoEntries = mutableMapOf<String, List<DiaryOneEntry>>()

    fun entriesFor(patientId: DatabaseId): List<DiaryOneEntry> =
        _entries.value[patientId.queryValue].orEmpty()

    suspend fun loadEntries(patientId: DatabaseId): List<DiaryOneEntry> {
        if (DemoData.isDemoId(patientId)) {
            val cached = demoEntries[patientId.queryValue].orEmpty()
            _entries.update { it + (patientId.queryValue to cached) }
            return cached
        }
        if (!SupabaseConfig.isConfigured) throw IllegalStateException("not_configured")
        val patientUuid = PatientAssignmentRepository.uuidOrNull(patientId)
            ?: throw IllegalStateException("not_configured")
        val rows = client.from("diary_one_entries")
            .select(columns) {
                filter { eq("patient_id", patientUuid) }
                order("created_at", Order.DESCENDING)
            }
            .decodeList<DiaryOneEntryRow>()
        val loaded = rows.map { it.toDomain(patientId) }
        _entries.update { it + (patientId.queryValue to loaded) }
        return loaded
    }

    suspend fun createEntry(
        patientId: DatabaseId,
        event: String,
        thought: String,
        feelings: List<DiaryFeeling>,
        behaviour: String,
        physicalSymptoms: String?,
    ): DiaryOneEntry {
        val symptoms = physicalSymptoms?.trim()?.ifEmpty { null }
        if (DemoData.isDemoId(patientId)) {
            val entry = DiaryOneEntry(
                id = UUID.randomUUID().toString(),
                patientId = patientId,
                therapistId = UUID.randomUUID().toString(),
                createdBy = DiaryOneEntryCreator.Therapist,
                event = event,
                thought = thought,
                feelings = feelings,
                behaviour = behaviour,
                physicalSymptoms = symptoms,
                createdAt = Date(),
                updatedAt = Date(),
            )
            upsert(entry)
            return entry
        }
        if (!SupabaseConfig.isConfigured) throw IllegalStateException("not_configured")
        val patientUuid = PatientAssignmentRepository.uuidOrNull(patientId)
            ?: throw IllegalStateException("not_configured")
        val therapistId = client.auth.currentSessionOrNull()?.user?.id
            ?: throw IllegalStateException("not_signed_in")
        val body = buildJsonObject {
            put("patient_id", patientUuid)
            put("therapist_id", therapistId)
            put("created_by", DiaryOneEntryCreator.Therapist.raw)
            put("event", event)
            put("thought", thought)
            put("feelings", feelingsJson(feelings))
            put("behaviour", behaviour)
            if (symptoms == null) put("physical_symptoms", JsonNull) else put("physical_symptoms", symptoms)
        }
        val saved = client.from("diary_one_entries")
            .insert(body) { select(columns) }
            .decodeSingle<DiaryOneEntryRow>()
            .toDomain(patientId)
        upsert(saved)
        return saved
    }

    suspend fun updateEntry(
        id: String,
        patientId: DatabaseId,
        event: String,
        thought: String,
        feelings: List<DiaryFeeling>,
        behaviour: String,
        physicalSymptoms: String?,
    ): DiaryOneEntry {
        val symptoms = physicalSymptoms?.trim()?.ifEmpty { null }
        if (DemoData.isDemoId(patientId)) {
            val existing = demoEntries[patientId.queryValue].orEmpty().first { it.id == id }
            val updated = existing.copy(
                event = event,
                thought = thought,
                feelings = feelings,
                behaviour = behaviour,
                physicalSymptoms = symptoms,
                updatedAt = Date(),
            )
            upsert(updated)
            return updated
        }
        if (!SupabaseConfig.isConfigured) throw IllegalStateException("not_configured")
        val body = buildJsonObject {
            put("event", event)
            put("thought", thought)
            put("feelings", feelingsJson(feelings))
            put("behaviour", behaviour)
            if (symptoms == null) put("physical_symptoms", JsonNull) else put("physical_symptoms", symptoms)
            put("updated_at", timestampNow())
        }
        val saved = client.from("diary_one_entries")
            .update(body) {
                filter { eq("id", id) }
                select(columns)
            }
            .decodeSingle<DiaryOneEntryRow>()
            .toDomain(patientId)
        upsert(saved)
        return saved
    }

    suspend fun deleteEntry(id: String, patientId: DatabaseId) {
        if (DemoData.isDemoId(patientId)) {
            demoEntries[patientId.queryValue] =
                demoEntries[patientId.queryValue].orEmpty().filterNot { it.id == id }
            _entries.update { it + (patientId.queryValue to demoEntries[patientId.queryValue].orEmpty()) }
            return
        }
        if (!SupabaseConfig.isConfigured) throw IllegalStateException("not_configured")
        val deleted = client.from("diary_one_entries")
            .delete {
                filter { eq("id", id) }
                select(Columns.raw("id"))
            }
            .decodeList<DeletedId>()
        if (deleted.isEmpty()) throw IllegalStateException("not_configured")
        _entries.update { map ->
            val next = map[patientId.queryValue].orEmpty().filterNot { it.id == id }
            map + (patientId.queryValue to next)
        }
    }

    fun clear() {
        _entries.value = emptyMap()
        demoEntries.clear()
    }

    private fun upsert(entry: DiaryOneEntry) {
        val key = entry.patientId.queryValue
        val next = (listOf(entry) + entriesFor(entry.patientId).filterNot { it.id == entry.id })
            .sortedByDescending { it.createdAt.time }
        if (DemoData.isDemoId(entry.patientId)) demoEntries[key] = next
        _entries.update { it + (key to next) }
    }

    private fun feelingsJson(feelings: List<DiaryFeeling>) = buildJsonArray {
        feelings.forEach { feeling ->
            add(
                buildJsonObject {
                    put("name", feeling.name)
                    put("intensity", feeling.intensity)
                },
            )
        }
    }

    private fun timestampNow(): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US)
        formatter.timeZone = TimeZone.getTimeZone("UTC")
        return formatter.format(Date())
    }

    private fun DiaryOneEntryRow.toDomain(patientId: DatabaseId) = DiaryOneEntry(
        id = id,
        patientId = patientId,
        therapistId = therapistId,
        createdBy = DiaryOneEntryCreator.fromRaw(createdBy),
        event = event,
        thought = thought,
        feelings = feelings,
        behaviour = behaviour,
        physicalSymptoms = physicalSymptoms,
        createdAt = parseIso(createdAt),
        updatedAt = parseIso(updatedAt),
    )

    @Serializable
    private data class DeletedId(val id: String)

    companion object {
        private val columns = Columns.raw(
            "id, patient_id, therapist_id, created_by, event, thought, feelings, behaviour, physical_symptoms, created_at, updated_at",
        )

        private fun parseIso(raw: String): Date {
            listOf(
                SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US),
                SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US),
            ).forEach { it.parse(raw)?.let { date -> return date } }
            return Date()
        }
    }
}
