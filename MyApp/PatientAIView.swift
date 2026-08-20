import SwiftUI

/// AI assistant for a patient: a WhatsApp-style chat. Every question is
/// answered with all patient data (sessions, notes, questionnaires) as
/// context, and the conversation history is kept while the screen is open.
struct PatientAIView: View {
    let patient: Patient

    @Environment(PatientStore.self) private var store
    @Environment(AuthManager.self) private var auth

    /// One message of the transcript. Raw text is kept so the whole
    /// conversation can be resent to the model on the next turn;
    /// `displayedText` holds the partial answer while it types in.
    private struct ChatEntry: Identifiable, Equatable {
        let id = UUID()
        let role: ChatTurn.Role
        var text: String
        var displayedText: AttributedString?
    }

    @State private var chatEntries: [ChatEntry] = []
    @State private var prompt = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var typingTask: Task<Void, Never>?
    @AppStorage("aiResponseStyle") private var responseStyle: AIResponseStyle = .typing

    private var canSend: Bool {
        !isLoading && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(chatEntries) { entry in
                    chatBubble(entry)
                }

                if isLoading {
                    HStack {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(QuestionnaireText.aiThinkingLabel)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                        Spacer(minLength: 48)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .defaultScrollAnchor(.bottom)
        .dismissesKeyboardOnTap()
        .animation(.easeInOut(duration: 0.25), value: chatEntries.count)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .safeAreaInset(edge: .bottom) {
            inputBar
        }
        .navigationTitle("Chat about \(patient.displayName)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // The questionnaire context needs the cache filled.
            if store.cachedQuestionnaires(for: patient) == nil {
                _ = try? await store.loadQuestionnaires(for: patient)
            }
        }
    }

    /// The message field with a send icon, pinned above the keyboard.
    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(QuestionnaireText.aiPromptPlaceholder, text: $prompt, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(canSend ? Color.accentColor : Color(.systemGray3))
            }
            .disabled(!canSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    /// One transcript row: user messages on the right in an accent bubble,
    /// AI answers on the left in a gray bubble.
    private func chatBubble(_ entry: ChatEntry) -> some View {
        HStack {
            if entry.role == .user { Spacer(minLength: 48) }
            Text(entry.displayedText
                 ?? (entry.role == .assistant ? aiMarkdown(entry.text) : AttributedString(entry.text)))
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    entry.role == .user
                        ? Color.accentColor.opacity(0.18)
                        : Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 18)
                )
            if entry.role == .assistant { Spacer(minLength: 48) }
        }
    }

    /// Appends the typed question to the transcript and asks the model with
    /// the whole conversation, so follow-up questions keep their context.
    /// The patient data goes into the system prompt on every turn.
    private func send() {
        let question = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        typingTask?.cancel()
        prompt = ""
        errorMessage = nil
        isLoading = true
        chatEntries.append(ChatEntry(role: .user, text: question))

        let systemPrompt = """
        \(AIPrompts.system)

        === Patient data ===
        \(fullContext())
        """
        let turns = chatEntries.map { ChatTurn(role: $0.role, content: $0.text) }
        let chatService = SupabaseChatService(client: auth.client)
        typingTask = Task {
            do {
                let answer = try await chatService.complete(systemPrompt: systemPrompt, turns: turns)
                isLoading = false
                if responseStyle == .typing {
                    await typeOutAnswer(answer)
                } else {
                    chatEntries.append(ChatEntry(role: .assistant, text: answer))
                }
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    /// Streams the answer word by word into a new assistant bubble. The
    /// markdown is parsed once up front so styling never flickers.
    private func typeOutAnswer(_ text: String) async {
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
