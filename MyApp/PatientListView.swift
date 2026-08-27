import SwiftUI

/// Lists the therapist's patients and allows adding new ones.
struct PatientListView: View {
    @Environment(PatientStore.self) private var store

    @State private var isAddingPatient = false
    @State private var isShowingSettings = false
    @State private var isLoading = false
    @State private var loadError: String?

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
                        Button(L10n.retry) {
                            Task { await load() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if store.patients.isEmpty {
                    ContentUnavailableView {
                        Label(L10n.noPatientsTitle, systemImage: "person.crop.circle.badge.plus")
                    } description: {
                        Text(L10n.addFirstPatientMessage)
                    } actions: {
                        Button(L10n.addPatientAction) { isAddingPatient = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(sortedPatients) { patient in
                        NavigationLink(value: patient) {
                            PatientRow(patient: patient)
                        }
                        .listRowBackground(Theme.surface)
                        .listRowSeparatorTint(Theme.borderFaint)
                    }
                    .themedScreen()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.base.ignoresSafeArea())
            .animation(.easeInOut(duration: 0.25), value: isLoading)
            .animation(.easeInOut(duration: 0.25), value: loadError)
            .navigationTitle(L10n.patientsTitle)
            .task { await load() }
            .refreshable { await load() }
            .navigationDestination(for: Patient.self) { patient in
                PatientDetailView(patient: patient)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingPatient = true
                    } label: {
                        Label(L10n.addPatientAction, systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Label(L10n.settingsTitle, systemImage: "gearshape")
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

    /// Patients with the active ones on top, alphabetical within each group,
    /// independent of the order the database returns them in.
    private var sortedPatients: [Patient] {
        store.patients.sorted {
            if ($0.status == .active) != ($1.status == .active) {
                return $0.status == .active
            }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
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

/// A single row in the patient list: name and the last session's type with
/// the session count next to the avatar, the latest questionnaire scores on
/// the trailing edge, and a minimal status dot on the avatar (green =
/// active, faint = inactive).
private struct PatientRow: View {
    let patient: Patient

    @Environment(PatientStore.self) private var store

    var body: some View {
        HStack(spacing: 12) {
            InitialsAvatar(name: patient.displayName, size: 44)
                .overlay(alignment: .bottomTrailing) { statusDot }
                .accessibilityLabel(patient.status.rawValue)
            VStack(alignment: .leading, spacing: 3) {
                Text(patient.displayName)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            scoresLine
                .animation(.easeInOut(duration: 0.35), value: isLoadingScores)
                .animation(.easeInOut(duration: 0.35), value: lastQuestionnaire?.id)
        }
        .padding(.vertical, 2)
        .task {
            // Fill the questionnaire cache lazily, once per patient.
            if store.cachedQuestionnaires(for: patient) == nil {
                _ = try? await store.loadQuestionnaires(for: patient)
            }
        }
    }

    /// The minimal active/inactive indication, ringed so it reads against
    /// the avatar.
    private var statusDot: some View {
        Circle()
            .fill(patient.status == .active ? Theme.success : Theme.textFaint)
            .frame(width: 12, height: 12)
            .overlay(Circle().strokeBorder(Theme.surface, lineWidth: 2))
    }

    /// The last session's type (its date when no type was picked) plus the
    /// session count so far.
    private var subtitle: String {
        guard let lastSession = patient.sessions.max(by: { $0.date < $1.date }) else {
            return L10n.noSessionsYetLabel
        }
        let typeOrDate = lastSession.type.map(L10n.label(for:))
            ?? L10n.hebrewDate(lastSession.date)
        return L10n.lastSessionSummary(typeOrDate, count: patient.sessionsUpToTodayCount)
    }

    /// The latest scores with trends; reserved placeholders while loading.
    @ViewBuilder
    private var scoresLine: some View {
        if let questionnaire = lastQuestionnaire?.questionnaire {
            VStack(alignment: .trailing, spacing: 4) {
                ScoreCapsule.gad7(questionnaire, previous: previousQuestionnaire?.questionnaire)
                ScoreCapsule.phq9(questionnaire, previous: previousQuestionnaire?.questionnaire)
            }
            .transition(.opacity)
        } else if isLoadingScores {
            VStack(alignment: .trailing, spacing: 4) {
                ScoreCapsule(text: L10n.scoreBadge(name: L10n.gad7ShortName, score: 10),
                             color: Theme.textFaint)
                ScoreCapsule(text: L10n.scoreBadge(name: L10n.phq9ShortName, score: 10),
                             color: Theme.textFaint)
            }
            .redacted(reason: .placeholder)
            .opacity(0.4)
            .transition(.opacity)
        }
    }

    private var isLoadingScores: Bool {
        store.cachedQuestionnaires(for: patient) == nil
    }

    private var lastQuestionnaire: CompletedQuestionnaire? {
        store.cachedQuestionnaires(for: patient)?.max { $0.answeredDate < $1.answeredDate }
    }

    private var previousQuestionnaire: CompletedQuestionnaire? {
        guard let records = store.cachedQuestionnaires(for: patient),
              let last = lastQuestionnaire else { return nil }
        return records
            .filter { $0.id != last.id && $0.answeredDate <= last.answeredDate }
            .max { $0.answeredDate < $1.answeredDate }
    }
}

/// A circular gradient badge showing a person's initials.
struct InitialsAvatar: View {
    let name: String
    var size: CGFloat = 44

    private var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters)
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.textOnAccent)
            .frame(width: size, height: size)
            .background(Theme.accentFill, in: Circle())
    }
}

/// A colored capsule showing whether a patient is active.
struct StatusBadge: View {
    let status: PatientStatus

    private var color: Color { status == .active ? Theme.success : Theme.textBody }

    var body: some View {
        Text(status.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

#Preview {
    let auth = AuthManager()
    let store = PatientStore(client: auth.client)
    store.patients = [
        Patient(id: .integer(1), firstName: "Alex", lastName: "Rivera"),
        Patient(id: .integer(2), firstName: "Jordan", lastName: "Lee", status: .inactive),
    ]
    return PatientListView()
        .environment(auth)
        .environment(store)
        .appTextSize()
}
