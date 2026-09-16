package com.cbtipul.app.ui.onboarding

import com.cbtipul.app.data.OnboardingStore
import com.cbtipul.app.data.PatientRepository
import com.cbtipul.app.model.DatabaseId
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

enum class ShowcaseRevealPhase {
    Idle,
    CountingDown,
    Intro,
}

data class GettingStartedRouterState(
    val highlight: TutorialHighlight? = null,
    val placement: TutorialCoachPlacement = TutorialCoachPlacement.PatientList,
    val viewingPatientId: DatabaseId? = null,
    val progress: GettingStartedProgress = GettingStartedProgress.empty,
    val wantsPatientListReset: Boolean = false,
    val showcaseRevealPhase: ShowcaseRevealPhase = ShowcaseRevealPhase.Idle,
    val showcaseCountdownEndsAtMillis: Long? = null,
)

class GettingStartedRouter(
    private val scope: CoroutineScope,
) {
    private val _state = MutableStateFlow(GettingStartedRouterState())
    val state: StateFlow<GettingStartedRouterState> = _state.asStateFlow()

    private var showcaseCountdownJob: Job? = null
    private var pendingShowcaseIntro = false
    private var pendingShowcaseIntroExit = false

    fun clearHighlight() {
        _state.update { it.copy(highlight = null) }
    }

    fun shouldPulse(value: TutorialHighlight): Boolean {
        val s = _state.value
        val expected = TutorialCoach.highlight(
            step = s.progress.currentStep,
            placement = s.placement,
            progress = s.progress,
            viewingPatientId = s.viewingPatientId,
        )
        return expected == value
    }

    fun refresh(repository: PatientRepository) {
        val progress = GettingStartedProgress.evaluate(
            patients = repository.patients.value,
            questionnairesForPatient = { patient ->
                repository.cachedQuestionnaires(patient.id.queryValue)
            },
        )
        _state.update { it.copy(progress = progress) }
        syncHighlight()
    }

    fun setPlacement(
        placement: TutorialCoachPlacement,
        viewingPatientId: DatabaseId? = null,
    ) {
        _state.update {
            it.copy(placement = placement, viewingPatientId = viewingPatientId)
        }
        syncHighlight()
    }

    fun syncHighlight() {
        val s = _state.value
        _state.update {
            it.copy(
                highlight = TutorialCoach.highlight(
                    step = s.progress.currentStep,
                    placement = s.placement,
                    progress = s.progress,
                    viewingPatientId = s.viewingPatientId,
                ),
            )
        }
    }

    fun resetShowcaseReveal() {
        cancelShowcaseCountdown()
        pendingShowcaseIntro = false
        pendingShowcaseIntroExit = false
        _state.update { it.copy(showcaseRevealPhase = ShowcaseRevealPhase.Idle) }
    }

    fun restart(repository: PatientRepository) {
        resetShowcaseReveal()
        repository.restartDemoTutorial()
        _state.update {
            it.copy(
                wantsPatientListReset = true,
                placement = TutorialCoachPlacement.PatientList,
                viewingPatientId = null,
            )
        }
        refresh(repository)
    }

    suspend fun dismissCoach(onboarding: OnboardingStore) {
        onboarding.dismissChecklist()
        clearHighlight()
    }

    fun beginShowcaseCountdownIfNeeded(repository: PatientRepository) {
        val s = _state.value
        if (!s.progress.isComplete || repository.showcaseDataLoaded.value) return
        if (s.showcaseRevealPhase != ShowcaseRevealPhase.Idle) return
        startShowcaseCountdown()
    }

    fun skipToShowcaseData(repository: PatientRepository) {
        cancelShowcaseCountdown()
        clearHighlight()
        pendingShowcaseIntroExit = false
        pendingShowcaseIntro = true
        returnToPatientList()
    }

    fun finishShowcaseIntro(onboarding: OnboardingStore, repository: PatientRepository) {
        if (_state.value.showcaseRevealPhase != ShowcaseRevealPhase.Intro) return
        repository.loadShowcaseDemoData()
        refresh(repository)
        pendingShowcaseIntro = false
        pendingShowcaseIntroExit = true
        returnToPatientList()
    }

    suspend fun patientListDidReset(onboarding: OnboardingStore) {
        if (pendingShowcaseIntro) {
            pendingShowcaseIntro = false
            _state.update { it.copy(showcaseRevealPhase = ShowcaseRevealPhase.Intro) }
        }
        if (pendingShowcaseIntroExit) {
            pendingShowcaseIntroExit = false
            _state.update { it.copy(showcaseRevealPhase = ShowcaseRevealPhase.Idle) }
            dismissCoach(onboarding)
        }
    }

    fun cancelShowcaseCountdown() {
        showcaseCountdownJob?.cancel()
        showcaseCountdownJob = null
        _state.update {
            it.copy(
                showcaseCountdownEndsAtMillis = null,
                showcaseRevealPhase = if (it.showcaseRevealPhase == ShowcaseRevealPhase.CountingDown) {
                    ShowcaseRevealPhase.Idle
                } else {
                    it.showcaseRevealPhase
                },
            )
        }
    }

    fun consumePatientListReset(): Boolean {
        if (!_state.value.wantsPatientListReset) return false
        _state.update { it.copy(wantsPatientListReset = false) }
        return true
    }

    private fun returnToPatientList() {
        _state.update {
            it.copy(
                wantsPatientListReset = true,
                placement = TutorialCoachPlacement.PatientList,
                viewingPatientId = null,
            )
        }
    }

    private fun startShowcaseCountdown() {
        cancelShowcaseCountdown()
        val endsAt = System.currentTimeMillis() + SHOWCASE_COUNTDOWN_DURATION_MS
        _state.update {
            it.copy(
                showcaseCountdownEndsAtMillis = endsAt,
                showcaseRevealPhase = ShowcaseRevealPhase.CountingDown,
            )
        }
        showcaseCountdownJob = scope.launch {
            delay(SHOWCASE_COUNTDOWN_DURATION_MS)
            _state.update {
                it.copy(
                    showcaseCountdownEndsAtMillis = null,
                    showcaseRevealPhase = ShowcaseRevealPhase.Idle,
                )
            }
            pendingShowcaseIntro = true
            returnToPatientList()
        }
    }

    companion object {
        const val SHOWCASE_COUNTDOWN_DURATION_MS = 30_000L
    }
}
