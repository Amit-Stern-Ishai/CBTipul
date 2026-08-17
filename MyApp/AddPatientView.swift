import SwiftUI

/// Form for adding a new patient. Saving inserts a row into the Supabase
/// `Patients` table.
struct AddPatientView: View {
    @Environment(PatientStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var status: PatientStatus = .active
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var trimmedFirstName: String {
        firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedLastName: String {
        lastName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !(trimmedFirstName.isEmpty && trimmedLastName.isEmpty) && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.65)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Circle()
                        )
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }

                Section("Patient") {
                    TextField("First name", text: $firstName)
                    TextField("Last name", text: $lastName)
                    Picker("Status", selection: $status) {
                        ForEach(PatientStatus.allCases) { Text($0.rawValue).tag($0) }
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
            .dismissesKeyboardOnTap()
            .navigationTitle("New Patient")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(!canSave)
                }
            }
            .overlay {
                if isSaving { ProgressView() }
            }
        }
    }

    private func save() {
        errorMessage = nil
        isSaving = true
        Task {
            do {
                try await store.addPatient(
                    firstName: trimmedFirstName,
                    lastName: trimmedLastName,
                    status: status
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

#Preview {
    AddPatientView()
        .environment(PatientStore(client: AuthManager().client))
}
