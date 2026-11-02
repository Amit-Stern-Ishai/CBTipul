package com.cbtipul.app.data

import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import kotlinx.coroutines.CancellationException
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.contentOrNull

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
import kotlinx.coroutines.launch
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
    val nameSync: PatientNameSync,
    private val nameScope: kotlinx.coroutines.CoroutineScope,
    private val cache: PatientCache,
    private val textGate: ClinicalTextGate,
    private val whisper: WhisperService,
    private val ai: AiService,
    private val demoClinicStore: DemoClinicStore,
    private val aiConsentStore: AiConsentStore,
    private val resetDemoContent: (List<Patient>) -> Unit = {},
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

    init {
        nameSync.changed = {
            if (!_isDemoMode.value) _patients.update { list -> list.map { it.copy(localName = identityStore.name(it.id)) } }
        }
    }
    private fun scheduleNameSync() {
        if (_isDemoMode.value) return
        nameSync.register(_patients.value.associate { it.id.queryValue to identityStore.legacyName(it.id) })
        nameSync.changed?.invoke()
        nameScope.launch { nameSync.refresh(true) }
    }

    fun loadCachedPatients() {
        if (_isDemoMode.value) return
        if (_patients.value.isNotEmpty()) return
        val cached = cache.load() ?: return
        _patients.value = cached.patients.map { patient ->
            patient.copy(localName = identityStore.name(patient.id))
        }
        _questionnaires.value = cached.questionnaires
    }

    private fun persistCache() {
        if (_isDemoMode.value) {
            persistDemoClinic()
            return
        }
        cache.save(_patients.value, _questionnaires.value)
    }

    /** Start a fresh local sample clinic on every entry. */
    fun enterDemoMode() {
        if (_isDemoMode.value) return
        Entitlements.setLocalDemo(true)
        _isDemoMode.value = true
        com.cbtipul.app.telemetry.Telemetry.client.setDemo(true)
        aiConsentStore.setDemoBypass(true)
        _showcaseDataLoaded.value = false
        _patients.value = emptyList()
        _questionnaires.value = emptyMap()
        // Read legacy patient/session IDs only to remove old demo draft keys.
        demoClinicStore.loadClinic()?.let { applyTutorialOnlySnapshot(it) }
        resetDemoContent(_patients.value)
        demoClinicStore.clearAll()
        _patients.value = emptyList()
        _questionnaires.value = emptyMap()
        loadShowcaseDemoData()
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
        resetDemoContent(_patients.value)
        demoClinicStore.clearAll()
        Entitlements.setLocalDemo(false)
        _isDemoMode.value = false
        com.cbtipul.app.telemetry.Telemetry.client.setDemo(false)
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
        val snapshot = demoClinicStore.snapshotFrom(_patients.value, _questionnaires.value).copy(includesSampleData = _showcaseDataLoaded.value)
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
            patients = snapshot.patients.filter { DemoData.isDemoId(it.id) },
            questionnairesByPatient = snapshot.questionnairesByPatient.filterKeys { key ->
                DemoData.isDemoId(DatabaseId.Text(key))
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

    /** Original storage text; AI input is protected separately. */
    suspend fun prepareSummaryForStorage(text: String, patientNotes: Boolean = false): String = text
    private suspend fun saveEncrypted(endpoint: String, previous: JsonObject?, id: DatabaseId? = null, changes: JsonObject): JsonObject {
        if(id != null && previous?.get("id")?.jsonPrimitive?.content != id.queryValue) throw SummaryFailure(SummaryFailure.Kind.Conflict)
        val owner = client.auth.currentUserOrNull()?.id ?: throw CancellationException()
        val epoch = clinicalLoadEpoch
        fun checkpoint() { if(owner != client.auth.currentUserOrNull()?.id || epoch != clinicalLoadEpoch || _isDemoMode.value) throw CancellationException() }
        return ClinicalRecordSave.save(previous, changes, ::checkpoint) { body ->
            json.decodeFromString<JsonObject>(client.functions.invoke(endpoint, body = body, headers = PatientNameSync.jsonHeaders()).bodyAsText())
        }
    }
    private fun applyEncryptedPatient(record: JsonObject) {
        val row = json.decodeFromJsonElement<PatientRow>(record)
        _patients.update { list -> list.map { if(it.id == row.id) it.copy(notes = row.notes.orEmpty(), formulation = decodeFormulation(row.formulation), status = PatientStatus.fromActive(row.active), loadedClinicalRecord = record) else it } }
        persistCache()
    }
    private suspend fun saveEncryptedSession(session: Session, patientId: DatabaseId? = null, beforeInsert: (String) -> Unit = {}) {
        if (patientId != null && session.type == null) throw SummaryFailure(SummaryFailure.Kind.Validation)
        val changes = sessionWriteBody(session.date, session.notes, session.type, patientId).toMutableMap()
        session.loadedClinicalRecord?.let { baseline ->
            val row = json.decodeFromJsonElement<SessionRow>(baseline)
            if(session.type == row.sessionType) changes.remove("type")
            if(dateOnly.format(session.date) == dateOnly.format(parseDate(row.sessionDate))) changes.remove("session_date")
        }
        if(session.loadedClinicalRecord != null && session.notes == (session.loadedClinicalRecord["notes"] as? JsonPrimitive)?.contentOrNull.orEmpty()) changes.remove("notes")
        val analysis = session.structuredNotes?.let { json.encodeToJsonElement(CBTSessionAnalysis.serializer(), it) } ?: JsonNull
        if(session.structuredNotes != decodeAnalysis(session.loadedClinicalRecord?.get("structured_notes"))) changes["structured_notes"] = analysis
        beforeInsert(session.notes)
        val record = saveEncrypted("save-session", session.loadedClinicalRecord, if(patientId == null) session.databaseId else null, JsonObject(changes))
        val row = json.decodeFromJsonElement<SessionRow>(record)
        val saved = session.copy(databaseId = row.id, date = parseDate(row.sessionDate), notes = row.notes.orEmpty(), type = row.sessionType, structuredNotes = decodeAnalysis(row.structuredNotes), loadedClinicalRecord = record)
        _patients.update { list -> list.map { patient -> if(patient.id == row.patientId) patient.copy(sessions = (patient.sessions.filterNot { it.databaseId == row.id || it.id == session.id } + saved).sortedBy { it.date }) else patient } }
        persistCache()
    }

    private var clinicalLoadEpoch = UUID.randomUUID()
    private suspend fun loadClinical(endpoint: String, patientId: String? = null): List<JsonObject> {
        val owner = client.auth.currentUserOrNull()?.id ?: throw CancellationException()
        val epoch = clinicalLoadEpoch
        return ClinicalRecordLoad.pages(endpoint,
            buildJsonObject { patientId?.let { put("patient_id", JsonPrimitive(it.lowercase())) } },
            checkpoint = {
                if (owner != client.auth.currentUserOrNull()?.id || epoch != clinicalLoadEpoch || _isDemoMode.value) throw CancellationException()
            }, invoke = { name, body ->
                json.decodeFromString<JsonObject>(client.functions.invoke(name, body = body, headers = PatientNameSync.jsonHeaders()).bodyAsText())
            })
    }

    private suspend fun loadPatientsLocked() {
        val nameOwner = nameSync.account
        val epoch = clinicalLoadEpoch
        val patientRecords = loadClinical("load-patients")
        val sessionRecords = loadClinical("load-sessions")
        if (epoch != clinicalLoadEpoch) throw CancellationException()
        val patientRows = patientRecords.map { json.decodeFromJsonElement<PatientRow>(it) }
        val sessionRows = sessionRecords.map { json.decodeFromJsonElement<SessionRow>(it) }
        val patientSnapshots = patientRecords.associateBy { it.getValue("id").jsonPrimitive.content }
        val sessionSnapshots = sessionRecords.associateBy { it.getValue("id").jsonPrimitive.content }
        if (_isDemoMode.value || nameOwner != nameSync.account) return

        val sessionsByPatient = sessionRows.groupBy { it.patientId.queryValue }
        val existing = _patients.value
        val loaded = patientRows.map { row ->
            val current = existing.find { it.id.queryValue == row.id.queryValue }
            val sessions = (sessionsByPatient[row.id.queryValue] ?: emptyList())
                .map { sessionRow ->
                    val existingSession = current?.sessions?.find {
                        it.databaseId?.queryValue == sessionRow.id.queryValue
                    }
                    Session(
                        id = existingSession?.id ?: UUID.randomUUID(),
                        databaseId = sessionRow.id,
                        date = parseDate(sessionRow.sessionDate),
                        notes = sessionRow.notes.orEmpty(),
                        loadedClinicalRecord = sessionSnapshots[sessionRow.id.queryValue],
                        type = sessionRow.sessionType,
                        structuredNotes = decodeAnalysis(sessionRow.structuredNotes),
                    )
                }
                .sortedBy { it.date }
            val decodedFormulation = decodeFormulation(row.formulation)
            val patient = Patient(
                id = row.id,
                firstName = current?.firstName.orEmpty(),
                lastName = current?.lastName.orEmpty(),
                status = PatientStatus.fromActive(row.active),
                notes = row.notes.orEmpty(),
                loadedClinicalRecord = patientSnapshots[row.id.queryValue],
                sessions = sessions,
                formulation = decodedFormulation,
            )
            patient.copy(localName = identityStore.name(patient.id))
        }
        // Pending edits and confirmed account-scoped names take precedence over legacy values.
        _patients.value = loaded.map { it.copy(localName = identityStore.name(it.id)) }
        scheduleNameSync()
        persistCache()
    }

    suspend fun addPatient(firstName: String, lastName: String, status: PatientStatus) {
        Entitlements.requireWrite(localDemo = _isDemoMode.value)
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
        val enteredName = listOf(firstName, lastName).filter { it.isNotEmpty() }.joinToString(" ")
        if (!PatientNameRules.valid(enteredName)) throw NameSyncFailure("invalid_name")
        val nameOwner = nameSync.account
        val encryptedRecord = saveEncrypted("save-patient", null, changes = buildJsonObject { put("active", JsonPrimitive(status == PatientStatus.Active)) })
        val inserted = InsertedRow(DatabaseId.Text(encryptedRecord.getValue("id").jsonPrimitive.content))
        if (nameOwner != nameSync.account || _isDemoMode.value) return
        val patient = Patient(
            id = inserted.id,
            firstName = firstName,
            lastName = lastName,
            status = status,
        )
        runCatching { identityStore.save(patient.id, enteredName) }
        nameSync.rememberCreated(patient.id.queryValue, enteredName)
        val named = patient.copy(localName = identityStore.name(patient.id), loadedClinicalRecord = encryptedRecord)
        _patients.update { it + named }
        scheduleNameSync()
        persistCache()
    }

    fun renamePatient(patientId: DatabaseId, firstName: String, lastName: String) {
        Entitlements.requireWrite(localDemo = DemoData.isDemoId(patientId) || _isDemoMode.value)
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
        val exactName = listOf(firstName, lastName).filter { it.isNotEmpty() }.joinToString(" ")
        nameSync.edit(patientId.queryValue, exactName)
        _patients.update { list ->
            list.map { patient ->
                if (patient.id.queryValue == patientId.queryValue) {
                    patient.copy(firstName = firstName, lastName = lastName, localName = exactName)
                } else {
                    patient
                }
            }
        }
        persistCache()
    }

    suspend fun deletePatient(patientId: DatabaseId) {
        Entitlements.requireWrite(localDemo = DemoData.isDemoId(patientId) || _isDemoMode.value)
        if (DemoData.isDemoId(patientId) || _isDemoMode.value) {
            _patients.update { it.filterNot { patient -> patient.id.queryValue == patientId.queryValue } }
            _questionnaires.update { it - patientId.queryValue }
            demoClinicStore.deletePreparation(patientId.queryValue)
            demoClinicStore.deleteName(patientId)
            persistDemoClinic()
            return
        }
        ensureConfigured()
        val nameOwner = nameSync.account
        nameSync.beginDeletion(patientId.queryValue)
        var deletionConfirmed = false
        try {
        cacheLock.withLock {
            val deleted = client.from("Patients").delete {
                filter { eq("id", patientId.queryValue) }
                select(Columns.raw("id"))
            }.decodeList<InsertedRow>()
            if (deleted.isEmpty()) throw PatientStoreException(PatientStoreException.Kind.UpdateRejected)
            if (nameOwner != nameSync.account) return@withLock
            deletionConfirmed = true
            nameSync.remove(patientId.queryValue)
            runCatching { identityStore.delete(patientId) }
            _patients.update { it.filterNot { patient -> patient.id.queryValue == patientId.queryValue } }
            _questionnaires.update { it - patientId.queryValue }
            cache.deletePreparation(patientId.queryValue)
            persistCache()
        }
        } finally { if (!deletionConfirmed && nameOwner == nameSync.account) nameSync.cancelDeletion(patientId.queryValue) }
    }

    suspend fun addSession(patientId: DatabaseId, session: Session, preparedNotes: String? = null, beforeInsert: (String) -> Unit = {}) {
        Entitlements.requireWrite(localDemo = DemoData.isDemoId(patientId) || _isDemoMode.value)
        if (DemoData.isDemoId(patientId) || _isDemoMode.value) {
            // Sample edits stay local, just like updateSession in sample mode.
            textGate.markSafe(session.notes)
            markAnalysisSafe(session.structuredNotes)
            val saved = session.copy(
                databaseId = session.databaseId ?: DatabaseId.Text("demo-session-${session.id}"),
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
        saveEncryptedSession(session, patientId, beforeInsert)
    }

    suspend fun updateSession(session: Session, preparedNotes: String? = null) {
        Entitlements.requireWrite(localDemo = _isDemoMode.value || session.databaseId?.let { DemoData.isDemoId(it) } == true)
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
        saveEncryptedSession(session)
    }

    suspend fun deleteSession(session: Session) {
        val patient = _patients.value.find { p ->
            p.sessions.any { it.id == session.id || it.databaseId?.queryValue == session.databaseId?.queryValue }
        }
        Entitlements.requireWrite(localDemo = patient != null && (DemoData.isDemoId(patient.id) || _isDemoMode.value))
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

    suspend fun summaryAllowance(): SummaryAllowance {
        try {
            return client.postgrest.rpc("get_my_ai_allowance").decodeAs<SummaryAllowance>().also { it.validate() }
        } catch (error: kotlinx.coroutines.CancellationException) { throw error }
        catch (_: Exception) { throw SummaryFailure(SummaryFailure.Kind.Lookup) }
    }

    suspend fun anonymizedText(text: String): String = textGate.prepare(text).orEmpty()

    suspend fun transcribeAudio(file: File): String = whisper.transcribe(file)

    fun registerAIAnalysis(analysis: CBTSessionAnalysis) = markAnalysisSafe(analysis)

    suspend fun analyzeSessionNotes(notes: String): CBTSessionAnalysis = ai.analyzeSession(notes)

    suspend fun prepareNextSession(patientId: DatabaseId): SavedPreparation {
        Entitlements.requireWrite()
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

    suspend fun chat(patientId: DatabaseId, systemPrompt: String, turns: List<ChatTurn>): String {
        val unavailable = mutableListOf<String>()
        suspend fun <T> load(number: Int, operation: suspend () -> List<T>): List<T> = try {
            operation()
        } catch (error: kotlinx.coroutines.CancellationException) {
            throw error
        } catch (error: Exception) {
            unavailable += "Diary $number could not be loaded. Its history is unknown; do not infer that it is empty."
            emptyList()
        }
        val one = load(1) { DiaryOneRepository(client).loadEntries(patientId) }
        val two = load(2) { DiaryTwoRepository(client).loadEntries(patientId) }
        val three = load(3) { DiaryThreeRepository(client).loadEntries(patientId) }
        val diaries = diaryChatContext(one, two, three, unavailable)
        return ai.chat("$systemPrompt\n\n$diaries", turns)
    }

    suspend fun updatePatientNotes(patientId: DatabaseId, notes: String) {
        Entitlements.requireWrite(localDemo = DemoData.isDemoId(patientId) || _isDemoMode.value)
        if (DemoData.isDemoId(patientId) || _isDemoMode.value) {
            textGate.markSafe(notes)
            val prepared = notes
            _patients.update { list ->
                list.map {
                    if (it.id.queryValue == patientId.queryValue) it.copy(notes = prepared.orEmpty()) else it
                }
            }
            persistDemoClinic()
            return
        }
        ensureConfigured()

        val previous = _patients.value.firstOrNull { it.id == patientId }?.loadedClinicalRecord
        applyEncryptedPatient(saveEncrypted("save-patient", previous, patientId, buildJsonObject { put("notes", JsonPrimitive(notes)) }))
    }

    suspend fun updatePatientStatus(patientId: DatabaseId, status: PatientStatus) {
        Entitlements.requireWrite(localDemo = DemoData.isDemoId(patientId) || _isDemoMode.value)
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

        val previous = _patients.value.firstOrNull { it.id == patientId }?.loadedClinicalRecord
        applyEncryptedPatient(saveEncrypted("save-patient", previous, patientId, buildJsonObject { put("active", JsonPrimitive(status.storageActive)) }))
    }

    suspend fun saveFormulation(patientId: DatabaseId, formulation: PatientFormulation) {
        Entitlements.requireWrite(localDemo = DemoData.isDemoId(patientId) || _isDemoMode.value)
        if (DemoData.isDemoId(patientId) || _isDemoMode.value) {
            val anonymized = formulation
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

        val previous = _patients.value.firstOrNull { it.id == patientId }?.loadedClinicalRecord
        applyEncryptedPatient(saveEncrypted("save-patient", previous, patientId, buildJsonObject { put("formulation", json.encodeToJsonElement(PatientFormulation.serializer(), formulation)) }))
    }

    suspend fun challengeFormulation(patientId: DatabaseId): FormulationSupervision {
        Entitlements.requireWrite()
        val patient = patient(patientId.queryValue)
            ?: throw PatientStoreException(PatientStoreException.Kind.PatientNotSaved)
        val formulation = patient.formulation ?: PatientFormulation()
        if (!formulation.hasContent()) throw AiException("invalid_input")
        val questionnaires = cachedQuestionnaires(patientId.queryValue) ?: loadQuestionnaires(patientId)
        return ai.challengeFormulation(PatientContext.make(patient, questionnaires), formulation)
    }

    suspend fun whatAmIMissing(patientId: DatabaseId): WhatAmIMissingResponse {
        Entitlements.requireWrite()
        val patient = patient(patientId.queryValue)
            ?: throw PatientStoreException(PatientStoreException.Kind.PatientNotSaved)
        val questionnaires = cachedQuestionnaires(patientId.queryValue) ?: loadQuestionnaires(patientId)
        return ai.whatAmIMissing(PatientContext.make(patient, questionnaires))
    }

    suspend fun longitudinalCaseReview(patientId: DatabaseId): LongitudinalCaseReviewResponse {
        Entitlements.requireWrite()
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
        val records = loadClinical("load-questionnaires", patientId.queryValue)
        val rows = records.map { json.decodeFromJsonElement<QuestionnaireDbRow>(it) }
        val snapshots = records.associateBy { it.getValue("id").jsonPrimitive.content }
        val loaded = rows.map { row ->
            val questionnaire = CombinedMoodQuestionnaire(
                gad7Answers = paddedAnswers(row.gad7Answers, CombinedMoodQuestionnaire.GAD7_COUNT),
                phq9Answers = paddedAnswers(row.phq9Answers, CombinedMoodQuestionnaire.PHQ9_COUNT),
                interferenceLevel = row.interferenceLevel,
                gad7Notes = paddedNotes(row.combinedNotes?.gad7, CombinedMoodQuestionnaire.GAD7_COUNT),
                phq9Notes = paddedNotes(row.combinedNotes?.phq9, CombinedMoodQuestionnaire.PHQ9_COUNT),
                interferenceNote = row.combinedNotes?.interference.orEmpty(),
            )
            CompletedQuestionnaire(
                databaseId = row.id,
                sessionId = row.sessionId,
                answeredDate = row.answeredDate?.let(::parseDate) ?: Date(),
                questionnaire = questionnaire,
                createdBy = row.createdBy,
                loadedClinicalRecord = snapshots[row.id.queryValue],
            )
        }.sortedByDescending { it.answeredDate.time }
        if (_isDemoMode.value) return loaded
        _questionnaires.update { it + (patientId.queryValue to loaded) }
        persistCache()
        return loaded
    }

    suspend fun saveQuestionnaire(
        questionnaire: CombinedMoodQuestionnaire,
        patientId: DatabaseId,
        session: Session,
        recordId: DatabaseId? = null,
    ) {
        return com.cbtipul.app.telemetry.Telemetry.measure(com.cbtipul.app.telemetry.Flow.submission, form=com.cbtipul.app.telemetry.Form.questionnaire) {
            Entitlements.requireWrite(localDemo = DemoData.isDemoId(patientId) || _isDemoMode.value)
            if (_questionnaires.value[patientId.queryValue].orEmpty().any { (if (recordId != null) it.databaseId == recordId else session.databaseId != null && it.sessionId == session.databaseId) && it.createdBy == "patient" }) throw PatientStoreException(PatientStoreException.Kind.UpdateRejected)
            if (DemoData.isDemoId(patientId) || _isDemoMode.value) {
                val sessionId = session.databaseId
                val completed = CompletedQuestionnaire(
                    databaseId = recordId ?: DatabaseId.Text("demo-q-${UUID.randomUUID()}"),
                    sessionId = sessionId,
                    answeredDate = session.date,
                    questionnaire = questionnaire,
                )
                _questionnaires.update { cache ->
                    val current = cache[patientId.queryValue].orEmpty()
                        .filterNot { (recordId != null && it.databaseId == recordId) || (sessionId != null && it.sessionId?.queryValue == sessionId.queryValue) } + completed
                    cache + (patientId.queryValue to current.sortedByDescending { it.answeredDate.time })
                }
                persistDemoClinic()
                return@measure
            }
            ensureConfigured()

            val previous = _questionnaires.value[patientId.queryValue].orEmpty().firstOrNull { if(recordId != null) it.databaseId == recordId else session.databaseId != null && it.sessionId == session.databaseId }
            val existingId = recordId ?: previous?.databaseId
            val payload = NewQuestionnaireRecord(patientId, session.databaseId, dateOnly.format(session.date), questionnaire.gad7Answers.mapNotNull { it }, questionnaire.phq9Answers.mapNotNull { it }, questionnaire.interferenceLevel,
                QuestionnaireNotes(questionnaire.gad7Notes, questionnaire.phq9Notes, questionnaire.interferenceNote))
            val changes = json.encodeToJsonElement(NewQuestionnaireRecord.serializer(), payload).jsonObject.toMutableMap()
            // The nullable link is deliberate even when the encoder omits defaults.
            changes["session_id"] = session.databaseId?.let { JsonPrimitive(it.queryValue) } ?: JsonNull
            if(previous != null && previous.questionnaire.gad7Notes == questionnaire.gad7Notes && previous.questionnaire.phq9Notes == questionnaire.phq9Notes && previous.questionnaire.interferenceNote == questionnaire.interferenceNote) changes.remove("combined_notes")
            val record = saveEncrypted("save-questionnaire", previous?.loadedClinicalRecord, existingId, JsonObject(changes))
            val row = json.decodeFromJsonElement<QuestionnaireDbRow>(record)
            val value = CombinedMoodQuestionnaire(gad7Answers = paddedAnswers(row.gad7Answers, 7), phq9Answers = paddedAnswers(row.phq9Answers, 9), interferenceLevel = row.interferenceLevel,
                gad7Notes = paddedNotes(row.combinedNotes?.gad7, 7), phq9Notes = paddedNotes(row.combinedNotes?.phq9, 9), interferenceNote = row.combinedNotes?.interference.orEmpty())
            val completed = CompletedQuestionnaire(databaseId = row.id, sessionId = row.sessionId, answeredDate = row.answeredDate?.let(::parseDate) ?: session.date, questionnaire = value, createdBy = row.createdBy, loadedClinicalRecord = record)
            _questionnaires.update { cache -> cache + (patientId.queryValue to (cache[patientId.queryValue].orEmpty().filterNot { it.databaseId == row.id } + completed).sortedByDescending { it.answeredDate.time }) }
            persistCache(); return@measure

        }
    }

    suspend fun deleteQuestionnaire(patientId: DatabaseId, session: Session, recordId: DatabaseId? = null) {
        Entitlements.requireWrite(localDemo = DemoData.isDemoId(patientId) || _isDemoMode.value)
        if (_questionnaires.value[patientId.queryValue].orEmpty().any { (if (recordId != null) it.databaseId == recordId else session.databaseId != null && it.sessionId == session.databaseId) && it.createdBy == "patient" }) throw PatientStoreException(PatientStoreException.Kind.UpdateRejected)
        if (DemoData.isDemoId(patientId) || _isDemoMode.value) {
            val sessionId = session.databaseId
            _questionnaires.update { cache ->
                val current = cache[patientId.queryValue].orEmpty()
                    .filterNot { (recordId != null && it.databaseId == recordId) || (sessionId != null && it.sessionId?.queryValue == sessionId.queryValue) }
                cache + (patientId.queryValue to current)
            }
            persistDemoClinic()
            return
        }
        ensureConfigured()
        val sessionId = session.databaseId
        if (recordId == null && sessionId == null) throw PatientStoreException(PatientStoreException.Kind.SessionNotSaved)
        val deleted = client.from(CombinedMoodQuestionnaire.TABLE).delete {
            filter {
                eq("patient_id", patientId.queryValue)
                eq("created_by", "therapist")
                if (recordId != null) eq("id", recordId.queryValue) else eq("session_id", sessionId!!.queryValue)
            }
            select(Columns.raw("id"))
        }.decodeList<InsertedRow>()
        if (deleted.isEmpty()) throw PatientStoreException(PatientStoreException.Kind.UpdateRejected)
        _questionnaires.update { cache ->
            val current = cache[patientId.queryValue].orEmpty()
                .filterNot { (recordId != null && it.databaseId == recordId) || (sessionId != null && it.sessionId?.queryValue == sessionId.queryValue) }
            cache + (patientId.queryValue to current)
        }
        persistCache()
    }

    fun patient(id: String): Patient? = _patients.value.find { it.id.queryValue == id }

    fun session(patientId: String, sessionId: String): Session? =
        patient(patientId)?.sessions?.find { it.id.toString() == sessionId || it.databaseId?.queryValue == sessionId }

    fun clearAllCaches() {
        clinicalLoadEpoch = UUID.randomUUID()
        if (_isDemoMode.value) {
            resetDemoContent(_patients.value)
            demoClinicStore.clearAll()
        }
        _isDemoMode.value = false
        Entitlements.setLocalDemo(false)
        aiConsentStore.setDemoBypass(false)
        cache.clear()
        _patients.value = emptyList()
        _questionnaires.value = emptyMap()
    }

    fun wipeLocalData() {
        if (_isDemoMode.value) {
            resetDemoContent(_patients.value)
            demoClinicStore.clearAll()
            Entitlements.setLocalDemo(false)
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
        internal fun sessionWriteBody(
            date: Date,
            notes: String?,
            type: SessionType?,
            patientId: DatabaseId? = null,
            analysis: CBTSessionAnalysis? = null,
        ) = buildJsonObject {
            if (patientId != null) put("patient_id", patientId.toJsonElement())
            put("session_date", JsonPrimitive(dateOnly.format(date)))
            // Explicit null clears an existing summary; omitting the field preserves it.
            put("notes", notes?.let(::JsonPrimitive) ?: JsonNull)
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
    @Serializable(with = ClinicalStringId::class) val id: DatabaseId,
    val active: Boolean? = null,
    val notes: String? = null,
    val formulation: JsonElement? = null,
)

@Serializable
private data class SessionRow(
    @Serializable(with = ClinicalStringId::class) val id: DatabaseId,
    @SerialName("patient_id") @Serializable(with = ClinicalStringId::class) val patientId: DatabaseId,
    @SerialName("session_date") val sessionDate: String,
    val notes: String? = null,
    @SerialName("type") val sessionType: SessionType? = null,
    @SerialName("structured_notes") val structuredNotes: JsonElement? = null,
)

@Serializable
private data class NewQuestionnaireRecord(
    @SerialName("patient_id") val patientId: DatabaseId,
    @SerialName("session_id") val sessionId: DatabaseId?,
    @SerialName("answered_date") val answeredDate: String,
    @SerialName("gad7_answers") val gad7Answers: List<Int>,
    @SerialName("phq9_answers") val phq9Answers: List<Int>,
    @SerialName("interference_level") val interferenceLevel: Int? = null,
    @SerialName("combined_notes") val combinedNotes: QuestionnaireNotes,
)

@Serializable
private data class QuestionnaireDbRow(
    @SerialName("created_by") val createdBy: String? = null,
    @Serializable(with = ClinicalStringId::class) val id: DatabaseId,
    @SerialName("session_id") @Serializable(with = ClinicalStringId::class) val sessionId: DatabaseId? = null,
    @SerialName("answered_date") val answeredDate: String? = null,
    @SerialName("gad7_answers") val gad7Answers: List<Int>? = null,
    @SerialName("phq9_answers") val phq9Answers: List<Int>? = null,
    @SerialName("interference_level") val interferenceLevel: Int? = null,
    @SerialName("combined_notes") val combinedNotes: QuestionnaireNotes? = null,
)

/** Only clinical fields are serialized; identity fields stay local. */
internal fun diaryChatContext(
    one: List<DiaryOneEntry>, two: List<DiaryTwoEntry>, three: List<DiaryThreeEntry>,
    unavailable: List<String>,
): String {
    fun header(number: Int, date: Date, creator: DiaryOneEntryCreator) =
        "Diary $number\nauthor: ${creator.raw}\nrecordedAt: ${date.toInstant()}\nrecordedAtMeaning: record creation time; the described event may have occurred at another time"
    val entries = mutableListOf<String>()
    one.sortedBy { it.createdAt }.forEach { entry ->
        entries += listOf(
            header(1, entry.createdAt, entry.createdBy),
            "Event: ${entry.event}",
            "Automatic thoughts: ${entry.automaticThoughts.joinToString("; ")}",
            "Feelings: ${entry.feelings.joinToString("; ") { "${it.name}: ${it.intensity}%" }}",
            "Behaviour: ${entry.behaviour}",
            "Physical symptoms: ${entry.physicalSymptoms.orEmpty()}",
        ).joinToString("\n")
    }
    two.sortedBy { it.createdAt }.forEach { entry ->
        entries += listOf(
            header(2, entry.createdAt, entry.createdBy),
            "Event: ${entry.event}",
            "Automatic thoughts: ${entry.automaticThoughts.joinToString("; ")}",
            "Feelings: ${entry.feelings.joinToString("; ") { "${it.name}: ${it.intensity}%" }}",
            "Thinking errors: ${entry.thinkingErrors.joinToString("; ") { it.code }}",
            "Alternative thoughts: ${entry.alternativeThoughts.joinToString("; ")}",
        ).joinToString("\n")
    }
    three.sortedBy { it.createdAt }.forEach { entry ->
        entries += listOf(
            header(3, entry.createdAt, entry.createdBy),
            "Situation: ${entry.situation}",
            "Automatic thoughts: ${entry.automaticThoughts.joinToString("; ") { "${it.text} (belief before: ${it.beliefBefore}%, after: ${it.beliefAfter}%)" }}",
            "Feelings: ${entry.feelings.joinToString("; ") { "${it.name} (intensity before: ${it.intensityBefore}%, after: ${it.intensityAfter}%)" }}",
            "Thinking errors: ${entry.thinkingErrors.joinToString("; ") { it.code }}",
            "Alternative thoughts: ${entry.alternativeThoughts.joinToString("; ") { "${it.text} (belief: ${it.belief}%)" }}",
        ).joinToString("\n")
    }
    return "Saved diary entries (intensity and belief use 0–100%; dates are record creation dates):\n" +
        (if (entries.isEmpty()) "No entries in successfully loaded diaries." else entries.joinToString("\n\n")) +
        "\n" + unavailable.joinToString("\n")
}
