import SwiftUI

/// Identifiable wrapper so the preparation can be presented with `.sheet(item:)`.
struct NextSessionPreparationResult: Identifiable {
    let id = UUID()
    let response: WhisperService.PrepareSessionResponse
    var isOutdated: Bool = false
}

/// The latest "prepare next session" result, stored locally per patient
/// (device only, never synced to the database). Patient data is sensitive,
/// so the file is written with complete file protection.
nonisolated struct SavedPreparation: Codable {
    let generatedAt: Date
    let response: WhisperService.PrepareSessionResponse

    private static func fileURL(for patientID: DatabaseID) -> URL {
        URL.cachesDirectory.appending(path: "preparation-\(patientID.queryValue).json")
    }

    static func load(for patientID: DatabaseID) -> SavedPreparation? {
        guard let data = try? Data(contentsOf: fileURL(for: patientID)) else { return nil }
        return try? JSONDecoder().decode(SavedPreparation.self, from: data)
    }

    @discardableResult
    static func save(_ response: WhisperService.PrepareSessionResponse,
                     for patientID: DatabaseID) -> SavedPreparation {
        let saved = SavedPreparation(generatedAt: .now, response: response)
        if let data = try? JSONEncoder().encode(saved) {
            try? data.write(to: fileURL(for: patientID),
                            options: [.atomic, .completeFileProtection])
        }
        return saved
    }
}

/// Pre-session CBT supervision/formulation briefing.
///
/// Ordered so the therapist can scan the clinical story top to bottom:
/// what has been happening (summary) → recurring automatic thoughts → the
/// cycles that may be maintaining them → the deeper belief possibly involved
/// → what changed, questionnaire insights, supervision questions, and what
/// to explore next. AI inferences carry hypothesis markers and tentative
/// wording throughout; empty sections are hidden. Uses the same card
/// language as the session review screen.
struct NextSessionPreparationView: View {
    let response: WhisperService.PrepareSessionResponse
    var isOutdated: Bool = false

    @Environment(\.dismiss) private var dismiss

