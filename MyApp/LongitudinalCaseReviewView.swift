import SwiftUI

/// Identifiable wrapper so the review can be presented with `.sheet(item:)`.
struct LongitudinalCaseReviewResult: Identifiable {
    let id = UUID()
    let response: LongitudinalCaseReviewResponse
}

/// 📈 Longitudinal Case Review — what has changed in this case over time,
/// what has not, and what deserves attention now. Read-only supervision:
/// observations are not clinical facts, interpretations are not diagnoses,
/// and suggestions are not treatment instructions. Nothing here is ever
/// persisted or written into the patient's data or formulation. Empty
/// sections are hidden. Uses the same card language as the other
/// supervision screens.
struct LongitudinalCaseReviewView: View {
    let response: LongitudinalCaseReviewResponse

    @Environment(\.dismiss) private var dismiss

    /// Normalized confidence level for display.
    private enum Level {
        case high, medium, low

        init?(_ raw: String) {
            let lowered = raw.lowercased()
            if lowered.contains("high") || lowered.contains("גבוה") {
                self = .high
            } else if lowered.contains("med") || lowered.contains("בינוני") {
                self = .medium
            } else if lowered.contains("low") || lowered.contains("נמוך") {
                self = .low
            } else {
                return nil
            }
        }

        var label: String {
            switch self {
            case .high: return L10n.highConfidenceLabel
            case .medium: return L10n.mediumConfidenceLabel
            case .low: return L10n.lowConfidenceLabel
            }
        }
    }

