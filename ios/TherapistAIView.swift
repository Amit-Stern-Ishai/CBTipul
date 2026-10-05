import SwiftUI

/// A local patient picker; the destination owns the existing transient chat.
struct TherapistAIView: View {
    @Environment(PatientStore.self) private var store
    @State private var search = ""
    @State private var isLoading = false
    @State private var loadError: String?

    private var patients: [Patient] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.patients.filter { query.isEmpty || $0.displayName.localizedStandardContains(query) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if isLoading && store.patients.isEmpty {
                        ProgressView()
                    } else if let loadError, store.patients.isEmpty {
                        Text(loadError).foregroundStyle(Theme.error)
                        Button(L10n.retry) { Task { await load() } }
                    } else if store.patients.isEmpty {
                        Text(L10n.addFirstPatientMessage).foregroundStyle(.secondary)
                    } else if patients.isEmpty {
                        Text(L10n.patientsSearchEmpty).foregroundStyle(.secondary)
                    } else {
                        ForEach(patients) { patient in
                            NavigationLink {
                                PatientAIView(patient: patient)
                            } label: {
                                PatientListRow(patient: patient)
                            }
                        }
                    }
                } header: {
                    Text(L10n.aiPatientPickerPrompt).textCase(nil)
                }
            }
            .searchable(text: $search, prompt: L10n.patientsSearchPrompt)
            .navigationTitle(L10n.aiPatientPickerTitle)
            .patientAtmosphere(Theme.gold)
            .demoModeChrome()
            .task {
                store.loadCachedPatients()
                if store.patients.isEmpty { await load() }
            }
            .refreshable { await load() }
            .accessibilityIdentifier("therapist.ai.patientPicker")
        }
    }

    @MainActor private func load() async {
        guard !store.isDemoMode else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do { try await store.loadPatients() }
        catch is CancellationError { }
        catch { loadError = error.localizedDescription }
    }
}
