package com.cbtipul.app.data

import com.cbtipul.app.model.AiException
import com.cbtipul.app.model.CBTSessionAnalysis
import com.cbtipul.app.model.ChatTurn
import com.cbtipul.app.model.CombinedMoodQuestionnaire
import com.cbtipul.app.model.CompletedQuestionnaire
import com.cbtipul.app.model.DatabaseId
import com.cbtipul.app.model.FormulationSupervision
import com.cbtipul.app.model.LongitudinalCaseReviewResponse
import com.cbtipul.app.model.Patient
import com.cbtipul.app.model.PatientFormulation
import com.cbtipul.app.model.PatientStatus
import com.cbtipul.app.model.PatientStoreException
import com.cbtipul.app.model.QuestionnaireNotes
import com.cbtipul.app.model.SavedPreparation
import com.cbtipul.app.model.Session
import com.cbtipul.app.model.SessionType
import com.cbtipul.app.model.WhatAmIMissingResponse
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.encodeToJsonElement
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.io.File
import java.util.UUID

class PatientRepository(
    private val client: SupabaseClient,
    private val identityStore: PatientIdentityStore,
    private val cache: PatientCache,
    private val textGate: ClinicalTextGate,
    private val whisper: WhisperService,
    private val ai: AiService,
    private val demoClinicStore: DemoClinicStore,
    private val aiConsentStore: AiConsentStore,
) {
    private val _patients = MutableStateFlow<List<Patient>>(emptyList())
    val patients: StateFlow<List<Patient>> = _patients.asStateFlow()
    private val _questionnaires = MutableStateFlow<Map<String, List<CompletedQuestionnaire>>>(emptyMap())
    val questionnaires: StateFlow<Map<String, List<CompletedQuestionnaire>>> = _questionnaires.asStateFlow()
    private val _isDemoMode = MutableStateFlow(false)
    val isDemoMode: StateFlow<Boolean> = _isDemoMode.asStateFlow()
    private val _showcaseDataLoaded = MutableStateFlow(false)
    val showcaseDataLoaded: StateFlow<Boolean> = _showcaseDataLoaded.asStateFlow()
    private val cacheLock = Mutex()

    fun loadCachedPatients() {
        if (_isDemoMode.value) return
        if (_patients.value.isNotEmpty()) return
        val cached = cache.load() ?: return
        _patients.value = cached.patients.map { patient ->
            textGate.markSafe(patient.notes)
            markFormulationSafe(patient.formulation)
            patient.sessions.forEach {
                textGate.markSafe(it.notes)
                markAnalysisSafe(it.structuredNotes)
            }
            patient.copy(localName = identityStore.name(patient.id))
        }
        _questionnaires.value = cached.questionnaires.mapValues { (_, records) ->
            records.onEach { record ->
                record.questionnaire.gad7Notes.forEach { textGate.markSafe(it) }
                record.questionnaire.phq9Notes.forEach { textGate.markSafe(it) }
                textGate.markSafe(record.questionnaire.interferenceNote)
            }
        }
    }

    private fun persistCache() {
        if (_isDemoMode.value) {
            persistDemoClinic()
            return
        }
        cache.save(_patients.value, _questionnaires.value)
    }

    /** Empty local demo clinic (like a new signup); restores tutorial-only work if present. */
    fun enterDemoMode() {
        _isDemoMode.value = true
        aiConsentStore.setDemoBypass(true)
        _showcaseDataLoaded.value = false
        _patients.value = emptyList()
        _questionnaires.value = emptyMap()
        val snapshot = demoClinicStore.loadClinic()
        if (snapshot != null) {
            applyTutorialOnlySnapshot(snapshot)
        }
    }

    fun loadShowcaseDemoData() {
        if (!_isDemoMode.value || _showcaseDataLoaded.value) return
        val bundle = DemoData.makeBundle()
        val existingIds = _patients.value.map { it.id.queryValue }.toSet()
        val added = mutableListOf<Patient>()
        for (patient in bundle.patients) {
            if (!DemoData.isShowcaseId(patient.id)) continue
            if (patient.id.queryValue in existingIds) continue
            val name = patient.localName?.takeIf { it.isNotEmpty() } ?: patient.backendName
            if (name.isNotEmpty()) {
                demoClinicStore.saveName(name, patient.id)
            }
            markFormulationSafe(patient.formulation)
            patient.sessions.forEach {
                textGate.markSafe(it.notes)
                markAnalysisSafe(it.structuredNotes)
            }
            added += patient.copy(localName = name.ifEmpty { null })
        }
        _patients.update { it + added }
        _questionnaires.update { current ->
            val next = current.toMutableMap()
            for ((patientId, records) in bundle.questionnairesByPatient) {
                if (!DemoData.isShowcaseId(patientId)) continue
                next[patientId.queryValue] = records
            }
            for (patient in _patients.value) {
                if (patient.id.queryValue !in next) next[patient.id.queryValue] = emptyList()
            }
            next
        }
        _showcaseDataLoaded.value = true
        persistDemoClinic()
    }

    suspend fun exitDemoMode() {
        if (!_isDemoMode.value) return
        demoClinicStore.clearAll()
        _isDemoMode.value = false
        aiConsentStore.setDemoBypass(false)
        _showcaseDataLoaded.value = false
        _patients.value = emptyList()
        _questionnaires.value = emptyMap()
        loadCachedPatients()
        runCatching { loadPatients() }
    }

    fun restartDemoTutorial() {
        if (!_isDemoMode.value) return
        val demoIds = _patients.value.filter { DemoData.isDemoId(it.id) }.map { it.id }
        _patients.update { list -> list.filterNot { DemoData.isDemoId(it.id) } }
        _questionnaires.update { cache ->
            cache.filterKeys { key -> demoIds.none { it.queryValue == key } }
        }
        demoIds.forEach { id ->
            demoClinicStore.deleteName(id)
            demoClinicStore.deletePreparation(id.queryValue)
        }
        _showcaseDataLoaded.value = false
        persistDemoClinic()
    }

    private fun persistDemoClinic() {
        if (!_isDemoMode.value) return
        val snapshot = demoClinicStore.snapshotFrom(_patients.value, _questionnaires.value)
        demoClinicStore.saveClinic(snapshot)
        val names = demoClinicStore.loadNames().toMutableMap()
        for (patient in _patients.value) {
            val name = patient.localName
            if (!name.isNullOrEmpty()) names[patient.id.queryValue] = name
        }
        demoClinicStore.saveNames(names)
    }

    private fun applyTutorialOnlySnapshot(snapshot: DemoClinicStore.Snapshot) {
        val names = demoClinicStore.loadNames()
        val tutorialSnapshot = snapshot.copy(
            patients = snapshot.patients.filter { DemoData.isTutorialPatientId(it.id) },
            questionnairesByPatient = snapshot.questionnairesByPatient.filterKeys { key ->
                DemoData.isTutorialPatientId(DatabaseId.Text(key))
            },
        )
        val patients = demoClinicStore.patientsFrom(tutorialSnapshot, names)
        patients.forEach { patient ->
            markFormulationSafe(patient.formulation)
            textGate.markSafe(patient.notes)
            patient.sessions.forEach {
                textGate.markSafe(it.notes)
                markAnalysisSafe(it.structuredNotes)
            }
        }
        _patients.value = patients
        val questionnaires = demoClinicStore.questionnairesFrom(tutorialSnapshot)
        _questionnaires.value = questionnaires
        _showcaseDataLoaded.value = false
    }

    suspend fun loadPatients() {
        if (_isDemoMode.value) return
        ensureConfigured()
        cacheLock.withLock {
            loadPatientsLocked()
        }
    }

    private suspend fun loadPatientsLocked() {
        val patientRows = client.from("Patients")
            .select(Columns.raw("id, active, notes, formulation"))
            .decodeList<PatientRow>()
        val sessionRows = client.from("Sessions")
            .select(Columns.raw("id, patient_id, session_date, notes, type, structured_notes"))
            .decodeList<SessionRow>()

        val sessionsByPatient = sessionRows.groupBy { it.patientId.queryValue }
        val existing = _patients.value
        val loaded = patientRows.map { row ->
            textGate.markSafe(row.notes)
            val current = existing.find { it.id.queryValue == row.id.queryValue }
            val sessions = (sessionsByPatient[row.id.queryValue] ?: emptyList())
                .map { sessionRow ->
                    textGate.markSafe(sessionRow.notes)
                    val existingSession = current?.sessions?.find {
                        it.databaseId?.queryValue == sessionRow.id.queryValue
                    }
                    Session(
                        id = existingSession?.id ?: UUID.randomUUID(),
                        databaseId = sessionRow.id,
                        date = parseDate(sessionRow.sessionDate),
                        notes = sessionRow.notes.orEmpty(),
                        type = sessionRow.sessionType,
                        structuredNotes = decodeAnalysis(sessionRow.structuredNotes)?.also { markAnalysisSafe(it) },
                    )
                }
                .sortedBy { it.date }
            val decodedFormulation = decodeFormulation(row.formulation)
            if (decodedFormulation != null) markFormulationSafe(decodedFormulation)
            val patient = Patient(
                id = row.id,
                firstName = current?.firstName.orEmpty(),
                lastName = current?.lastName.orEmpty(),
                status = PatientStatus.fromActive(row.active),
                notes = row.notes.orEmpty(),
                sessions = sessions,
                formulation = decodedFormulation ?: current?.formulation,
            )
            patient.copy(localName = identityStore.name(patient.id))
        }
        identityStore.upsertIdentities(
            loaded.associate { it.id to it.backendName },
        )
        _patients.value = loaded.map { it.copy(localName = identityStore.name(it.id)) }
        persistCache()
    }

    suspend fun addPatient(firstName: String, lastName: String, status: PatientStatus) {
        if (_isDemoMode.value) {
            val name = listOf(firstName, lastName).map { it.trim() }.filter { it.isNotEmpty() }.joinToString(" ")
            if (name.isEmpty()) return
            val patient = Patient(
                id = DemoData.makeTutorialPatientId(),
                firstName = firstName,
                lastName = lastName,
                status = status,
                localName = name,
            )
            demoClinicStore.saveName(name, patient.id)
            _patients.update { it + patient }
            persistDemoClinic()
            return
        }
        ensureConfigured()
        val inserted = client.from("Patients")
            .insert(NewPatientRecord(active = status == PatientStatus.Active)) {
                select(Columns.raw("id"))
            }
            .decodeSingle<InsertedRow>()
        val patient = Patient(
            id = inserted.id,
            firstName = firstName,
            lastName = lastName,
            status = status,
        )
        identityStore.upsertIdentities(mapOf(patient.id to patient.backendName))
        val named = patient.copy(localName = identityStore.name(patient.id))
        _patients.update { it + named }
        persistCache()
    }

    fun renamePatient(patientId: DatabaseId, firstName: String, lastName: String) {
        val name = listOf(firstName, lastName).map { it.trim() }.filter { it.isNotEmpty() }.joinToString(" ")
        if (name.isEmpty()) return
        if (DemoData.isDemoId(patientId) || _isDemoMode.value) {
            demoClinicStore.saveName(name, patientId)
            _patients.update { list ->
                list.map { patient ->
                    if (patient.id.queryValue == patientId.queryValue) {
                        patient.copy(firstName = firstName, lastName = lastName, localName = name)
                    } else {
                        patient
                    }
                }
            }
            persistDemoClinic()
            return
        }
        identityStore.save(patientId, name)
        _patients.update { list ->
            list.map { patient ->
                if (patient.id.queryValue == patientId.queryValue) {
                    patient.copy(firstName = firstName, lastName = lastName, localName = name)
                } else {
                    patient
                }
            }
        }
    }

    suspend fun deletePatient(patientId: DatabaseId) {
        if (DemoData.isDemoId(patientId) || _isDemoMode.value) {
            _patients.update { it.filterNot { patient -> patient.id.queryValue == patientId.queryValue } }
            _questionnaires.update { it - patientId.queryValue }
            demoClinicStore.deletePreparation(patientId.queryValue)
            demoClinicStore.deleteName(patientId)
            persistDemoClinic()
            return
        }
        ensureConfigured()
        cacheLock.withLock {
            val deleted = client.from("Patients").delete {
                filter { eq("id", patientId.queryValue) }
                select(Columns.raw("id"))
            }.decodeList<InsertedRow>()
            if (deleted.isEmpty()) throw PatientStoreException(PatientStoreException.Kind.UpdateRejected)
            runCatching { identityStore.delete(patientId) }
            _patients.update { it.filterNot { patient -> patient.id.queryValue == patientId.queryValue } }
            _questionnaires.update { it - patientId.queryValue }
            cache.deletePreparation(patientId.queryValue)
            persistCache()
        }
    }

    suspend fun addSession(patientId: DatabaseId, session: Session) {
        if (DemoData.isDemoId(patientId) || _isDemoMode.value) {
            val notes = textGate.prepare(session.notes)
            val analysis = anonymizedAnalysis(session.structuredNotes)
            val saved = session.copy(
                databaseId = session.databaseId ?: DatabaseId.Text("demo-session-${session.id}"),
                notes = notes.orEmpty(),
                structuredNotes = analysis,
            )
            _patients.update { list ->
                list.map { patient ->
                    if (patient.id.queryValue == patientId.queryValue) {
                        patient.copy(sessions = (patient.sessions + saved).sortedBy { it.date })
                    } else {
                        patient
                    }
                }
            }
            persistDemoClinic()
            return
        }
        ensureConfigured()
        val notes = textGate.prepare(session.notes)
        val analysis = anonymizedAnalysis(session.structuredNotes)
        val inserted = client.from("Sessions")
            .insert(sessionWriteBody(session.date, notes, session.type, patientId, analysis)) {
                select(Columns.raw("id"))
            }
            .decodeSingle<InsertedRow>()
        val saved = session.copy(databaseId = inserted.id, notes = notes.orEmpty(), structuredNotes = analysis)
        _patients.update { list ->
            list.map { patient ->
                if (patient.id.queryValue == patientId.queryValue) {
                    patient.copy(sessions = (patient.sessions + saved).sortedBy { it.date })
                } else {
                    patient
                }
            }
        }
        persistCache()
    }

    suspend fun updateSession(session: Session) {
        if (_isDemoMode.value || session.databaseId?.let { DemoData.isDemoId(it) } == true) {
            textGate.markSafe(session.notes)
            markAnalysisSafe(session.structuredNotes)
            val sessionId = session.databaseId
            _patients.update { list ->
                list.map { patient ->
                    patient.copy(
                        sessions = patient.sessions
                            .map {
                                if (it.id == session.id ||
                                    (sessionId != null && it.databaseId?.queryValue == sessionId.queryValue)
                                ) {
                                    session
                                } else {
                                    it
                                }
                            }
                            .sortedBy { it.date },
                    )
                }
            }
            persistDemoClinic()
            return
        }
        ensureConfigured()
        val sessionId = session.databaseId
            ?: throw PatientStoreException(PatientStoreException.Kind.SessionNotSaved)
        val notes = textGate.prepare(session.notes)
        val analysis = anonymizedAnalysis(session.structuredNotes)
        val updated = client.from("Sessions")
            .update(sessionWriteBody(session.date, notes, session.type, analysis = analysis)) {
                filter { eq("id", sessionId.queryValue) }
                select(Columns.raw("id"))
            }
            .decodeList<InsertedRow>()
        if (updated.isEmpty()) throw PatientStoreException(PatientStoreException.Kind.UpdateRejected)
        val saved = session.copy(notes = notes.orEmpty(), structuredNotes = analysis)
        _patients.update { list ->
            list.map { patient ->
                patient.copy(
                    sessions = patient.sessions
                        .map { if (it.id == session.id || it.databaseId?.queryValue == sessionId.queryValue) saved else it }
                        .sortedBy { it.date },
                )
            }
        }
        persistCache()
    }

    suspend fun deleteSession(session: Session) {
        val patient = _patients.value.find { p ->
            p.sessions.any { it.id == session.id || it.databaseId?.queryValue == session.databaseId?.queryValue }
        }
        if (patient != null && (DemoData.isDemoId(patient.id) || _isDemoMode.value)) {
            val sessionId = session.databaseId
            _patients.update { list ->
                list.map { p ->
                    p.copy(
                        sessions = p.sessions.filterNot { existing ->
                            existing.id == session.id ||
                                existing.databaseId?.queryValue == sessionId?.queryValue
                        },
                    )
                }
            }
            if (sessionId != null) {
                _questionnaires.update { cached ->
                    cached.mapValues { (_, records) ->
                        records.filterNot { it.sessionId?.queryValue == sessionId.queryValue }
                    }
                }
            }
            persistDemoClinic()
            return
        }
        ensureConfigured()
        val sessionId = session.databaseId
            ?: throw PatientStoreException(PatientStoreException.Kind.SessionNotSaved)
        cacheLock.withLock {
            val deleted = client.from("Sessions").delete {
                filter { eq("id", sessionId.queryValue) }
                select(Columns.raw("id"))
            }.decodeList<InsertedRow>()
            if (deleted.isEmpty()) throw PatientStoreException(PatientStoreException.Kind.UpdateRejected)
            _patients.update { list ->
                list.map { patient ->
                    patient.copy(
                        sessions = patient.sessions.filterNot { existing ->
                            existing.id == session.id ||
                                existing.databaseId?.queryValue == sessionId.queryValue
                        },
                    )
                }
            }
            _questionnaires.update { cached ->
                cached.mapValues { (_, records) ->
                    records.filterNot { it.sessionId?.queryValue == sessionId.queryValue }
                }
            }
            persistCache()
        }
    }

    suspend fun anonymizedText(text: String): String = textGate.prepare(text).orEmpty()

    suspend fun transcribeAudio(file: File): String = whisper.transcribe(file)

    fun registerAIAnalysis(analysis: CBTSessionAnalysis) = markAnalysisSafe(analysis)

    suspend fun analyzeSessionNotes(notes: String): CBTSessionAnalysis = ai.analyzeSession(notes)

    suspend fun prepareNextSession(patientId: DatabaseId): SavedPreparation {
        val patient = patient(patientId.queryValue)
            ?: throw PatientStoreException(PatientStoreException.Kind.PatientNotSaved)
        val questionnaires = cachedQuestionnaires(patientId.queryValue) ?: loadQuestionnaires(patientId)
        val context = PatientContext.make(patient, questionnaires)
        val assignments = PatientContext.lastSessionAssignments(patient)
        val preparation = ai.prepareNextSession(context, assignments)
        return if (_isDemoMode.value || DemoData.isDemoId(patientId)) {
            demoClinicStore.savePreparation(patientId.queryValue, preparation)
        } else {
            cache.savePreparation(patientId.queryValue, preparation)
        }
    }

    fun loadPreparation(patientId: String): SavedPreparation? =
        if (_isDemoMode.value || DemoData.isDemoId(DatabaseId.Text(patientId))) {
            demoClinicStore.loadPreparation(patientId)
        } else {
            cache.loadPreparation(patientId)
        }

    suspend fun chat(systemPrompt: String, turns: List<ChatTurn>): String = ai.chat(systemPrompt, turns)

    suspend fun updatePatientNotes(patientId: DatabaseId, notes: String) {
        if (DemoData.isDemoId(patientId) || _isDemoMode.value) {
            val prepared = textGate.prepare(notes)
            _patients.update { list ->
                list.map {
                    if (it.id.queryValue == patientId.queryValue) it.copy(notes = prepared.orEmpty()) else it
                }
            }
            persistDemoClinic()
            return
        }
        ensureConfigured()
        val prepared = textGate.prepare(notes)
        val updated = client.from("Patients")
            .update(buildJsonObject {
                if (prepared == null) put("notes", JsonNull) else put("notes", JsonPrimitive(prepared))
            }) {
                filter { eq("id", patientId.queryValue) }
                select(Columns.raw("id"))
            }
            .decodeList<InsertedRow>()
        if (updated.isEmpty()) throw PatientStoreException(PatientStoreException.Kind.UpdateRejected)
        _patients.update { list ->
            list.map {
                if (it.id.queryValue == patientId.queryValue) it.copy(notes = prepared.orEmpty()) else it
            }
        }
        persistCache()
    }

    suspend fun updatePatientStatus(patientId: DatabaseId, status: PatientStatus) {
        if (DemoData.isDemoId(patientId) || _isDemoMode.value) {
            _patients.update { list ->
                list.map {
                    if (it.id.queryValue == patientId.queryValue) it.copy(status = status) else it
                }
            }
            persistDemoClinic()
            return
        }
        ensureConfigured()
        val updated = client.from("Patients")
            .update(buildJsonObject {
                put("active", JsonPrimitive(status.storageActive))
            }) {
                filter { eq("id", patientId.queryValue) }
                select(Columns.raw("id"))
            }
            .decodeList<InsertedRow>()
        if (updated.isEmpty()) throw PatientStoreException(PatientStoreException.Kind.UpdateRejected)
        _patients.update { list ->
            list.map {
                if (it.id.queryValue == patientId.queryValue) it.copy(status = status) else it
            }
        }
        persistCache()
    }

    suspend fun saveFormulation(patientId: DatabaseId, formulation: PatientFormulation) {
        if (DemoData.isDemoId(patientId) || _isDemoMode.value) {
            val anonymized = anonymizedFormulation(formulation)
            markFormulationSafe(anonymized)
            _patients.update { list ->
                list.map {
                    if (it.id.queryValue == patientId.queryValue) it.copy(formulation = anonymized) else it
                }
            }
            persistDemoClinic()
            return
        }
        ensureConfigured()
        val anonymized = anonymizedFormulation(formulation)
        val updated = client.from("Patients")
            .update(buildJsonObject {
                put("formulation", json.encodeToJsonElement(PatientFormulation.serializer(), anonymized))
            }) {
                filter { eq("id", patientId.queryValue) }
                select(Columns.raw("id"))
            }
            .decodeList<InsertedRow>()
        if (updated.isEmpty()) throw PatientStoreException(PatientStoreException.Kind.UpdateRejected)
        _patients.update { list ->
            list.map {
                if (it.id.queryValue == patientId.queryValue) it.copy(formulation = anonymized) else it
            }
        }
        persistCache()
    }

    suspend fun challengeFormulation(patientId: DatabaseId): FormulationSupervision {
        val patient = patient(patientId.queryValue)
            ?: throw PatientStoreException(PatientStoreException.Kind.PatientNotSaved)
        val formulation = patient.formulation ?: PatientFormulation()
        if (!formulation.hasContent()) throw AiException("invalid_input")
        val questionnaires = cachedQuestionnaires(patientId.queryValue) ?: loadQuestionnaires(patientId)
        return ai.challengeFormulation(PatientContext.make(patient, questionnaires), formulation)
    }

    suspend fun whatAmIMissing(patientId: DatabaseId): WhatAmIMissingResponse {
        val patient = patient(patientId.queryValue)
            ?: throw PatientStoreException(PatientStoreException.Kind.PatientNotSaved)
        val questionnaires = cachedQuestionnaires(patientId.queryValue) ?: loadQuestionnaires(patientId)
        return ai.whatAmIMissing(PatientContext.make(patient, questionnaires))
    }

    suspend fun longitudinalCaseReview(patientId: DatabaseId): LongitudinalCaseReviewResponse {
        val patient = patient(patientId.queryValue)
            ?: throw PatientStoreException(PatientStoreException.Kind.PatientNotSaved)
        val questionnaires = cachedQuestionnaires(patientId.queryValue) ?: loadQuestionnaires(patientId)
        return ai.longitudinalCaseReview(PatientContext.make(patient, questionnaires))
    }

    fun cachedQuestionnaires(patientId: String): List<CompletedQuestionnaire>? = _questionnaires.value[patientId]

    suspend fun loadQuestionnaires(patientId: DatabaseId): List<CompletedQuestionnaire> {
        if (_isDemoMode.value || DemoData.isDemoId(patientId)) {
            return _questionnaires.value[patientId.queryValue].orEmpty()
        }
        ensureConfigured()
        val rows = client.from(CombinedMoodQuestionnaire.TABLE)
            .select(Columns.raw("id, session_id, answered_date, gad7_answers, phq9_answers, interference_level, combined_notes")) {
                filter { eq("patient_id", patientId.queryValue) }
                order("answered_date", Order.DESCENDING)
            }
            .decodeList<QuestionnaireDbRow>()
        val loaded = rows.map { row ->
            val questionnaire = CombinedMoodQuestionnaire(
                gad7Answers = paddedAnswers(row.gad7Answers, CombinedMoodQuestionnaire.GAD7_COUNT),
                phq9Answers = paddedAnswers(row.phq9Answers, CombinedMoodQuestionnaire.PHQ9_COUNT),
                interferenceLevel = row.interferenceLevel,
                gad7Notes = paddedNotes(row.combinedNotes?.gad7, CombinedMoodQuestionnaire.GAD7_COUNT),
                phq9Notes = paddedNotes(row.combinedNotes?.phq9, CombinedMoodQuestionnaire.PHQ9_COUNT),
                interferenceNote = row.combinedNotes?.interference.orEmpty(),
            )
            questionnaire.gad7Notes.forEach { textGate.markSafe(it) }
            questionnaire.phq9Notes.forEach { textGate.markSafe(it) }
            textGate.markSafe(questionnaire.interferenceNote)
            CompletedQuestionnaire(
                databaseId = row.id,
                sessionId = row.sessionId,
                answeredDate = row.answeredDate?.let(::parseDate) ?: Date(),
                questionnaire = questionnaire,
            )
        }
        _questionnaires.update { it + (patientId.queryValue to loaded) }
        persistCache()
        return loaded
    }

    suspend fun saveQuestionnaire(
        questionnaire: CombinedMoodQuestionnaire,
        patientId: DatabaseId,
        session: Session,
    ) {
        if (DemoData.isDemoId(patientId) || _isDemoMode.value) {
            val sessionId = session.databaseId
                ?: throw PatientStoreException(PatientStoreException.Kind.SessionNotSaved)
            val completed = CompletedQuestionnaire(
                databaseId = DatabaseId.Text("demo-q-${UUID.randomUUID()}"),
                sessionId = sessionId,
                answeredDate = session.date,
                questionnaire = questionnaire,
            )
            _questionnaires.update { cache ->
                val current = cache[patientId.queryValue].orEmpty()
                    .filterNot { it.sessionId?.queryValue == sessionId.queryValue } + completed
                cache + (patientId.queryValue to current.sortedByDescending { it.answeredDate.time })
            }
            persistDemoClinic()
            return
        }
        ensureConfigured()
        val sessionId = session.databaseId
            ?: throw PatientStoreException(PatientStoreException.Kind.SessionNotSaved)
        val gad7Notes = textGate.prepare(questionnaire.gad7Notes)
        val phq9Notes = textGate.prepare(questionnaire.phq9Notes)
        val interferenceNote = textGate.prepare(questionnaire.interferenceNote).orEmpty()
        val anonymized = questionnaire.copy(
            gad7Notes = gad7Notes,
            phq9Notes = phq9Notes,
            interferenceNote = interferenceNote,
        )
        val saved = client.from(CombinedMoodQuestionnaire.TABLE)
            .upsert(
                NewQuestionnaireRecord(
                    patientId = patientId,
                    sessionId = sessionId,
                    answeredDate = dateOnly.format(session.date),
                    gad7Answers = anonymized.gad7Answers.mapNotNull { it },
                    phq9Answers = anonymized.phq9Answers.mapNotNull { it },
                    interferenceLevel = anonymized.interferenceLevel,
                    combinedNotes = QuestionnaireNotes(
                        gad7 = anonymized.gad7Notes,
                        phq9 = anonymized.phq9Notes,
                        interference = anonymized.interferenceNote,
                    ),
                ),
            ) {
                onConflict = "session_id"
                select(Columns.raw("id"))
            }
            .decodeSingle<InsertedRow>()
        val completed = CompletedQuestionnaire(
            databaseId = saved.id,
            sessionId = sessionId,
            answeredDate = session.date,
            questionnaire = anonymized,
        )
        _questionnaires.update { cache ->
            val current = cache[patientId.queryValue].orEmpty()
                .filterNot { it.sessionId?.queryValue == sessionId.queryValue } + completed
            cache + (patientId.queryValue to current.sortedByDescending { it.answeredDate.time })
        }
        persistCache()
    }

    suspend fun deleteQuestionnaire(patientId: DatabaseId, session: Session) {
        if (DemoData.isDemoId(patientId) || _isDemoMode.value) {
            val sessionId = session.databaseId
                ?: throw PatientStoreException(PatientStoreException.Kind.SessionNotSaved)
            _questionnaires.update { cache ->
                val current = cache[patientId.queryValue].orEmpty()
                    .filterNot { it.sessionId?.queryValue == sessionId.queryValue }
                cache + (patientId.queryValue to current)
            }
            persistDemoClinic()
            return
        }
        ensureConfigured()
        val sessionId = session.databaseId
            ?: throw PatientStoreException(PatientStoreException.Kind.SessionNotSaved)
        val deleted = client.from(CombinedMoodQuestionnaire.TABLE).delete {
            filter { eq("session_id", sessionId.queryValue) }
            select(Columns.raw("id"))
        }.decodeList<InsertedRow>()
        if (deleted.isEmpty()) throw PatientStoreException(PatientStoreException.Kind.UpdateRejected)
        _questionnaires.update { cache ->
            val current = cache[patientId.queryValue].orEmpty()
                .filterNot { it.sessionId?.queryValue == sessionId.queryValue }
            cache + (patientId.queryValue to current)
        }
        persistCache()
    }

    fun patient(id: String): Patient? = _patients.value.find { it.id.queryValue == id }

    fun session(patientId: String, sessionId: String): Session? =
        patient(patientId)?.sessions?.find { it.id.toString() == sessionId || it.databaseId?.queryValue == sessionId }

    fun clearAllCaches() {
        cache.clear()
        _patients.value = emptyList()
        _questionnaires.value = emptyMap()
    }

    fun wipeLocalData() {
        if (_isDemoMode.value) {
            demoClinicStore.clearAll()
            _isDemoMode.value = false
            aiConsentStore.setDemoBypass(false)
            _showcaseDataLoaded.value = false
        }
        _patients.value.forEach { patient ->
            runCatching { identityStore.delete(patient.id) }
            cache.deletePreparation(patient.id.queryValue)
        }
        identityStore.clearAll()
        clearAllCaches()
        demoClinicStore.clearAll()
    }

    private fun ensureConfigured() {
        if (!SupabaseConfig.isConfigured) {
            throw PatientStoreException(PatientStoreException.Kind.NotConfigured)
        }
    }

    private fun sessionWriteBody(
        date: Date,
        notes: String?,
        type: SessionType?,
        patientId: DatabaseId? = null,
        analysis: CBTSessionAnalysis? = null,
    ) = buildJsonObject {
        if (patientId != null) put("patient_id", patientId.toJsonElement())
        put("session_date", JsonPrimitive(dateOnly.format(date)))
        if (notes != null) put("notes", JsonPrimitive(notes))
        put(
            "type",
            if (type == null) JsonNull else json.encodeToJsonElement(SessionType.serializer(), type),
        )
        if (analysis != null) {
            put("structured_notes", json.encodeToJsonElement(CBTSessionAnalysis.serializer(), analysis))
        }
    }

    private fun DatabaseId.toJsonElement(): JsonElement = when (this) {
        is DatabaseId.Integer -> JsonPrimitive(value)
        is DatabaseId.Text -> JsonPrimitive(value)
    }

    private fun parseDate(raw: String): Date {
        dateOnly.parse(raw)?.let { return it }
        isoFractional.parse(raw)?.let { return it }
        iso.parse(raw)?.let { return it }
        return Date()
    }

    private fun decodeAnalysis(raw: JsonElement?): CBTSessionAnalysis? {
        if (raw == null || raw is JsonNull) return null
        return runCatching { json.decodeFromJsonElement(CBTSessionAnalysis.serializer(), raw) }.getOrNull()
    }

    private fun markAnalysisSafe(analysis: CBTSessionAnalysis?) {
        if (analysis == null) return
        textGate.markSafe(analysis.sessionSummary)
        analysis.keySituations.forEach {
            textGate.markSafe(it.situation)
            textGate.markSafe(it.whyItMatters)
        }
        analysis.possibleNats.forEach {
            textGate.markSafe(it.thought)
            textGate.markSafe(it.situation)
            textGate.markSafe(it.emotion)
            textGate.markSafe(it.behavior)
        }
        analysis.followUpQuestions.forEach {
            textGate.markSafe(it.question)
            textGate.markSafe(it.reason)
        }
    }

    private suspend fun anonymizedAnalysis(analysis: CBTSessionAnalysis?): CBTSessionAnalysis? {
        if (analysis == null) return null
        return analysis.copy(
            sessionSummary = textGate.prepare(analysis.sessionSummary).orEmpty(),
            keySituations = analysis.keySituations.map {
                it.copy(
                    situation = textGate.prepare(it.situation).orEmpty(),
                    whyItMatters = textGate.prepare(it.whyItMatters).orEmpty(),
                )
            },
            possibleNats = analysis.possibleNats.map {
                it.copy(
                    thought = textGate.prepare(it.thought).orEmpty(),
                    situation = textGate.prepare(it.situation).orEmpty(),
                    emotion = textGate.prepare(it.emotion.orEmpty()),
                    behavior = textGate.prepare(it.behavior.orEmpty()),
                )
            },
            followUpQuestions = analysis.followUpQuestions.map {
                it.copy(
                    question = textGate.prepare(it.question).orEmpty(),
                    reason = textGate.prepare(it.reason).orEmpty(),
                )
            },
        )
    }

    private fun decodeFormulation(raw: JsonElement?): PatientFormulation? {
        if (raw == null || raw is JsonNull) return null
        return runCatching { json.decodeFromJsonElement(PatientFormulation.serializer(), raw) }.getOrNull()
    }

    private fun markFormulationSafe(formulation: PatientFormulation?) {
        if (formulation == null) return
        textGate.markSafe(formulation.treatmentGoal)
        textGate.markSafe(formulation.coreBelief)
        formulation.keyAutomaticThoughts.forEach { textGate.markSafe(it) }
        formulation.maintainingBehaviors.forEach { textGate.markSafe(it) }
        textGate.markSafe(formulation.therapistHypothesis)
        formulation.keyCBTCycle?.let { cycle ->
            textGate.markSafe(cycle.triggerSituation)
            textGate.markSafe(cycle.automaticThought)
            textGate.markSafe(cycle.emotion)
            textGate.markSafe(cycle.behavior)
            textGate.markSafe(cycle.shortTermConsequence)
            textGate.markSafe(cycle.longTermConsequence)
            textGate.markSafe(cycle.evidence)
        }
    }

    private suspend fun anonymizedFormulation(formulation: PatientFormulation): PatientFormulation {
        val cycle = formulation.keyCBTCycle
        return formulation.copy(
            treatmentGoal = textGate.prepare(formulation.treatmentGoal.orEmpty()),
            coreBelief = textGate.prepare(formulation.coreBelief.orEmpty()),
            keyAutomaticThoughts = textGate.prepare(formulation.keyAutomaticThoughts),
            maintainingBehaviors = textGate.prepare(formulation.maintainingBehaviors),
            therapistHypothesis = textGate.prepare(formulation.therapistHypothesis.orEmpty()),
            keyCBTCycle = cycle?.copy(
                triggerSituation = textGate.prepare(cycle.triggerSituation.orEmpty()),
                automaticThought = textGate.prepare(cycle.automaticThought.orEmpty()),
                emotion = textGate.prepare(cycle.emotion.orEmpty()),
                behavior = textGate.prepare(cycle.behavior.orEmpty()),
                shortTermConsequence = textGate.prepare(cycle.shortTermConsequence.orEmpty()),
                longTermConsequence = textGate.prepare(cycle.longTermConsequence.orEmpty()),
                evidence = textGate.prepare(cycle.evidence).orEmpty(),
            ),
        )
    }

    companion object {
        private val json = Json { encodeDefaults = true; ignoreUnknownKeys = true }
        private val dateOnly = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
        private val isoFractional = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US)
        private val iso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US)

        fun paddedNotes(values: List<String>?, count: Int): List<String> {
            val result = (values ?: emptyList()).toMutableList()
            while (result.size > count) result.removeAt(result.lastIndex)
            while (result.size < count) result.add("")
            return result
        }

        fun paddedAnswers(values: List<Int>?, count: Int): List<Int?> {
            val result = (values ?: emptyList()).map<Int, Int?> { it }.toMutableList()
            while (result.size > count) result.removeAt(result.lastIndex)
            while (result.size < count) result.add(null)
            return result
        }
    }
}

