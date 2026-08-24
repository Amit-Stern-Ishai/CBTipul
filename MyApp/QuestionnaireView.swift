import SwiftUI

/// The combined mood questionnaire screen for a session: the GAD-7 section
/// first, with the PHQ-9 section below it.
///
/// Saving upserts one combined row into Supabase, linked to the patient and
/// session. All wording comes from `L10n` (placeholders for now,
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

    /// The patient's most recent questionnaire from before this session,
    /// used to indicate the previous answers alongside each question.
    private var previousQuestionnaire: CompletedQuestionnaire? {
        guard let cached = store.cachedQuestionnaires(for: patient) else { return nil }
        let sessionDay = Calendar.current.startOfDay(for: session.date)
        return cached.first { $0.sessionID != session.databaseID && $0.answeredDate < sessionDay }
    }

    var body: some View {
        Form {
            QuestionnaireSections(
                questionnaire: $session.questionnaire,
                isEditable: true,
                previous: previousQuestionnaire
            )

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(patient.displayName)
        // The session's date, which is saved as the answered date.
        .navigationSubtitle(session.date.formatted(date: .abbreviated, time: .omitted))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.cancel) { dismiss() }
                    .disabled(isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.save) { save() }
                    .disabled(!canSave)
            }
        }
        .busyOverlay(isSaving)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .task {
            // Make sure the previous questionnaire is available when this
            // screen is opened before the cache was ever filled.
            if store.cachedQuestionnaires(for: patient) == nil {
                _ = try? await store.loadQuestionnaires(for: patient)
            }
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
    /// The questionnaire preceding this one, for the previous-answer marks.
    var previous: CompletedQuestionnaire? = nil

    var body: some View {
        Form {
            QuestionnaireSections(
                questionnaire: .constant(record.questionnaire),
                isEditable: false,
                previous: previous
            )
        }
        .navigationTitle(patientName ?? "")
        .navigationSubtitle(record.answeredDate.formatted(date: .abbreviated, time: .omitted))
    }
}

/// The GAD-7 and PHQ-9 form sections shared by the editing and read-only
/// screens.
private struct QuestionnaireSections: View {
    @Binding var questionnaire: CombinedMoodQuestionnaire
    let isEditable: Bool
    var previous: CompletedQuestionnaire? = nil

    private func previousAnswer(_ answers: [Int?]?, at index: Int) -> Int? {
        guard let answers, answers.indices.contains(index) else { return nil }
        return answers[index]
    }

    var body: some View {
        Section(L10n.gad7Title) {
            AnswerKeyView(previousDate: previous?.answeredDate)

            Text(markdown: L10n.gad7MainQuestion)
                .font(.body)

            ForEach(L10n.gad7Questions.indices, id: \.self) { index in
                QuestionRow(
                    text: L10n.gad7Questions[index],
                    selection: $questionnaire.gad7Answers[index],
                    note: $questionnaire.gad7Notes[index],
                    isEditable: isEditable,
                    previousAnswer: previousAnswer(previous?.questionnaire.gad7Answers, at: index)
                )
            }

            ScoreRow(
                score: questionnaire.gad7Score,
                classification: L10n.label(for: questionnaire.gad7Severity),
                previousScore: previous?.questionnaire.gad7Score,
                previousDate: previous?.answeredDate
            )
        }

        Section(L10n.phq9Title) {
            
            Text(markdown: L10n.phq9MainQuestion)
                .font(.body)
            
            ForEach(L10n.phq9Questions.indices, id: \.self) { index in
                QuestionRow(
                    text: L10n.phq9Questions[index],
                    selection: $questionnaire.phq9Answers[index],
                    note: $questionnaire.phq9Notes[index],
                    isEditable: isEditable,
                    previousAnswer: previousAnswer(previous?.questionnaire.phq9Answers, at: index)
                )
            }

            InterferencePicker(
                selection: $questionnaire.interferenceLevel,
                note: $questionnaire.interferenceNote,
                isEditable: isEditable,
                previousSelection: previous?.questionnaire.interferenceLevel
            )

            ScoreRow(
                score: questionnaire.phq9Score,
                classification: L10n.label(for: questionnaire.phq9Severity),
                previousScore: previous?.questionnaire.phq9Score,
                previousDate: previous?.answeredDate
            )

            Text(L10n.suggestion(for: questionnaire.phq9Severity))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// Legend explaining what each 0–3 answer value means.
private struct AnswerKeyView: View {
    var previousDate: Date? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.answerKeyTitle)
                .font(.subheadline.weight(.semibold))
            ForEach(L10n.answerDescriptions.indices, id: \.self) { index in
                Text(L10n.answerDescriptions[index])
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let previousDate {
                Text(L10n.previousAnswerLegend(
                    dateText: previousDate.formatted(date: .abbreviated, time: .omitted)
                ))
                .font(.footnote)
                .foregroundStyle(.orange)
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
    var previousSelection: Int? = nil

    @State private var isEditingNote = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                // Regular weight so the string's **bold** words stand out
                // (headline is semibold, which drowns the emphasis).
                Text(markdown: L10n.phq9InterferenceQuestion)
                    .font(.body)
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

            ForEach(L10n.phq9InterferenceOptions.indices, id: \.self) { index in
                let isSelected = selection == index
                Button {
                    selection = index
                } label: {
                    HStack {
                        Text(L10n.phq9InterferenceOptions[index])
                        if previousSelection == index {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
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
            QuestionNoteEditor(question: L10n.phq9InterferenceQuestion, note: $note)
        }
    }
}

/// The live sum of a questionnaire part with its classification next to it,
/// plus the previous questionnaire's sum when known.
private struct ScoreRow: View {
    let score: Int
    let classification: String
    var previousScore: Int? = nil
    var previousDate: Date? = nil

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.totalScoreLine(score))
                    .font(.headline)
                if let previousScore, let previousDate {
                    Text(L10n.previousScoreLine(dateText: previousDate.formatted(date: .abbreviated, time: .omitted), score: previousScore))
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
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
    var previousAnswer: Int? = nil

    @State private var isEditingNote = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(markdown: text)
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

            AnswerScaleView(selection: $selection, previousValue: previousAnswer)
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
                    Text(markdown: question)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section(L10n.questionNoteTitle) {
                    NotesField(text: $draft, placeholder: L10n.notesFieldPlaceholder,
                               minLines: 4, maxLines: 10)
                }
            }
            .dismissesKeyboardOnTap()
            .navigationTitle(L10n.questionNoteTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        note = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                }
            }
            .onAppear { draft = note }
        }
        .presentationDetents([.medium, .large])
        .appTextSize()
    }
}

private extension Text {
    /// Renders inline markdown (e.g. `**bold**`) in wording-table strings.
    /// `Text` with a plain `String` shows markdown literally, so strings that
    /// carry emphasis must go through this initializer.
    init(markdown string: String) {
        if let attributed = try? AttributedString(markdown: string) {
            self.init(attributed)
        } else {
            self.init(string)
        }
    }
}

/// A segmented 0...3 selector that shows an unanswered state when nil.
/// The previous questionnaire's answer, when known, is outlined.
struct AnswerScaleView: View {
    @Binding var selection: Int?
    var previousValue: Int? = nil

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
                        .overlay {
                            if previousValue == value {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.orange, lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview("Editing") {
    NavigationStack {
        CombinedMoodQuestionnaireView(patient: Patient(id: .integer(1), firstName: "Alex"), session: Session())
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
