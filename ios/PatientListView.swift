import SwiftUI

/// Lists the therapist's patients and allows adding new ones.
struct PatientListView: View {
    @Environment(PatientStore.self) private var store
    @Environment(OnboardingStore.self) private var onboarding

    @State private var isAddingPatient = false
    @State private var isShowingSettings = false
    @State private var isShowingWelcome = false
    @State private var isLoading = false
    @State private var hasFinishedInitialLoad = false
    @State private var loadError: String?
    @State private var path = NavigationPath()
    @State private var gettingStartedRouter = GettingStartedRouter()
    @State private var progress = GettingStartedProgress.empty

    private var shouldShowWelcome: Bool {
        hasFinishedInitialLoad
            && !isLoading
            && !store.isDemoMode
            && store.patients.filter { !DemoData.isDemoID($0.id) }.isEmpty
            && !onboarding.welcomeDismissed
            && loadError == nil
    }

    private var shouldShowGettingStartedCard: Bool {
        hasFinishedInitialLoad
            && !onboarding.checklistDismissed
            && (onboarding.welcomeDismissed || !store.patients.filter { !DemoData.isDemoID($0.id) }.isEmpty || store.isDemoMode)
    }

    var body: some View {
        NavigationStack(path: $path) {
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
                    emptyPatientsContent
                } else {
                    patientsListContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .demoModeChrome()
            .patientAtmosphere(Theme.gold)
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
            .fullScreenCover(isPresented: $isShowingWelcome) {
                WelcomeOnboardingView(
                    onStartDemoTour: {
                        startDemoTour()
                    },
                    onSkip: {
                        onboarding.dismissWelcome()
                        isShowingWelcome = false
                    }
                )
                .appTextSize()
            }
            .onChange(of: shouldShowWelcome, initial: true) { _, show in
                isShowingWelcome = show
            }
            .onChange(of: store.patients.count, initial: true) { _, _ in
                refreshProgress()
            }
            .onChange(of: path.count) { _, count in
                if count == 0 { refreshProgress() }
            }
            .onAppear { refreshProgress() }
            .task(id: store.patients.map(\.id.queryValue).joined(separator: ",")) {
                await loadQuestionnairesForProgress()
                refreshProgress()
            }
        }
        .onChange(of: store.isDemoMode) { wasDemo, isDemo in
            // Leaving demo from any screen should land on the real patient list.
            guard wasDemo, !isDemo else { return }
            path = NavigationPath()
            isAddingPatient = false
            isShowingSettings = false
            refreshProgress()
        }
        .environment(gettingStartedRouter)
    }

    @ViewBuilder
    private var gettingStartedSection: some View {
        if shouldShowGettingStartedCard {
            GettingStartedCard(
                progress: progress,
                onSelectStep: handleGettingStartedStep,
                onDismiss: { onboarding.dismissChecklist() }
            )
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
    }

    private var emptyPatientsContent: some View {
        VStack(spacing: 0) {
            gettingStartedSection
            ContentUnavailableView {
                Label(L10n.noPatientsTitle, systemImage: "person.crop.circle.badge.plus")
            } description: {
                Text(L10n.addFirstPatientMessage)
            } actions: {
                Button(L10n.emptyPatientsPrimaryAction) { isAddingPatient = true }
                    .buttonStyle(.borderedProminent)
                if !store.isDemoMode {
                    Button(L10n.enterDemoModeAction) { startDemoTour() }
                        .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var patientsListContent: some View {
        List {
            if shouldShowGettingStartedCard {
                Section {
                    GettingStartedCard(
                        progress: progress,
                        onSelectStep: handleGettingStartedStep,
                        onDismiss: { onboarding.dismissChecklist() }
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            Section {
                ForEach(sortedPatients) { patient in
                    NavigationLink(value: patient) {
                        PatientRow(patient: patient)
                    }
                    .listRowBackground(groupBorderedRow(
                        .at(sortedPatients.firstIndex(of: patient) ?? 0,
                            of: sortedPatients.count),
                        accent: Theme.gold))
                    .listRowSeparatorTint(Theme.borderFaint)
                }
            }
        }
        .patientAtmosphere(Theme.gold)
        .themedScreen()
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
        refreshProgress()
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
        hasFinishedInitialLoad = true
        await loadQuestionnairesForProgress()
        refreshProgress()
    }

    private func refreshProgress() {
        progress = GettingStartedProgress.evaluate(
            store: store,
            hasCompletedDemoTour: onboarding.hasCompletedDemoTour
        )
    }

    /// Fills questionnaire caches needed for Getting Started progress.
    private func loadQuestionnairesForProgress() async {
        for patient in store.patients where store.cachedQuestionnaires(for: patient) == nil {
            _ = try? await store.loadQuestionnaires(for: patient)
        }
    }

    private func startDemoTour() {
        store.enterDemoMode()
        onboarding.markDemoTourCompleted()
        onboarding.dismissWelcome()
        isShowingWelcome = false
        refreshProgress()
        if let first = sortedPatients.first {
            path.append(first)
        }
    }

    /// Checklist steps after the tour stay inside the local demo clinic.
    private func ensureDemoModeForTutorial() {
        guard !store.isDemoMode else { return }
        store.enterDemoMode()
        onboarding.markDemoTourCompleted()
        onboarding.dismissWelcome()
        isShowingWelcome = false
        refreshProgress()
    }

    private func handleGettingStartedStep(_ step: GettingStartedStep) {
        switch step {
        case .demoTour:
            startDemoTour()
        case .addPatient:
            ensureDemoModeForTutorial()
            isAddingPatient = true
        case .treatmentGoal:
            ensureDemoModeForTutorial()
            navigateToTutorialPatient(focus: .editTreatmentGoal)
        case .firstSession:
            ensureDemoModeForTutorial()
            navigateToTutorialPatient(focus: .sessions(.addSession))
        case .questionnaire:
            ensureDemoModeForTutorial()
            navigateToTutorialPatient(focus: .sessions(.addQuestionnaire))
        case .sessionSummary:
            ensureDemoModeForTutorial()
            navigateToTutorialPatient(focus: .sessions(.editLatestForSummary))
        case .preparation:
            ensureDemoModeForTutorial()
            navigateToTutorialPatient(focus: .prepareNextSession)
        }
    }

    private func navigateToTutorialPatient(focus: GettingStartedFocus) {
        let tutorial = sortedPatients.first { DemoData.isTutorialPatientID($0.id) }
        guard let patient = tutorial else {
            isAddingPatient = true
            return
        }
        gettingStartedRouter.pendingFocus = focus
        path.append(patient)
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
            InitialsAvatar(name: patient.displayName, size: 44, patientID: patient.id)
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
    /// The patient's stable ID. When set, the circle uses the patient's
    /// deterministic palette color instead of the brand accent, with black
    /// or white initials picked automatically for contrast.
    var patientID: DatabaseID? = nil

    private var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters)
    }

    private var background: Color {
        patientID.map(PatientAvatarColor.background(for:)) ?? Theme.accentFill
    }

    private var foreground: Color {
        patientID.map(PatientAvatarColor.foreground(for:)) ?? Theme.textOnAccent
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(background, in: Circle())
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
        .environment(OnboardingStore.shared)
        .appTextSize()
}