@Serializable
private data class InsertedRow(val id: DatabaseId)

@Serializable
private data class NewPatientRecord(val active: Boolean)

@Serializable
private data class PatientRow(
    val id: DatabaseId,
    val active: Boolean? = null,
    val notes: String? = null,
    val formulation: JsonElement? = null,
)

@Serializable
private data class SessionRow(
    val id: DatabaseId,
    @SerialName("patient_id") val patientId: DatabaseId,
    @SerialName("session_date") val sessionDate: String,
    val notes: String? = null,
    @SerialName("type") val sessionType: SessionType? = null,
    @SerialName("structured_notes") val structuredNotes: JsonElement? = null,
)

@Serializable
private data class NewQuestionnaireRecord(
    @SerialName("patient_id") val patientId: DatabaseId,
    @SerialName("session_id") val sessionId: DatabaseId,
    @SerialName("answered_date") val answeredDate: String,
    @SerialName("gad7_answers") val gad7Answers: List<Int>,
    @SerialName("phq9_answers") val phq9Answers: List<Int>,
    @SerialName("interference_level") val interferenceLevel: Int? = null,
    @SerialName("combined_notes") val combinedNotes: QuestionnaireNotes,
)

@Serializable
private data class QuestionnaireDbRow(
    val id: DatabaseId,
    @SerialName("session_id") val sessionId: DatabaseId? = null,
    @SerialName("answered_date") val answeredDate: String? = null,
    @SerialName("gad7_answers") val gad7Answers: List<Int>? = null,
    @SerialName("phq9_answers") val phq9Answers: List<Int>? = null,
    @SerialName("interference_level") val interferenceLevel: Int? = null,
    @SerialName("combined_notes") val combinedNotes: QuestionnaireNotes? = null,
)
