import SwiftUI

/// AI assistant for a patient. Three modes:
/// 1. One-tap insights generated from the questionnaire history.
/// 2. A free question answered with all questionnaire data as context.
/// 3. A general query answered with all available patient data as context.
struct PatientAIView: View {
    let patient: Patient

    @Environment(PatientStore.self) private var store

    private enum Mode: Hashable {
        case insights
        case questionnaires
        case general
    }

    @State private var mode: Mode = .insights
    @State private var prompt = ""
    @State private var response: String?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var canRun: Bool {
        guard !isLoading else { return false }
        if mode == .insights { return true }
        return !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                    TextField(QuestionnaireText.aiPromptPlaceholder, text: $prompt, axis: .vertical)
                        .lineLimit(2...6)
                }

                Button {
                    run()
                } label: {
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text(QuestionnaireText.aiThinkingLabel)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Label(
                            mode == .insights
                                ? QuestionnaireText.aiGenerateInsightsAction
                                : QuestionnaireText.aiAskAction,
                            systemImage: "sparkles"
                        )
                    }
                }
                .disabled(!canRun)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            if let response {
                Section(QuestionnaireText.aiResponseTitle) {
                    Text(aiMarkdown(response))
                        .textSelection(.enabled)
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
        errorMessage = nil
        isLoading = true
        let userMessage = buildUserMessage()
        Task {
            do {
                response = try await OpenAIChatService.complete(
                    systemPrompt: AIPrompts.system,
                    userMessage: userMessage
                )
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func buildUserMessage() -> String {
        switch mode {
        case .insights:
            return "\(AIPrompts.insights)\n\n--- Patient questionnaire data ---\n\(questionnairesContext())"
        case .questionnaires:
            return "\(prompt)\n\n--- Patient questionnaire data ---\n\(questionnairesContext())"
        case .general:
            return "\(prompt)\n\n--- Patient data ---\n\(fullContext())"
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
        lines.append("GAD-7 total: \(q.gad7Score)")

        lines.append("PHQ-9 (each answer 0-3):")
        lines.append(contentsOf: answerLines(
            questions: QuestionnaireText.phq9Questions, answers: q.phq9Answers, notes: q.phq9Notes
        ))
        lines.append("PHQ-9 total: \(q.phq9Score)")

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
    .environment(PatientStore(client: auth.client))
}