    private var preparation: WhisperService.NextSessionPreparation { response.preparation }

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
                    if isOutdated {
                        Label(L10n.preparationOutdatedMessage,
                              systemImage: "clock.badge.exclamationmark")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.orange.opacity(0.12))
                            )
                    }

                    if !preparation.executiveSummary.isEmpty {
                        card {
                            Text(preparation.executiveSummary)
                                .font(.body)
                                .lineSpacing(4)
                        }
                    }

                    section(L10n.recurringNatsSection,
                            items: preparation.recurringNats) { item in
                        natCard(item)
                    }

                    section(L10n.maintenanceCyclesSection,
                            subtitle: L10n.maintenanceCyclesSubtitle,
                            items: preparation.cbtCycles) { item in
                        cycleCard(item)
                    }

                    if let coreBelief = preparation.coreBeliefHypothesis {
                        coreBeliefSection(coreBelief)
                    }

                    section(L10n.whatChangedSection,
                            items: preparation.whatChanged) { item in
                        card {
                            Text(item.observation)
                                .font(.headline)
                            if !item.significance.isEmpty {
                                labeledText(L10n.whyItMattersLabel, item.significance)
                            }
                            evidenceDisclosure(item.evidence)
                        }
                    }

                    section(L10n.questionnaireInsightsSection,
                            items: preparation.questionnaireInsights) { item in
                        card {
                            Text(item.observation)
                                .font(.headline)
                            if !item.clinicalRelevance.isEmpty {
                                Text(item.clinicalRelevance)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            evidenceDisclosure(item.evidence)
                        }
                    }

                    section(L10n.supervisionConsiderSection,
                            items: preparation.supervisoryObservations) { item in
                        supervisionCard(item)
                    }

                    section(L10n.priorityFollowUpsSection,
                            items: preparation.priorityFollowUps) { item in
                        card {
                            HStack(alignment: .firstTextBaseline) {
                                Text(item.item)
                                    .font(.headline)
                                Spacer()
                                priorityBadge(item.priority)
                            }
                            if !item.reason.isEmpty {
                                Text(item.reason)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if !item.source.isEmpty {
                                Text(L10n.sourceLine(item.source))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    section(L10n.treatmentFocusSection,
                            subtitle: L10n.treatmentFocusSubtitle,
                            items: preparation.possibleTreatmentFocus) { item in
                        card {
                            HStack(alignment: .firstTextBaseline) {
                                Text(item.focus)
                                    .font(.headline)
                                Spacer()
                                priorityBadge(item.priority)
                            }
                            if !item.rationale.isEmpty {
                                Text(item.rationale)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    section(L10n.suggestedQuestionsSection,
                            items: preparation.suggestedQuestions) { item in
                        card {
                            HStack(alignment: .firstTextBaseline) {
                                Text(item.question)
                                    .font(.body.weight(.medium).italic())
                                Spacer()
                                priorityBadge(item.priority)
                            }
                            if !item.purpose.isEmpty {
                                Text(item.purpose)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !preparation.unresolvedIssues.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.unresolvedIssuesPreparationSection)
                                .font(.title3.bold())
                            card {
                                ForEach(preparation.unresolvedIssues.indices, id: \.self) { index in
                                    Text(L10n.bulleted(preparation.unresolvedIssues[index]))
                                        .font(.subheadline)
                                }
                            }
                        }
                    }

                    VStack(spacing: 4) {
                        Text(L10n.aiDisclaimer)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(L10n.tokensUsed(response.usage.totalTokens))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L10n.sessionPreparationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) { dismiss() }
                }
            }
        }
        .appTextSize()
    }

    // MARK: - Formulation cards

    /// One recurring automatic thought: the thought itself, where it shows
    /// up, the possible thinking patterns (labeled as possibilities, never
    /// diagnoses), with evidence one tap away.
    private func natCard(_ item: WhisperService.NextSessionPreparation.RecurringNAT) -> some View {
        card {
            HStack(alignment: .top) {
                Text(item.thought)
                    .font(.body.weight(.semibold).italic())
                Spacer()
                hypothesisBadge
            }
            if !item.situations.isEmpty {
                labeledText(L10n.situationsLabel, item.situations.joined(separator: " · "))
            }
            if !item.cognitivePatterns.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.possibleThinkingPatternsLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.cognitivePatterns.joined(separator: " · "))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.tint)
                }
            }
            evidenceDisclosure(item.evidence)
            confidenceText(item.confidence)
        }
    }

    /// A hypothesized maintenance cycle as a vertical CBT chain. Stages the
    /// AI could not evidence are omitted entirely.
    private func cycleCard(_ cycle: WhisperService.NextSessionPreparation.CBTCycle) -> some View {
        let stages = cycleStages(of: cycle)
        return card {
            HStack {
                Text(L10n.possibleMaintenanceCycleLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                hypothesisBadge
            }
            ForEach(stages.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 2) {
                    Text(stages[index].title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(stages[index].text)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.tertiarySystemFill))
                )
                if index < stages.count - 1 {
                    Image(systemName: "arrow.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 16)
                }
            }
            evidenceDisclosure(cycle.evidence)
            confidenceText(cycle.confidence)
        }
    }

    private func cycleStages(of cycle: WhisperService.NextSessionPreparation.CBTCycle)
        -> [(title: String, text: String)] {
        let pairs: [(String, String?)] = [
            (L10n.situationLabel, cycle.triggerSituation),
            (L10n.automaticThoughtLabel, cycle.automaticThought),
            (L10n.emotionLabel, cycle.emotion),
            (L10n.behaviorLabel, cycle.behavior),
            (L10n.shortTermConsequenceLabel, cycle.shortTermConsequence),
            (L10n.longTermConsequenceLabel, cycle.longTermConsequence),
        ]
        return pairs.compactMap { title, text in
            guard let text, !text.isEmpty else { return nil }
            return (title, text)
        }
    }

    /// Deliberately subdued and tentative: a softened card with a dashed
    /// border, so the hypothesis reads as exploratory next to the
    /// evidence-grounded sections around it.
    private func coreBeliefSection(_ item: WhisperService.NextSessionPreparation.CoreBeliefHypothesis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.possibleCoreBeliefSection)
                    .font(.title3.bold())
                Text(L10n.coreBeliefSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(item.belief)
                        .font(.body.weight(.medium).italic())
                    Spacer()
                    hypothesisBadge
                }
                if !item.evidence.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.evidenceLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(item.evidence.indices, id: \.self) { index in
                            Text(L10n.bulleted(item.evidence[index]))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                confidenceText(item.confidence)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .opacity(0.6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(.separator),
                                  style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            )
        }
    }

    /// Observation and why it matters, with the reflective question in the
    /// tinted inset so it draws the eye.
    private func supervisionCard(_ item: WhisperService.NextSessionPreparation.SupervisoryObservation) -> some View {
        card {
            HStack(alignment: .top) {
                Text(item.observation)
                    .font(.body)
                Spacer()
                hypothesisBadge
            }
            if !item.whyItMatters.isEmpty {
                Text(item.whyItMatters)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !item.questionForTherapist.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label(L10n.questionToConsiderLabel, systemImage: "magnifyingglass")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                    Text(item.questionForTherapist)
                        .font(.body.weight(.medium).italic())
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.tint.opacity(0.08))
                )
            }
            confidenceText(item.confidence)
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