    /// True when nothing beyond the overall trajectory came back.
    private var hasOnlyTrajectory: Bool {
        response.improvements.isEmpty
            && response.persistentDifficulties.isEmpty
            && response.recurringPatterns.isEmpty
            && response.importantChanges.isEmpty
            && response.treatmentGoalProgress.isEmpty
            && response.formulationEvolution.isEmpty
            && response.clinicalAttentionPoints.isEmpty
            && response.questionsForTherapist.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    disclaimerHeader

                    trajectorySection

                    if hasOnlyTrajectory {
                        insufficientEvidenceCard
                    }

                    section(L10n.improvementsSection,
                            items: response.improvements) { item in
                        improvementCard(item)
                    }

                    section(L10n.persistentDifficultiesSection,
                            subtitle: L10n.persistentDifficultiesSubtitle,
                            items: response.persistentDifficulties) { item in
                        findingCard(item, outlined: true)
                    }

                    section(L10n.recurringPatternsSection,
                            subtitle: L10n.recurringPatternsSubtitle,
                            items: response.recurringPatterns) { item in
                        findingCard(item)
                    }

                    section(L10n.importantChangesSection,
                            items: response.importantChanges) { item in
                        findingCard(item)
                    }

                    section(L10n.treatmentGoalProgressSection,
                            items: response.treatmentGoalProgress) { item in
                        goalCard(item)
                    }

                    section(L10n.formulationEvolutionSection,
                            subtitle: L10n.formulationEvolutionSubtitle,
                            items: response.formulationEvolution) { item in
                        findingCard(item, showsHypothesisBadge: true)
                    }

                    section(L10n.worthAttentionSection,
                            subtitle: L10n.worthAttentionSubtitle,
                            items: response.clinicalAttentionPoints,
                            prominent: true) { item in
                        findingCard(item, outlined: true, showsHypothesisBadge: true)
                    }

                    questionsSection

                    Text(L10n.aiDisclaimer)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L10n.longitudinalCaseReviewTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) { dismiss() }
                }
            }
        }
        .appTextSize()
    }

    // MARK: - Header, trajectory, and empty state

    private var disclaimerHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.aiGeneratedSupervisionLabel)
                .font(.footnote.weight(.semibold))
            Text(L10n.supervisionDisclaimerBody)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.tint.opacity(0.08))
        )
    }

    @ViewBuilder
    private var trajectorySection: some View {
        if !response.overallTrajectory.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.overallTrajectorySection)
                    .font(.title3.bold())
                card {
                    Text(response.overallTrajectory)
                        .font(.body)
                        .lineSpacing(4)
                }
            }
        }
    }

    /// Shown when the history supported no conclusions beyond the trajectory.
    private var insufficientEvidenceCard: some View {
        Text(L10n.insufficientLongitudinalDataMessage)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
    }

    // MARK: - Cards

    /// An improvement, with the labels the feature specifies in Hebrew.
    private func improvementCard(_ item: LongitudinalFinding) -> some View {
        card {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.whatImprovedLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(item.observation)
                    .font(.headline)
            }
            if !item.interpretation.isEmpty {
                labeledText(L10n.possibleInterpretationHebrewLabel, item.interpretation)
            }
            evidenceDisclosure(item.evidence, label: L10n.whyWeThinkSoLabel)
            confidenceText(item.confidence)
        }
    }

    /// A generic longitudinal finding. `outlined` adds the orange border
    /// used for content that should be harder to scroll past.
    private func findingCard(_ item: LongitudinalFinding,
                             outlined: Bool = false,
                             showsHypothesisBadge: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(item.observation)
                    .font(.headline)
                if showsHypothesisBadge {
                    Spacer()
                    hypothesisBadge
                }
            }
            if !item.interpretation.isEmpty {
                labeledText(L10n.possibleInterpretationLabel, item.interpretation)
            }
            evidenceDisclosure(item.evidence)
            confidenceText(item.confidence)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay {
            if outlined {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.orange.opacity(0.5), lineWidth: 1.5)
            }
        }
    }

    private func goalCard(_ item: TreatmentGoalProgress) -> some View {
        card {
            HStack(alignment: .firstTextBaseline) {
                Text(item.goal)
                    .font(.headline)
                Spacer()
                statusBadge(item.status)
            }
            if !item.currentEstimate.isEmpty {
                labeledText(L10n.currentEstimateLabel, item.currentEstimate)
            }
            if !item.suggestion.isEmpty {
                labeledText(L10n.possibleNextStepLabel, item.suggestion)
            }
            evidenceDisclosure(item.evidence)
            confidenceText(item.confidence)
        }
    }

    @ViewBuilder
    private var questionsSection: some View {
        if !response.questionsForTherapist.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.questionsForTherapistSection)
                        .font(.title2.bold())
                    Text(L10n.questionsForTherapistSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(response.questionsForTherapist.indices, id: \.self) { index in
                    Text(response.questionsForTherapist[index])
                        .font(.body.weight(.medium).italic())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.tint.opacity(0.08))
                        )
                }
            }
        }
    }

    // MARK: - Section and card scaffolding

    /// A titled group of cards; renders nothing when there are no items.
    /// `prominent` sections use a larger title so they draw the eye.
    @ViewBuilder
    private func section<Item>(_ title: String,
                               subtitle: String? = nil,
                               items: [Item],
                               prominent: Bool = false,
                               @ViewBuilder cardContent: @escaping (Item) -> some View) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(prominent ? .title2.bold() : .title3.bold())
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(items.indices, id: \.self) { index in
                    cardContent(items[index])
                }
            }
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
    }

    // MARK: - Small helpers

    /// Marks content the AI inferred, so hypotheses never read as facts.
    private var hypothesisBadge: some View {
        Label(L10n.hypothesisBadge, systemImage: "lightbulb")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(.orange.opacity(0.12)))
    }

    /// Friendly goal-status label and a quiet capsule; worsening is the
    /// only status that visually raises its voice. Raw values never show.
    @ViewBuilder
    private func statusBadge(_ raw: String) -> some View {
        let (label, color): (String, Color) = {
            switch raw.lowercased() {
            case "progressing": return (L10n.goalStatusProgressing, .green)
            case "partially_progressing": return (L10n.goalStatusPartiallyProgressing, .green)
            case "unchanged": return (L10n.goalStatusUnchanged, .secondary)
            case "worsening": return (L10n.goalStatusWorsening, .orange)
            case "achieved": return (L10n.goalStatusAchieved, .green)
            case "unclear": return (L10n.goalStatusUnclear, .secondary)
            default:
                return (raw.replacingOccurrences(of: "_", with: " ").capitalized, .secondary)
            }
        }()
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    @ViewBuilder
    private func confidenceText(_ raw: String) -> some View {
        if let level = Level(raw) {
            Text(level.label)
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else if !raw.isEmpty {
            Text(L10n.confidenceLine(raw.capitalized))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func labeledText(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
        }
    }

    /// Evidence stays one tap away so cards remain scannable.
    @ViewBuilder
    private func evidenceDisclosure(_ evidence: String,
                                    label: String = L10n.evidenceLabel) -> some View {
        if !evidence.isEmpty {
            DisclosureGroup {
                Text(evidence)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            } label: {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
