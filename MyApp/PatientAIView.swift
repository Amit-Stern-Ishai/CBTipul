import SwiftUI

/// AI assistant for a patient. Four modes:
/// 1. One-tap insights generated from the questionnaire history.
/// 2. A free question answered with all questionnaire data as context.
/// 3. A general query answered with all available patient data as context.
/// 4. A multi-turn chat with all patient data as context; the conversation
///    history is kept while the screen is open.
struct PatientAIView: View {
    let patient: Patient

    @Environment(PatientStore.self) private var store
    @Environment(AuthManager.self) private var auth

    private enum Mode: Hashable {
        case insights
        case questionnaires
        case general
        case chat
    }

    /// One message of the chat mode's transcript. Raw text is kept so the
    /// whole conversation can be resent to the model on the next turn;
    /// `displayedText` holds the partial answer while it types in.
    private struct ChatEntry: Identifiable, Equatable {
        let id = UUID()
        let role: ChatTurn.Role
        var text: String
        var displayedText: AttributedString?
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
        .insights: ModeState(), .questionnaires: ModeState(),
        .general: ModeState(), .chat: ModeState()
    ]
    @State private var chatEntries: [ChatEntry] = []
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
                    Text(QuestionnaireText.aiModeChat).tag(Mode.chat)
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
                                buttonTitle,
                                systemImage: mode == .chat ? "paperplane.fill" : "sparkles"
                            )
                            .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.pressableProminent)
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

            if mode == .chat, !chatEntries.isEmpty {
                Section(QuestionnaireText.aiChatTitle) {
                    ForEach(chatEntries) { entry in
                        chatBubble(entry)
                    }
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
        .animation(.easeInOut(duration: 0.2), value: current.errorMessage)
        .animation(.easeInOut(duration: 0.25), value: current.displayedResponse == nil)
        .animation(.easeInOut(duration: 0.25), value: chatEntries.count)
        .navigationTitle(QuestionnaireText.aiTitle)
        .task {
            // The questionnaire context needs the cache filled.
            if store.cachedQuestionnaires(for: patient) == nil {
                _ = try? await store.loadQuestionnaires(for: patient)
            }
        }
    }

    private var buttonTitle: String {
        switch mode {
        case .insights: QuestionnaireText.aiGenerateInsightsAction
        case .questionnaires, .general: QuestionnaireText.aiAskAction
        case .chat: QuestionnaireText.aiSendAction
        }
    }

    /// One transcript row: user messages on the right in an accent bubble,
    /// AI answers on the left in a gray bubble.
    private func chatBubble(_ entry: ChatEntry) -> some View {
        HStack(spacing: 0) {
            if entry.role == .user { Spacer(minLength: 40) }
            Text(entry.displayedText
                 ?? (entry.role == .assistant ? aiMarkdown(entry.text) : AttributedString(entry.text)))
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    entry.role == .user
                        ? Color.accentColor.opacity(0.15)
                        : Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 14)
                )
            if entry.role == .assistant { Spacer(minLength: 40) }
        }
        .listRowSeparator(.hidden)
    }

    private func run() {
        guard mode != .chat else {
            sendChatMessage()
            return
        }
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

    /// Appends the typed question to the transcript and asks the model with
    /// the whole conversation, so follow-up questions keep their context.
    /// The patient data goes into the system prompt, like the other modes.
    private func sendChatMessage() {
        let question = current.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        typingTasks[.chat]?.cancel()
        modeStates[.chat]?.prompt = ""
        modeStates[.chat]?.errorMessage = nil
        modeStates[.chat]?.isLoading = true
        chatEntries.append(ChatEntry(role: .user, text: question))

        let systemPrompt = """
        \(AIPrompts.system)

        === Patient data ===
        \(fullContext())
        """
        let turns = chatEntries.map { ChatTurn(role: $0.role, content: $0.text) }
        let chatService = SupabaseChatService(client: auth.client)
        typingTasks[.chat] = Task {
            do {
                let answer = try await chatService.complete(systemPrompt: systemPrompt, turns: turns)
                modeStates[.chat]?.isLoading = false
                if responseStyle == .typing {
                    await typeOutChatAnswer(answer)
                } else {
                    chatEntries.append(ChatEntry(role: .assistant, text: answer))
                }
            } catch {
                modeStates[.chat]?.errorMessage = error.localizedDescription
                modeStates[.chat]?.isLoading = false
            }
        }
    }

    /// Streams the answer word by word into a new assistant bubble, the same
    /// way `typeOut` streams the single-answer modes.
    private func typeOutChatAnswer(_ text: String) async {
        let entry = ChatEntry(role: .assistant, text: text, displayedText: AttributedString())
        chatEntries.append(entry)
        guard let index = chatEntries.firstIndex(where: { $0.id == entry.id }) else { return }

        let full = aiMarkdown(text)
        var end = full.startIndex
        while end < full.endIndex {
            if Task.isCancelled { break }
            end = nextWordBoundary(in: full, after: end)
            chatEntries[index].displayedText = AttributedString(full[full.startIndex..<end])
            try? await Task.sleep(for: .milliseconds(30))
        }
        // Show the final parsed text even when cancelled early — the raw
        // answer is already part of the conversation history.
        chatEntries[index].displayedText = nil
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
        case .chat:
            // Chat assembles its own message list in sendChatMessage().
            return ""
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
