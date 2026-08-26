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
/// what has been happening (summary) → what to follow up on → recurring
/// automatic thoughts → the cycles that may be maintaining them →
/// questionnaire insights → the single recommended treatment focus →
/// questions to explore → the deeper belief possibly involved. AI
/// inferences carry hypothesis markers and tentative wording throughout;
/// empty sections are hidden. Uses the same card language as the session
/// review screen.
struct NextSessionPreparationView: View {
    let response: WhisperService.PrepareSessionResponse
    var isOutdated: Bool = false

    @Environment(\.dismiss) private var dismiss

    private var preparation: WhisperService.NextSessionPreparation { response.preparation }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if isOutdated {
                        Label(L10n.preparationOutdatedMessage,
                              systemImage: "clock.badge.exclamationmark")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.warning)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Theme.warning.opacity(0.12))
                            )
                    }

                    if !preparation.executiveSummary.isEmpty {
                        card {
                            Text(preparation.executiveSummary)
                                .font(.body)
                                .lineSpacing(4)
                        }
                    }

                    section(L10n.priorityFollowUpsSection,
                            items: preparation.priorityFollowUps) { item in
                        card {
                            Text(item.item)
                                .font(.headline)
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

                    section(L10n.recurringNatsSection,
                            items: preparation.recurringNats) { item in
                        natCard(item)
                    }

                    section(L10n.maintenanceCyclesSection,
                            subtitle: L10n.maintenanceCyclesSubtitle,
                            items: preparation.cbtCycles) { item in
                        cycleCard(item)
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

                    if let treatmentFocus = preparation.treatmentFocus {
                        treatmentFocusSection(treatmentFocus)
                    }

                    section(L10n.suggestedQuestionsSection,
                            items: preparation.suggestedQuestions) { item in
                        card {
                            Text(item.question)
                                .font(.body.weight(.medium).italic())
                            if !item.purpose.isEmpty {
                                Text(item.purpose)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let coreBelief = preparation.coreBeliefHypothesis {
                        coreBeliefSection(coreBelief)
                    }

                    VStack(spacing: 4) {
                        Text(L10n.aiDisclaimer)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
//                        Text(L10n.tokensUsed(response.usage.totalTokens))
//                            .font(.caption2)
//                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                }
                .padding()
            }
            .background(Theme.base)
            .navigationTitle(L10n.sessionPreparationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label(L10n.back, systemImage: "chevron.backward")
                            .labelStyle(.titleAndIcon)
                    }
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
            evidenceDisclosure(item.evidence)
            if !item.cognitivePatterns.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.possibleThinkingPatternsLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(item.cognitivePatterns.indices, id: \.self) { index in
                        cognitivePatternRow(item.cognitivePatterns[index])
                    }
                }
            }
        }
    }

    /// One possible classification of the thought: the pattern name with a
    /// subtle confidence caption alongside (this varies, unlike the NAT's
    /// always-high confidence), and the model's reasoning underneath.
    private func cognitivePatternRow(_ item: WhisperService.CognitivePattern) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.pattern)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tint)
                Spacer()
                if let caption = confidenceCaption(for: item.confidence) {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if !item.evidence.isEmpty {
                Text(item.evidence)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.elevated)
        )
    }

    /// Hebrew caption for a pattern's confidence; unknown raw values show
    /// as-is, and empty ones (old saved preparations) show nothing.
    private func confidenceCaption(for raw: String) -> String? {
        let lowered = raw.lowercased()
        if lowered.contains("high") || lowered.contains("גבוה") { return L10n.confidenceHigh }
        if lowered.contains("med") || lowered.contains("בינוני") { return L10n.confidenceMedium }
        if lowered.contains("low") || lowered.contains("נמוך") { return L10n.confidenceLow }
        return raw.isEmpty ? nil : raw
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
                        .fill(Theme.elevated)
                )
                if index < stages.count - 1 {
                    Image(systemName: "arrow.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 16)
                }
            }
            evidenceDisclosure(cycle.evidence)
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.surface)
                    .opacity(0.6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Theme.borderDefault,
                                  style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            )
        }
    }

    /// The single recommended focus for the next session. Accent-tinted so
    /// it reads as the preparation's primary recommendation.
    private func treatmentFocusSection(_ item: WhisperService.NextSessionPreparation.TreatmentFocus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.treatmentFocusSection)
                    .font(.title3.bold())
                Text(L10n.treatmentFocusSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label(item.focus, systemImage: "scope")
                    .font(.headline)
                if !item.rationale.isEmpty {
                    Text(item.rationale)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.goldGhost)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Theme.gold.opacity(0.45))
            )
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
                    .fill(Theme.surface)
            )
    }

    // MARK: - Small helpers

    /// Marks content the AI inferred, so hypotheses never read as facts.
    private var hypothesisBadge: some View {
        Label(L10n.hypothesisBadge, systemImage: "lightbulb")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.warning)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Theme.warning.opacity(0.12)))
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
