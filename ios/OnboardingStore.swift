import Foundation
import SwiftUI

/// Device-local first-run / Getting Started flags, namespaced by Supabase
/// Auth user id (never email).
@MainActor
@Observable
final class OnboardingStore {
    static let shared = OnboardingStore()

    private(set) var welcomeDismissed = false
    private(set) var checklistDismissed = false
    private(set) var hasSeenFirstPreparationTip = false
    private(set) var hasSeenFirstQuestionnaireTip = false
    private(set) var hasCompletedDemoTour = false
    /// Settings asked to show demo consent on the root patient list (not
    /// as a cover inside the Settings sheet — that flashed Settings on exit).
    private(set) var wantsDemoConsent = false

    @ObservationIgnored
    private var activeUserId: String?

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Switches flags to the given account. Signed out (`nil`) clears the
    /// in-memory flags without writing.
    func setActiveUser(id: String?) {
        activeUserId = id
        reloadFromDefaults()
    }

    /// Called when the welcome primary or secondary button is used.
    func dismissWelcome() {
        welcomeDismissed = true
        persist()
    }

    /// Hides the Getting Started card until Settings restores it.
    func dismissChecklist() {
        checklistDismissed = true
        persist()
    }

    /// Settings → מדריך התחלה.
    func showChecklistAgain() {
        checklistDismissed = false
        persist()
    }

    /// Settings requests the root list to present demo consent.
    func requestDemoConsent() {
        wantsDemoConsent = true
    }

    func clearDemoConsentRequest() {
        wantsDemoConsent = false
    }

    func markFirstPreparationTipSeen() {
        hasSeenFirstPreparationTip = true
        persist()
    }

    func markFirstQuestionnaireTipSeen() {
        hasSeenFirstQuestionnaireTip = true
        persist()
    }

    func markDemoTourCompleted() {
        hasCompletedDemoTour = true
        persist()
    }

    /// Clears this account's onboarding keys after account deletion wipe.
    func clearPersistedState(for userId: String) {
        defaults.removeObject(forKey: Self.welcomeKey(for: userId))
        defaults.removeObject(forKey: Self.checklistKey(for: userId))
        defaults.removeObject(forKey: Self.firstPrepTipKey(for: userId))
        defaults.removeObject(forKey: Self.firstQuestionnaireTipKey(for: userId))
        defaults.removeObject(forKey: Self.demoTourKey(for: userId))
        if activeUserId == userId {
            welcomeDismissed = false
            checklistDismissed = false
            hasSeenFirstPreparationTip = false
            hasSeenFirstQuestionnaireTip = false
            hasCompletedDemoTour = false
        }
    }

    /// Clears the active account's keys when still signed in.
    func clearPersistedStateForActiveUser() {
        guard let id = activeUserId else { return }
        clearPersistedState(for: id)
    }

    private func reloadFromDefaults() {
        guard let id = activeUserId else {
            welcomeDismissed = false
            checklistDismissed = false
            hasSeenFirstPreparationTip = false
            hasSeenFirstQuestionnaireTip = false
            hasCompletedDemoTour = false
            return
        }
        welcomeDismissed = defaults.bool(forKey: Self.welcomeKey(for: id))
        checklistDismissed = defaults.bool(forKey: Self.checklistKey(for: id))
        hasSeenFirstPreparationTip = defaults.bool(forKey: Self.firstPrepTipKey(for: id))
        hasSeenFirstQuestionnaireTip = defaults.bool(forKey: Self.firstQuestionnaireTipKey(for: id))
        hasCompletedDemoTour = defaults.bool(forKey: Self.demoTourKey(for: id))
    }

    private func persist() {
        guard let id = activeUserId else { return }
        defaults.set(welcomeDismissed, forKey: Self.welcomeKey(for: id))
        defaults.set(checklistDismissed, forKey: Self.checklistKey(for: id))
        defaults.set(hasSeenFirstPreparationTip, forKey: Self.firstPrepTipKey(for: id))
        defaults.set(hasSeenFirstQuestionnaireTip, forKey: Self.firstQuestionnaireTipKey(for: id))
        defaults.set(hasCompletedDemoTour, forKey: Self.demoTourKey(for: id))
    }

