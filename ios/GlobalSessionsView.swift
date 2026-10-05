import SwiftUI

/// Cross-patient Sessions tab: all clinic sessions grouped by month.
struct GlobalSessionsView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(PatientStore.self) private var store

    @State private var isLoading = false
    @State private var loadError: String?
    @State private var editor: SessionEditorRoute?
    @State private var patientSearch = ""

    private var hasRecoverableSession: Bool {
        guard let account = auth.currentUserId,
              let key = try? DeviceDraftStorage.key(userID: account, kind: store.isDemoMode ? "demo-session" : "therapist-session", target: "new:global") else { return false }
        return DeviceDraftStorage().contains(key: key)
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
                        Button(L10n.retry) {
                            Task { await load() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if allItems.isEmpty {
                    ContentUnavailableView {
                        Label(L10n.noSessionsYetLabel, systemImage: "calendar.badge.plus")
                    } description: {
                        Text(L10n.emptySessionsBody)
                    }
                } else if visibleItems.isEmpty {
                    ContentUnavailableView {
                        Label(L10n.sessionsSearchEmpty, systemImage: "magnifyingglass")
                    }
                } else {
                    sessionsList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("sessions.root")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                addSessionCTA
            }
            .patientAtmosphere(Theme.gold)
            .themedScreen()
            .background(Theme.base.ignoresSafeArea())
            .demoModeChrome()
            .navigationTitle(L10n.therapistTabSessions)
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $patientSearch, prompt: L10n.sessionsSearchPrompt)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if EntitlementState.shared.allowMutation() { editor = SessionEditorRoute(patient: nil, session: Session(), isNew: true) }
                    } label: {
                        Label(L10n.newSessionTitle, systemImage: "plus")
                    }.entitlementCreateControl()
                }
            }
            .sheet(item: $editor) { route in
                SessionEditorView(
                    session: route.session,
                    patient: route.patient,
                    isNew: route.isNew,
                    sessionNumber: route.sessionNumber
                )
            }
            .task { await load() }
            .task(id: store.patients.map(\.id.queryValue).joined(separator: ",")) {
                await loadQuestionnairesForScores()
            }
            .refreshable { await load() }
        }
    }

    private var addSessionCTA: some View {
        Button(hasRecoverableSession ? L10n.resumeSessionSummary : allItems.isEmpty ? L10n.createSessionAction : L10n.addSessionAction) {
            if EntitlementState.shared.allowMutation() { editor = SessionEditorRoute(patient: nil, session: Session(), isNew: true) }
        }.entitlementCreateControl()
        .buttonStyle(.pressableProminent)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Theme.base)
    }

    private var sessionsList: some View {
        List {
            if upcomingItems.isEmpty {
                Section(L10n.upcomingSessionsSection) {
                    Text(L10n.noUpcomingSessionsBody)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
            } else {
                ForEach(months(upcomingItems), id: \.month) { group in
                    Section(header: Text(L10n.sessionsMonthSection(
                        L10n.upcomingSessionsSection, month: L10n.hebrewMonth(group.month)))) {
                        sessionRows(group.items)
                    }
                }
            }
            if pastItems.isEmpty {
                Section(L10n.pastSessionsSection) {
                    Text(L10n.noPastSessionsBody)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
            } else {
                ForEach(months(pastItems), id: \.month) { group in
                    Section(header: Text(L10n.sessionsMonthSection(
                        L10n.pastSessionsSection, month: L10n.hebrewMonth(group.month)))) {
                        sessionRows(group.items)
                    }
                }
            }
        }
        .patientAtmosphere(Theme.gold)
        .themedScreen()
    }

    @ViewBuilder
    private func sessionRows(_ items: [GlobalSessionItem]) -> some View {
        ForEach(items) { item in
            Button {
                editor = SessionEditorRoute(patient: item.patient, session: item.session, isNew: false)
            } label: {
                GlobalSessionRow(item: item, scores: scorePreview(for: item))
            }
            .buttonStyle(.plain)
            .listRowBackground(groupBorderedRow(
                .at(items.firstIndex(of: item) ?? 0, of: items.count),
                accent: Theme.gold))
            .listRowSeparatorTint(Theme.borderFaint)
        }
    }

    /// All clinic sessions with the owning patient, derived from PatientStore.
    private var allItems: [GlobalSessionItem] {
        store.patients.flatMap { patient in
            let chronological = patient.sessions.sorted { $0.date < $1.date }
            return chronological.enumerated().map { index, session in
                GlobalSessionItem(
                    patient: patient,
                    session: session,
                    number: index + 1
                )
            }
        }
    }

    /// Search patient names across the clinic while retaining session context.
    private var visibleItems: [GlobalSessionItem] {
        let query = patientSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return allItems }
        return allItems.filter { $0.patient.displayName.localizedStandardContains(query) }
    }

    /// Date-only sessions for today and later are upcoming; closest first.
    /// The editor has no time-of-day field, so today's sessions stay here all day.
    private var upcomingItems: [GlobalSessionItem] {
        let today = Calendar.current.startOfDay(for: .now)
        return visibleItems
            .filter { $0.session.date >= today }
            .sorted {
                if $0.session.date != $1.session.date { return $0.session.date < $1.session.date }
                return $0.patient.displayName.localizedCaseInsensitiveCompare($1.patient.displayName) == .orderedAscending
            }
    }

    /// Earlier sessions are grouped by month, newest first.
    private var pastItems: [GlobalSessionItem] {
        let today = Calendar.current.startOfDay(for: .now)
        return visibleItems
            .filter { $0.session.date < today }
            .sorted {
                if $0.session.date != $1.session.date { return $0.session.date > $1.session.date }
                return $0.patient.displayName.localizedCaseInsensitiveCompare($1.patient.displayName) == .orderedAscending
            }
    }

    private func months(_ items: [GlobalSessionItem]) -> [(month: Date, items: [GlobalSessionItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items) { item in
            calendar.dateInterval(of: .month, for: item.session.date)?.start ?? item.session.date
        }
        var orderedMonths: [Date] = []
        var seenMonths = Set<Date>()
        for item in items {
            let month = calendar.dateInterval(of: .month, for: item.session.date)?.start ?? item.session.date
            if seenMonths.insert(month).inserted {
                orderedMonths.append(month)
            }
        }
        return orderedMonths.compactMap { month in
            grouped[month].map { (month: month, items: $0) }
        }
    }

    private func load() async {
        store.loadCachedPatients()
        guard !store.isDemoMode else { return }
        isLoading = true
        loadError = nil
        do {
            try await store.loadPatients()
        } catch is CancellationError {
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
        await loadQuestionnairesForScores()
    }

    /// Fills questionnaire caches so session-linked score chips can render.
    private func loadQuestionnairesForScores() async {
        for patient in store.patients where store.cachedQuestionnaires(for: patient) == nil {
            _ = try? await store.loadQuestionnaires(for: patient)
        }
    }

    /// Same association as Patient → Sessions: questionnaire whose
    /// `sessionID` matches this session, plus the previous session-linked one.
    private func scorePreview(for item: GlobalSessionItem) -> ScorePreview? {
        let newestFirst = item.patient.sessions.sorted { $0.date > $1.date }
        guard let index = newestFirst.firstIndex(where: { $0.id == item.session.id }),
              let records = store.cachedQuestionnaires(for: item.patient),
              let sessionID = item.session.databaseID,
              let record = records.first(where: { $0.sessionID == sessionID })
        else { return nil }
        let previous = newestFirst[(index + 1)...].lazy
            .compactMap { earlier in
                earlier.databaseID.flatMap { id in records.first { $0.sessionID == id } }
            }
            .first
        return ScorePreview(
            questionnaire: record.questionnaire,
            previous: previous?.questionnaire
        )
    }
}

/// Presentation-only pairing of a session with its patient.
private struct GlobalSessionItem: Identifiable, Equatable {
    let patient: Patient
    let session: Session
    let number: Int

    var id: UUID { session.id }

    static func == (lhs: GlobalSessionItem, rhs: GlobalSessionItem) -> Bool {
        lhs.session.id == rhs.session.id
    }
}

private struct SessionEditorRoute: Identifiable {
    let patient: Patient?
    let session: Session
    let isNew: Bool

    var id: UUID { session.id }

    var sessionNumber: Int? {
        guard !isNew, let patient else { return nil }
        let chronological = patient.sessions.sorted { $0.date < $1.date }
        return (chronological.firstIndex { $0.id == session.id } ?? 0) + 1
    }
}

private struct GlobalSessionRow: View {
    let item: GlobalSessionItem
    let scores: ScorePreview?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.title3)
                .foregroundStyle(Theme.gold)
                .frame(width: 34, height: 34)
                .background(Theme.goldGhost, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.patient.displayName)
                    .font(.headline)
                Text(sessionSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(L10n.hebrewDate(item.session.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let scores {
                VStack(alignment: .trailing, spacing: 4) {
                    ScoreCapsule.gad7(scores.questionnaire, previous: scores.previous)
                    ScoreCapsule.phq9(scores.questionnaire, previous: scores.previous)
                }
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var sessionSummary: String {
        if let type = item.session.type {
            return "\(L10n.session(item.number)) · \(L10n.label(for: type))"
        }
        return L10n.session(item.number)
    }
}
