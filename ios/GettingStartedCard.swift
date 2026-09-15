import SwiftUI

/// Checklist steps for the Getting Started card.
enum GettingStartedStep: Int, CaseIterable, Identifiable {
    case demoTour
    case addPatient
    case treatmentGoal
    case firstSession
    case questionnaire
    case sessionSummary
    case preparation

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .demoTour: L10n.gettingStartedStepDemoTour
        case .addPatient: L10n.gettingStartedStepAddPatient
        case .treatmentGoal: L10n.gettingStartedStepTreatmentGoal
        case .firstSession: L10n.gettingStartedStepFirstSession
        case .questionnaire: L10n.gettingStartedStepQuestionnaire
        case .sessionSummary: L10n.gettingStartedStepSessionSummary
        case .preparation: L10n.gettingStartedStepPreparation
        }
    }
}

/// Completion derived from live patient / session / questionnaire / preparation data.
struct GettingStartedProgress: Equatable {
    var hasCompletedDemoTour: Bool
    var hasPatient: Bool
    var hasTreatmentGoal: Bool
    var hasSession: Bool
    var hasQuestionnaire: Bool
    var hasSessionSummary: Bool
    var hasPreparation: Bool

    static let empty = GettingStartedProgress(
        hasCompletedDemoTour: false,
        hasPatient: false,
        hasTreatmentGoal: false,
        hasSession: false,
        hasQuestionnaire: false,
        hasSessionSummary: false,
        hasPreparation: false
    )

    var completedCount: Int {
        [hasCompletedDemoTour, hasPatient, hasTreatmentGoal, hasSession,
         hasQuestionnaire, hasSessionSummary, hasPreparation]
            .filter(\.self)
            .count
    }

    var isComplete: Bool { completedCount == GettingStartedStep.allCases.count }

    func isComplete(_ step: GettingStartedStep) -> Bool {
        switch step {
        case .demoTour: hasCompletedDemoTour
        case .addPatient: hasPatient
        case .treatmentGoal: hasTreatmentGoal
        case .firstSession: hasSession
        case .questionnaire: hasQuestionnaire
        case .sessionSummary: hasSessionSummary
        case .preparation: hasPreparation
        }
    }

    /// Builds progress from the local demo clinic.
    ///
    /// Showcase seed patients are for browsing only. Steps after the demo
    /// tour complete from user-created demo patients (`demo-user-…`).
    static func evaluate(
        patients: [Patient],
        questionnairesForPatient: (Patient) -> [CompletedQuestionnaire]?,
        hasPreparation: (DatabaseID) -> Bool,
        hasCompletedDemoTour: Bool
    ) -> GettingStartedProgress {
        let tutorialPatients = patients.filter { DemoData.isTutorialPatientID($0.id) }
        let hasPatient = !tutorialPatients.isEmpty
        let hasTreatmentGoal = tutorialPatients.contains {
            guard let goal = $0.formulation?.treatmentGoal else { return false }
            return !goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let hasSession = tutorialPatients.contains { !$0.sessions.isEmpty }
        let hasQuestionnaire = tutorialPatients.contains { patient in
            guard let records = questionnairesForPatient(patient) else { return false }
            return !records.isEmpty
        }
        let hasSessionSummary = tutorialPatients.contains { patient in
            patient.sessions.contains(where: Self.sessionHasSummary)
        }
        let hasPreparationFlag = tutorialPatients.contains { hasPreparation($0.id) }
        return GettingStartedProgress(
            hasCompletedDemoTour: hasCompletedDemoTour,
            hasPatient: hasPatient,
            hasTreatmentGoal: hasTreatmentGoal,
            hasSession: hasSession,
            hasQuestionnaire: hasQuestionnaire,
            hasSessionSummary: hasSessionSummary,
            hasPreparation: hasPreparationFlag
        )
    }

    /// Builds progress from the in-memory store and local preparation files.
    @MainActor
    static func evaluate(store: PatientStore, hasCompletedDemoTour: Bool) -> GettingStartedProgress {
        evaluate(
            patients: store.patients,
            questionnairesForPatient: { store.cachedQuestionnaires(for: $0) },
            hasPreparation: { SavedPreparation.load(for: $0) != nil },
            hasCompletedDemoTour: hasCompletedDemoTour
        )
    }

    static func sessionHasSummary(_ session: Session) -> Bool {
        if session.structuredNotes != nil { return true }
        return !session.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// True when there is at least one session summary/notes result or
    /// questionnaire — enough signal for a useful preparation.
    static func hasUsefulPreparationInput(
        patient: Patient,
        questionnaires: [CompletedQuestionnaire]
    ) -> Bool {
        patient.sessions.contains(where: sessionHasSummary) || !questionnaires.isEmpty
    }

    /// Picks the most useful next action when preparation input is missing.
    static func missingPreparationAction(for patient: Patient) -> PreparationMissingAction {
        if patient.sessions.isEmpty { return .addSession }
        if !patient.sessions.contains(where: sessionHasSummary) { return .addSessionSummary }
        return .addQuestionnaire
    }
}

/// Dismissible Getting Started card for the patient list home screen.
struct GettingStartedCard: View {
    let progress: GettingStartedProgress
    var onSelectStep: (GettingStartedStep) -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    if progress.isComplete {
                        Text(L10n.gettingStartedCompleteMessage)
                            .font(.headline)
                            .foregroundStyle(Theme.textBright)
                    } else {
                        Text(L10n.gettingStartedTitle)
                            .font(.headline)
                            .foregroundStyle(Theme.textBright)
                        Text(L10n.gettingStartedSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textBody)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(L10n.gettingStartedProgress(
                            progress.completedCount,
                            total: GettingStartedStep.allCases.count))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.gold)
                            .padding(.top, 2)
                    }
                }
                Spacer(minLength: 8)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textFaint)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.gettingStartedDismissAccessibilityLabel)
            }

            if !progress.isComplete {
                VStack(spacing: 0) {
                    ForEach(GettingStartedStep.allCases) { step in
                        let complete = progress.isComplete(step)
                        Button {
                            onSelectStep(step)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                                    .font(.body)
                                    .foregroundStyle(complete ? Theme.success : Theme.textFaint)
                                Text(step.title)
                                    .font(.subheadline)
                                    .foregroundStyle(complete ? Theme.textBody : Theme.textBright)
                                    .strikethrough(complete, color: Theme.textFaint)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.left")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.textFaint)
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(complete ? [.isSelected] : [])

                        if step != GettingStartedStep.allCases.last {
                            Divider()
                                .overlay(Theme.borderFaint)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Theme.borderDefault, lineWidth: 1)
        )
    }
}

#Preview("Checklist incomplete") {
    GettingStartedCard(
        progress: GettingStartedProgress(
            hasCompletedDemoTour: true,
            hasPatient: true,
            hasTreatmentGoal: true,
            hasSession: false,
            hasQuestionnaire: false,
            hasSessionSummary: false,
            hasPreparation: false
        ),
        onSelectStep: { _ in },
        onDismiss: {}
    )
    .padding()
    .background(Theme.base)
    .appTextSize()
}

#Preview("Checklist complete") {
    GettingStartedCard(
        progress: GettingStartedProgress(
            hasCompletedDemoTour: true,
            hasPatient: true,
            hasTreatmentGoal: true,
            hasSession: true,
            hasQuestionnaire: true,
            hasSessionSummary: true,
            hasPreparation: true
        ),
        onSelectStep: { _ in },
        onDismiss: {}
    )
    .padding()
    .background(Theme.base)
    .appTextSize()
}
