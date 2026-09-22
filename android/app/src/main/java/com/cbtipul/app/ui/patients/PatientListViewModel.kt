package com.cbtipul.app.ui.patients

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.cbtipul.app.data.ClinicalTextAnonymizerError
import com.cbtipul.app.data.OnboardingStore
import com.cbtipul.app.data.PatientRepository
import com.cbtipul.app.data.WhisperException
import com.cbtipul.app.model.AiException
import com.cbtipul.app.model.CBTSessionAnalysis
import com.cbtipul.app.model.ChatTurn
import com.cbtipul.app.model.CombinedMoodQuestionnaire
import com.cbtipul.app.model.CompletedQuestionnaire
import com.cbtipul.app.model.ConsentDeclinedException
import com.cbtipul.app.model.DatabaseId
import com.cbtipul.app.model.FollowUpStatus
import com.cbtipul.app.model.FormulationSupervision
import com.cbtipul.app.model.LongitudinalCaseReviewResponse
import com.cbtipul.app.model.Patient
import com.cbtipul.app.model.PatientFormulation
import com.cbtipul.app.model.PatientStatus
import com.cbtipul.app.model.PatientStoreException
import com.cbtipul.app.model.SavedPreparation
import com.cbtipul.app.model.Session
import com.cbtipul.app.model.WhatAmIMissingResponse
import com.cbtipul.app.ui.onboarding.GettingStartedRouter
import com.cbtipul.app.ui.onboarding.GettingStartedRouterState
import java.util.Calendar
import java.util.Date
import java.io.File
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class PatientListUiState(
    val isLoading: Boolean = true,
    val hasLoaded: Boolean = false,
    val loadError: String? = null,
    val isAdding: Boolean = false,
    val addError: String? = null,
    val isSavingAdd: Boolean = false,
    val isSavingSession: Boolean = false,
    val isTranscribing: Boolean = false,
    val isAnonymizingTranscription: Boolean = false,
    val isSavingQuestionnaire: Boolean = false,
    val isAnalyzing: Boolean = false,
    val isPreparing: Boolean = false,
    val savedPreparations: Map<String, SavedPreparation> = emptyMap(),
    val pendingAnalysis: CBTSessionAnalysis? = null,
    val isSavingNotes: Boolean = false,
    val isSavingStatus: Boolean = false,
    val isSavingFormulation: Boolean = false,
    val isAiBusy: Boolean = false,
    val isLoadingQuestionnaires: Boolean = false,
    val questionnairesError: String? = null,
    val formulationSupervision: FormulationSupervision? = null,
    val missingReview: WhatAmIMissingResponse? = null,
    val longitudinalReview: LongitudinalCaseReviewResponse? = null,
    val sessionError: String? = null,
)

