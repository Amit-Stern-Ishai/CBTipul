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
/// Ordered top to bottom: the session summary as editable prose, the key
/// situations, possible automatic thoughts, CBT cycles, the therapist
/// hypotheses, and the questions worth clarifying. Empty sections are
/// hidden.
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

    /// True when a field carries real content. The backend now sends true
    /// JSON null for missing values; the textual-"null" check stays as a
    /// harmless safety net for older saved analyses.
    private func isPopulated(_ text: String?) -> Bool {
        guard let text else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.lowercased() != "null"
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

                    if !edited.cbtCycles.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.cbtCycleSection)
                                .font(.title3.bold())

                            ForEach(edited.cbtCycles.indices, id: \.self) { index in
                                cycleCard(edited.cbtCycles[index])
                            }
                        }
                    }

                    if !edited.therapistHypotheses.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.therapistHypothesesSection)
                                .font(.title3.bold())

                            ForEach(edited.therapistHypotheses.indices, id: \.self) { index in
                                hypothesisCard(edited.therapistHypotheses[index])
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
                }
                .padding()
            }
            .background(Theme.base)
            .navigationTitle(L10n.sessionSummaryTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if needsSaveDecision {
                            isShowingSaveAsk = true
                        } else {
                            dismiss()
                        }
                    } label: {
                        Label(L10n.back, systemImage: "chevron.backward")
                            .labelStyle(.titleAndIcon)
                    }
                }
                // No Save when just viewing an already-saved summary; it
                // appears for fresh results and the moment anything is edited.
                if needsSaveDecision {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.save) {
                            onSave?(edited)
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

    /// One automatic thought: source badge on top, the quoted thought, then
    /// its situation and emotion side by side. All editable. Confidence is
    /// never shown — everything the backend returns is high confidence.
    private func natCard(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sourceBadge(for: edited.possibleNats[index].source)

            TextField(L10n.thoughtLabel, text: $edited.possibleNats[index].thought, axis: .vertical)
                .font(.body.weight(.semibold).italic())

            Divider()

            HStack(alignment: .top, spacing: 16) {
                labeledField(L10n.situationLabel, text: $edited.possibleNats[index].situation)
                if isPopulated(analysis.possibleNats[index].emotion) {
                    labeledField(L10n.emotionLabel,
                                 text: optionalBinding($edited.possibleNats[index].emotion))
                }
            }

            if isPopulated(analysis.possibleNats[index].behavior) {
                labeledField(L10n.behaviorLabel,
                             text: optionalBinding($edited.possibleNats[index].behavior))
            }

            if !edited.possibleNats[index].cognitivePatterns.isEmpty {
                let patterns = sortedByConfidence(edited.possibleNats[index].cognitivePatterns)
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.possibleCognitivePatternsLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(patterns.indices, id: \.self) { patternIndex in
                        cognitivePatternRow(patterns[patternIndex])
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.surface)
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

    /// The Hebrew label for a machine source value, and whether it reads as
    /// reported fact (quote style) or as an inference (hypothesis style).
    /// Unknown values fall back to the heuristic reading.
    private func sourceLabel(for source: String) -> (label: String, isReported: Bool) {
        switch source {
        case "explicit_patient": return (L10n.sourceExplicitPatient, true)
        case "therapist_reported": return (L10n.sourceTherapistReported, true)
        case "therapist_inferred": return (L10n.sourceTherapistInferred, false)
        case "ai_inferred": return (L10n.sourceAIInferred, false)
        default:
            let stated = isPatientStated(source)
            return (stated ? L10n.patientSaidBadge : L10n.possibleInferenceBadge, stated)
        }
    }

    @ViewBuilder
    private func sourceBadge(for source: String) -> some View {
        let (label, isReported) = sourceLabel(for: source)
        if isReported {
            Label(label, systemImage: "quote.opening")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.tint.opacity(0.12)))
        } else {
            Label(label, systemImage: "lightbulb")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.warning)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Theme.warning.opacity(0.12)))
        }
    }

    /// One possible classification of the thought: the pattern name with a
    /// subtle confidence caption alongside, and the model's reasoning
    /// underneath. Kept visually subordinate to the NAT itself.
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

    /// High → medium → low, unrecognized values last; ties keep the
    /// server's order.
    private func sortedByConfidence(
        _ patterns: [WhisperService.CognitivePattern]
    ) -> [WhisperService.CognitivePattern] {
        func rank(_ raw: String) -> Int {
            let lowered = raw.lowercased()
            if lowered.contains("high") || lowered.contains("גבוה") { return 0 }
            if lowered.contains("med") || lowered.contains("בינוני") { return 1 }
            if lowered.contains("low") || lowered.contains("נמוך") { return 2 }
            return 3
        }
        return patterns.enumerated()
            .sorted { (rank($0.element.confidence), $0.offset)
                    < (rank($1.element.confidence), $1.offset) }
            .map(\.element)
    }

    /// Hebrew caption for a pattern's confidence; unknown raw values show
    /// as-is rather than being hidden.
    private func confidenceCaption(for raw: String) -> String? {
        let lowered = raw.lowercased()
        if lowered.contains("high") || lowered.contains("גבוה") { return L10n.confidenceHigh }
        if lowered.contains("med") || lowered.contains("בינוני") { return L10n.confidenceMedium }
        if lowered.contains("low") || lowered.contains("נמוך") { return L10n.confidenceLow }
        return raw.isEmpty ? nil : raw
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

    /// Bridges an optional string to the editable fields; the field only
    /// shows when the value is present, so nil never becomes visible.
    private func optionalBinding(_ source: Binding<String?>) -> Binding<String> {
        Binding(get: { source.wrappedValue ?? "" },
                set: { source.wrappedValue = $0 })
    }

    /// One hypothesized cycle as a vertical CBT chain:
    /// situation → thought → emotion → behavior → consequences.
    /// Stages the AI could not evidence are omitted entirely.
    private func cycleCard(_ cycle: CBTCycle) -> some View {
        let stages: [(title: String, text: String)] = [
            (L10n.situationLabel, cycle.triggerSituation),
            (L10n.thoughtLabel, cycle.automaticThought),
            (L10n.emotionLabel, cycle.emotion),
            (L10n.behaviorLabel, cycle.behavior),
            (L10n.shortTermConsequenceLabel, cycle.shortTermConsequence),
            (L10n.longTermConsequenceLabel, cycle.longTermConsequence),
        ].compactMap { title, text in
            guard let text, isPopulated(text) else { return nil }
            return (title, text)
        }
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(stages.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 2) {
                    Text(stages[index].title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(stages[index].text)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if index < stages.count - 1 {
                    cycleArrow
                }
            }
            if !cycle.evidence.isEmpty {
                Text("\(L10n.evidenceLabel): \(cycle.evidence)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.surface)
        )
    }

    private var cycleArrow: some View {
        Image(systemName: "arrow.down")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
            .padding(.vertical, 2)
    }

    /// One hypothesis with its evidence and confidence. Badged as an
    /// inference so it never reads as an established fact.
    private func hypothesisCard(_ item: WhisperService.TherapistHypothesis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(item.hypothesis)
                    .font(.body.weight(.medium))
                Spacer()
                Label(L10n.possibleInferenceBadge, systemImage: "lightbulb")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.warning)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.warning.opacity(0.12)))
            }
            if !item.evidence.isEmpty {
                Text(item.evidence)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.surface)
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

//            HStack(spacing: 8) {
//                statusChip(L10n.discussedAction, systemImage: "checkmark",
//                           status: .discussed, index: index, color: .green)
//                statusChip(L10n.followUpAction, systemImage: "arrow.forward",
//                           status: .followUp, index: index, color: .blue)
//                statusChip(L10n.notRelevantAction, systemImage: "xmark",
//                           status: .notRelevant, index: index, color: .red)
//            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.surface)
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
                    Capsule().fill(isSelected ? color.opacity(0.15) : Theme.elevated)
                )
        }
        .buttonStyle(.plain)
    }

    private func keySituationCard(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(L10n.situationLabel, text: $edited.keySituations[index].situation, axis: .vertical)
                .font(.headline)
            TextField(L10n.whyItMattersLabel, text: $edited.keySituations[index].whyItMatters, axis: .vertical)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.surface)
        )
    }
}
