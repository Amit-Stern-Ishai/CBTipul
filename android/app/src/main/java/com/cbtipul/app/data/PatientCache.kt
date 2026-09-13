package com.cbtipul.app.data

import android.content.Context
import androidx.security.crypto.EncryptedFile
import androidx.security.crypto.MasterKey
import com.cbtipul.app.model.CBTSessionAnalysis
import com.cbtipul.app.model.CombinedMoodQuestionnaire
import com.cbtipul.app.model.CompletedQuestionnaire
import com.cbtipul.app.model.DatabaseId
import com.cbtipul.app.model.NextSessionPreparation
import com.cbtipul.app.model.Patient
import com.cbtipul.app.model.PatientFormulation
import com.cbtipul.app.model.PatientStatus
import com.cbtipul.app.model.SavedPreparation
import com.cbtipul.app.model.Session
import com.cbtipul.app.model.SessionType
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.decodeFromJsonElement
import java.io.File
import java.util.Date
import java.util.UUID

data class LoadedPatientCache(
    val patients: List<Patient>,
    val questionnaires: Map<String, List<CompletedQuestionnaire>>,
)

class PatientCache(context: Context) {

    private val appContext = context.applicationContext
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private val filesDir = appContext.filesDir
    private val cacheDir = appContext.cacheDir
    private val file = File(filesDir, "patients-cache.json")
    private val legacyFile = File(cacheDir, "patients-cache.json")
    private val masterKey = MasterKey.Builder(appContext).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build()

    fun load(): LoadedPatientCache? {
        val bytes = readEncrypted(file) ?: readEncrypted(legacyFile)?.also {
            writeEncrypted(file, it)
            legacyFile.delete()
        } ?: return null
        return runCatching {
            val text = bytes.decodeToString()
            val snapshot = decodeSnapshot(text)
            LoadedPatientCache(
                patients = snapshot.patients.mapNotNull { it.toPatient() },
                questionnaires = snapshot.questionnaires.mapValues { (_, rows) ->
                    rows.map { it.toCompleted() }
                },
            )
        }.getOrNull()
    }

    fun save(
        patients: List<Patient>,
        questionnaires: Map<String, List<CompletedQuestionnaire>> = emptyMap(),
    ) {
        val snapshot = PatientsCacheSnapshot(
            patients = patients.map { CachedPatient.from(it) },
            questionnaires = questionnaires.mapValues { (_, rows) ->
                rows.map { CachedQuestionnaire.from(it) }
            },
        )
        val bytes = json.encodeToString(snapshot).toByteArray()
        runCatching {
            writeEncrypted(file, bytes)
            if (legacyFile.exists()) legacyFile.delete()
        }.onFailure {
            // Prefer an empty cache over keeping deleted patients/sessions.
            if (file.exists()) file.delete()
            if (legacyFile.exists()) legacyFile.delete()
        }
    }

    fun clear() {
        if (file.exists()) file.delete()
        if (legacyFile.exists()) legacyFile.delete()
        clearPreparations()
    }

    fun loadPreparation(patientId: String): SavedPreparation? {
        val target = preparationFile(patientId)
        if (!target.exists()) return null
        return runCatching {
            encryptedFile(target).openFileInput().use { input ->
                json.decodeFromString<SavedPreparation>(input.readBytes().decodeToString())
            }
        }.getOrNull()
    }

    fun savePreparation(patientId: String, preparation: NextSessionPreparation): SavedPreparation {
        val saved = SavedPreparation(generatedAtMillis = System.currentTimeMillis(), preparation = preparation)
        val target = preparationFile(patientId)
        runCatching {
            writeEncrypted(target, json.encodeToString(saved).toByteArray())
        }
        return saved
    }

    fun deletePreparation(patientId: String) {
        val target = preparationFile(patientId)
        if (target.exists()) target.delete()
        val legacy = File(cacheDir, "preparation-$patientId.json")
        if (legacy.exists()) legacy.delete()
    }

    fun clearPreparations() {
        filesDir.listFiles { f -> f.name.startsWith("preparation-") && f.name.endsWith(".json") }
            ?.forEach { it.delete() }
        cacheDir.listFiles { f -> f.name.startsWith("preparation-") && f.name.endsWith(".json") }
            ?.forEach { it.delete() }
    }

    private fun decodeSnapshot(text: String): PatientsCacheSnapshot {
        val element = json.parseToJsonElement(text)
        return if (element is JsonArray) {
            PatientsCacheSnapshot(patients = json.decodeFromJsonElement(element))
        } else {
            json.decodeFromJsonElement(element)
        }
    }