class PatientListViewModel(
    private val repository: PatientRepository,
    private val onboardingStore: OnboardingStore,
) : ViewModel() {

    val isDemoMode: StateFlow<Boolean> = repository.isDemoMode
    val showcaseDataLoaded: StateFlow<Boolean> = repository.showcaseDataLoaded
    val onboarding: OnboardingStore get() = onboardingStore

    private val gettingStartedRouter = GettingStartedRouter(viewModelScope)
    val gettingStarted: GettingStartedRouter get() = gettingStartedRouter
    val gettingStartedState: StateFlow<GettingStartedRouterState> = gettingStartedRouter.state

    init {
        repository.loadCachedPatients()
    }

    val patients: StateFlow<List<Patient>> = repository.patients
        .map { list -> sortPatients(list) }
        .stateIn(viewModelScope, SharingStarted.Eagerly, sortPatients(repository.patients.value))

    val questionnaires: StateFlow<Map<String, List<CompletedQuestionnaire>>> = repository.questionnaires

    private val _ui = MutableStateFlow(
        PatientListUiState(
            isLoading = repository.patients.value.isEmpty(),
            hasLoaded = repository.patients.value.isNotEmpty(),
        ),
    )
    val ui: StateFlow<PatientListUiState> = _ui.asStateFlow()

    init {
        refresh()
    }

    fun refresh(fromUser: Boolean = false) {
        viewModelScope.launch {
            if (repository.isDemoMode.value) {
                refreshGettingStartedProgress()
                _ui.update { it.copy(isLoading = false, hasLoaded = true, loadError = null) }
                return@launch
            }
            val blocking = fromUser || repository.patients.value.isEmpty()
            _ui.update { it.copy(isLoading = blocking, loadError = null) }
            try {
                repository.loadPatients()
                _ui.update { it.copy(isLoading = false, hasLoaded = true) }
                refreshGettingStartedProgress()
            } catch (error: Exception) {
                _ui.update { it.copy(isLoading = false, hasLoaded = true, loadError = error.message ?: error.toString()) }
            }
        }
    }

    fun refreshGettingStartedProgress() {
        gettingStartedRouter.refresh(repository)
    }

    fun startDemoTour() {
        viewModelScope.launch {
            onboardingStore.markDemoTourCompleted()
            onboardingStore.dismissWelcome()
            onboardingStore.showChecklistAgain()
            repository.enterDemoMode()
            gettingStartedRouter.setPlacement(
                com.cbtipul.app.ui.onboarding.TutorialCoachPlacement.PatientList,
            )
            gettingStartedRouter.refresh(repository)
            gettingStartedRouter.resetShowcaseReveal()
            _ui.update { it.copy(isLoading = false, hasLoaded = true, loadError = null) }
        }
    }

    fun exitDemoMode() {
        viewModelScope.launch {
            gettingStartedRouter.resetShowcaseReveal()
            repository.exitDemoMode()
            refreshGettingStartedProgress()
            refresh()
        }
    }

    fun skipWelcome() {
        viewModelScope.launch { onboardingStore.dismissWelcome() }
    }

    fun requestDemoConsent() = onboardingStore.requestDemoConsent()

    fun clearDemoConsentRequest() = onboardingStore.clearDemoConsentRequest()

    fun restartDemoTutorial() {
        gettingStartedRouter.restart(repository)
    }

    fun skipToShowcaseData() {
        gettingStartedRouter.skipToShowcaseData(repository)
    }

    fun finishShowcaseIntro() {
        gettingStartedRouter.finishShowcaseIntro(onboardingStore, repository)
    }

    fun dismissCoach() {
        viewModelScope.launch { gettingStartedRouter.dismissCoach(onboardingStore) }
    }

    fun beginShowcaseCountdownIfNeeded() {
        gettingStartedRouter.beginShowcaseCountdownIfNeeded(repository)
    }

    fun setAdding(value: Boolean) = _ui.update { it.copy(isAdding = value, addError = null) }

    fun addPatient(
        firstName: String,
        lastName: String,
        status: PatientStatus,
        notConfigured: String,
        rejected: String,
        onDone: () -> Unit,
    ) {
        viewModelScope.launch {
            _ui.update { it.copy(isSavingAdd = true, addError = null) }
            try {
                repository.addPatient(firstName, lastName, status)
                refreshGettingStartedProgress()
                _ui.update { it.copy(isSavingAdd = false, isAdding = false) }
                onDone()
            } catch (error: Exception) {
                _ui.update {
                    it.copy(isSavingAdd = false, addError = mapError(error, notConfigured, rejected))
                }
            }
        }
    }

    fun rename(id: DatabaseId, firstName: String, lastName: String) {
        repository.renamePatient(id, firstName, lastName)
    }

    fun delete(id: DatabaseId, notConfigured: String, rejected: String, onDone: () -> Unit) {
        viewModelScope.launch {
            try {
                repository.deletePatient(id)
                onDone()
            } catch (error: Exception) {
                _ui.update { it.copy(loadError = mapError(error, notConfigured, rejected)) }
            }
        }
    }

    fun patient(id: String): Patient? = repository.patient(id)

    fun session(patientId: String, sessionId: String): Session? = repository.session(patientId, sessionId)

    fun clearSessionError() = _ui.update { it.copy(sessionError = null) }

    fun saveSession(
        patientId: DatabaseId,
        session: Session,
        isNew: Boolean,
        leaveAfterSave: Boolean,
        notConfigured: String,
        rejected: String,
        sessionNotSaved: String,
        anonymizationFailed: String,
        onDone: () -> Unit,
    ) {
        viewModelScope.launch {
            _ui.update { it.copy(isSavingSession = true, sessionError = null) }
            try {
                if (isNew) repository.addSession(patientId, session)
                else repository.updateSession(session)
                refreshGettingStartedProgress()
                _ui.update { it.copy(isSavingSession = false) }
                if (leaveAfterSave) onDone()
            } catch (error: Exception) {
                _ui.update {
                    it.copy(
                        isSavingSession = false,
                        sessionError = mapSessionError(error, notConfigured, rejected, sessionNotSaved, anonymizationFailed),
                    )
                }
            }
        }
    }

    fun deleteSession(
        session: Session,
        notConfigured: String,
        rejected: String,
        sessionNotSaved: String,
        anonymizationFailed: String,
        onDone: () -> Unit,
    ) {
        viewModelScope.launch {
            _ui.update { it.copy(isSavingSession = true, sessionError = null) }
            try {
                repository.deleteSession(session)
                _ui.update { it.copy(isSavingSession = false) }
                onDone()
            } catch (error: Exception) {
                _ui.update {
                    it.copy(
                        isSavingSession = false,
                        sessionError = mapSessionError(error, notConfigured, rejected, sessionNotSaved, anonymizationFailed),
                    )
                }
            }
        }
    }

    fun markFollowUpDiscussed(
        session: Session,
        questionIndex: Int,
        notConfigured: String,
        rejected: String,
        sessionNotSaved: String,
        anonymizationFailed: String,
    ) {
        val analysis = session.structuredNotes ?: return
        if (questionIndex !in analysis.followUpQuestions.indices) return
        val questions = analysis.followUpQuestions.toMutableList()
        questions[questionIndex] = questions[questionIndex].copy(status = FollowUpStatus.Discussed)
        val updated = session.copy(structuredNotes = analysis.copy(followUpQuestions = questions))
        viewModelScope.launch {
            try {
                repository.updateSession(updated)
            } catch (error: Exception) {
                _ui.update {
                    it.copy(
                        sessionError = mapSessionError(error, notConfigured, rejected, sessionNotSaved, anonymizationFailed),
                    )
                }
            }
        }
    }

    fun clearPendingAnalysis() = _ui.update { it.copy(pendingAnalysis = null) }

    fun transcribeVoice(
        file: File,
        existingNotes: String,
        sessionForAutosave: Session?,
        notConfigured: String,
        rejected: String,
        sessionNotSaved: String,
        anonymizationFailed: String,
        transcriptionFailed: (String) -> String,
        couldNotReadAudio: (String) -> String,
        onNotes: (String) -> Unit,
        onTranscribed: () -> Unit,
        patientIdForNotes: DatabaseId? = null,
    ) {
        viewModelScope.launch {
            _ui.update { it.copy(isTranscribing = true, sessionError = null) }
            try {
                val text = repository.transcribeAudio(file)
                _ui.update { it.copy(isTranscribing = false, isAnonymizingTranscription = true) }
                val existing = existingNotes.trim()
                val combined = if (existing.isEmpty()) text else existingNotes + "\n\n" + text
                val notes = repository.anonymizedText(combined)
                onNotes(notes)
                onTranscribed()
                val saved = sessionForAutosave?.copy(notes = notes)
                if (saved?.databaseId != null) {
                    repository.updateSession(saved)
                } else if (patientIdForNotes != null) {
                    repository.updatePatientNotes(patientIdForNotes, notes)
                }
                _ui.update { it.copy(isAnonymizingTranscription = false) }
            } catch (error: Exception) {
                _ui.update {
                    it.copy(
                        isTranscribing = false,
                        isAnonymizingTranscription = false,
                        sessionError = mapVoiceError(
                            error,
                            notConfigured,
                            rejected,
                            sessionNotSaved,
                            anonymizationFailed,
                            transcriptionFailed,
                            couldNotReadAudio,
                        ),
                    )
                }
            }
        }
    }

    fun ensureQuestionnaires(patientId: DatabaseId) {
        viewModelScope.launch {
            if (repository.cachedQuestionnaires(patientId.queryValue) != null) return@launch
            try {
                repository.loadQuestionnaires(patientId)
            } catch (_: Exception) {
                // List-row scores are best-effort, matching iOS.
            }
        }
    }

    fun loadQuestionnaires(patientId: DatabaseId, notConfigured: String, rejected: String) {
        viewModelScope.launch {
            val hasCache = repository.cachedQuestionnaires(patientId.queryValue) != null
            if (!hasCache) {
                _ui.update { it.copy(isLoadingQuestionnaires = true, questionnairesError = null) }
            }
            try {
                repository.loadQuestionnaires(patientId)
                _ui.update { it.copy(isLoadingQuestionnaires = false, questionnairesError = null) }
            } catch (error: Exception) {
                _ui.update {
                    it.copy(
                        isLoadingQuestionnaires = false,
                        questionnairesError = if (hasCache) null else mapError(error, notConfigured, rejected),
                    )
                }
            }
        }
    }

    fun refreshQuestionnaires(patientId: DatabaseId, notConfigured: String, rejected: String) {
        loadQuestionnaires(patientId, notConfigured, rejected)
    }

    fun saveQuestionnaire(
        questionnaire: CombinedMoodQuestionnaire,
        patientId: DatabaseId,
        session: Session,
        notConfigured: String,
        rejected: String,
        sessionNotSaved: String,
        anonymizationFailed: String,
        onDone: () -> Unit,
    ) {
        viewModelScope.launch {
            _ui.update { it.copy(isSavingQuestionnaire = true, sessionError = null) }
            try {
                repository.saveQuestionnaire(questionnaire, patientId, session)
                refreshGettingStartedProgress()
                _ui.update { it.copy(isSavingQuestionnaire = false) }
                onDone()
            } catch (error: Exception) {
                _ui.update {
                    it.copy(
                        isSavingQuestionnaire = false,
                        sessionError = mapSessionError(error, notConfigured, rejected, sessionNotSaved, anonymizationFailed),
                    )
                }
            }
        }
    }

    fun deleteQuestionnaire(
        patientId: DatabaseId,
        session: Session,
        notConfigured: String,
        rejected: String,
        sessionNotSaved: String,
        anonymizationFailed: String,
        onDone: () -> Unit,
    ) {
        viewModelScope.launch {
            _ui.update { it.copy(isSavingQuestionnaire = true, sessionError = null) }
            try {
                repository.deleteQuestionnaire(patientId, session)
                _ui.update { it.copy(isSavingQuestionnaire = false) }
                onDone()
            } catch (error: Exception) {
                _ui.update {
                    it.copy(
                        isSavingQuestionnaire = false,
                        sessionError = mapSessionError(error, notConfigured, rejected, sessionNotSaved, anonymizationFailed),
                    )
                }
            }
        }
    }

    fun loadSavedPreparation(patientId: String) {
        val saved = repository.loadPreparation(patientId) ?: return
        _ui.update { it.copy(savedPreparations = it.savedPreparations + (patientId to saved)) }
    }

    fun isPreparationOutdated(patient: Patient, generatedAtMillis: Long): Boolean {
        val startOfToday = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.time
        val generated = Date(generatedAtMillis)
        return patient.sessions.any { it.date.after(generated) && it.date.before(startOfToday) }
    }

    fun analyzeSession(
        session: Session,
        notConfigured: String,
        rejected: String,
        sessionNotSaved: String,
        anonymizationFailed: String,
        invalidInput: String,
        analysisFailed: String,
        emptyAi: String,
        onNotes: (String) -> Unit,
        onAnalysis: (CBTSessionAnalysis) -> Unit,
    ) {
        viewModelScope.launch {
            _ui.update { it.copy(isAnonymizingTranscription = true, sessionError = null) }
            try {
                val notes = repository.anonymizedText(session.notes)
                onNotes(notes)
                _ui.update { it.copy(isAnonymizingTranscription = false, isAnalyzing = true) }
                val analysis = repository.analyzeSessionNotes(notes)
                repository.registerAIAnalysis(analysis)
                val updated = session.copy(notes = notes, structuredNotes = analysis)
                if (updated.databaseId != null) repository.updateSession(updated)
                _ui.update { it.copy(isAnalyzing = false, pendingAnalysis = analysis) }
                onAnalysis(analysis)
                refreshGettingStartedProgress()
                beginShowcaseCountdownIfNeeded()
            } catch (error: Exception) {
                _ui.update {
                    it.copy(
                        isAnonymizingTranscription = false,
                        isAnalyzing = false,
                        sessionError = mapAiError(
                            error,
                            notConfigured,
                            rejected,
                            sessionNotSaved,
                            anonymizationFailed,
                            invalidInput,
                            analysisFailed,
                            emptyAi,
                        ),
                    )
                }
            }
        }
    }

    fun saveAnalysis(
        session: Session,
        analysis: CBTSessionAnalysis,
        notConfigured: String,
        rejected: String,
        sessionNotSaved: String,
        anonymizationFailed: String,
        onDone: () -> Unit,
    ) {
        viewModelScope.launch {
            _ui.update { it.copy(isSavingSession = true, sessionError = null) }
            try {
                repository.updateSession(session.copy(structuredNotes = analysis))
                _ui.update { it.copy(isSavingSession = false) }
                onDone()
            } catch (error: Exception) {
                _ui.update {
                    it.copy(
                        isSavingSession = false,
                        sessionError = mapSessionError(error, notConfigured, rejected, sessionNotSaved, anonymizationFailed),
                    )
                }
            }
        }
    }

    fun prepareSession(
        patientId: DatabaseId,
        notConfigured: String,
        rejected: String,
        sessionNotSaved: String,
        anonymizationFailed: String,
        invalidInput: String,
        analysisFailed: String,
        emptyAi: String,
        onDone: () -> Unit,
    ) {
        viewModelScope.launch {
            _ui.update { it.copy(isPreparing = true, sessionError = null) }
            try {
                val saved = repository.prepareNextSession(patientId)
                _ui.update {
                    it.copy(
                        isPreparing = false,
                        savedPreparations = it.savedPreparations + (patientId.queryValue to saved),
                    )
                }
                onDone()
            } catch (error: Exception) {
                _ui.update {
                    it.copy(
                        isPreparing = false,
                        sessionError = mapAiError(
                            error,
                            notConfigured,
                            rejected,
                            sessionNotSaved,
                            anonymizationFailed,
                            invalidInput,
                            analysisFailed,
                            emptyAi,
                        ),
                    )
                }
            }
        }
    }

    fun sendChat(
        systemPrompt: String,
        turns: List<ChatTurn>,
        notConfigured: String,
        rejected: String,
        sessionNotSaved: String,
        anonymizationFailed: String,
        invalidInput: String,
        analysisFailed: String,
        emptyAi: String,
        onAnswer: (String) -> Unit,
        onDone: () -> Unit,
    ) {
        viewModelScope.launch {
            _ui.update { it.copy(sessionError = null) }
            try {
                onAnswer(repository.chat(systemPrompt, turns))
            } catch (error: Exception) {
                _ui.update {
                    it.copy(
                        sessionError = mapAiError(
                            error,
                            notConfigured,
                            rejected,
                            sessionNotSaved,
                            anonymizationFailed,
                            invalidInput,
                            analysisFailed,
                            emptyAi,
                        ),
                    )
                }
            } finally {
                onDone()
            }
        }
    }

    fun savePatientNotes(
        patientId: DatabaseId,
        notes: String,
        notConfigured: String,
        rejected: String,
        sessionNotSaved: String,
        anonymizationFailed: String,
        onDone: () -> Unit = {},
    ) {
        viewModelScope.launch {
            _ui.update { it.copy(isSavingNotes = true, sessionError = null) }
            try {
                repository.updatePatientNotes(patientId, notes)
                _ui.update { it.copy(isSavingNotes = false) }
                onDone()
            } catch (error: Exception) {
                _ui.update {
                    it.copy(
                        isSavingNotes = false,
                        sessionError = mapSessionError(error, notConfigured, rejected, sessionNotSaved, anonymizationFailed),
                    )
                }
            }
        }
    }

    fun updatePatientStatus(
        patientId: DatabaseId,
        status: PatientStatus,
        notConfigured: String,
        rejected: String,
        sessionNotSaved: String,
        anonymizationFailed: String,
    ) {
        viewModelScope.launch {
            _ui.update { it.copy(isSavingStatus = true, sessionError = null) }
            try {
                repository.updatePatientStatus(patientId, status)
                _ui.update { it.copy(isSavingStatus = false) }
            } catch (error: Exception) {
                _ui.update {
                    it.copy(
                        isSavingStatus = false,
                        sessionError = mapSessionError(
                            error,
                            notConfigured,
                            rejected,
                            sessionNotSaved,
                            anonymizationFailed,
                        ),
                    )
                }
            }
        }
    }

    fun saveFormulation(
        patientId: DatabaseId,
        formulation: PatientFormulation,
        notConfigured: String,
        rejected: String,
        sessionNotSaved: String,
        anonymizationFailed: String,
        onDone: () -> Unit,
    ) {
        viewModelScope.launch {
            _ui.update { it.copy(isSavingFormulation = true, sessionError = null) }
            try {
                repository.saveFormulation(patientId, formulation)
                _ui.update { it.copy(isSavingFormulation = false) }
                onDone()
            } catch (error: Exception) {
                _ui.update {
                    it.copy(
                        isSavingFormulation = false,
                        sessionError = mapSessionError(error, notConfigured, rejected, sessionNotSaved, anonymizationFailed),
                    )
                }
            }
        }
    }

    fun challengeFormulation(
        patientId: DatabaseId,
        notConfigured: String,
        rejected: String,
        sessionNotSaved: String,
        anonymizationFailed: String,
        invalidInput: String,
        analysisFailed: String,
        emptyAi: String,
        onDone: () -> Unit,
    ) {
        viewModelScope.launch {
            _ui.update { it.copy(isAiBusy = true, sessionError = null) }
            try {
                val result = repository.challengeFormulation(patientId)
                _ui.update { it.copy(isAiBusy = false, formulationSupervision = result) }
                onDone()
            } catch (error: Exception) {
                _ui.update {
                    it.copy(
                        isAiBusy = false,
                        sessionError = mapAiError(
                            error, notConfigured, rejected, sessionNotSaved, anonymizationFailed,
                            invalidInput, analysisFailed, emptyAi,
                        ),
                    )
                }
            }
        }
    }

    fun whatAmIMissing(
        patientId: DatabaseId,
        notConfigured: String,
        rejected: String,
        sessionNotSaved: String,
        anonymizationFailed: String,
        invalidInput: String,
        analysisFailed: String,
        emptyAi: String,
        onDone: () -> Unit,
    ) {
        viewModelScope.launch {
            _ui.update { it.copy(isAiBusy = true, sessionError = null) }
            try {
                val result = repository.whatAmIMissing(patientId)
                _ui.update { it.copy(isAiBusy = false, missingReview = result) }
                onDone()
            } catch (error: Exception) {
                _ui.update {
                    it.copy(
                        isAiBusy = false,
                        sessionError = mapAiError(
                            error, notConfigured, rejected, sessionNotSaved, anonymizationFailed,
                            invalidInput, analysisFailed, emptyAi,
                        ),
                    )
                }
            }
        }
    }

    fun longitudinalReview(
        patientId: DatabaseId,
        notConfigured: String,
        rejected: String,
        sessionNotSaved: String,
        anonymizationFailed: String,
        invalidInput: String,
        analysisFailed: String,
        emptyAi: String,
        onDone: () -> Unit,
    ) {
        viewModelScope.launch {
            _ui.update { it.copy(isAiBusy = true, sessionError = null) }
            try {
                val result = repository.longitudinalCaseReview(patientId)
                _ui.update { it.copy(isAiBusy = false, longitudinalReview = result) }
                onDone()
            } catch (error: Exception) {
                _ui.update {
                    it.copy(
                        isAiBusy = false,
                        sessionError = mapAiError(
                            error, notConfigured, rejected, sessionNotSaved, anonymizationFailed,
                            invalidInput, analysisFailed, emptyAi,
                        ),
                    )
                }
            }
        }
    }

    private fun sortPatients(list: List<Patient>): List<Patient> = list.sortedWith(
        compareByDescending<Patient> { it.status == PatientStatus.Active }
            .thenBy(String.CASE_INSENSITIVE_ORDER) { it.localName.orEmpty() },
    )

    private fun mapError(error: Exception, notConfigured: String, rejected: String): String =
        mapSessionError(error, notConfigured, rejected, rejected, rejected) ?: (error.message ?: error.toString())

    private fun mapSessionError(
        error: Exception,
        notConfigured: String,
        rejected: String,
        sessionNotSaved: String,
        anonymizationFailed: String,
    ): String? = when {
        error is ConsentDeclinedException -> null
        error is ClinicalTextAnonymizerError -> anonymizationFailed
        error is PatientStoreException -> when (error.kind) {
            PatientStoreException.Kind.NotConfigured -> notConfigured
            PatientStoreException.Kind.UpdateRejected -> rejected
            PatientStoreException.Kind.PatientNotSaved -> error.message ?: rejected
            PatientStoreException.Kind.SessionNotSaved -> sessionNotSaved
            PatientStoreException.Kind.AnonymizationFailed -> anonymizationFailed
        }
        else -> error.message ?: error.toString()
    }

    private fun mapAiError(
        error: Exception,
        notConfigured: String,
        rejected: String,
        sessionNotSaved: String,
        anonymizationFailed: String,
        invalidInput: String,
        analysisFailed: String,
        emptyAi: String,
    ): String? {
        if (error is AiException) {
            return when (error.message) {
                "invalid_input" -> invalidInput
                "empty_ai_response" -> emptyAi
                "session_analysis_failed", "invalid_response" -> analysisFailed
                else -> error.message ?: analysisFailed
            }
        }
        return mapSessionError(error, notConfigured, rejected, sessionNotSaved, anonymizationFailed)
    }

    private fun mapVoiceError(
        error: Exception,
        notConfigured: String,
        rejected: String,
        sessionNotSaved: String,
        anonymizationFailed: String,
        transcriptionFailed: (String) -> String,
        couldNotReadAudio: (String) -> String,
    ): String? {
        if (error is WhisperException) {
            return if (error.readFailed) couldNotReadAudio(error.detail) else transcriptionFailed(error.detail)
        }
        return mapSessionError(error, notConfigured, rejected, sessionNotSaved, anonymizationFailed)
    }

    class Factory(
        private val repository: PatientRepository,
        private val onboardingStore: OnboardingStore,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            PatientListViewModel(repository, onboardingStore) as T
    }
}
