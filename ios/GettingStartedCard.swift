import Foundation
import SwiftUI

/// Checklist steps for the demo-mode walkthrough (in order).
enum GettingStartedStep: Int, CaseIterable, Identifiable {
    case createPatient
    case createSession
    case fillQuestionnaire
    case recordSessionSummary
    case createAISummary

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .createPatient: L10n.gettingStartedStepAddPatient
        case .createSession: L10n.gettingStartedStepFirstSession
        case .fillQuestionnaire: L10n.gettingStartedStepQuestionnaire
        case .recordSessionSummary: L10n.gettingStartedStepSessionSummary
        case .createAISummary: L10n.gettingStartedStepAISummary
        }
    }
}

/// Where the walkthrough coach is currently shown — drives which control pulses.
enum TutorialCoachPlacement: Equatable {
    case patientList
    case addPatient
    case patientDetail
    case sessions
    case sessionEditor
    case questionnaire
}

/// Maps the active step + screen to the next control on *this* screen.
///
/// After an action, the therapist may be anywhere in the stack. The coach
/// always points at the next hop from the current screen toward the goal —
/// never at a control that is not visible here.
enum TutorialCoach {
    static func highlight(
        for step: GettingStartedStep?,
        on placement: TutorialCoachPlacement,
        progress: GettingStartedProgress,
        viewingPatientID: DatabaseID? = nil
    ) -> TutorialHighlight? {
        guard let step else { return nil }

        // On a patient-scoped screen that is not the tour patient, do not
        // pulse local controls — send them back via the patients list.
        if placement != .patientList,
           placement != .addPatient,
           let focus = progress.focusPatientID,
           let viewing = viewingPatientID,
           viewing != focus {
            return nil
        }

        switch step {
        case .createPatient:
            switch placement {
            case .patientList: return .addPatient
            case .addPatient: return nil
            default: return nil
            }

        case .createSession:
            switch placement {
            case .patientList: return .tutorialPatient
            case .patientDetail: return .sessionsEntry
            case .sessions: return .addSession
            case .sessionEditor: return nil
            case .addPatient, .questionnaire: return nil
            }

        case .fillQuestionnaire, .recordSessionSummary, .createAISummary:
            switch placement {
            case .patientList: return .tutorialPatient
            case .patientDetail: return .sessionsEntry
            case .sessions:
                return progress.hasSession ? .latestSession : .addSession
            case .sessionEditor:
                switch step {
                case .fillQuestionnaire: return .fillQuestionnaire
                case .recordSessionSummary: return .recordNotes
                case .createAISummary: return .aiSummary
                default: return nil
                }
            case .questionnaire, .addPatient: return nil
            }
        }
    }

    /// Short hint under the step title for the current screen.
    static func hint(
        for step: GettingStartedStep?,
        on placement: TutorialCoachPlacement,
        progress: GettingStartedProgress,
        viewingPatientID: DatabaseID? = nil
    ) -> String {
        guard let step else { return "" }

        if placement != .patientList,
           placement != .addPatient,
           let focus = progress.focusPatientID,
           let viewing = viewingPatientID,
           viewing != focus {
            return L10n.tutorialCoachHintOpenPatient
        }

        switch step {
        case .createPatient:
            switch placement {
            case .patientList: return L10n.tutorialCoachHintAddPatient
            case .addPatient: return L10n.tutorialCoachHintFillNewPatient
            default: return L10n.tutorialCoachHintReturnPatientsAdd
            }

        case .createSession:
            switch placement {
            case .patientList: return L10n.tutorialCoachHintOpenPatient
            case .patientDetail: return L10n.tutorialCoachHintOpenSessions
            case .sessions: return L10n.tutorialCoachHintAddSession
            case .sessionEditor: return L10n.tutorialCoachHintSaveSession
            case .addPatient, .questionnaire: return L10n.tutorialCoachHintOpenPatient
            }

        case .fillQuestionnaire:
            switch placement {
            case .patientList: return L10n.tutorialCoachHintOpenPatient
            case .patientDetail: return L10n.tutorialCoachHintOpenSessions
            case .sessions:
                return progress.hasSession
                    ? L10n.tutorialCoachHintOpenSession
                    : L10n.tutorialCoachHintAddSession
            case .sessionEditor: return L10n.tutorialCoachHintFillQuestionnaire
            case .questionnaire: return L10n.tutorialCoachHintCompleteQuestionnaire
            case .addPatient: return L10n.tutorialCoachHintOpenPatient
            }

        case .recordSessionSummary:
            switch placement {
            case .patientList: return L10n.tutorialCoachHintOpenPatient
            case .patientDetail: return L10n.tutorialCoachHintOpenSessions
            case .sessions:
                return progress.hasSession
                    ? L10n.tutorialCoachHintOpenSession
                    : L10n.tutorialCoachHintAddSession
            case .sessionEditor: return L10n.tutorialCoachHintRecordNotes
            case .questionnaire, .addPatient: return L10n.tutorialCoachHintOpenSession
            }

        case .createAISummary:
            switch placement {
            case .patientList: return L10n.tutorialCoachHintOpenPatient
            case .patientDetail: return L10n.tutorialCoachHintOpenSessions
            case .sessions:
                return progress.hasSession
                    ? L10n.tutorialCoachHintOpenSession
                    : L10n.tutorialCoachHintAddSession
            case .sessionEditor: return L10n.tutorialCoachHintAISummary
            case .questionnaire, .addPatient: return L10n.tutorialCoachHintOpenSession
            }
        }
    }
}