    static func welcomeKey(for userId: String) -> String {
        "onboarding.welcomeDismissed-\(userId)"
    }

    static func checklistKey(for userId: String) -> String {
        "onboarding.checklistDismissed-\(userId)"
    }

    static func firstPrepTipKey(for userId: String) -> String {
        "onboarding.firstPreparationTipSeen-\(userId)"
    }

    static func firstQuestionnaireTipKey(for userId: String) -> String {
        "onboarding.firstQuestionnaireTipSeen-\(userId)"
    }

    static func demoTourKey(for userId: String) -> String {
        "onboarding.demoTourCompleted-\(userId)"
    }
}

/// Phase of the post-tour showcase reveal (countdown → intro sheet).
enum ShowcaseRevealPhase: Equatable {
    case idle
    case countingDown
    case intro
}

/// One-shot coach-mark state for the demo walkthrough.
@MainActor
@Observable
final class GettingStartedRouter {
    /// Highlighted control the therapist should tap next.
    var highlight: TutorialHighlight?

    /// Screen the coach is currently attached to.
    var placement: TutorialCoachPlacement = .patientList

    /// Patient whose screen is visible (detail / sessions / editor), if any.
    var viewingPatientID: DatabaseID?

    /// Latest evaluated walkthrough progress.
    var progress = GettingStartedProgress.empty

    /// When true, the patient list should pop back to root (e.g. restart).
    var wantsPatientListReset = false

    /// Countdown / intro after the tour completes or “skip to sample data”.
    var showcaseRevealPhase: ShowcaseRevealPhase = .idle

    /// When counting down, the moment the auto-advance fires.
    private(set) var showcaseCountdownEndsAt: Date?

    /// Length of the post-tour auto-advance countdown.
    static let showcaseCountdownDuration: TimeInterval = 30

    /// Optional deep-link into sessions (legacy; walkthrough no longer sets this).
    var pendingSessionsAction: SessionsInitialAction?

    @ObservationIgnored
    private var showcaseCountdownTask: Task<Void, Never>?

    /// After the stack is cleared, present the fake-data intro.
    @ObservationIgnored
    private var pendingShowcaseIntro = false

    /// After the stack is cleared, dismiss the intro cover (land on the list).
    @ObservationIgnored
    private var pendingShowcaseIntroExit = false

    func clearHighlight() {
        highlight = nil
    }

    func clearHighlightIfMatching(_ value: TutorialHighlight) {
        if highlight == value { highlight = nil }
    }

    /// Whether `value` should flash right now (ignores stale highlight).
    func shouldPulse(_ value: TutorialHighlight) -> Bool {
        let expected = TutorialCoach.highlight(
            for: progress.currentStep,
            on: placement,
            progress: progress,
            viewingPatientID: viewingPatientID
        )
        return expected == value
    }

    func consumeSessionsAction() -> SessionsInitialAction? {
        let action = pendingSessionsAction
        pendingSessionsAction = nil
        return action
    }

    func refresh(using store: PatientStore) {
        progress = GettingStartedProgress.evaluate(store: store)
        syncHighlight()
    }

    func setPlacement(
        _ newPlacement: TutorialCoachPlacement,
        viewingPatientID: DatabaseID? = nil
    ) {
        placement = newPlacement
        self.viewingPatientID = viewingPatientID
        syncHighlight()
    }

    func syncHighlight() {
        highlight = TutorialCoach.highlight(
            for: progress.currentStep,
            on: placement,
            progress: progress,
            viewingPatientID: viewingPatientID
        )
    }

    func resetShowcaseReveal() {
        cancelShowcaseCountdown()
        pendingShowcaseIntro = false
        pendingShowcaseIntroExit = false
        showcaseRevealPhase = .idle
    }

