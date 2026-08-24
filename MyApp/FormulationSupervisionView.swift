import SwiftUI

/// Identifiable wrapper so the supervision can be presented with `.sheet(item:)`.
struct FormulationSupervisionResult: Identifiable {
    let id = UUID()
    let supervision: FormulationSupervision
}

/// AI supervision of the therapist's own formulation ("Challenge My
/// Formulation"). Read-only reflection: hypotheses to weigh, never changes
/// to apply — nothing here writes back into `PatientFormulation`, and the
/// therapist remains the decision maker. Empty sections are hidden, so a
/// compact result (little to challenge) reads naturally. Uses the same
/// card language as the session preparation screen.
struct FormulationSupervisionView: View {
    let supervision: FormulationSupervision

    @Environment(\.dismiss) private var dismiss

    /// Normalized priority/confidence level for display.
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
            case .high: return L10n.priorityHigh
            case .medium: return L10n.priorityMedium
            case .low: return L10n.priorityLow
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    disclaimerHeader

                    section(L10n.supportsFormulationSection,
                            items: supervision.supportingEvidence) { item in
                        pointCard(item)
                    }

                    section(L10n.mayNotFitSection,
                            subtitle: L10n.mayNotFitSubtitle,
                            items: supervision.challengingEvidence) { item in
                        pointCard(item)
                    }

                    blindSpotsSection

                    section(L10n.alternativeFormulationsSection,
                            subtitle: L10n.alternativeFormulationsSubtitle,
                            items: supervision.alternativeFormulations) { item in
                        alternativeCard(item)
                    }

                    section(L10n.questionsToExploreSection,
                            items: supervision.questionsToExplore) { item in
                        questionCard(item)
                    }

                    section(L10n.treatmentImplicationsSection,
                            subtitle: L10n.treatmentImplicationsSubtitle,
                            items: supervision.treatmentImplications) { item in
                        implicationCard(item)
                    }

                    Text(L10n.aiDisclaimer)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L10n.aiSupervisionSection)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) { dismiss() }
                }
            }
        }
        .appTextSize()
    }

    // MARK: - Header

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

    // MARK: - Cards

    /// A supporting or challenging observation with its evidence one tap away.
    private func pointCard(_ item: SupervisionPoint) -> some View {
        card {
            Text(item.observation)
                .font(.headline)
            evidenceDisclosure(item.evidence)
            confidenceText(item.confidence)
        }
    }

    /// The most visually prominent section: hypothesized blind spots, each
    /// marked as a hypothesis and outlined so it draws the eye.
    @ViewBuilder
    private var blindSpotsSection: some View {
        if !supervision.possibleBlindSpots.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.possibleBlindSpotsSection)
                        .font(.title2.bold())
                    Text(L10n.blindSpotsSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(supervision.possibleBlindSpots.indices, id: \.self) { index in
                    blindSpotCard(supervision.possibleBlindSpots[index])
                }
            }
        }
    }

    private func blindSpotCard(_ item: SupervisionPoint) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(item.observation)
                    .font(.body.weight(.semibold))
                Spacer()
                hypothesisBadge
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
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.orange.opacity(0.5), lineWidth: 1.5)
        )
    }

    private func alternativeCard(_ item: AlternativeFormulation) -> some View {
        card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.possibleFormulationLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(item.formulation)
                        .font(.body.weight(.medium).italic())
                }
                Spacer()
                hypothesisBadge
            }
            if !item.whatItWouldExplain.isEmpty {
                labeledText(L10n.whatThisMightExplainLabel, item.whatItWouldExplain)
            }
            evidenceDisclosure(item.evidence)
            confidenceText(item.confidence)
        }
    }

    private func questionCard(_ item: SuggestedQuestion) -> some View {
        card {
            HStack(alignment: .firstTextBaseline) {
                Text(item.question)
                    .font(.body.weight(.medium).italic())
                Spacer()
                priorityBadge(item.priority)
            }
            if !item.purpose.isEmpty {
                Text(L10n.purposeLine(item.purpose))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func implicationCard(_ item: TreatmentImplication) -> some View {
        card {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.possibleAreaToConsiderLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline) {
                    Text(item.implication)
                        .font(.headline)
                    Spacer()
                    priorityBadge(item.priority)
                }
            }
            if !item.rationale.isEmpty {
                Text(item.rationale)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Section and card scaffolding

    /// A titled group of cards; renders nothing when there are no items.
    @ViewBuilder
    private func section<Item>(_ title: String,
                               subtitle: String? = nil,
                               items: [Item],
                               @ViewBuilder cardContent: @escaping (Item) -> some View) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title3.bold())
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

    /// High priority stands out; medium and low stay quiet.
    @ViewBuilder
    private func priorityBadge(_ raw: String) -> some View {
        switch Level(raw) {
        case .high:
            Text(L10n.priorityHigh)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.orange))
        case .medium:
            Text(L10n.priorityMedium)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color(.tertiarySystemFill)))
        case .low:
            Text(L10n.priorityLow)
                .font(.caption)
                .foregroundStyle(.tertiary)
        case nil:
            if !raw.isEmpty {
                Text(raw.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func confidenceText(_ raw: String) -> some View {
        if let level = Level(raw) {
            Text(L10n.confidenceLine(level.label))
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
    private func evidenceDisclosure(_ evidence: String) -> some View {
        if !evidence.isEmpty {
            DisclosureGroup {
                Text(evidence)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            } label: {
                Text(L10n.evidenceLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
