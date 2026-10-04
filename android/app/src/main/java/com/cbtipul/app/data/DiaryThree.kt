package com.cbtipul.app.data

import com.cbtipul.app.model.PatientStoreException
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
import kotlinx.serialization.json.encodeToJsonElement
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

@Serializable
data class DiaryThreeAutomaticThought(val text: String, val beliefBefore: Int, val beliefAfter: Int)
@Serializable
data class DiaryThreeFeeling(val name: String, val intensityBefore: Int, val intensityAfter: Int)
@Serializable
data class DiaryThreeAlternativeThought(val text: String, val belief: Int)

data class DiaryThreeEntry(
    val id: String,
    val patientId: DatabaseId,
    val therapistId: String,
    val createdBy: DiaryOneEntryCreator,
    val situation: String,
    val automaticThoughts: List<DiaryThreeAutomaticThought>,
    val feelings: List<DiaryThreeFeeling>,
    val thinkingErrors: List<ThinkingError>,
    val alternativeThoughts: List<DiaryThreeAlternativeThought>,
    val createdAt: Date,
    val updatedAt: Date,
) {
    val automaticThoughtsPreview: String
        get() {
            val first = automaticThoughts.firstOrNull()?.text.orEmpty()
            if (first.isEmpty()) return ""
            return if (automaticThoughts.size > 1) "$first · +${automaticThoughts.size - 1}" else first
        }
}

@Serializable
internal data class DiaryThreeEntryRow(
    val id: String,
    @SerialName("patient_id") val patientId: String,
    @SerialName("therapist_id") val therapistId: String,
    @SerialName("created_by") val createdBy: String,
    val situation: String,
    @SerialName("automatic_thoughts") val automaticThoughts: List<DiaryThreeAutomaticThought> = emptyList(),
    val feelings: List<DiaryThreeFeeling> = emptyList(),
    @SerialName("thinking_errors") val thinkingErrors: List<ThinkingError>,
    @SerialName("alternative_thoughts") val alternativeThoughts: List<DiaryThreeAlternativeThought>,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String,
)

class DiaryThreeRepository(private val client: SupabaseClient) {
    private val _entries = MutableStateFlow<Map<String, List<DiaryThreeEntry>>>(emptyMap())
    val entries: StateFlow<Map<String, List<DiaryThreeEntry>>> = _entries.asStateFlow()
    private val demoEntries = mutableMapOf<String, List<DiaryThreeEntry>>()

    fun entriesFor(patientId: DatabaseId): List<DiaryThreeEntry> =
        _entries.value[patientId.queryValue].orEmpty()

    suspend fun loadEntries(patientId: DatabaseId): List<DiaryThreeEntry> {
        if (DemoData.isDemoId(patientId)) {
            val cached = demoEntries[patientId.queryValue].orEmpty()
            _entries.update { it + (patientId.queryValue to cached) }
            return cached
        }
        if (!SupabaseConfig.isConfigured) throw IllegalStateException("not_configured")
        val patientUuid = PatientAssignmentRepository.uuidOrNull(patientId)
            ?: throw IllegalStateException("not_configured")
        val rows = client.from("diary_three_entries")
            .select(columns) {
                filter { eq("patient_id", patientUuid) }
                order("created_at", Order.DESCENDING)
            }
            .decodeList<DiaryThreeEntryRow>()
        val loaded = rows.map { it.toDomain(patientId) }
        _entries.update { it + (patientId.queryValue to loaded) }
        return loaded
    }

    suspend fun loadEntry(id: String, patientId: DatabaseId): DiaryThreeEntry? {
        if (DemoData.isDemoId(patientId)) return DiaryThreeEntryLookup.accepted(entriesFor(patientId).firstOrNull { it.id.equals(id, true) }, id, patientId)
        val patientUuid = PatientAssignmentRepository.uuidOrNull(patientId) ?: return null
        val rows = client.from("diary_three_entries").select(columns) {
            filter { eq("id", id); eq("patient_id", patientUuid) }
            limit(1)
        }.decodeList<DiaryThreeEntryRow>()
        // Preserve the row's actual identity before validating, never substitute the requested patient.
        val row = rows.firstOrNull() ?: return null
        val entry = DiaryThreeEntryLookup.accepted(row.toDomain(DatabaseId.Text(row.patientId)), id, patientId) ?: return null
        upsert(entry)
        return entry
    }

