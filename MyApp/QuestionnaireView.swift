import SwiftUI

/// A single questionnaire (GAD-7 or depression) for a session.
///
/// Saving inserts the answers into the questionnaire's Supabase table,
/// linked to the patient and session. Question text is currently a stub.
struct QuestionnaireView: View {
    let kind: QuestionnaireKind
    let patient: Patient
    @Bindable var session: Session

    @Environment(PatientStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isSaving = false
    @State private var errorMessage: String?

    private var answers: Binding<[Int?]> {
        switch kind {
        case .gad7: return $session.questionnaire.gad7
        case .depression: return $session.questionnaire.depression
        }
    }

    private var canSave: Bool {
        session.questionnaire.isComplete(kind) && !isSaving
    }

    var body: some View {
        Form {
            Section(kind.title) {
                ForEach(kind.questions.indices, id: \.self) { index in
                    QuestionRow(
                        text: kind.questions[index],
                        selection: answers[index]
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
        .navigationTitle(kind.title)
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
                try await store.saveQuestionnaire(
                    kind,
                    answers: session.questionnaire[kind].compactMap { $0 },
                    for: patient,
                    session: session
                )
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
            ForEach(QuestionnaireContent.answerValues, id: \.self) { value in
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

#Preview {
    NavigationStack {
        QuestionnaireView(kind: .gad7, patient: Patient(firstName: "Alex"), session: Session())
    }
    .environment(PatientStore(client: AuthManager().client))
}
