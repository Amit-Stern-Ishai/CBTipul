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

    /// The patient's identity color at the outline strength used across
    /// the patient screens.
    private var patientOutline: Color {
        PatientAvatarColor.background(for: patient.id).opacity(0.35)
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
                            Text(L10n.aiThinkingLabel)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(patientOutline, lineWidth: 1))
                        Spacer(minLength: 48)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Theme.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .defaultScrollAnchor(.bottom)
        .patientAtmosphere(PatientAvatarColor.background(for: patient.id))
        .background(Theme.base.ignoresSafeArea())
        .dismissesKeyboardOnTap()
        .overlay {
            if chatEntries.isEmpty && !isLoading && errorMessage == nil {
                emptyState
            }
        }
        .animation(.easeInOut(duration: 0.25), value: chatEntries.count)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .safeAreaInset(edge: .bottom) {
            inputBar
        }
        .navigationTitle(L10n.aiChatNavigationTitle)
        .navigationSubtitle(patient.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // The questionnaire context needs the cache filled.
            if store.cachedQuestionnaires(for: patient) == nil {
                _ = try? await store.loadQuestionnaires(for: patient)
            }
        }
    }

    /// Welcomes into the empty chat: what the assistant knows, plus a few
    /// example questions that fill the message field when tapped.
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(Theme.gold)
                .padding(22)
                .background(Theme.goldGhost, in: Circle())
            Text(L10n.aiTitle)
                .font(.title3.bold())
            Text(L10n.aiEmptyMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(spacing: 8) {
                ForEach(L10n.aiSuggestedQuestions, id: \.self) { question in
                    Button {
                        prompt = question
                    } label: {
                        Text(question)
                            .font(.subheadline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Theme.surface, in: Capsule())
                            .overlay(Capsule().strokeBorder(patientOutline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)
        }
        .padding(32)
    }

    /// The message field with a send icon, pinned above the keyboard.
    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(L10n.aiPromptPlaceholder(patient.displayName), text: $prompt, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(patientOutline, lineWidth: 1))

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(canSend ? Theme.gold : Theme.textFaint)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Theme.surface)
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
                    entry.role == .user ? Theme.goldGhost : Theme.surface,
                    in: RoundedRectangle(cornerRadius: 18)
                )
                // Patient color marks the patient-related content: only the
                // AI's answers get the outline, the user's gold bubbles stay.
                .overlay(RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(entry.role == .assistant ? patientOutline : .clear, lineWidth: 1))
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
            questions: L10n.gad7Questions, answers: q.gad7Answers, notes: q.gad7Notes
        ))
        lines.append("GAD-7 total: \(q.gad7Score) (\(L10n.label(for: q.gad7Severity)))")

        lines.append("PHQ-9 (each answer 0-3):")
        lines.append(contentsOf: answerLines(
            questions: L10n.phq9Questions, answers: q.phq9Answers, notes: q.phq9Notes
        ))
        lines.append("PHQ-9 total: \(q.phq9Score) (\(L10n.label(for: q.phq9Severity)))")

        if let level = q.interferenceLevel,
           L10n.phq9InterferenceOptions.indices.contains(level) {
            var line = "Interference: \(L10n.phq9InterferenceOptions[level]) (\(level))"
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

    /// Compact text digest of a session's saved structured AI review,
    /// mirroring the clinically relevant core that `PatientContext` sends
    /// to the Edge Functions.
    private func structuredContext(_ analysis: WhisperService.CBTSessionAnalysis) -> String {
        var lines = ["Summary: \(analysis.sessionSummary)"]
        if !analysis.possibleNats.isEmpty {
            lines.append("Possible NATs:")
            for nat in analysis.possibleNats {
                var details = ["situation: \(nat.situation)"]
                if let emotion = nat.emotion, !emotion.isEmpty { details.append("emotion: \(emotion)") }
                if let behavior = nat.behavior, !behavior.isEmpty { details.append("behavior: \(behavior)") }
                details.append("confidence: \(nat.confidence)")
                lines.append("- \(nat.thought) (\(details.joined(separator: ", ")))")
            }
        }
        if !analysis.cbtCycles.isEmpty {
            lines.append("CBT cycles:")
            for cycle in analysis.cbtCycles {
                let stages = [cycle.triggerSituation, cycle.automaticThought, cycle.emotion,
                              cycle.behavior, cycle.shortTermConsequence, cycle.longTermConsequence]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                lines.append("- \(stages.joined(separator: " → ")) (confidence: \(cycle.confidence))")
            }
        }
        if !analysis.therapistHypotheses.isEmpty {
            lines.append("Therapist hypotheses:")
            for hypothesis in analysis.therapistHypotheses {
                lines.append("- \(hypothesis.hypothesis) (confidence: \(hypothesis.confidence))")
            }
        }
        let openQuestions = analysis.followUpQuestions
            .filter { $0.status != .discussed && $0.status != .notRelevant }
        if !openQuestions.isEmpty {
            lines.append("Open follow-up questions:")
            for question in openQuestions {
                lines.append("- \(question.question) (\(question.reason))")
            }
        }
        return lines.joined(separator: "\n")
    }

    private func fullContext() -> String {
        var parts: [String] = []
        parts.append("Patient: \(patient.displayName), status: \(patient.status.rawValue)")

        let patientNotes = patient.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !patientNotes.isEmpty {
            parts.append("Patient notes (general, not tied to a session):\n\(patientNotes)")
        }

        let sessions = patient.sessions.sorted { $0.date < $1.date }
        // Same cap as PatientContext.maxReviews: only the most recent
        // structured reviews go in, keeping the prompt size bounded.
        let recentReviewIDs = Set(
            sessions.filter { $0.structuredNotes != nil }.suffix(5).map(\.id)
        )
        if sessions.isEmpty {
            parts.append("No sessions yet.")
        } else {
            var lines = ["Sessions:"]
            for session in sessions {
                var line = "- Session on \(session.date.formatted(date: .numeric, time: .omitted))"
                if !session.notes.isEmpty {
                    line += "\n  Notes: \(session.notes)"
                }
                if let analysis = session.structuredNotes,
                   recentReviewIDs.contains(session.id) {
                    let digest = structuredContext(analysis)
                        .split(separator: "\n")
                        .map { "  \($0)" }
                        .joined(separator: "\n")
                    line += "\n  Structured AI review:\n\(digest)"
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
        PatientAIView(patient: Patient(id: .integer(1), firstName: "Alex", lastName: "Rivera"))
    }
    .environment(auth)
    .environment(PatientStore(client: auth.client))
}