    suspend fun createEntry(
        patientId: DatabaseId,
        situation: String,
        automaticThoughts: List<DiaryThreeAutomaticThought>,
        feelings: List<DiaryThreeFeeling>,
        thinkingErrors: List<ThinkingError>,
        alternativeThoughts: List<DiaryThreeAlternativeThought>,
    ): DiaryThreeEntry {
        Entitlements.requireWrite(localDemo = DemoData.isDemoId(patientId))
        if (DemoData.isDemoId(patientId)) {
            val entry = DiaryThreeEntry(
                id = UUID.randomUUID().toString(),
                patientId = patientId,
                therapistId = UUID.randomUUID().toString(),
                createdBy = DiaryOneEntryCreator.Therapist,
                situation = situation,
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
        val body = createPayload(patientUuid, therapistId, situation, automaticThoughts, feelings, thinkingErrors, alternativeThoughts)
        val saved = client.from("diary_three_entries")
            .insert(body) { select(columns) }
            .decodeSingle<DiaryThreeEntryRow>()
            .toDomain(patientId)
        upsert(saved)
        return saved
    }

    suspend fun updateEntry(
        id: String,
        patientId: DatabaseId,
        situation: String,
        automaticThoughts: List<DiaryThreeAutomaticThought>,
        feelings: List<DiaryThreeFeeling>,
        thinkingErrors: List<ThinkingError>,
        alternativeThoughts: List<DiaryThreeAlternativeThought>,
    ): DiaryThreeEntry {
        Entitlements.requireWrite(localDemo = DemoData.isDemoId(patientId))
        if (_entries.value[patientId.queryValue].orEmpty().any { it.id == id && it.createdBy == DiaryOneEntryCreator.Patient }) throw PatientStoreException(PatientStoreException.Kind.UpdateRejected)
        if (DemoData.isDemoId(patientId)) {
            val existing = demoEntries[patientId.queryValue].orEmpty().first { it.id == id }
            val updated = existing.copy(
                situation = situation,
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
        val body = updatePayload(situation, automaticThoughts, feelings, thinkingErrors, alternativeThoughts, timestampNow())
        val saved = client.from("diary_three_entries")
            .update(body) {
                filter { eq("created_by", "therapist"); eq("id", id); eq("patient_id", patientId.queryValue) }
                select(columns)
            }
            .decodeSingle<DiaryThreeEntryRow>()
            .toDomain(patientId)
        upsert(saved)
        return saved
    }

    suspend fun deleteEntry(id: String, patientId: DatabaseId) {
        Entitlements.requireWrite(localDemo = DemoData.isDemoId(patientId))
        if (_entries.value[patientId.queryValue].orEmpty().any { it.id == id && it.createdBy == DiaryOneEntryCreator.Patient }) throw PatientStoreException(PatientStoreException.Kind.UpdateRejected)
        if (DemoData.isDemoId(patientId)) {
            demoEntries[patientId.queryValue] =
                demoEntries[patientId.queryValue].orEmpty().filterNot { it.id == id }
            _entries.update { it + (patientId.queryValue to demoEntries[patientId.queryValue].orEmpty()) }
            return
        }
        if (!SupabaseConfig.isConfigured) throw IllegalStateException("not_configured")
        val deleted = client.from("diary_three_entries")
            .delete {
                filter { eq("created_by", "therapist"); eq("id", id); eq("patient_id", patientId.queryValue) }
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

    private fun upsert(entry: DiaryThreeEntry) {
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

    private fun DiaryThreeEntryRow.toDomain(patientId: DatabaseId) = DiaryThreeEntry(
        id = id,
        patientId = patientId,
        therapistId = therapistId,
        createdBy = DiaryOneEntryCreator.fromRaw(createdBy),
        situation = situation,
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
        internal fun createPayload(patientId: String, therapistId: String, situation: String,
            automaticThoughts: List<DiaryThreeAutomaticThought>, feelings: List<DiaryThreeFeeling>, thinkingErrors: List<ThinkingError>, alternativeThoughts: List<DiaryThreeAlternativeThought>) = buildJsonObject {
            put("patient_id", patientId)
            put("therapist_id", therapistId)
            put("created_by", DiaryOneEntryCreator.Therapist.raw)
            clinicalPayload(situation, automaticThoughts, feelings, thinkingErrors, alternativeThoughts).forEach { (key, value) -> put(key, value) }
        }
        internal fun updatePayload(situation: String, automaticThoughts: List<DiaryThreeAutomaticThought>, feelings: List<DiaryThreeFeeling>,
            thinkingErrors: List<ThinkingError>, alternativeThoughts: List<DiaryThreeAlternativeThought>, updatedAt: String) = buildJsonObject {
            clinicalPayload(situation, automaticThoughts, feelings, thinkingErrors, alternativeThoughts).forEach { (key, value) -> put(key, value) }
            put("updated_at", updatedAt)
        }
        private fun clinicalPayload(situation: String, automaticThoughts: List<DiaryThreeAutomaticThought>, feelings: List<DiaryThreeFeeling>,
            thinkingErrors: List<ThinkingError>, alternativeThoughts: List<DiaryThreeAlternativeThought>) = buildJsonObject {
            put("situation", situation)
            put("automatic_thoughts", kotlinx.serialization.json.Json.encodeToJsonElement(automaticThoughts))
            put("feelings", kotlinx.serialization.json.Json.encodeToJsonElement(feelings))
            put("thinking_errors", thoughtsJson(thinkingErrors.map { it.code }))
            put("alternative_thoughts", kotlinx.serialization.json.Json.encodeToJsonElement(alternativeThoughts))
        }
        private fun thoughtsJson(thoughts: List<String>) = buildJsonArray {
            thoughts.forEach { add(JsonPrimitive(it)) }
        }

        private val columns = Columns.raw(
            "id, patient_id, therapist_id, created_by, situation, automatic_thoughts, feelings, thinking_errors, alternative_thoughts, created_at, updated_at",
        )

        private fun parseIso(raw: String): Date = PatientAssignmentRepository.parseAssignmentTimestamp(raw)
    }
}
