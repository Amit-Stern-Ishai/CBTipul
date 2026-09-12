package com.cbtipul.app.data

import android.content.Context
import androidx.security.crypto.EncryptedFile
import androidx.security.crypto.MasterKey
import com.cbtipul.app.model.CBTSessionAnalysis
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
import java.io.File
import java.util.Date
import java.util.UUID

class PatientCache(context: Context) {

    private val appContext = context.applicationContext
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private val cacheDir = appContext.cacheDir
    private val file = File(cacheDir, "patients-cache.json")
    private val masterKey = MasterKey.Builder(appContext).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build()
    private val encrypted = EncryptedFile.Builder(
        appContext,
        file,
        masterKey,
        EncryptedFile.FileEncryptionScheme.AES256_GCM_HKDF_4KB,
    ).build()

    fun load(): List<Patient>? {
        if (!file.exists()) return null
        return runCatching {
            encrypted.openFileInput().use { input ->
                json.decodeFromString<List<CachedPatient>>(input.readBytes().decodeToString())
                    .mapNotNull { it.toPatient() }
            }
        }.getOrNull()
    }

    fun save(patients: List<Patient>) {
        runCatching {
            if (file.exists()) file.delete()
            encrypted.openFileOutput().use { output ->
                output.write(json.encodeToString(patients.map { CachedPatient.from(it) }).toByteArray())
            }
        }
    }

    fun clear() {
        if (file.exists()) file.delete()
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
            if (target.exists()) target.delete()
            encryptedFile(target).openFileOutput().use { output ->
                output.write(json.encodeToString(saved).toByteArray())
            }
        }
        return saved
    }

    fun deletePreparation(patientId: String) {
        val target = preparationFile(patientId)
        if (target.exists()) target.delete()
    }

    fun clearPreparations() {
        cacheDir.listFiles { f -> f.name.startsWith("preparation-") && f.name.endsWith(".json") }
            ?.forEach { it.delete() }
    }

    private fun preparationFile(patientId: String) = File(cacheDir, "preparation-$patientId.json")

    private fun encryptedFile(target: File) = EncryptedFile.Builder(
        appContext,
        target,
        masterKey,
        EncryptedFile.FileEncryptionScheme.AES256_GCM_HKDF_4KB,
    ).build()
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
