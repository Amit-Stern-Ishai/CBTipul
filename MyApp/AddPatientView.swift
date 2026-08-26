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
                        .foregroundStyle(Theme.textOnAccent)
                        .frame(width: 64, height: 64)
                        .background(Theme.accentFill, in: Circle())
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }

                Section(L10n.patientSectionTitle) {
                    TextField(L10n.firstNamePlaceholder, text: $firstName, prompt: Text(""))
                        .stablePlaceholder(L10n.firstNamePlaceholder, isShown: firstName.isEmpty)
                    TextField(L10n.lastNamePlaceholder, text: $lastName, prompt: Text(""))
                        .stablePlaceholder(L10n.lastNamePlaceholder, isShown: lastName.isEmpty)
                    Picker(L10n.statusLabel, selection: $status) {
                        ForEach(PatientStatus.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                .listRowBackground(Theme.surface)

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Theme.error)
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            .themedScreen()
            .dismissesKeyboardOnTap()
            .animation(.easeInOut(duration: 0.2), value: errorMessage)
            .navigationTitle(L10n.newPatientTitle)
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
        }
        .appTextSize()
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
