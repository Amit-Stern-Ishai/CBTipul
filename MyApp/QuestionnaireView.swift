import SwiftUI

/// The GAD-7 anxiety questionnaire screen for a session.
struct GAD7QuestionnaireView: View {
    let patient: Patient
    @Bindable var session: Session

    var body: some View {
        QuestionnaireForm(patient: patient, session: session, questionnaire: $session.gad7)
    }
}

/// The depression questionnaire screen for a session.
struct DepressionQuestionnaireView: View {
    let patient: Patient
    @Bindable var session: Session

    var body: some View {
        QuestionnaireForm(patient: patient, session: session, questionnaire: $session.depression)
    }
}

/// Shared form UI for a single questionnaire: one row per question plus
/// save handling. Saving inserts the answers into the questionnaire's
/// Supabase table, linked to the patient and session.
private struct QuestionnaireForm<Questionnaire: SessionQuestionnaire>: View {
    let patient: Patient
    let session: Session
    @Binding var questionnaire: Questionnaire

    @Environment(PatientStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isSaving = false
    @State private var errorMessage: String?

    private var canSave: Bool {
        questionnaire.isComplete && !isSaving
    }

    var body: some View {
        Form {
            Section(Questionnaire.title) {
                ForEach(Questionnaire.questions.indices, id: \.self) { index in
                    QuestionRow(
                        text: Questionnaire.questions[index],
                        selection: $questionnaire.answers[index]
                    )
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(Questionnaire.title)
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
                try await store.saveQuestionnaire(questionnaire, for: patient, session: session)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
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
            ForEach(QuestionnaireScale.answerValues, id: \.self) { value in
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

#Preview("GAD-7") {
    NavigationStack {
        GAD7QuestionnaireView(patient: Patient(firstName: "Alex"), session: Session())
    }
    .environment(PatientStore(client: AuthManager().client))
}

#Preview("Depression") {
    NavigationStack {
        DepressionQuestionnaireView(patient: Patient(firstName: "Alex"), session: Session())
    }
    .environment(PatientStore(client: AuthManager().client))
}
