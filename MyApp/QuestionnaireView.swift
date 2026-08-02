import SwiftUI

/// The combined mood questionnaire screen for a session: the GAD-7 section
/// first, with the PHQ-9 section below it.
///
/// Saving upserts one combined row into Supabase, linked to the patient and
/// session. All wording comes from `QuestionnaireText` (placeholders for now,
/// Hebrew later).
struct CombinedMoodQuestionnaireView: View {
    let patient: Patient
    @Bindable var session: Session

    @Environment(PatientStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isSaving = false
    @State private var errorMessage: String?

    private var canSave: Bool {
        session.questionnaire.isComplete && !isSaving
    }

    var body: some View {
        Form {
            Section {
                Label(patient.displayName, systemImage: "person")
                    .foregroundStyle(.secondary)
            }

            QuestionnaireSections(questionnaire: $session.questionnaire)

            Section(QuestionnaireText.notesSectionTitle) {
                TextField(QuestionnaireText.notesFieldPlaceholder,
                          text: $session.questionnaire.notes,
                          axis: .vertical)
                    .lineLimit(3...8)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(QuestionnaireText.combinedTitle)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .disabled(isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
        .overlay {
            if isSaving { ProgressView() }
        }
    }

    private func save() {
        errorMessage = nil
        isSaving = true
        Task {
            do {
                try await store.saveQuestionnaire(session.questionnaire, for: patient, session: session)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

/// Read-only view of a saved questionnaire, opened from the questionnaire
/// history list. Uses the same layout as the editing screen but ignores taps.
struct CompletedQuestionnaireView: View {
    let record: CompletedQuestionnaire
    var patientName: String? = nil

    var body: some View {
        Form {
            if let patientName {
                Section {
                    Label(patientName, systemImage: "person")
                        .foregroundStyle(.secondary)
                }
            }

            QuestionnaireSections(questionnaire: .constant(record.questionnaire))

            if !record.questionnaire.notes.isEmpty {
                Section(QuestionnaireText.notesSectionTitle) {
                    Text(record.questionnaire.notes)
                }
            }
        }
        .navigationTitle(record.answeredDate.formatted(date: .abbreviated, time: .omitted))
    }
}

/// The GAD-7 and PHQ-9 form sections shared by the editing and read-only
/// screens.
private struct QuestionnaireSections: View {
    @Binding var questionnaire: CombinedMoodQuestionnaire

    var body: some View {
        Section(QuestionnaireText.gad7Title) {
            AnswerKeyView()

            Text(QuestionnaireText.gad7MainQuestion)
                .font(.headline)

            ForEach(QuestionnaireText.gad7Questions.indices, id: \.self) { index in
                QuestionRow(
                    text: QuestionnaireText.gad7Questions[index],
                    selection: $questionnaire.gad7Answers[index]
                )
            }

            ScoreRow(
                score: questionnaire.gad7Score,
                classification: QuestionnaireText.label(for: questionnaire.gad7Severity)
            )
        }

        Section(QuestionnaireText.phq9Title) {
            ForEach(QuestionnaireText.phq9Questions.indices, id: \.self) { index in
                QuestionRow(
                    text: QuestionnaireText.phq9Questions[index],
                    selection: $questionnaire.phq9Answers[index]
                )
            }

            InterferencePicker(selection: $questionnaire.interferenceLevel)

            ScoreRow(
                score: questionnaire.phq9Score,
                classification: QuestionnaireText.label(for: questionnaire.phq9Severity)
            )

            Text(QuestionnaireText.suggestion(for: questionnaire.phq9Severity))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// Legend explaining what each 0–3 answer value means.
private struct AnswerKeyView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(QuestionnaireText.answerKeyTitle)
                .font(.subheadline.weight(.semibold))
            ForEach(QuestionnaireText.answerDescriptions.indices, id: \.self) { index in
                Text(QuestionnaireText.answerDescriptions[index])
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// The PHQ-9 interference question with its four worded options.
private struct InterferencePicker: View {
    @Binding var selection: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(QuestionnaireText.phq9InterferenceQuestion)
                .font(.headline)

            ForEach(QuestionnaireText.phq9InterferenceOptions.indices, id: \.self) { index in
                let isSelected = selection == index
                Button {
                    selection = index
                } label: {
                    HStack {
                        Text(QuestionnaireText.phq9InterferenceOptions[index])
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

/// The live sum of a questionnaire part with its classification next to it.
private struct ScoreRow: View {
    let score: Int
    let classification: String

    var body: some View {
        HStack {
            Text("\(QuestionnaireText.scoreLabel): \(score)")
                .font(.headline)
            Spacer()
            Text(classification)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

/// A single question with its 0–3 answer scale.
private struct QuestionRow: View {
    let text: String
    @Binding var selection: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
            AnswerScaleView(selection: $selection)
        }
        .padding(.vertical, 4)
    }
}

/// A segmented 0...3 selector that shows an unanswered state when nil.
struct AnswerScaleView: View {
    @Binding var selection: Int?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(CombinedMoodQuestionnaire.answerValues, id: \.self) { value in
                let isSelected = selection == value
                Button {
                    selection = value
                } label: {
                    Text("\(value)")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview("Editing") {
    NavigationStack {
        CombinedMoodQuestionnaireView(patient: Patient(firstName: "Alex"), session: Session())
    }
    .environment(PatientStore(client: AuthManager().client))
}

#Preview("Read-only") {
    NavigationStack {
        CompletedQuestionnaireView(record: CompletedQuestionnaire(
            databaseID: .integer(1),
            sessionID: nil,
            answeredDate: .now,
            questionnaire: CombinedMoodQuestionnaire()
        ), patientName: "Alex Rivera")
    }
}
