import SwiftUI

/// AI assistant for a patient. Three modes:
/// 1. One-tap insights generated from the questionnaire history.
/// 2. A free question answered with all questionnaire data as context.
/// 3. A general query answered with all available patient data as context.
struct PatientAIView: View {
    let patient: Patient

    @Environment(PatientStore.self) private var store
    @Environment(AuthManager.self) private var auth

    private enum Mode: Hashable {
        case insights
        case questionnaires
        case general
    }

    /// Every mode keeps its own prompt and answer so switching modes
    /// switches to that mode's conversation state.
    private struct ModeState {
        var prompt = ""
        var displayedResponse: AttributedString?
        var isLoading = false
        var errorMessage: String?
    }

    @State private var mode: Mode = .insights
    @State private var modeStates: [Mode: ModeState] = [
        .insights: ModeState(), .questionnaires: ModeState(), .general: ModeState()
    ]
    @State private var typingTasks: [Mode: Task<Void, Never>] = [:]
    @AppStorage("aiResponseStyle") private var responseStyle: AIResponseStyle = .typing

    private var current: ModeState { modeStates[mode] ?? ModeState() }

    private var promptBinding: Binding<String> {
        Binding(
            get: { modeStates[mode]?.prompt ?? "" },
            set: { modeStates[mode, default: ModeState()].prompt = $0 }
        )
    }