    func restart(using store: PatientStore) {
        resetShowcaseReveal()
        store.restartDemoTutorial()
        wantsPatientListReset = true
        placement = .patientList
        viewingPatientID = nil
        refresh(using: store)
    }

    func dismissCoach(using onboarding: OnboardingStore) {
        onboarding.dismissChecklist()
        clearHighlight()
    }

    /// Starts the banner countdown after the AI-summary mission finishes —
    /// never on demo re-entry (that path shows Restart + Skip only).
    func beginShowcaseCountdownIfNeeded(using store: PatientStore) {
        guard progress.isComplete, !store.showcaseDataLoaded else { return }
        guard case .idle = showcaseRevealPhase else { return }
        startShowcaseCountdown()
    }

    /// Mission banner (or drained timer) → clear stack, then show intro.
    func skipToShowcaseData(using store: PatientStore) {
        cancelShowcaseCountdown()
        clearHighlight()
        pendingShowcaseIntroExit = false
        pendingShowcaseIntro = true
        returnToPatientList()
    }

    /// Keep the intro cover up, clear back to the patients list underneath,
    /// then dismiss the cover so the list is revealed — never the AI summary.
    func finishShowcaseIntro(using onboarding: OnboardingStore, store: PatientStore) {
        guard case .intro = showcaseRevealPhase else { return }
        store.loadShowcaseDemoData()
        refresh(using: store)
        pendingShowcaseIntro = false
        pendingShowcaseIntroExit = true
        returnToPatientList()
    }

    /// Called by `PatientListView` after it has emptied the navigation stack.
    func patientListDidReset(using onboarding: OnboardingStore) {
        if pendingShowcaseIntro {
            pendingShowcaseIntro = false
            showcaseRevealPhase = .intro
        }
        if pendingShowcaseIntroExit {
            pendingShowcaseIntroExit = false
            showcaseRevealPhase = .idle
            dismissCoach(using: onboarding)
        }
    }

    func cancelShowcaseCountdown() {
        showcaseCountdownTask?.cancel()
        showcaseCountdownTask = nil
        showcaseCountdownEndsAt = nil
        if case .countingDown = showcaseRevealPhase {
            showcaseRevealPhase = .idle
        }
    }

    /// Pop navigation back to the patients list without animating the stack.
    private func returnToPatientList() {
        wantsPatientListReset = true
        placement = .patientList
        viewingPatientID = nil
    }

    private func startShowcaseCountdown() {
        cancelShowcaseCountdown()
        let duration = Self.showcaseCountdownDuration
        showcaseCountdownEndsAt = Date().addingTimeInterval(duration)
        showcaseRevealPhase = .countingDown
        showcaseCountdownTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            showcaseCountdownEndsAt = nil
            showcaseRevealPhase = .idle
            pendingShowcaseIntro = true
            returnToPatientList()
        }
    }

    func consumePatientListReset() -> Bool {
        guard wantsPatientListReset else { return false }
        wantsPatientListReset = false
        return true
    }
}

/// Optional action applied once when `PatientSessionsView` appears.
enum SessionsInitialAction: Equatable {
    case addSession
    case editLatestForSummary
    case addQuestionnaire
}

/// Suggested next action when next-session preparation lacks useful input.
enum PreparationMissingAction: Equatable {
    case addSession
    case addSessionSummary
    case addQuestionnaire

    var buttonTitle: String {
        switch self {
        case .addSession: L10n.emptySessionsPrimaryAction
        case .addSessionSummary: L10n.gettingStartedStepSessionSummary
        case .addQuestionnaire: L10n.emptyQuestionnairesPrimaryAction
        }
    }
}

/// Legacy focus cases still referenced while patient detail applies
/// checklist navigation. Prefer `GettingStartedRouter.highlight`.
enum GettingStartedFocus: Equatable {
    case editTreatmentGoal
    case sessions(SessionsInitialAction?)
    case prepareNextSession
}
