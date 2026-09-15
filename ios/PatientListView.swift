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
            && store.isDemoMode
            && !onboarding.checklistDismissed
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
            .patientAtmosphere(Theme.gold)
            .background(Theme.base.ignoresSafeArea())
            .demoModeChrome()
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
                        gettingStartedRouter.clearHighlightIfMatching(.addPatient)
                        isAddingPatient = true
                    } label: {
                        Label(L10n.addPatientAction, systemImage: "plus")
                    }
                    .tutorialPulse(gettingStartedRouter.highlight == .addPatient)
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
            .onChange(of: tutorialProgressSignature) { _, _ in
                refreshProgress()
            }
            .onChange(of: progress.currentStep) { oldStep, newStep in
                handleCurrentStepChange(from: oldStep, to: newStep)
            }
            .onAppear { refreshProgress() }
            .task(id: store.patients.map(\.id.queryValue).joined(separator: ",")) {
                await loadQuestionnairesForProgress()
                refreshProgress()
            }
        }
        .onChange(of: store.isDemoMode) { wasDemo, isDemo in
            if isDemo {
                onboarding.showChecklistAgain()
                refreshProgress()
                gettingStartedRouter.highlight = progress.currentStep?.highlight
                return
            }
            // Leaving demo from any screen should land on the real patient list.
            guard wasDemo else { return }
            path = NavigationPath()
            isAddingPatient = false
            isShowingSettings = false
            gettingStartedRouter.clearHighlight()
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
                onRestart: restartTutorial,
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
                    .tutorialPulse(gettingStartedRouter.highlight == .addPatient)
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
                        onRestart: restartTutorial,
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

    /// Fingerprint of tutorial patients so nested session/notes changes refresh progress.
    private var tutorialProgressSignature: String {
        store.patients
            .filter { DemoData.isTutorialPatientID($0.id) }
            .map { patient in
                let questionnaireCount = store.cachedQuestionnaires(for: patient)?.count ?? -1
                let sessionPart = patient.sessions
                    .map { "\($0.notes.count)-\($0.structuredNotes != nil)" }
                    .joined(separator: ",")
                return "\(patient.id.queryValue):\(patient.sessions.count):\(sessionPart):\(questionnaireCount)"
            }
            .joined(separator: "|")
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
        progress = GettingStartedProgress.evaluate(store: store)
    }

    /// Fills questionnaire caches needed for Getting Started progress.
    private func loadQuestionnairesForProgress() async {
        for patient in store.patients where store.cachedQuestionnaires(for: patient) == nil {
            _ = try? await store.loadQuestionnaires(for: patient)
        }
    }

    private func startDemoTour() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            store.enterDemoMode()
            onboarding.markDemoTourCompleted()
            onboarding.dismissWelcome()
            onboarding.showChecklistAgain()
            isShowingWelcome = false
            path = NavigationPath()
        }
        refreshProgress()
        gettingStartedRouter.highlight = progress.currentStep?.highlight ?? .addPatient
    }

    /// Checklist steps stay inside the local demo clinic.
    private func ensureDemoModeForTutorial() {
        guard !store.isDemoMode else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            store.enterDemoMode()
            onboarding.markDemoTourCompleted()
            onboarding.dismissWelcome()
            onboarding.showChecklistAgain()
            isShowingWelcome = false
        }
        refreshProgress()
    }

    private func handleGettingStartedStep(_ step: GettingStartedStep) {
        ensureDemoModeForTutorial()
        applyTutorialNavigation(for: step)
    }

    private func restartTutorial() {
        ensureDemoModeForTutorial()
        store.restartDemoTutorial()
        path = NavigationPath()
        isAddingPatient = false
        refreshProgress()
        gettingStartedRouter.highlight = .addPatient
    }

    private func navigateToTutorialPatient() {
        let tutorial = sortedPatients.first { DemoData.isTutorialPatientID($0.id) }
        guard let patient = tutorial else {
            gettingStartedRouter.highlight = .addPatient
            return
        }
        path = NavigationPath()
        path.append(patient)
    }

    /// Updates the coach-mark when the active checklist step changes.
    /// Does not auto-navigate — pushing screens here on demo enter made a
    /// patient screen flash then get dismissed with the cover/sheet.
    private func handleCurrentStepChange(
        from oldStep: GettingStartedStep?,
        to newStep: GettingStartedStep?
    ) {
        guard store.isDemoMode else { return }
        guard let newStep else {
            gettingStartedRouter.clearHighlight()
            return
        }

        if newStep == .createSession,
           gettingStartedRouter.highlight == .addSession {
            return
        }

        gettingStartedRouter.highlight = newStep.highlight
    }

    private func applyTutorialNavigation(for step: GettingStartedStep) {
        switch step {
        case .createPatient:
            path = NavigationPath()
            isAddingPatient = false
            gettingStartedRouter.highlight = .addPatient

        case .createSession:
            gettingStartedRouter.highlight = .sessionsEntry
            navigateToTutorialPatient()

        case .fillQuestionnaire:
            gettingStartedRouter.highlight = .fillQuestionnaire
            gettingStartedRouter.pendingSessionsAction = .editLatestForSummary
            navigateToTutorialPatient()

        case .recordSessionSummary:
            gettingStartedRouter.highlight = .recordNotes
            gettingStartedRouter.pendingSessionsAction = .editLatestForSummary
            navigateToTutorialPatient()

        case .createAISummary:
            gettingStartedRouter.highlight = .aiSummary
            gettingStartedRouter.pendingSessionsAction = .editLatestForSummary
            navigateToTutorialPatient()
        }
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