    private var canRun: Bool {
        guard !current.isLoading else { return false }
        if mode == .insights { return true }
        return !current.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section {
                Label(patient.displayName, systemImage: "person")
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker(QuestionnaireText.aiModePickerTitle, selection: $mode) {
                    Text(QuestionnaireText.aiModeInsights).tag(Mode.insights)
                    Text(QuestionnaireText.aiModeQuestionnaires).tag(Mode.questionnaires)
                    Text(QuestionnaireText.aiModeGeneral).tag(Mode.general)
                }
                .pickerStyle(.segmented)

                if mode != .insights {
                    TextField(QuestionnaireText.aiPromptPlaceholder, text: promptBinding, axis: .vertical)
                        .lineLimit(2...6)
                        .id(mode)
                }

                Button {
                    run()
                } label: {
                    Group {
                        if current.isLoading {
                            HStack {
                                ProgressView()
                                    .tint(.white)
                                Text(QuestionnaireText.aiThinkingLabel)
                            }
                        } else {
                            Label(
                                mode == .insights
                                    ? QuestionnaireText.aiGenerateInsightsAction
                                    : QuestionnaireText.aiAskAction,
                                systemImage: "sparkles"
                            )
                            .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .disabled(!canRun)
            }

            if let errorMessage = current.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            if let response = current.displayedResponse {
                Section(QuestionnaireText.aiResponseTitle) {
                    // Fixed height so the row doesn't grow while the answer
                    // streams in; scroll inside to read the rest.
                    ScrollView {
                        Text(response)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 320)
                }
            }
        }
        .dismissesKeyboardOnTap()
        .navigationTitle(QuestionnaireText.aiTitle)
        .task {
            // The questionnaire context needs the cache filled.
            if store.cachedQuestionnaires(for: patient) == nil {
                _ = try? await store.loadQuestionnaires(for: patient)
            }
        }
    }

    private func run() {
        let mode = self.mode
        typingTasks[mode]?.cancel()
        modeStates[mode]?.errorMessage = nil
        modeStates[mode]?.isLoading = true
        let userMessage = buildUserMessage()
        let chatService = SupabaseChatService(client: auth.client)
        typingTasks[mode] = Task {
            do {
                let text = try await chatService.complete(
                    systemPrompt: AIPrompts.system,
                    userMessage: userMessage
                )
                modeStates[mode]?.isLoading = false
                if responseStyle == .typing {
                    await typeOut(text, for: mode)
                } else {
                    modeStates[mode]?.displayedResponse = aiMarkdown(text)
                }
            } catch {
                modeStates[mode]?.errorMessage = error.localizedDescription
                modeStates[mode]?.isLoading = false
            }
        }
    }

    /// Reveals the answer word by word, ChatGPT-style. The markdown is parsed
    /// once up front so styling never flickers while the text streams in.
    private func typeOut(_ text: String, for mode: Mode) async {
        let full = aiMarkdown(text)
        var end = full.startIndex
        while end < full.endIndex {
            if Task.isCancelled { return }
            end = nextWordBoundary(in: full, after: end)
            modeStates[mode]?.displayedResponse = AttributedString(full[full.startIndex..<end])
            try? await Task.sleep(for: .milliseconds(30))
        }
    }

    /// Advances past the next word and its trailing whitespace.
    private func nextWordBoundary(
        in string: AttributedString, after start: AttributedString.Index
    ) -> AttributedString.Index {
        let characters = string.characters
        var index = start
        while index < string.endIndex, !characters[index].isWhitespace {
            index = characters.index(after: index)
        }
        while index < string.endIndex, characters[index].isWhitespace {
            index = characters.index(after: index)
        }
        return index
    }

    /// Data first, the request last — models answer the final instruction,
    /// so the therapist's question must come after the context, not before.
    private func buildUserMessage() -> String {
        switch mode {
        case .insights:
            return """
            === Patient questionnaire data ===
            \(questionnairesContext())

            === Task ===
            \(AIPrompts.insights)
            """
        case .questionnaires:
            return """
            === Patient questionnaire data ===
            \(questionnairesContext())

            === Therapist's question ===
            \(current.prompt)
            """
        case .general:
            return """
            === Patient data ===
            \(fullContext())

            === Therapist's question ===
            \(current.prompt)
            """
        }
    }

    /// Renders the model's markdown, keeping line breaks.
    private func aiMarkdown(_ string: String) -> AttributedString {
        (try? AttributedString(
            markdown: string,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(string)
    }

    // MARK: - Context building

    private func questionnairesContext() -> String {
        let records = (store.cachedQuestionnaires(for: patient) ?? [])
            .sorted { $0.answeredDate < $1.answeredDate }
        guard !records.isEmpty else { return "No questionnaires have been filled in yet." }
        return records.map(context(for:)).joined(separator: "\n\n")
    }

    private func context(for record: CompletedQuestionnaire) -> String {
        let q = record.questionnaire
        var lines: [String] = []
        lines.append("Questionnaire answered on \(record.answeredDate.formatted(date: .numeric, time: .omitted)):")

        lines.append("GAD-7 (each answer 0-3):")
        lines.append(contentsOf: answerLines(
            questions: QuestionnaireText.gad7Questions, answers: q.gad7Answers, notes: q.gad7Notes
        ))
        lines.append("GAD-7 total: \(q.gad7Score) (\(QuestionnaireText.label(for: q.gad7Severity)))")

        lines.append("PHQ-9 (each answer 0-3):")
        lines.append(contentsOf: answerLines(
            questions: QuestionnaireText.phq9Questions, answers: q.phq9Answers, notes: q.phq9Notes
        ))
        lines.append("PHQ-9 total: \(q.phq9Score) (\(QuestionnaireText.label(for: q.phq9Severity)))")

        if let level = q.interferenceLevel,
           QuestionnaireText.phq9InterferenceOptions.indices.contains(level) {
            var line = "Interference: \(QuestionnaireText.phq9InterferenceOptions[level]) (\(level))"
            if !q.interferenceNote.isEmpty {
                line += " [note: \(q.interferenceNote)]"
            }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    private func answerLines(questions: [String], answers: [Int?], notes: [String]) -> [String] {
        questions.indices.map { index in
            let answer = answers.indices.contains(index) ? answers[index] : nil
            var line = "- \(questions[index]): \(answer.map(String.init) ?? "unanswered")"
            if notes.indices.contains(index), !notes[index].isEmpty {
                line += " [note: \(notes[index])]"
            }
            return line
        }
    }

    private func fullContext() -> String {
        var parts: [String] = []
        parts.append("Patient: \(patient.displayName), status: \(patient.status.rawValue)")

        let sessions = patient.sessions.sorted { $0.date < $1.date }
        if sessions.isEmpty {
            parts.append("No sessions yet.")
        } else {
            var lines = ["Sessions:"]
            for session in sessions {
                var line = "- Session on \(session.date.formatted(date: .numeric, time: .omitted))"
                if !session.notes.isEmpty {
                    line += "\n  Notes: \(session.notes)"
                }
                lines.append(line)
            }
            parts.append(lines.joined(separator: "\n"))
        }

        parts.append("Questionnaires:\n\(questionnairesContext())")
        return parts.joined(separator: "\n\n")
    }
}

#Preview {
    let auth = AuthManager()
    NavigationStack {
        PatientAIView(patient: Patient(firstName: "Alex", lastName: "Rivera"))
    }
    .environment(auth)
    .environment(PatientStore(client: auth.client))
}
