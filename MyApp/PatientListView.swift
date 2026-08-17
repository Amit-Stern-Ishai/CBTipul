import SwiftUI

/// Lists the therapist's patients and allows adding new ones.
struct PatientListView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(PatientStore.self) private var store

    @State private var isAddingPatient = false
    @State private var isShowingSettings = false
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && store.patients.isEmpty {
                    ProgressView("Loading patients…")
                } else if let loadError, store.patients.isEmpty {
                    ContentUnavailableView {
                        Label("Couldn't Load Patients", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(loadError)
                    } actions: {
                        Button("Retry") {
                            Task { await load() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if store.patients.isEmpty {
                    ContentUnavailableView {
                        Label("No Patients", systemImage: "person.crop.circle.badge.plus")
                    } description: {
                        Text("Add your first patient to get started.")
                    } actions: {
                        Button("Add Patient") { isAddingPatient = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(store.patients) { patient in
                        NavigationLink(value: patient) {
                            PatientRow(patient: patient)
                        }
                    }
                }
            }
            .navigationTitle("Patients")
            .task { await load() }
            .refreshable { await load() }
            .navigationDestination(for: Patient.self) { patient in
                PatientDetailView(patient: patient)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sign Out") {
                        store.clearCachedPatients()
                        auth.signOut()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingPatient = true
                    } label: {
                        Label("Add Patient", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Label(QuestionnaireText.settingsTitle, systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $isAddingPatient) {
                AddPatientView()
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
        }
    }

    private func load() async {
        store.loadCachedPatients()
        isLoading = true
        loadError = nil
        do {
            try await store.loadPatients()
        } catch is CancellationError {
            // View went away mid-load; nothing to show.
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}

/// A single row in the patient list.
private struct PatientRow: View {
    let patient: Patient

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(patient.displayName)
                    .font(.headline)
                Text(patient.sessions.isEmpty ? "No sessions yet" : "Session \(patient.currentSessionNumber)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusBadge(status: patient.status)
        }
    }
}

/// A colored capsule showing whether a patient is active.
struct StatusBadge: View {
    let status: PatientStatus

    private var color: Color { status == .active ? .green : .gray }

    var body: some View {
        Text(status.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

#Preview {
    let auth = AuthManager()
    let store = PatientStore(client: auth.client)
    store.patients = [
        Patient(firstName: "Alex", lastName: "Rivera"),
        Patient(firstName: "Jordan", lastName: "Lee", status: .inactive),
    ]
    return PatientListView()
        .environment(auth)
        .environment(store)
}