/// Completion derived from the therapist's own demo (tutorial) patient.
struct GettingStartedProgress: Equatable {
    var hasPatient: Bool
    var hasSession: Bool
    var hasQuestionnaire: Bool
    var hasSessionNotes: Bool
    var hasAISummary: Bool
    /// The single tutorial patient the walkthrough is following.
    var focusPatientID: DatabaseID? = nil

    static let empty = GettingStartedProgress(
        hasPatient: false,
        hasSession: false,
        hasQuestionnaire: false,
        hasSessionNotes: false,
        hasAISummary: false,
        focusPatientID: nil
    )

    var completedCount: Int {
        [hasPatient, hasSession, hasQuestionnaire, hasSessionNotes, hasAISummary]
            .filter(\.self)
            .count
    }

    var isComplete: Bool { completedCount == GettingStartedStep.allCases.count }

    func isComplete(_ step: GettingStartedStep) -> Bool {
        switch step {
        case .createPatient: hasPatient
        case .createSession: hasSession
        case .fillQuestionnaire: hasQuestionnaire
        case .recordSessionSummary: hasSessionNotes
        case .createAISummary: hasAISummary
        }
    }

    /// 1-based index of the active step, or `total` when the tour is done.
    var currentStepNumber: Int {
        guard let current = currentStep else {
            return GettingStartedStep.allCases.count
        }
        return current.rawValue + 1
    }

    /// First incomplete step, or `nil` when the walkthrough is done.
    var currentStep: GettingStartedStep? {
        GettingStartedStep.allCases.first { !isComplete($0) }
    }

    func isUnlocked(_ step: GettingStartedStep) -> Bool {
        guard let current = currentStep else { return true }
        return step.rawValue <= current.rawValue
    }

    /// How far a tutorial patient has progressed (higher = further along).
    private static func tourScore(
        for patient: Patient,
        questionnairesForPatient: (Patient) -> [CompletedQuestionnaire]?
    ) -> Int {
        var score = 1
        if !patient.sessions.isEmpty { score = 2 }
        if let records = questionnairesForPatient(patient), !records.isEmpty { score = 3 }
        if patient.sessions.contains(where: {
            !$0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) { score = 4 }
        if patient.sessions.contains(where: { $0.structuredNotes != nil }) { score = 5 }
        return score
    }

    /// The tutorial patient the coach should follow: furthest along the tour,
    /// ties broken by newest in the store list.
    static func focusTutorialPatient(
        patients: [Patient],
        questionnairesForPatient: (Patient) -> [CompletedQuestionnaire]?
    ) -> Patient? {
        let tutorial = patients.filter { DemoData.isTutorialPatientID($0.id) }
        guard !tutorial.isEmpty else { return nil }
        return tutorial.max { a, b in
            let scoreA = tourScore(for: a, questionnairesForPatient: questionnairesForPatient)
            let scoreB = tourScore(for: b, questionnairesForPatient: questionnairesForPatient)
            if scoreA != scoreB { return scoreA < scoreB }
            let indexA = patients.firstIndex(where: { $0.id == a.id }) ?? 0
            let indexB = patients.firstIndex(where: { $0.id == b.id }) ?? 0
            return indexA < indexB
        }
    }

    /// Builds progress from the local demo clinic.
    ///
    /// Only one user-created demo patient (`demo-user-…`) is followed — the
    /// furthest along — so the coach never points at a patient that does not
    /// match the recorded step.
    static func evaluate(
        patients: [Patient],
        questionnairesForPatient: (Patient) -> [CompletedQuestionnaire]?
    ) -> GettingStartedProgress {
        guard let focus = focusTutorialPatient(
            patients: patients,
            questionnairesForPatient: questionnairesForPatient
        ) else {
            return .empty
        }

        let records = questionnairesForPatient(focus)
        let hasQuestionnaire = !(records ?? []).isEmpty
        let hasSessionNotes = focus.sessions.contains {
            !$0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let hasAISummary = focus.sessions.contains { $0.structuredNotes != nil }

        return GettingStartedProgress(
            hasPatient: true,
            hasSession: !focus.sessions.isEmpty,
            hasQuestionnaire: hasQuestionnaire,
            hasSessionNotes: hasSessionNotes,
            hasAISummary: hasAISummary,
            focusPatientID: focus.id
        )
    }

    @MainActor
    static func evaluate(store: PatientStore) -> GettingStartedProgress {
        evaluate(
            patients: store.patients,
            questionnairesForPatient: { store.cachedQuestionnaires(for: $0) }
        )
    }

    static func sessionHasSummary(_ session: Session) -> Bool {
        if session.structuredNotes != nil { return true }
        return !session.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func hasUsefulPreparationInput(
        patient: Patient,
        questionnaires: [CompletedQuestionnaire]
    ) -> Bool {
        patient.sessions.contains(where: sessionHasSummary) || !questionnaires.isEmpty
    }

    static func missingPreparationAction(for patient: Patient) -> PreparationMissingAction {
        if patient.sessions.isEmpty { return .addSession }
        if !patient.sessions.contains(where: sessionHasSummary) { return .addSessionSummary }
        return .addQuestionnaire
    }
}

/// Single-mission walkthrough coach — docked at the bottom of the screen.
struct TutorialCoachCard: View {
    let progress: GettingStartedProgress
    let placement: TutorialCoachPlacement
    var viewingPatientID: DatabaseID? = nil
    var showcaseLoaded: Bool
    /// When set, the skip button shows a draining countdown fill.
    var countdownEndsAt: Date? = nil
    var countdownDuration: TimeInterval = GettingStartedRouter.showcaseCountdownDuration
    var onRestart: () -> Void
    var onDismiss: () -> Void
    var onSkipToShowcase: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "figure.walk")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.textOnAccent)
                    .symbolEffect(.bounce, options: .repeating.speed(0.5))

                VStack(alignment: .leading, spacing: 6) {
                    if progress.isComplete {
                        Text(L10n.gettingStartedCompleteMessage)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.textOnAccent)
                    } else if let step = progress.currentStep {
                        Text(L10n.gettingStartedProgress(
                            progress.currentStepNumber,
                            total: GettingStartedStep.allCases.count))
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(Theme.textOnAccent.opacity(0.85))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.22), in: Capsule())

