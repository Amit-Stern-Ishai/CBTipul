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

            QuestionnaireSections(questionnaire: $session.questionnaire, isEditable: true)

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
/// history list. Uses the same layout as the editing screen (including the
/// per-question notes) but without note icons, and taps change nothing.
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

            QuestionnaireSections(questionnaire: .constant(record.questionnaire), isEditable: false)
        }
        .navigationTitle(record.answeredDate.formatted(date: .abbreviated, time: .omitted))
    }
}

/// The GAD-7 and PHQ-9 form sections shared by the editing and read-only
/// screens.
private struct QuestionnaireSections: View {
    @Binding var questionnaire: CombinedMoodQuestionnaire
    let isEditable: Bool

    var body: some View {
        Section(QuestionnaireText.gad7Title) {
            AnswerKeyView()

            Text(QuestionnaireText.gad7MainQuestion)
                .font(.headline)

            ForEach(QuestionnaireText.gad7Questions.indices, id: \.self) { index in
                QuestionRow(
                    text: QuestionnaireText.gad7Questions[index],
                    selection: $questionnaire.gad7Answers[index],
                    note: $questionnaire.gad7Notes[index],
                    isEditable: isEditable
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
                    selection: $questionnaire.phq9Answers[index],
                    note: $questionnaire.phq9Notes[index],
                    isEditable: isEditable
                )
            }

            InterferencePicker(
                selection: $questionnaire.interferenceLevel,
                note: $questionnaire.interferenceNote,
                isEditable: isEditable
            )

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

/// The PHQ-9 interference question with its four worded options and note.
private struct InterferencePicker: View {
    @Binding var selection: Int?
    @Binding var note: String
    let isEditable: Bool

    @State private var isEditingNote = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(QuestionnaireText.phq9InterferenceQuestion)
                    .font(.headline)
                Spacer()
                if isEditable {
                    Button {
                        isEditingNote = true
                    } label: {
                        Image(systemName: note.isEmpty ? "square.and.pencil" : "note.text")
                            .foregroundStyle(note.isEmpty ? Color.secondary : Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !note.isEmpty {
                NoteBox(note: note, onTap: isEditable ? { isEditingNote = true } : nil)
            }

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
        .sheet(isPresented: $isEditingNote) {
            QuestionNoteEditor(question: QuestionnaireText.phq9InterferenceQuestion, note: $note)
        }
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

/// A single question with its 0–3 answer scale and optional note.
///
/// In edit mode a note icon opens the note editor (tap again to change an
/// existing note); the note itself is shown under the question in both modes.
private struct QuestionRow: View {
    let text: String
    @Binding var selection: Int?
    @Binding var note: String
    let isEditable: Bool

    @State private var isEditingNote = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(text)
                Spacer()
                if isEditable {
                    Button {
                        isEditingNote = true
                    } label: {
                        Image(systemName: note.isEmpty ? "square.and.pencil" : "note.text")
                            .foregroundStyle(note.isEmpty ? Color.secondary : Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !note.isEmpty {
                NoteBox(note: note, onTap: isEditable ? { isEditingNote = true } : nil)
            }

            AnswerScaleView(selection: $selection)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $isEditingNote) {
            QuestionNoteEditor(question: text, note: $note)
        }
    }
}

/// The inline display of a question's note. In edit mode tapping it opens
/// the note editor, same as the note icon.
private struct NoteBox: View {
    let note: String
    var onTap: (() -> Void)? = nil

    var body: some View {
        if let onTap {
            Button(action: onTap) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var content: some View {
        Text(note)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Sheet for adding or editing the note of a single question.
private struct QuestionNoteEditor: View {
    let question: String
    @Binding var note: String

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(question)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section(QuestionnaireText.questionNoteTitle) {
                    TextField(QuestionnaireText.notesFieldPlaceholder, text: $draft, axis: .vertical)
                        .lineLimit(4...10)
                }
            }
            .dismissesKeyboardOnTap()
            .navigationTitle(QuestionnaireText.questionNoteTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        note = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                }
            }
            .onAppear { draft = note }
        }
        .presentationDetents([.medium, .large])
    }
}

/// A segmented 0...3 selector that shows an unanswered state when nil.
struct AnswerScaleView: View {
    @Binding var selection: Int?

    var body: some View {
        HStack(spacing: 8) {
            // Highest value first so 0 ends up on the right.
            ForEach(CombinedMoodQuestionnaire.answerValues.reversed(), id: \.self) { value in
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
    var questionnaire = CombinedMoodQuestionnaire()
    questionnaire.gad7Notes[0] = "Example note for the first question."
    return NavigationStack {
        CompletedQuestionnaireView(record: CompletedQuestionnaire(
            databaseID: .integer(1),
            sessionID: nil,
            answeredDate: .now,
            questionnaire: questionnaire
        ), patientName: "Alex Rivera")
    }
}
