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
                    TextField("Session summary", text: $edited.sessionSummary, axis: .vertical)
                        .font(.body)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !edited.keySituations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Key Situations")
                                .font(.title3.bold())

                            ForEach(edited.keySituations.indices, id: \.self) { index in
                                keySituationCard(index: index)
                            }
                        }
                    }

                    if !edited.possibleNats.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Possible Automatic Thoughts")
                                .font(.title3.bold())

                            ForEach(edited.possibleNats.indices, id: \.self) { index in
                                natCard(index: index)
                            }
                        }
                    }

                    if !edited.possibleNats.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("CBT Cycle")
                                .font(.title3.bold())

                            ForEach(edited.possibleNats.indices, id: \.self) { index in
                                cycleCard(index: index)
                            }
                        }
                    }

                    if !edited.therapistReflections.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Things Worth Exploring")
                                .font(.title3.bold())

                            ForEach(edited.therapistReflections.indices, id: \.self) { index in
                                explorationCard(index: index)
                            }
                        }
                    }

                    if !edited.followUpQuestions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Questions You May Want to Revisit")
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
                            Label("Full Analysis", systemImage: "list.bullet.rectangle")
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
            .navigationTitle("Session Summary")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if needsSaveDecision {
                            isShowingSaveAsk = true
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Save this summary to the session?",
                   isPresented: $isShowingSaveAsk) {
                Button("Save") {
                    onSave?(edited)
                    dismiss()
                }
                Button("Don't Save", role: .destructive) { dismiss() }
                Button("Keep Viewing", role: .cancel) {}
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

            TextField("Thought", text: $edited.possibleNats[index].thought, axis: .vertical)
                .font(.body.weight(.semibold).italic())

            Divider()

            HStack(alignment: .top, spacing: 16) {
                labeledField("Situation", text: $edited.possibleNats[index].situation)
                labeledField("Emotion", text: $edited.possibleNats[index].emotion)
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
            Label("Patient said", systemImage: "quote.opening")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.tint.opacity(0.12)))
        } else {
            Label("Possible inference", systemImage: "lightbulb")
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
            cycleStep("Situation", text: $edited.possibleNats[index].situation)
            cycleArrow
            cycleStep("Thought", text: $edited.possibleNats[index].thought)
            cycleArrow
            cycleStep("Emotion", text: $edited.possibleNats[index].emotion)
            cycleArrow
            cycleStep("Behavior", text: $edited.possibleNats[index].behavior)
            if edited.possibleNats[index].possibleConsequence != nil {
                cycleArrow
                cycleStep("Possible consequence", text: Binding(
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
                    Label("The AI noticed", systemImage: "eye")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !edited.therapistReflections[index].confidence.isEmpty {
                        Text(edited.therapistReflections[index].confidence)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                TextField("Observation",
                          text: $edited.therapistReflections[index].observation,
                          axis: .vertical)
                    .font(.body)

                TextField("Why it may matter",
                          text: $edited.therapistReflections[index].whyItMayMatter,
                          axis: .vertical)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Label("Worth exploring", systemImage: "magnifyingglass")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)

                TextField("Question to explore",
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
                TextField("Question",
                          text: $edited.followUpQuestions[index].question,
                          axis: .vertical)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Why it matters")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Reason",
                          text: $edited.followUpQuestions[index].reason,
                          axis: .vertical)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                statusChip("Discussed", systemImage: "checkmark",
                           status: .discussed, index: index, color: .green)
                statusChip("Follow up", systemImage: "arrow.forward",
                           status: .followUp, index: index, color: .blue)
                statusChip("Not relevant", systemImage: "xmark",
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
            TextField("Situation", text: $edited.keySituations[index].situation, axis: .vertical)
                .font(.headline)
            TextField("Importance", text: $edited.keySituations[index].importance, axis: .vertical)
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
                Section("Emotions") {
                    ForEach(analysis.emotions.indices, id: \.self) { index in
                        let item = analysis.emotions[index]
                        entry(title: item.emotion, details: [
                            ("Context", item.context),
                            ("Evidence", item.evidence)
                        ])
                    }
                }
            }

            if !analysis.possibleNats.isEmpty {
                Section("Possible Negative Automatic Thoughts") {
                    ForEach(analysis.possibleNats.indices, id: \.self) { index in
                        let item = analysis.possibleNats[index]
                        entry(title: item.thought, details: [
                            ("Situation", item.situation),
                            ("Emotion", item.emotion),
                            ("Behavior", item.behavior),
                            ("Source", item.source),
                            ("Confidence", item.confidence),
                            ("Possible cognitive patterns",
                             item.possibleCognitivePatterns.joined(separator: ", "))
                        ])
                    }
                }
            }

            if !analysis.behaviors.isEmpty {
                Section("Behaviors") {
                    ForEach(analysis.behaviors.indices, id: \.self) { index in
                        let item = analysis.behaviors[index]
                        entry(title: item.behavior, details: [
                            ("Type", item.type),
                            ("Context", item.context),
                            ("Possible function", item.possibleFunction)
                        ])
                    }
                }
            }

            if !analysis.cbtPatterns.isEmpty {
                Section("CBT Patterns") {
                    ForEach(analysis.cbtPatterns.indices, id: \.self) { index in
                        let item = analysis.cbtPatterns[index]
                        entry(title: item.pattern, details: [
                            ("Evidence", item.evidence),
                            ("Confidence", item.confidence)
                        ])
                    }
                }
            }

            if !analysis.maintainingCycles.isEmpty {
                Section("Maintaining Cycles") {
                    ForEach(analysis.maintainingCycles.indices, id: \.self) { index in
                        let item = analysis.maintainingCycles[index]
                        entry(title: item.cycle, details: [
                            ("Evidence", item.evidence),
                            ("Confidence", item.confidence)
                        ])
                    }
                }
            }

            if !analysis.developments.isEmpty {
                Section("Developments") {
                    ForEach(analysis.developments.indices, id: \.self) { index in
                        let item = analysis.developments[index]
                        entry(title: item.development, details: [
                            ("Significance", item.significance)
                        ])
                    }
                }
            }

            if !analysis.therapistHypotheses.isEmpty {
                Section("Therapist Hypotheses") {
                    ForEach(analysis.therapistHypotheses.indices, id: \.self) { index in
                        let item = analysis.therapistHypotheses[index]
                        entry(title: item.hypothesis, details: [
                            ("Evidence", item.evidence),
                            ("Confidence", item.confidence)
                        ])
                    }
                }
            }

            if !analysis.therapistReflections.isEmpty {
                Section("Therapist Reflections") {
                    ForEach(analysis.therapistReflections.indices, id: \.self) { index in
                        let item = analysis.therapistReflections[index]
                        entry(title: item.observation, details: [
                            ("Why it may matter", item.whyItMayMatter),
                            ("Question to explore", item.questionToExplore),
                            ("Confidence", item.confidence)
                        ])
                    }
                }
            }

            if !analysis.followUpQuestions.isEmpty {
                Section("Follow-up Questions") {
                    ForEach(analysis.followUpQuestions.indices, id: \.self) { index in
                        let item = analysis.followUpQuestions[index]
                        entry(title: item.question, details: [
                            ("Reason", item.reason),
                            ("Category", item.category),
                            ("Priority", item.priority)
                        ])
                    }
                }
            }

            if !analysis.unresolvedIssues.isEmpty {
                Section("Unresolved Issues") {
                    ForEach(analysis.unresolvedIssues.indices, id: \.self) { index in
                        Text(analysis.unresolvedIssues[index])
                    }
                }
            }
        }
        .navigationTitle("Full Analysis")
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
