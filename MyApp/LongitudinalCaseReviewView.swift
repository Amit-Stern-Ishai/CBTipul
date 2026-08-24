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
            case .high: return "High confidence"
            case .medium: return "Medium confidence"
            case .low: return "Low confidence"
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

                    section("✅ Improvements",
                            items: response.improvements) { item in
                        improvementCard(item)
                    }

                    section("⚠️ Persistent Difficulties",
                            subtitle: "Things that do not appear to have changed sufficiently yet",
                            items: response.persistentDifficulties) { item in
                        findingCard(item, outlined: true)
                    }

                    section("🔄 Recurring Patterns",
                            subtitle: "What keeps coming back across the treatment",
                            items: response.recurringPatterns) { item in
                        findingCard(item)
                    }

                    section("🔀 Important Changes",
                            items: response.importantChanges) { item in
                        findingCard(item)
                    }

                    section("🎯 Treatment Goal Progress",
                            items: response.treatmentGoalProgress) { item in
                        goalCard(item)
                    }

                    section("🧠 Formulation Evolution",
                            subtitle: "What appears to be becoming clearer? Hypotheses and interpretations, not established facts",
                            items: response.formulationEvolution) { item in
                        findingCard(item, showsHypothesisBadge: true)
                    }

                    section("👀 Worth Paying Attention To",
                            subtitle: "Areas the therapist may want to investigate — not instructions",
                            items: response.clinicalAttentionPoints,
                            prominent: true) { item in
                        findingCard(item, outlined: true, showsHypothesisBadge: true)
                    }

                    questionsSection

                    Text("AI-generated clinical support. Use your professional judgment.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("📈 Longitudinal Case Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .appTextSize()
    }

    // MARK: - Header, trajectory, and empty state

    private var disclaimerHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AI-generated supervision")
                .font(.footnote.weight(.semibold))
            Text("These are hypotheses for clinical reflection, not established conclusions.")
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
                Text("📈 Overall Trajectory")
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
        Text("אין מספיק מידע לאורך זמן כדי להסיק מסקנות נוספות בשלב זה.")
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
                Text("מה השתפר")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(item.observation)
                    .font(.headline)
            }
            if !item.interpretation.isEmpty {
                labeledText("פרשנות אפשרית", item.interpretation)
            }
            evidenceDisclosure(item.evidence, label: "למה אנחנו חושבים כך")
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
                labeledText("Possible interpretation", item.interpretation)
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
                labeledText("Current estimate", item.currentEstimate)
            }
            if !item.suggestion.isEmpty {
                labeledText("Possible next step to consider", item.suggestion)
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
                    Text("❓ Questions for Therapist")
                        .font(.title2.bold())
                    Text("For reflective supervision — there are no required answers")
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
        Label("Hypothesis", systemImage: "lightbulb")
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
            case "progressing": return ("Progressing", .green)
            case "partially_progressing": return ("Partially progressing", .green)
            case "unchanged": return ("Unchanged", .secondary)
            case "worsening": return ("Worsening", .orange)
            case "achieved": return ("Achieved", .green)
            case "unclear": return ("Unclear", .secondary)
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
            Text("Confidence: \(raw.capitalized)")
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
                                    label: String = "Evidence") -> some View {
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
