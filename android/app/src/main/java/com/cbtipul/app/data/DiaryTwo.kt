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

data class DiaryTwoEntry(
    val id: String,
    val patientId: DatabaseId,
    val therapistId: String,
    val createdBy: DiaryOneEntryCreator,
    val event: String,
    val automaticThoughts: List<String>,
    val feelings: List<DiaryFeeling>,
    val thinkingErrors: List<ThinkingError>,
    val alternativeThoughts: List<String>,
    val createdAt: Date,
    val updatedAt: Date,
) {
    val automaticThoughtsPreview: String
        get() {
            val first = automaticThoughts.firstOrNull().orEmpty()
            if (first.isEmpty()) return ""
            return if (automaticThoughts.size > 1) "$first · +${automaticThoughts.size - 1}" else first
        }
}

@Serializable
internal data class DiaryTwoEntryRow(
    val id: String,
    @SerialName("patient_id") val patientId: String,
    @SerialName("therapist_id") val therapistId: String,
    @SerialName("created_by") val createdBy: String,
    val event: String,
    @SerialName("automatic_thoughts") val automaticThoughts: List<String> = emptyList(),
    val feelings: List<DiaryFeeling> = emptyList(),
    @SerialName("thinking_errors") val thinkingErrors: List<ThinkingError>,
    @SerialName("alternative_thoughts") val alternativeThoughts: List<String>,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String,
)

class DiaryTwoRepository(private val client: SupabaseClient) {
    private val _entries = MutableStateFlow<Map<String, List<DiaryTwoEntry>>>(emptyMap())
    val entries: StateFlow<Map<String, List<DiaryTwoEntry>>> = _entries.asStateFlow()
    private val demoEntries = mutableMapOf<String, List<DiaryTwoEntry>>()

    fun entriesFor(patientId: DatabaseId): List<DiaryTwoEntry> =
        _entries.value[patientId.queryValue].orEmpty()

    suspend fun loadEntries(patientId: DatabaseId): List<DiaryTwoEntry> {
        if (DemoData.isDemoId(patientId)) {
            val cached = demoEntries[patientId.queryValue].orEmpty()
            _entries.update { it + (patientId.queryValue to cached) }
            return cached
        }
        if (!SupabaseConfig.isConfigured) throw IllegalStateException("not_configured")
        val patientUuid = PatientAssignmentRepository.uuidOrNull(patientId)
            ?: throw IllegalStateException("not_configured")
        val rows = client.from("diary_two_entries")
            .select(columns) {
                filter { eq("patient_id", patientUuid) }
                order("created_at", Order.DESCENDING)
            }
            .decodeList<DiaryTwoEntryRow>()
        val loaded = rows.map { it.toDomain(patientId) }
        _entries.update { it + (patientId.queryValue to loaded) }
        return loaded
    }

    suspend fun loadEntry(id: String, patientId: DatabaseId): DiaryTwoEntry? {
        if (DemoData.isDemoId(patientId)) return DiaryTwoEntryLookup.accepted(entriesFor(patientId).firstOrNull { it.id.equals(id, true) }, id, patientId)
        val patientUuid = PatientAssignmentRepository.uuidOrNull(patientId) ?: return null
        val rows = client.from("diary_two_entries").select(columns) {
            filter { eq("id", id); eq("patient_id", patientUuid) }
            limit(1)
        }.decodeList<DiaryTwoEntryRow>()
        // Preserve the row's actual identity before validating, never substitute the requested patient.
        val row = rows.firstOrNull() ?: return null
        val entry = DiaryTwoEntryLookup.accepted(row.toDomain(DatabaseId.Text(row.patientId)), id, patientId) ?: return null
        upsert(entry)
        return entry
    }

