import SwiftUI

/// Form for adding a new patient. Saving inserts a row into the Supabase
/// `Patients` table.
struct AddPatientView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(PatientStore.self) private var store
    @Environment(GettingStartedRouter.self) private var gettingStartedRouter
    @Environment(\.dismiss) private var dismiss

    @State private var creationID = UUID()
    @State private var creationOwner: String?
    var onInviteCreatedPatient: (Patient) -> Void = { _ in }
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
                        ForEach(PatientStatus.allCases) { Text(L10n.patientStatus($0)).tag($0) }
                    }
                }
                .listRowBackground(Theme.surface)

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(BrandTypography.footnote)
                            .foregroundStyle(Theme.error)
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            // The popup presenter is zero-sized; keep its screen background full-width.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .themedScreen()
            .dismissesKeyboardOnTap()
            .animation(.easeInOut(duration: 0.2), value: errorMessage)
            .brandNavigationTitle(L10n.newPatientTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                        .disabled(isSaving)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: save) {
                    Group {
                        if isSaving {
                            ProgressView()
                                .tint(Theme.textOnAccent)
                        } else {
                            Text(L10n.savePatientAction)
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.pressableProminent)
                .disabled(!canSave)
                .padding(24)
            }
            .onDisappear { FeatureDiscovery.shared.presentationOpportunity() }
        .onChange(of: auth.currentUserId) { _, value in
                if value != creationOwner { dismiss() }
            }
            .demoModeChrome()
            .busyOverlay(isSaving)
            .onAppear {
                gettingStartedRouter.setPlacement(.addPatient)
            }
        }
        .appTextSize()
    }

    private func save() {
        errorMessage = nil
        isSaving = true
        creationOwner = auth.currentUserId
        Task {
            do {
                let patient = try await store.addPatient(
                    firstName: firstName,
                    lastName: lastName,
                    status: status,
                    creationID: creationID
                )
                guard creationOwner == auth.currentUserId else { dismiss(); return }
                if !store.isDemoMode, let patient {
                    FeatureDiscovery.shared.enqueue("invite", account: creationOwner, patient: patient.id, demo: store.isDemoMode, initialOnly: true)
                    dismiss()
                } else { dismiss() }
            } catch {
                errorMessage = error.userFacingMessage
                isSaving = false
            }
        }
    }
}

#Preview {
    AddPatientView()
        .environment(PatientStore(client: AuthManager().client))
}
