import SwiftUI

/// Identifiable wrapper so the analysis can be presented with `.sheet(item:)`.
struct SessionAnalysisResult: Identifiable {
    let id = UUID()
    let analysis: WhisperService.CBTSessionAnalysis
    /// True for a freshly generated summary that hasn't been saved yet, so
    /// closing the screen asks whether to keep it.
    let requiresSaveDecision: Bool
}

/// Session review flow for an AI analysis.
///
/// The first screen orients the therapist: the session summary as editable
/// prose, followed by the key situations. The full analysis (emotions,
/// thoughts, patterns, hypotheses, ...) is one tap deeper.
///
/// Closing the screen asks whether to save when the analysis is freshly
/// generated (`requiresSaveDecision`) or has been edited.
struct SessionAnalysisView: View {
    let analysis: WhisperService.CBTSessionAnalysis
    var requiresSaveDecision: Bool = false
    var onSave: ((WhisperService.CBTSessionAnalysis) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var isShowingSaveAsk = false
    /// The therapist's working copy; what gets saved.
    @State private var edited: WhisperService.CBTSessionAnalysis

    init(analysis: WhisperService.CBTSessionAnalysis,
         requiresSaveDecision: Bool = false,
         onSave: ((WhisperService.CBTSessionAnalysis) -> Void)? = nil) {
        self.analysis = analysis
        self.requiresSaveDecision = requiresSaveDecision
        self.onSave = onSave
        _edited = State(initialValue: analysis)
    }

    /// Whether dismissing without deciding would lose anything.
    private var needsSaveDecision: Bool {
        onSave != nil && (requiresSaveDecision || edited != analysis)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    TextField(L10n.sessionSummaryPlaceholder, text: $edited.sessionSummary, axis: .vertical)
                        .font(.body)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !edited.keySituations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.keySituationsSection)
                                .font(.title3.bold())

                            ForEach(edited.keySituations.indices, id: \.self) { index in
                                keySituationCard(index: index)
                            }
                        }
                    }

                    if !edited.possibleNats.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.possibleAutomaticThoughtsSection)
                                .font(.title3.bold())

                            ForEach(edited.possibleNats.indices, id: \.self) { index in
                                natCard(index: index)
                            }
                        }
                    }

                    if !edited.possibleNats.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.cbtCycleSection)
                                .font(.title3.bold())

                            ForEach(edited.possibleNats.indices, id: \.self) { index in
                                cycleCard(index: index)
                            }
                        }
                    }

                    if !edited.therapistReflections.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.thingsWorthExploringSection)
                                .font(.title3.bold())

                            ForEach(edited.therapistReflections.indices, id: \.self) { index in
                                explorationCard(index: index)
                            }
                        }
                    }

                    if !edited.followUpQuestions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.questionsToRevisitSection)
                                .font(.title3.bold())

                            ForEach(edited.followUpQuestions.indices, id: \.self) { index in
                                followUpCard(index: index)
                            }
                        }
                    }

                    NavigationLink {
                        SessionAnalysisDetailView(analysis: edited)
                    } label: {
                        HStack {
                            Label(L10n.fullAnalysisTitle, systemImage: "list.bullet.rectangle")
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L10n.sessionSummaryTitle)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) {
                        if needsSaveDecision {
                            isShowingSaveAsk = true
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .alert(L10n.saveSummaryPrompt,
                   isPresented: $isShowingSaveAsk) {
                Button(L10n.save) {
                    onSave?(edited)
                    dismiss()
                }
                Button(L10n.dontSaveAction, role: .destructive) { dismiss() }
                Button(L10n.keepViewingAction, role: .cancel) {}
            }
        }
        .interactiveDismissDisabled(needsSaveDecision)
        .appTextSize()
    }

    /// One automatic thought: source badge and confidence on top, the quoted
    /// thought, then its situation and emotion side by side. All editable.
    private func natCard(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sourceBadge(for: edited.possibleNats[index].source)
                Spacer()
                if !edited.possibleNats[index].confidence.isEmpty {
                    Text(edited.possibleNats[index].confidence)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            TextField(L10n.thoughtLabel, text: $edited.possibleNats[index].thought, axis: .vertical)
                .font(.body.weight(.semibold).italic())

            Divider()

            HStack(alignment: .top, spacing: 16) {
                labeledField(L10n.situationLabel, text: $edited.possibleNats[index].situation)
                labeledField(L10n.emotionLabel, text: $edited.possibleNats[index].emotion)
            }

            if !edited.possibleNats[index].possibleCognitivePatterns.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.possibleCognitivePatternsLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(edited.possibleNats[index].possibleCognitivePatterns
                        .joined(separator: " · "))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.tint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    /// Whether the thought was voiced by the patient rather than inferred by
    /// the model — a clinically important distinction, so unrecognized source
    /// values fall back to the weaker "inference" reading.
    private func isPatientStated(_ source: String) -> Bool {
        let lowered = source.lowercased()
        return ["patient", "stated", "explicit", "quote", "said", "verbatim",
                "אמר", "אמרה", "ציטוט", "מפורש"]
            .contains { lowered.contains($0) }
    }

    @ViewBuilder
    private func sourceBadge(for source: String) -> some View {
        if isPatientStated(source) {
            Label(L10n.patientSaidBadge, systemImage: "quote.opening")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.tint.opacity(0.12)))
        } else {
            Label(L10n.possibleInferenceBadge, systemImage: "lightbulb")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.orange.opacity(0.12)))
        }
    }

    private func labeledField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(title, text: text, axis: .vertical)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One thought's full CBT cycle as a vertical chain:
    /// situation → thought → emotion → behavior → possible consequence.
    /// The steps edit the same fields as the thought's card above.
    private func cycleCard(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            cycleStep(L10n.situationLabel, text: $edited.possibleNats[index].situation)
            cycleArrow
            cycleStep(L10n.thoughtLabel, text: $edited.possibleNats[index].thought)
            cycleArrow
            cycleStep(L10n.emotionLabel, text: $edited.possibleNats[index].emotion)
            cycleArrow
            cycleStep(L10n.behaviorLabel, text: $edited.possibleNats[index].behavior)
            if edited.possibleNats[index].possibleConsequence != nil {
                cycleArrow
                cycleStep(L10n.possibleConsequenceLabel, text: Binding(
                    get: { edited.possibleNats[index].possibleConsequence ?? "" },
                    set: { edited.possibleNats[index].possibleConsequence = $0 }
                ))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func cycleStep(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(title, text: text, axis: .vertical)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cycleArrow: some View {
        Image(systemName: "arrow.down")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
            .padding(.vertical, 2)
    }

    /// One supervision reflection: what the AI noticed, why it may matter,
    /// and the question worth exploring with the patient. All editable.
    private func explorationCard(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label(L10n.aiNoticedLabel, systemImage: "eye")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !edited.therapistReflections[index].confidence.isEmpty {
                        Text(edited.therapistReflections[index].confidence)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                TextField(L10n.observationPlaceholder,
                          text: $edited.therapistReflections[index].observation,
                          axis: .vertical)
                    .font(.body)

                TextField(L10n.whyItMayMatterPlaceholder,
                          text: $edited.therapistReflections[index].whyItMayMatter,
                          axis: .vertical)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Label(L10n.worthExploringLabel, systemImage: "magnifyingglass")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)

                TextField(L10n.questionToExplorePlaceholder,
                          text: $edited.therapistReflections[index].questionToExplore,
                          axis: .vertical)
                    .font(.body.weight(.medium).italic())
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.tint.opacity(0.08))
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    /// One follow-up question with why it matters, plus the therapist's
    /// triage: discussed, follow up next session, or not relevant.
    private func followUpCard(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(index + 1).")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                TextField(L10n.questionPlaceholder,
                          text: $edited.followUpQuestions[index].question,
                          axis: .vertical)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.whyItMattersLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField(L10n.reasonPlaceholder,
                          text: $edited.followUpQuestions[index].reason,
                          axis: .vertical)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                statusChip(L10n.discussedAction, systemImage: "checkmark",
                           status: .discussed, index: index, color: .green)
                statusChip(L10n.followUpAction, systemImage: "arrow.forward",
                           status: .followUp, index: index, color: .blue)
                statusChip(L10n.notRelevantAction, systemImage: "xmark",
                           status: .notRelevant, index: index, color: .red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    /// Toggleable triage chip; tapping the selected one clears the choice.
    private func statusChip(_ title: String, systemImage: String,
                            status: WhisperService.FollowUpQuestion.Status,
                            index: Int, color: Color) -> some View {
        let isSelected = edited.followUpQuestions[index].status == status
        return Button {
            edited.followUpQuestions[index].status = isSelected ? nil : status
        } label: {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? color : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isSelected ? color.opacity(0.15) : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }

    private func keySituationCard(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(L10n.situationLabel, text: $edited.keySituations[index].situation, axis: .vertical)
                .font(.headline)
            TextField(L10n.importancePlaceholder, text: $edited.keySituations[index].importance, axis: .vertical)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

/// The rest of the analysis, one section per part of the response. Empty
/// sections are hidden.
private struct SessionAnalysisDetailView: View {
    let analysis: WhisperService.CBTSessionAnalysis

    var body: some View {
        List {
            if !analysis.emotions.isEmpty {
                Section(L10n.emotionsSection) {
                    ForEach(analysis.emotions.indices, id: \.self) { index in
                        let item = analysis.emotions[index]
                        entry(title: item.emotion, details: [
                            (L10n.contextLabel, item.context),
                            (L10n.evidenceLabel, item.evidence)
                        ])
                    }
                }
            }

            if !analysis.possibleNats.isEmpty {
                Section(L10n.possibleNatsSection) {
                    ForEach(analysis.possibleNats.indices, id: \.self) { index in
                        let item = analysis.possibleNats[index]
                        entry(title: item.thought, details: [
                            (L10n.situationLabel, item.situation),
                            (L10n.emotionLabel, item.emotion),
                            (L10n.behaviorLabel, item.behavior),
                            (L10n.sourceLabel, item.source),
                            (L10n.confidenceLabel, item.confidence),
                            (L10n.possibleCognitivePatternsLabel,
                             item.possibleCognitivePatterns.joined(separator: ", "))
                        ])
                    }
                }
            }

            if !analysis.behaviors.isEmpty {
                Section(L10n.behaviorsSection) {
                    ForEach(analysis.behaviors.indices, id: \.self) { index in
                        let item = analysis.behaviors[index]
                        entry(title: item.behavior, details: [
                            (L10n.typeLabel, item.type),
                            (L10n.contextLabel, item.context),
                            (L10n.possibleFunctionLabel, item.possibleFunction)
                        ])
                    }
                }
            }

            if !analysis.cbtPatterns.isEmpty {
                Section(L10n.cbtPatternsSection) {
                    ForEach(analysis.cbtPatterns.indices, id: \.self) { index in
                        let item = analysis.cbtPatterns[index]
                        entry(title: item.pattern, details: [
                            (L10n.evidenceLabel, item.evidence),
                            (L10n.confidenceLabel, item.confidence)
                        ])
                    }
                }
            }

            if !analysis.maintainingCycles.isEmpty {
                Section(L10n.maintainingCyclesSection) {
                    ForEach(analysis.maintainingCycles.indices, id: \.self) { index in
                        let item = analysis.maintainingCycles[index]
                        entry(title: item.cycle, details: [
                            (L10n.evidenceLabel, item.evidence),
                            (L10n.confidenceLabel, item.confidence)
                        ])
                    }
                }
            }

            if !analysis.developments.isEmpty {
                Section(L10n.developmentsSection) {
                    ForEach(analysis.developments.indices, id: \.self) { index in
                        let item = analysis.developments[index]
                        entry(title: item.development, details: [
                            (L10n.significanceLabel, item.significance)
                        ])
                    }
                }
            }

            if !analysis.therapistHypotheses.isEmpty {
                Section(L10n.therapistHypothesesSection) {
                    ForEach(analysis.therapistHypotheses.indices, id: \.self) { index in
                        let item = analysis.therapistHypotheses[index]
                        entry(title: item.hypothesis, details: [
                            (L10n.evidenceLabel, item.evidence),
                            (L10n.confidenceLabel, item.confidence)
                        ])
                    }
                }
            }

            if !analysis.therapistReflections.isEmpty {
                Section(L10n.therapistReflectionsSection) {
                    ForEach(analysis.therapistReflections.indices, id: \.self) { index in
                        let item = analysis.therapistReflections[index]
                        entry(title: item.observation, details: [
                            (L10n.whyItMayMatterPlaceholder, item.whyItMayMatter),
                            (L10n.questionToExplorePlaceholder, item.questionToExplore),
                            (L10n.confidenceLabel, item.confidence)
                        ])
                    }
                }
            }

            if !analysis.followUpQuestions.isEmpty {
                Section(L10n.followUpQuestionsSection) {
                    ForEach(analysis.followUpQuestions.indices, id: \.self) { index in
                        let item = analysis.followUpQuestions[index]
                        entry(title: item.question, details: [
                            (L10n.reasonPlaceholder, item.reason),
                            (L10n.categoryLabel, item.category),
                            (L10n.priorityLabel, item.priority)
                        ])
                    }
                }
            }

            if !analysis.unresolvedIssues.isEmpty {
                Section(L10n.unresolvedIssuesSection) {
                    ForEach(analysis.unresolvedIssues.indices, id: \.self) { index in
                        Text(analysis.unresolvedIssues[index])
                    }
                }
            }
        }
        .navigationTitle(L10n.fullAnalysisTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A titled row followed by labeled detail lines; empty details are hidden.
    private func entry(title: String, details: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            ForEach(details.indices, id: \.self) { index in
                let detail = details[index]
                if !detail.1.isEmpty {
                    Text("\(detail.0): \(detail.1)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