    suspend fun createEntry(
        patientId: DatabaseId,
        event: String,
        automaticThoughts: List<String>,
        feelings: List<DiaryFeeling>,
        thinkingErrors: List<ThinkingError>,
        alternativeThoughts: List<String>,
    ): DiaryTwoEntry {
        if (DemoData.isDemoId(patientId)) {
            val entry = DiaryTwoEntry(
                id = UUID.randomUUID().toString(),
                patientId = patientId,
                therapistId = UUID.randomUUID().toString(),
                createdBy = DiaryOneEntryCreator.Therapist,
                event = event,
                automaticThoughts = automaticThoughts,
                feelings = feelings,
                thinkingErrors = thinkingErrors,
                alternativeThoughts = alternativeThoughts,
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
        val body = createPayload(patientUuid, therapistId, event, automaticThoughts, feelings, thinkingErrors, alternativeThoughts)
        val saved = client.from("diary_two_entries")
            .insert(body) { select(columns) }
            .decodeSingle<DiaryTwoEntryRow>()
            .toDomain(patientId)
        upsert(saved)
        return saved
    }

    suspend fun updateEntry(
        id: String,
        patientId: DatabaseId,
        event: String,
        automaticThoughts: List<String>,
        feelings: List<DiaryFeeling>,
        thinkingErrors: List<ThinkingError>,
        alternativeThoughts: List<String>,
    ): DiaryTwoEntry {
        if (DemoData.isDemoId(patientId)) {
            val existing = demoEntries[patientId.queryValue].orEmpty().first { it.id == id }
            val updated = existing.copy(
                event = event,
                automaticThoughts = automaticThoughts,
                feelings = feelings,
                thinkingErrors = thinkingErrors,
                alternativeThoughts = alternativeThoughts,
                updatedAt = Date(),
            )
            upsert(updated)
            return updated
        }
        if (!SupabaseConfig.isConfigured) throw IllegalStateException("not_configured")
        val body = updatePayload(event, automaticThoughts, feelings, thinkingErrors, alternativeThoughts, timestampNow())
        val saved = client.from("diary_two_entries")
            .update(body) {
                filter { eq("id", id); eq("patient_id", patientId.queryValue) }
                select(columns)
            }
            .decodeSingle<DiaryTwoEntryRow>()
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
        val deleted = client.from("diary_two_entries")
            .delete {
                filter { eq("id", id); eq("patient_id", patientId.queryValue) }
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

    private fun upsert(entry: DiaryTwoEntry) {
        val key = entry.patientId.queryValue
        val next = (listOf(entry) + entriesFor(entry.patientId).filterNot { it.id == entry.id })
            .sortedByDescending { it.createdAt.time }
        if (DemoData.isDemoId(entry.patientId)) demoEntries[key] = next
        _entries.update { it + (key to next) }
    }

    private fun timestampNow(): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US)
        formatter.timeZone = TimeZone.getTimeZone("UTC")
        return formatter.format(Date())
    }

    private fun DiaryTwoEntryRow.toDomain(patientId: DatabaseId) = DiaryTwoEntry(
        id = id,
        patientId = patientId,
        therapistId = therapistId,
        createdBy = DiaryOneEntryCreator.fromRaw(createdBy),
        event = event,
        automaticThoughts = automaticThoughts,
        feelings = feelings,
        thinkingErrors = thinkingErrors,
        alternativeThoughts = alternativeThoughts,
        createdAt = parseIso(createdAt),
        updatedAt = parseIso(updatedAt),
    )

    @Serializable
    private data class DeletedId(val id: String)

    companion object {
        internal fun createPayload(patientId: String, therapistId: String, event: String,
            automaticThoughts: List<String>, feelings: List<DiaryFeeling>, thinkingErrors: List<ThinkingError>, alternativeThoughts: List<String>) = buildJsonObject {
            put("patient_id", patientId)
            put("therapist_id", therapistId)
            put("created_by", DiaryOneEntryCreator.Therapist.raw)
            clinicalPayload(event, automaticThoughts, feelings, thinkingErrors, alternativeThoughts).forEach { (key, value) -> put(key, value) }
        }
        internal fun updatePayload(event: String, automaticThoughts: List<String>, feelings: List<DiaryFeeling>,
            thinkingErrors: List<ThinkingError>, alternativeThoughts: List<String>, updatedAt: String) = buildJsonObject {
            clinicalPayload(event, automaticThoughts, feelings, thinkingErrors, alternativeThoughts).forEach { (key, value) -> put(key, value) }
            put("updated_at", updatedAt)
        }
        private fun clinicalPayload(event: String, automaticThoughts: List<String>, feelings: List<DiaryFeeling>,
            thinkingErrors: List<ThinkingError>, alternativeThoughts: List<String>) = buildJsonObject {
            put("event", event)
            put("automatic_thoughts", thoughtsJson(automaticThoughts))
            put("feelings", feelingsJson(feelings))
            put("thinking_errors", thoughtsJson(thinkingErrors.map { it.code }))
            put("alternative_thoughts", thoughtsJson(alternativeThoughts))
        }
        private fun thoughtsJson(thoughts: List<String>) = buildJsonArray {
            thoughts.forEach { add(JsonPrimitive(it)) }
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


        private val columns = Columns.raw(
            "id, patient_id, therapist_id, created_by, event, automatic_thoughts, feelings, thinking_errors, alternative_thoughts, created_at, updated_at",
        )

        private fun parseIso(raw: String): Date = PatientAssignmentRepository.parseAssignmentTimestamp(raw)
    }
}
