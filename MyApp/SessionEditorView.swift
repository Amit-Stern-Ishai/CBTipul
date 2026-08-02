import SwiftUI

/// Editor for a session's date and notes.
///
/// Saving a new session inserts a row into the Supabase `Sessions` table;
/// saving an existing one updates its row (date and notes). For existing
/// sessions the saved questionnaire, if any, is shown as a compact row that
/// opens the full read-only questionnaire.
struct SessionEditorView: View {
    @Bindable var session: Session
    let patient: Patient
    var isNew: Bool

    @Environment(PatientStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var questionnaire: CompletedQuestionnaire?
    @State private var isLoadingQuestionnaire = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(patient.displayName, systemImage: "person")
                        .foregroundStyle(.secondary)
                }

                Section("Session") {
                    DatePicker("Date", selection: $session.date, displayedComponents: [.date])
                }

                Section("Notes") {
                    TextField("Optional notes", text: $session.notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                if !isNew {
                    questionnaireSection
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isNew ? "New Session" : "Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isSaving)
                }
            }
            .overlay {
                if isSaving { ProgressView() }
            }
            .task { await loadQuestionnaire() }
        }
    }

    private var questionnaireSection: some View {
        Section(QuestionnaireText.questionnaireSectionTitle) {
            if let questionnaire {
                NavigationLink {
                    CompletedQuestionnaireView(record: questionnaire, patientName: patient.displayName)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(questionnaire.answeredDate, style: .date)
                            .font(.headline)
                        Text("\(QuestionnaireText.gad7ShortName): \(questionnaire.questionnaire.gad7Score) · \(QuestionnaireText.phq9ShortName): \(questionnaire.questionnaire.phq9Score)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if isLoadingQuestionnaire {
                ProgressView()
            } else {
                Text(QuestionnaireText.noQuestionnaireForSession)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Shows this session's questionnaire from the cache immediately, then
    /// refreshes from the server in the background.
    private func loadQuestionnaire() async {
        guard !isNew, let sessionID = session.databaseID else { return }

        if let cached = store.cachedQuestionnaires(for: patient) {
            questionnaire = cached.first { $0.sessionID == sessionID }
        } else {
            isLoadingQuestionnaire = true
        }

        do {
            let all = try await store.loadQuestionnaires(for: patient)
            questionnaire = all.first { $0.sessionID == sessionID }
        } catch {
            // Keep whatever the cache had; the section shows the empty state
            // rather than blocking the editor on a failed refresh.
        }
        isLoadingQuestionnaire = false
    }

    private func save() {
        errorMessage = nil
        isSaving = true
        Task {
            do {
                if isNew {
                    try await store.addSession(session, for: patient)
                } else {
                    try await store.updateSession(session)
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

#Preview {
    SessionEditorView(session: Session(), patient: Patient(firstName: "Alex"), isNew: true)
        .environment(PatientStore(client: AuthManager().client))
}
