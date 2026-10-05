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
            Group {
                if isLoading && store.patients.isEmpty {
                    ProgressView(L10n.loadingPatientsLabel)
                } else if let loadError, store.patients.isEmpty {
                    ContentUnavailableView {
                        Label(L10n.couldntLoadPatientsTitle, systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(loadError)
                    } actions: {
                        Button(L10n.retry) { Task { await load() } }
                            .buttonStyle(.borderedProminent)
                    }
                } else if store.patients.isEmpty {
                    ContentUnavailableView {
                        Label(L10n.noPatientsTitle, systemImage: "person.2")
                    } description: {
                        Text(L10n.addFirstPatientMessage)
                    }
                } else {
                    List {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(L10n.aiPatientPickerPrompt, systemImage: "sparkles")
                                .font(.headline)
                                .foregroundStyle(Theme.textBright)
                            Text(L10n.aiPatientPickerExplanation)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textBody)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        if patients.isEmpty {
                            Text(L10n.patientsSearchEmpty)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        } else {
                            patientSection(patients.filter { $0.status == .active }, title: L10n.activePatientsSectionTitle)
                            patientSection(patients.filter { $0.status != .active }, title: L10n.inactivePatientsSectionTitle)
                        }
                    }
                    .themedScreen()
                    .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: L10n.patientsSearchPrompt)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(L10n.aiPatientPickerTitle)
            .navigationBarTitleDisplayMode(.large)
            .patientAtmosphere(Theme.gold)
            .background(Theme.base.ignoresSafeArea())
            .subtleAnimation(value: isLoading)
            .subtleAnimation(value: loadError)
            .demoModeChrome()
            .task {
                store.loadCachedPatients()
                if store.patients.isEmpty { await load() }
            }
            .refreshable { await load() }
            .accessibilityIdentifier("therapist.ai.patientPicker")
        }
    }

    @ViewBuilder
    private func patientSection(_ patients: [Patient], title: String) -> some View {
        if !patients.isEmpty {
            Section(L10n.patientListSection(title, count: patients.count)) {
                ForEach(patients) { patient in
                    NavigationLink {
                        PatientAIView(patient: patient)
                    } label: {
                        PatientListRow(patient: patient, actionSubtitle: L10n.aiPatientPickerAction)
                    }
                    .listRowBackground(groupBorderedRow(
                        .at(patients.firstIndex(of: patient) ?? 0, of: patients.count),
                        accent: Theme.gold))
                    .listRowSeparatorTint(Theme.borderFaint)
                }
            }
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
