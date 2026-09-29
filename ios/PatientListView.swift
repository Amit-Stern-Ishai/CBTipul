import SwiftUI
import OSLog

/// Lists the therapist's patients and allows adding new ones.
struct PatientListView: View {
    @Environment(PatientStore.self) private var store
    @Environment(OnboardingStore.self) private var onboarding
    @Environment(GettingStartedRouter.self) private var gettingStartedRouter
    @Environment(TherapistNotificationCoordinator.self) private var notificationCoordinator

    @State private var isAddingPatient = false
    @State private var isLoading = false
    @State private var hasFinishedInitialLoad = false
    @State private var loadError: String?
    @State private var path = NavigationPath()
    @State private var patientSearch = ""

    /// Tutorial patient the walkthrough is following (furthest along).
    private var tutorialFocusPatientID: DatabaseID? {
        gettingStartedRouter.progress.focusPatientID
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
            .accessibilityIdentifier("patients.root")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showsPatientAddCTA {
                    addPatientCTA
                }
            }
            .patientAtmosphere(Theme.gold)
            .background(Theme.base.ignoresSafeArea())
            .demoModeChrome()
            .subtleAnimation(value: isLoading)
            .subtleAnimation(value: loadError)
            .navigationTitle(L10n.therapistTabPatients)
            .navigationBarTitleDisplayMode(.large)
            .task { await load() }
            .refreshable { await load() }
            .navigationDestination(for: Patient.self) { patient in
                PatientDetailView(patient: patient)
            }
            .navigationDestination(for: PatientQuestionnairesRoute.self) { route in
                if let patient = store.patients.first(where: { $0.id == route.patientID }) {
                    PatientQuestionnairesView(
                        patient: patient,
                        focusQuestionnaireID: route.focusQuestionnaireID
                    )
                } else {
                    ContentUnavailableView {
                        Label(L10n.notificationTargetUnavailable, systemImage: "questionmark.circle")
                    }
                }
            }
            .navigationDestination(for: PatientDiaryOneRoute.self) { route in
                if let patient = store.patients.first(where: { $0.id == route.patientID }) {
                    PatientDiaryOneView(patient: patient, focusEntryID: route.focusEntryID)
                } else {
                    ContentUnavailableView {
                        Label(L10n.notificationTargetUnavailable, systemImage: "questionmark.circle")
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingPatient = true
                    } label: {
                        Label(L10n.addPatientAction, systemImage: "plus")
                    }
                        .tutorialPulse(
                        store.isDemoMode
                            && !onboarding.checklistDismissed
                            && gettingStartedRouter.shouldPulse(.addPatient),
                        style: .toolbar
                    )
                }
            }
            .sheet(isPresented: $isAddingPatient, onDismiss: {
                gettingStartedRouter.setPlacement(.patientList)
                refreshProgress()
            }) {
                AddPatientView()
            }
            .onChange(of: tutorialProgressSignature) { _, _ in
                refreshProgress()
            }
            .onAppear {
                gettingStartedRouter.setPlacement(.patientList)
                refreshProgress()
            }
            .onChange(of: path.count) { _, count in
                guard count == 0 else { return }
                notificationCoordinator.finishInboxNavigation()
                gettingStartedRouter.setPlacement(.patientList)
                refreshProgress()
            }
            .task(id: store.patients.map(\.id.queryValue).joined(separator: ",")) {
                guard !store.isDemoMode else {
                    refreshProgress()
                    return
                }
                await loadQuestionnairesForProgress()
                refreshProgress()
            }
        }
        .onChange(of: store.isDemoMode) { wasDemo, isDemo in
            if isDemo {
                isAddingPatient = false
                gettingStartedRouter.setPlacement(.patientList)
                refreshProgress()
                return
            }
            guard wasDemo else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                path = NavigationPath()
                isAddingPatient = false
            }
            gettingStartedRouter.clearHighlight()
            refreshProgress()
        }
        .onChange(of: gettingStartedRouter.wantsPatientListReset) { _, wantsReset in
            guard wantsReset, gettingStartedRouter.consumePatientListReset() else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                path = NavigationPath()
                isAddingPatient = false
            }
            gettingStartedRouter.patientListDidReset(using: onboarding)
        }
        .onChange(of: notificationCoordinator.pendingPatientNavigation?.token) { _, token in
            guard token != nil else { return }
            applyPendingNotificationRoute()
        }
        .onAppear {
            applyPendingNotificationRoute()
        }
    }

    /// Gold add control stays on-screen after the first patient exists.
    private var showsPatientAddCTA: Bool {
        !store.patients.isEmpty || (!isLoading && loadError == nil)
    }

    private var addPatientCTA: some View {
        VStack(spacing: 8) {
            Button(store.patients.isEmpty ? L10n.emptyPatientsPrimaryAction : L10n.addPatientAction) {
                isAddingPatient = true
            }
            .buttonStyle(.pressableProminent)
            .frame(maxWidth: .infinity)
            .tutorialPulse(
                store.isDemoMode
                    && !onboarding.checklistDismissed
                    && gettingStartedRouter.shouldPulse(.addPatient)
            )
            if store.patients.isEmpty && !store.isDemoMode {
                Button(L10n.enterDemoModeAction) { startDemoTour() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Theme.base)
    }

    private var emptyPatientsContent: some View {
        ContentUnavailableView {
            Label(L10n.noPatientsTitle, systemImage: "person.crop.circle.badge.plus")
        } description: {
            Text(L10n.addFirstPatientMessage)
        }
    }

    private var patientsListContent: some View {
        List {
            if visibleActivePatients.isEmpty, visibleInactivePatients.isEmpty {
                Text(L10n.patientsSearchEmpty)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                if !visibleActivePatients.isEmpty {
                    Section(L10n.patientListSection(L10n.activePatientsSectionTitle, count: visibleActivePatients.count)) {
                        patientRows(visibleActivePatients)
                    }
                }
                if !visibleInactivePatients.isEmpty {
                    Section(L10n.patientListSection(L10n.inactivePatientsSectionTitle, count: visibleInactivePatients.count)) {
                        patientRows(visibleInactivePatients)
                    }
                }
            }
        }
        .patientAtmosphere(Theme.gold)
        .themedScreen()
        .searchable(text: $patientSearch, placement: .navigationBarDrawer(displayMode: .always), prompt: L10n.patientsSearchPrompt)
    }

    @ViewBuilder
    private func patientRows(_ patients: [Patient]) -> some View {
        ForEach(patients) { patient in
            let isTutorialFocus =
                store.isDemoMode
                && !onboarding.checklistDismissed
                && gettingStartedRouter.shouldPulse(.tutorialPatient)
                && patient.id == tutorialFocusPatientID
            NavigationLink(value: patient) {
                PatientRow(patient: patient)
                    .tutorialPulse(isTutorialFocus)
            }
            .listRowBackground(groupBorderedRow(
                .at(patients.firstIndex(of: patient) ?? 0, of: patients.count),
                accent: Theme.gold))
            .listRowSeparatorTint(Theme.borderFaint)
        }
    }

    /// Alphabetical within each status group.
    private var sortedPatients: [Patient] {
        store.patients.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private var matchingPatients: [Patient] {
        let query = patientSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sortedPatients }
        return sortedPatients.filter {
            $0.displayName.localizedStandardContains(query)
        }
    }

    private var visibleActivePatients: [Patient] {
        matchingPatients.filter { $0.status == .active }
    }

    private var visibleInactivePatients: [Patient] {
        matchingPatients.filter { $0.status == .inactive }
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
        notificationCoordinator.markPatientsLoadSettled()
        notificationCoordinator.processPending(patients: store.patients)
        await loadQuestionnairesForProgress()
        refreshProgress()
    }

    private func applyPendingNotificationRoute() {
        guard let pending = notificationCoordinator.consumePatientNavigation() else { return }
        guard let patient = store.patients.first(where: { $0.id == pending.patientID }) else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            var next = NavigationPath()
            next.append(patient)
            if let questionnaires = pending.questionnairesRoute {
                next.append(questionnaires)
            } else if let diaryOne = pending.diaryOneRoute {
                next.append(diaryOne)
            }
            path = next
        }
        #if DEBUG
        AppLog.store.debug(
            "notification path applied patient=\(patient.id.queryValue, privacy: .public) focus=\(pending.questionnairesRoute?.focusQuestionnaireID?.queryValue ?? "nil", privacy: .public)"
        )
        #endif
    }

    private func refreshProgress() {
        gettingStartedRouter.refresh(using: store)
    }

    /// Fills questionnaire caches needed for Getting Started progress.
    private func loadQuestionnairesForProgress() async {
        for patient in store.patients where store.cachedQuestionnaires(for: patient) == nil {
            _ = try? await store.loadQuestionnaires(for: patient)
        }
    }

    private func startDemoTour() {
        store.enterDemoMode()
        path = NavigationPath()
    }

}

/// A single row in the patient directory: local display name and last session date.
private struct PatientRow: View {
    let patient: Patient

    var body: some View {
        HStack(spacing: 12) {
            InitialsAvatar(name: patient.displayName, size: 44, patientID: patient.id)
            VStack(alignment: .leading, spacing: 3) {
                Text(patient.displayName)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textBody)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Match the date-only split used by the sessions list: today is upcoming.
    private var subtitle: String {
        let today = Calendar.current.startOfDay(for: .now)
        if let next = patient.sessions.filter({ $0.date >= today }).min(by: { $0.date < $1.date }) {
            return L10n.patientListNextSession(next.date)
        }
        guard let last = patient.sessions.max(by: { $0.date < $1.date }) else {
            return L10n.noSessionsYetLabel
        }
        return L10n.patientListLastSession(last.date)
    }

    private var accessibilityLabel: String {
        "\(patient.displayName), \(L10n.patientStatus(patient.status)), \(subtitle)"
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

    private var color: Color { status == .active ? Theme.success : Theme.error }

    var body: some View {
        Text(L10n.patientStatus(status))
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
        .environment(GettingStartedRouter())
        .appTextSize()
}
