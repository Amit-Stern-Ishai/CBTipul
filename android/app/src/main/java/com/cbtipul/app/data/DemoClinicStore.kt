package com.cbtipul.app.data

import android.content.Context
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
import java.io.File
import java.util.Date
import java.util.UUID

/** Local-only persistence for the demo clinic (separate from production cache). */
class DemoClinicStore(context: Context) {
    private val appContext = context.applicationContext
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private val filesDir = appContext.filesDir
    private val cacheDir = appContext.cacheDir
    private val clinicFile = File(filesDir, "demo-clinic.json")
    private val namesFile = File(filesDir, "demo-patient-names.json")

    @Serializable
    data class Snapshot(
        val patients: List<PatientRecord> = emptyList(),
        val questionnairesByPatient: Map<String, List<QuestionnaireRecord>> = emptyMap(),
    )

    @Serializable
    data class PatientRecord(
        val id: DatabaseId,
        val firstName: String,
        val lastName: String,
        val active: Boolean,
        val notes: String = "",
        val sessions: List<SessionRecord> = emptyList(),
        val formulation: PatientFormulation? = null,
    )

    @Serializable
    data class SessionRecord(
        val databaseID: DatabaseId? = null,
        val dateMillis: Long,
        val notes: String = "",
        val type: SessionType? = null,
        val structuredNotes: CBTSessionAnalysis? = null,
    )

    @Serializable
    data class QuestionnaireRecord(
        val databaseID: DatabaseId,
        val sessionID: DatabaseId? = null,
        val answeredMillis: Long,
        val gad7Answers: List<Int?> = emptyList(),
        val phq9Answers: List<Int?> = emptyList(),
        val interferenceLevel: Int? = null,
        val gad7Notes: List<String> = emptyList(),
        val phq9Notes: List<String> = emptyList(),
        val interferenceNote: String = "",
    )

    fun loadClinic(): Snapshot? {
        if (!clinicFile.exists()) return null
        return runCatching {
            json.decodeFromString<Snapshot>(clinicFile.readText())
        }.getOrNull()
    }

    fun saveClinic(snapshot: Snapshot) {
        runCatching {
            clinicFile.parentFile?.mkdirs()
            clinicFile.writeText(json.encodeToString(snapshot))
        }
    }

    fun loadNames(): Map<String, String> {
        if (!namesFile.exists()) return emptyMap()
        return runCatching {
            json.decodeFromString<Map<String, String>>(namesFile.readText())
        }.getOrDefault(emptyMap())
    }

    fun saveNames(names: Map<String, String>) {
        runCatching {
            namesFile.parentFile?.mkdirs()
            namesFile.writeText(json.encodeToString(names))
        }
    }

    fun name(forPatientId: DatabaseId): String? =
        loadNames()[forPatientId.queryValue]?.takeIf { it.isNotEmpty() }

    fun saveName(name: String, forPatientId: DatabaseId) {
        val names = loadNames().toMutableMap()
        names[forPatientId.queryValue] = name
        saveNames(names)
    }

    fun deleteName(forPatientId: DatabaseId) {
        val names = loadNames().toMutableMap()
        names.remove(forPatientId.queryValue)
        saveNames(names)
    }

    fun loadPreparation(patientId: String): SavedPreparation? {
        val target = preparationFile(patientId)
        if (!target.exists()) return null
        return runCatching {
            json.decodeFromString<SavedPreparation>(target.readText())
        }.getOrNull()
    }

    fun savePreparation(patientId: String, preparation: NextSessionPreparation): SavedPreparation {
        val saved = SavedPreparation(
            generatedAtMillis = System.currentTimeMillis(),
            preparation = preparation,
        )
        runCatching {
            preparationFile(patientId).writeText(json.encodeToString(saved))
        }
        return saved
    }

    fun deletePreparation(patientId: String) {
        val target = preparationFile(patientId)
        if (target.exists()) target.delete()
    }

    fun clearAll() {
        if (clinicFile.exists()) clinicFile.delete()
        if (namesFile.exists()) namesFile.delete()
        cacheDir.listFiles { f -> f.name.startsWith("demo-preparation-") }
            ?.forEach { it.delete() }
        filesDir.listFiles { f -> f.name.startsWith("demo-preparation-") }
            ?.forEach { it.delete() }
    }

    fun snapshotFrom(
        patients: List<Patient>,
        questionnaires: Map<String, List<CompletedQuestionnaire>>,
    ): Snapshot = Snapshot(
        patients = patients.map { patient ->
            PatientRecord(
                id = patient.id,
                firstName = patient.firstName,
                lastName = patient.lastName,
                active = patient.status == PatientStatus.Active,
                notes = patient.notes,
                sessions = patient.sessions.map {
                    SessionRecord(
                        databaseID = it.databaseId,
                        dateMillis = it.date.time,
                        notes = it.notes,
                        type = it.type,
                        structuredNotes = it.structuredNotes,
                    )
                },
                formulation = patient.formulation,
            )
        },
        questionnairesByPatient = questionnaires.mapValues { (_, rows) ->
            rows.map { record ->
                QuestionnaireRecord(
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
        },
    )

    fun patientsFrom(snapshot: Snapshot, names: Map<String, String>): List<Patient> =
        snapshot.patients.map { record ->
            Patient(
                id = record.id,
                firstName = record.firstName,
                lastName = record.lastName,
                status = PatientStatus.fromActive(record.active),
                notes = record.notes,
                sessions = record.sessions.map {
                    Session(
                        id = UUID.randomUUID(),
                        databaseId = it.databaseID,
                        date = Date(it.dateMillis),
                        notes = it.notes,
                        type = it.type,
                        structuredNotes = it.structuredNotes,
                    )
                },
                localName = names[record.id.queryValue],
                formulation = record.formulation,
            )
        }

    fun questionnairesFrom(snapshot: Snapshot): Map<String, List<CompletedQuestionnaire>> =
        snapshot.questionnairesByPatient.mapValues { (_, rows) ->
            rows.map { record ->
                CompletedQuestionnaire(
                    databaseId = record.databaseID,
                    sessionId = record.sessionID,
                    answeredDate = Date(record.answeredMillis),
                    questionnaire = CombinedMoodQuestionnaire(
                        gad7Answers = padAnswers(record.gad7Answers, CombinedMoodQuestionnaire.GAD7_COUNT),
                        phq9Answers = padAnswers(record.phq9Answers, CombinedMoodQuestionnaire.PHQ9_COUNT),
                        interferenceLevel = record.interferenceLevel,
                        gad7Notes = padNotes(record.gad7Notes, CombinedMoodQuestionnaire.GAD7_COUNT),
                        phq9Notes = padNotes(record.phq9Notes, CombinedMoodQuestionnaire.PHQ9_COUNT),
                        interferenceNote = record.interferenceNote,
                    ),
                )
            }
        }

    private fun preparationFile(patientId: String) =
        File(cacheDir, "demo-preparation-$patientId.json")

    private fun padAnswers(values: List<Int?>, count: Int): List<Int?> =
        List(count) { index -> values.getOrNull(index) }

    private fun padNotes(values: List<String>, count: Int): List<String> =
        List(count) { index -> values.getOrNull(index).orEmpty() }
}