    private fun readEncrypted(target: File): ByteArray? {
        if (!target.exists()) return null
        return runCatching {
            encryptedFile(target).openFileInput().use { it.readBytes() }
        }.getOrNull()
    }

    private fun writeEncrypted(target: File, bytes: ByteArray) {
        if (target.exists()) target.delete()
        encryptedFile(target).openFileOutput().use { it.write(bytes) }
    }

    private fun preparationFile(patientId: String): File {
        val current = File(filesDir, "preparation-$patientId.json")
        if (current.exists()) return current
        val legacy = File(cacheDir, "preparation-$patientId.json")
        return if (legacy.exists()) legacy else current
    }

    private fun encryptedFile(target: File) = EncryptedFile.Builder(
        appContext,
        target,
        masterKey,
        EncryptedFile.FileEncryptionScheme.AES256_GCM_HKDF_4KB,
    ).build()
}

@Serializable
private data class PatientsCacheSnapshot(
    val patients: List<CachedPatient> = emptyList(),
    val questionnaires: Map<String, List<CachedQuestionnaire>> = emptyMap(),
)

@Serializable
private data class CachedQuestionnaire(
    val databaseID: DatabaseId,
    val sessionID: DatabaseId? = null,
    val answeredMillis: Long,
    val gad7Answers: List<Int?> = emptyList(),
    val phq9Answers: List<Int?> = emptyList(),
    val interferenceLevel: Int? = null,
    val gad7Notes: List<String> = emptyList(),
    val phq9Notes: List<String> = emptyList(),
    val interferenceNote: String = "",
) {
    fun toCompleted() = CompletedQuestionnaire(
        databaseId = databaseID,
        sessionId = sessionID,
        answeredDate = Date(answeredMillis),
        questionnaire = CombinedMoodQuestionnaire(
            gad7Answers = gad7Answers,
            phq9Answers = phq9Answers,
            interferenceLevel = interferenceLevel,
            gad7Notes = gad7Notes,
            phq9Notes = phq9Notes,
            interferenceNote = interferenceNote,
        ),
    )

    companion object {
        fun from(record: CompletedQuestionnaire) = CachedQuestionnaire(
            databaseID = record.databaseId,
            sessionID = record.sessionId,
            answeredMillis = record.answeredDate.time,
            gad7Answers = record.questionnaire.gad7Answers,
            phq9Answers = record.questionnaire.phq9Answers,
            interferenceLevel = record.questionnaire.interferenceLevel,
            gad7Notes = record.questionnaire.gad7Notes,
            phq9Notes = record.questionnaire.phq9Notes,
            interferenceNote = record.questionnaire.interferenceNote,
        )
    }
}

@Serializable
private data class CachedPatient(
    val databaseID: DatabaseId? = null,
    val firstName: String,
    val lastName: String,
    val active: Boolean,
    val notes: String? = null,
    val sessions: List<CachedSession> = emptyList(),
    val formulation: PatientFormulation? = null,
) {
    fun toPatient(): Patient? {
        val id = databaseID ?: return null
        return Patient(
            id = id,
            firstName = firstName,
            lastName = lastName,
            status = PatientStatus.fromActive(active),
            notes = notes.orEmpty(),
            sessions = sessions.map { it.toSession() },
            formulation = formulation,
        )
    }

    companion object {
        fun from(patient: Patient) = CachedPatient(
            databaseID = patient.id,
            firstName = patient.firstName,
            lastName = patient.lastName,
            active = patient.status == PatientStatus.Active,
            notes = patient.notes,
            sessions = patient.sessions.map { CachedSession.from(it) },
            formulation = patient.formulation,
        )
    }
}

@Serializable
private data class CachedSession(
    val databaseID: DatabaseId? = null,
    val dateMillis: Long,
    val notes: String,
    val type: SessionType? = null,
    val structuredNotes: CBTSessionAnalysis? = null,
) {
    fun toSession() = Session(
        id = UUID.randomUUID(),
        databaseId = databaseID,
        date = Date(dateMillis),
        notes = notes,
        type = type,
        structuredNotes = structuredNotes,
    )

    companion object {
        fun from(session: Session) = CachedSession(
            databaseID = session.databaseId,
            dateMillis = session.date.time,
            notes = session.notes,
            type = session.type,
            structuredNotes = session.structuredNotes,
        )
    }
}
