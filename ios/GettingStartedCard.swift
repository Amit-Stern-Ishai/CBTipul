import Foundation
import SwiftUI

/// Checklist steps for the demo-mode tutorial (in order).
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

    var highlight: TutorialHighlight {
        switch self {
        case .createPatient: .addPatient
        case .createSession: .sessionsEntry
        case .fillQuestionnaire: .fillQuestionnaire
        case .recordSessionSummary: .recordNotes
        case .createAISummary: .aiSummary
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

    static let empty = GettingStartedProgress(
        hasPatient: false,
        hasSession: false,
        hasQuestionnaire: false,
        hasSessionNotes: false,
        hasAISummary: false
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

    /// First incomplete step, or `nil` when the checklist is done.
    var currentStep: GettingStartedStep? {
        GettingStartedStep.allCases.first { !isComplete($0) }
    }

    func isUnlocked(_ step: GettingStartedStep) -> Bool {
        guard let current = currentStep else { return true }
        return step.rawValue <= current.rawValue
    }

    /// Builds progress from the local demo clinic.
    ///
    /// Only user-created demo patients (`demo-user-…`) count — showcase
    /// seed patients are for browsing only.
    static func evaluate(
        patients: [Patient],
        questionnairesForPatient: (Patient) -> [CompletedQuestionnaire]?
    ) -> GettingStartedProgress {
        let tutorialPatients = patients.filter { DemoData.isTutorialPatientID($0.id) }
        let hasPatient = !tutorialPatients.isEmpty
        let hasSession = tutorialPatients.contains { !$0.sessions.isEmpty }
        let hasQuestionnaire = tutorialPatients.contains { patient in
            guard let records = questionnairesForPatient(patient) else { return false }
            return !records.isEmpty
        }
        let hasSessionNotes = tutorialPatients.contains { patient in
            patient.sessions.contains {
                !$0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
        let hasAISummary = tutorialPatients.contains { patient in
            patient.sessions.contains { $0.structuredNotes != nil }
        }
        return GettingStartedProgress(
            hasPatient: hasPatient,
            hasSession: hasSession,
            hasQuestionnaire: hasQuestionnaire,
            hasSessionNotes: hasSessionNotes,
            hasAISummary: hasAISummary
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

/// Dismissible Getting Started card for the patient list home screen.
struct GettingStartedCard: View {
    let progress: GettingStartedProgress
    var onSelectStep: (GettingStartedStep) -> Void
    var onRestart: () -> Void
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

            if progress.isComplete {
                Button(action: onRestart) {
                    Text(L10n.gettingStartedRestartAction)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                VStack(spacing: 0) {
                    ForEach(GettingStartedStep.allCases) { step in
                        let complete = progress.isComplete(step)
                        let unlocked = progress.isUnlocked(step)
                        let current = progress.currentStep == step
                        Button {
                            guard unlocked else { return }
                            onSelectStep(step)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: complete
                                      ? "checkmark.circle.fill"
                                      : (unlocked ? "circle" : "lock.fill"))
                                    .font(.body)
                                    .foregroundStyle(
                                        complete ? Theme.success
                                        : (unlocked ? Theme.textFaint : Theme.textFaint.opacity(0.55))
                                    )
                                Text(step.title)
                                    .font(.subheadline.weight(current ? .semibold : .regular))
                                    .foregroundStyle(
                                        complete ? Theme.textBody
                                        : (unlocked ? Theme.textBright : Theme.textFaint)
                                    )
                                    .strikethrough(complete, color: Theme.textFaint)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                if unlocked && !complete {
                                    Image(systemName: "chevron.left")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Theme.textFaint)
                                }
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!unlocked)
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
            hasPatient: true,
            hasSession: false,
            hasQuestionnaire: false,
            hasSessionNotes: false,
            hasAISummary: false
        ),
        onSelectStep: { _ in },
        onRestart: {},
        onDismiss: {}
    )
    .padding()
    .background(Theme.base)
    .appTextSize()
}
