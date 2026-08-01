import SwiftUI

/// Editor for a session's date and notes.
///
/// Saving a new session inserts a row into the Supabase `Sessions` table.
/// Edits to an existing session currently only update the in-memory model.
struct SessionEditorView: View {
    @Bindable var session: Session
    let patient: Patient
    var isNew: Bool

    @Environment(PatientStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    DatePicker("Date", selection: $session.date, displayedComponents: [.date])
                }

                Section("Notes") {
                    TextField("Optional notes", text: $session.notes, axis: .vertical)
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
        }
    }

    private func save() {
        guard isNew else {
            dismiss()
            return
        }
        errorMessage = nil
        isSaving = true
        Task {
            do {
                try await store.addSession(session, for: patient)
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
