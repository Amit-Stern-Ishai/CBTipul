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

/// One-shot navigation / coach-mark state for the demo tutorial.
@MainActor
@Observable
final class GettingStartedRouter {
    /// Highlighted control the therapist should tap next.
    var highlight: TutorialHighlight?

    /// Optional deep-link into sessions when opening a patient from the card.
    var pendingSessionsAction: SessionsInitialAction?

    func clearHighlight() {
        highlight = nil
    }

    func clearHighlightIfMatching(_ value: TutorialHighlight) {
        if highlight == value { highlight = nil }
    }

    func consumeSessionsAction() -> SessionsInitialAction? {
        let action = pendingSessionsAction
        pendingSessionsAction = nil
        return action
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