                        Text(step.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Theme.textOnAccent)

                        Text(TutorialCoach.hint(
                            for: step,
                            on: placement,
                            progress: progress,
                            viewingPatientID: viewingPatientID
                        ))
                            .font(.subheadline)
                            .foregroundStyle(Theme.textOnAccent.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 4)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.textOnAccent.opacity(0.85))
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.gettingStartedDismissAccessibilityLabel)
            }

            if let endsAt = countdownEndsAt {
                ShowcaseAdvanceButton(
                    endsAt: endsAt,
                    duration: countdownDuration,
                    action: onSkipToShowcase
                )
            } else if progress.isComplete {
                VStack(spacing: 8) {
                    if !showcaseLoaded {
                        Button(action: onSkipToShowcase) {
                            Label(L10n.tutorialCoachSkipToShowcase, systemImage: "sparkles")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.surface)
                        .foregroundStyle(Theme.gold)
                    }

                    Button(action: onRestart) {
                        Text(L10n.gettingStartedRestartAction)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.textOnAccent)
                }
            } else if !showcaseLoaded {
                Button(action: onSkipToShowcase) {
                    Label(L10n.tutorialCoachSkipToShowcase, systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.textOnAccent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            LinearGradient(
                colors: [Theme.gold, Theme.warning],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                TimelineView(.animation(minimumInterval: 1 / 20)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 3) / 3
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.18), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: CGFloat(t) * 400 - 200)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .shadow(color: Theme.warning.opacity(0.35), radius: 16, y: -4)
    }
}

/// Skip-to-sample-data control with a fill that drains over the countdown.
struct ShowcaseAdvanceButton: View {
    let endsAt: Date
    let duration: TimeInterval
    var action: () -> Void

    private let buttonHeight: CGFloat = 44

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let remaining = max(0, endsAt.timeIntervalSince(context.date))
            let fill = duration > 0 ? remaining / duration : 0
            let seconds = Int(ceil(remaining))

            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text(L10n.tutorialCoachSkipToShowcase)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("\(seconds)")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .contentTransition(.numericText())
                }
                .font(.subheadline)
                .foregroundStyle(Theme.gold)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight)
                .background {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.22))
                        GeometryReader { geo in
                            Capsule()
                                .fill(Theme.surface)
                                .frame(width: max(0, geo.size.width * fill), height: geo.size.height)
                        }
                        .clipShape(Capsule())
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .accessibilityLabel(L10n.tutorialCoachSkipToShowcase)
            .accessibilityValue(L10n.showcaseCountdownSeconds(seconds))
        }
        .frame(height: buttonHeight)
    }
}

#Preview("Coach — create patient") {
    TutorialCoachCard(
        progress: .empty,
        placement: .patientList,
        showcaseLoaded: false,
        onRestart: {},
        onDismiss: {},
        onSkipToShowcase: {}
    )
    .background(Theme.base)
    .appTextSize()
}
