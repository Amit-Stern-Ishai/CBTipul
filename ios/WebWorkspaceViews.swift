import SwiftUI

struct WebWorkspaceRoute: Hashable { let id: String }
struct WebWorkspaceAssociationRoute: Hashable { let id: String }

struct WebWorkspaceInboxView: View {
    @Environment(WebWorkspaceStore.self) private var workspaces
    var body: some View {
        List {
            if workspaces.isLoading && workspaces.items.isEmpty { ProgressView() }
            if workspaces.failed {
                Section { Text(L10n.wwLoadFailed); Button(L10n.retry) { Task { await workspaces.refresh() } } }
            } else if !workspaces.isLoading && workspaces.items.isEmpty {
                ContentUnavailableView(L10n.wwEmpty, systemImage: "tray", description: Text(L10n.wwEmptyBody))
            }
            // Uncertain requests remain recoverable even after the server removed the pending row.
            ForEach(workspaces.requests.keys.sorted().filter { id in !workspaces.items.contains { $0.id == id } }, id: \.self) { id in
                NavigationLink(L10n.wwRetryAssociation, value: WebWorkspaceRoute(id: id))
            }
            ForEach(workspaces.items) { item in
                NavigationLink(value: WebWorkspaceRoute(id: item.id)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.reference_label ?? L10n.wwUntitled).font(.headline)
                        Text(L10n.wwStarted + WebWorkspaceDate.display(item.started_at))
                        Text(L10n.wwFinished + WebWorkspaceDate.display(item.finished_at))
                        Text(L10n.wwActivityCount(item.item_count, notes: item.has_notes)).foregroundStyle(Theme.textBody)
                    }.font(.subheadline).padding(.vertical, 6)
                }
            }
        }
        .navigationTitle(L10n.wwInbox).themedScreen()
        .navigationDestination(for: WebWorkspaceRoute.self) { WebWorkspacePreview(id: $0.id) }
        .task { await workspaces.refresh() }
        .refreshable { await workspaces.refresh() }
        .toolbar { Button(L10n.wwRefresh, systemImage: "arrow.clockwise") { Task { await workspaces.refresh() } }.disabled(workspaces.isLoading) }
    }
}

enum WebWorkspaceDate {
    static func display(_ raw: String) -> String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = f.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        return date?.formatted(date: .numeric, time: .shortened) ?? raw
    }
    static func dateOnly(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.calendar = Calendar(identifier: .gregorian); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

struct WebWorkspacePreview: View {
    let id: String
    @Environment(WebWorkspaceStore.self) private var workspaces
    @Environment(PatientStore.self) private var patients
    @State private var entitlement = EntitlementState.shared
    @State private var workspace: WebWorkspace?
    @State private var loading = true
    @State private var error: String?
    @State private var unavailable = false
    @State private var completed = false
    @State private var confirmDiscard = false
    private var busy: Bool { workspaces.busyIDs.contains(id) }
    var body: some View {
        List {
            if completed {
                Section { Label(L10n.wwDone, systemImage: "checkmark.circle")
                    if workspaces.refreshFailed { Text(L10n.wwRefreshFailed); Button(L10n.retry) { Task { await reloadRecords() } } }
                }
            } else {
                if loading { ProgressView() }
                if let error { Section { Text(error).foregroundStyle(Theme.error)
                    if !unavailable { Button(L10n.retry) { Task { await load() } } }
                } }
                if let workspace {
                    Section {
                        if let label = workspace.reference_label { Text(label).font(.headline) }
                        Text(L10n.wwStarted + WebWorkspaceDate.display(workspace.started_at))
                        if let finished = workspace.finished_at { Text(L10n.wwFinished + WebWorkspaceDate.display(finished)) }
                        Text(L10n.wwActivityCount(workspace.payload.items.count, notes: workspace.payload.hasNotes))
                    }
                    ForEach(workspace.payload.items) { item in
                        NavigationLink { WebWorksheetPreview(item: item) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.title)
                                Text(WebWorkspaceDate.display(item.completed_at)).font(.caption)
                                if case .questionnaire(let q) = item.content {
                                    HStack { ScoreCapsule.gad7(q.questionnaire); ScoreCapsule.phq9(q.questionnaire) }
                                    if q.flagsQuestionNine { Text(L10n.wwQuestionNineFlag).foregroundStyle(Theme.error) }
                                }
                            }
                        }
                    }
                    if workspace.payload.hasNotes { Section(L10n.wwNotes) { Text(workspace.payload.notes).textSelection(.enabled) } }
                }
                if (!unavailable && !workspaces.closedIDs.contains(id)) || workspaces.requests[id] != nil {
                    if entitlement.access == .full {
                        if workspace != nil {
                            NavigationLink(L10n.wwAssociate, value: WebWorkspaceAssociationRoute(id: id)).disabled(busy)
                        } else if workspaces.requests[id] != nil {
                            NavigationLink(L10n.wwRetryAssociation, value: WebWorkspaceAssociationRoute(id: id)).disabled(busy)
                        }
                        if workspace != nil && workspaces.requests[id] == nil {
                            Button(L10n.wwDiscard, role: .destructive) { confirmDiscard = true }.disabled(busy)
                        }
                    } else { Text(L10n.entitlementReadOnlyExplanation).foregroundStyle(Theme.textBody) }
                }
                if busy { ProgressView() }
            }
        }
        .navigationTitle(L10n.wwPreview).navigationBarTitleDisplayMode(.inline).themedScreen()
        .navigationDestination(for: WebWorkspaceAssociationRoute.self) { route in
            WebWorkspaceAssociationView(id: route.id, payload: workspace?.payload) { completed = true }
        }
        .task { if !completed { await load() } }
        .refreshable { if !completed && !busy { await load() } }
        .confirmationDialog(L10n.wwDiscard, isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button(L10n.wwDiscard, role: .destructive) { Task {
                do { try await workspaces.discard(id); completed = true }
                catch { self.error = (error as? WebWorkspaceFailure ?? .uncertain).message; await workspaces.refresh() }
            } }
        } message: { Text(L10n.wwDiscardConfirm) }
    }
    private func load() async {
        loading = true; defer { loading = false }
        do { workspace = try await workspaces.load(id); error = nil; unavailable = false }
        catch {
            let failure = error as? WebWorkspaceFailure ?? WebWorkspaceFailure.classify(error)
            unavailable = failure == .unavailable
            self.error = unavailable ? L10n.wwUnavailable : L10n.wwLoadFailed
            if unavailable {
                if workspaces.requests[id] == nil { workspaces.markUnavailable(id) }
                await workspaces.refresh()
            }
        }
    }
    private func reloadRecords() async {
        // Completion already happened; retry only the refresh, never transfer again.
        await workspaces.refreshAfterSuccess()
    }
}

struct WebWorkspaceAssociationView: View {
    let id: String
    let payload: WebWorkspacePayload?
    let onSuccess: () -> Void
    @Environment(WebWorkspaceStore.self) private var workspaces
    @Environment(PatientStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var patientID = ""
    @State private var target = 0 // 0 patient-level, 1 existing session, 2 new session
    @State private var sessionID = ""
    @State private var sessionDate = Date()
    @State private var sessionType: SessionType?
    @State private var linkQuestionnaire = false
    @State private var error: String?
    @State private var loadingPatients = false
    @State private var closed = false
    @State private var confirmation: WebAssociationRequest?
    @State private var entitlement = EntitlementState.shared
    private var locked: WebAssociationRequest? { workspaces.requests[id] }
    private var busy: Bool { workspaces.busyIDs.contains(id) }
    private var patient: Patient? { store.patients.first { $0.id.matches(patientID) } }
    private var needsSession: Bool { payload?.hasNotes == true || linkQuestionnaire }
    private var conflict: Bool {
        guard linkQuestionnaire, target == 1, let patient else { return false }
        return store.cachedQuestionnaires(for: patient)?.contains { $0.sessionID?.matches(sessionID) == true } == true
    }
    private var proposed: WebAssociationRequest {
        WebAssociationRequest(p_workspace_id: id, p_patient_id: patientID,
            p_existing_session_id: needsSession && target == 1 ? sessionID : nil,
            p_create_session: needsSession && target == 2, p_link_questionnaire: linkQuestionnaire,
            p_session_date: needsSession && target == 2 ? WebWorkspaceDate.dateOnly(sessionDate) : nil,
            p_session_type: needsSession && target == 2 ? sessionType?.rawValue : nil)
    }
    private var valid: Bool {
        guard !closed, !workspaces.closedIDs.contains(id), !loadingPatients, entitlement.access == .full else { return false }
        if locked != nil { return true }
        guard let payload, patient != nil, !conflict,
              !needsSession || (target == 2 || (target == 1 && patient?.sessions.contains { $0.databaseID?.matches(sessionID) == true } == true)) else { return false }
        return (try? proposed.validate(hasNotes: payload.hasNotes, hasQuestionnaire: payload.hasQuestionnaire)) != nil
    }
    var body: some View {
        Form {
            if let locked { Section { Text(L10n.wwUncertain); Text(summary(locked)) } }
            else {
                Section(L10n.wwPatient) {
                    Picker(L10n.wwPatient, selection: $patientID) {
                        Text(L10n.wwChoosePatient).tag("")
                        ForEach(store.patients) { Text($0.displayName).tag($0.id.queryValue) }
                    }.pickerStyle(.menu).accessibilityIdentifier("workspace.associate.patient")
                    if loadingPatients { ProgressView() }
                    Button(L10n.wwRefresh) { Task { await refreshPatients() } }
                }
                if payload?.hasQuestionnaire == true {
                    Section { Toggle(L10n.wwLinkQuestionnaire, isOn: $linkQuestionnaire); Text(L10n.wwQuestionnaireHelp).font(.footnote) }
                }
                if needsSession {
                    Section(L10n.wwSessionTarget) {
                        if payload?.hasNotes == true { Text(L10n.wwNotesRequireSession).font(.footnote) }
                        Picker(L10n.wwSessionTarget, selection: $target) {
                            Text(L10n.wwChooseSession).tag(0)
                            Text(L10n.wwExistingSession).tag(1)
                            Text(L10n.wwNewSession).tag(2)
                        }.pickerStyle(.menu)
                        if target == 1 {
                            Picker(L10n.wwExistingSession, selection: $sessionID) {
                                Text(L10n.wwChooseSession).tag("")
                                ForEach(patient?.sessions.filter { $0.databaseID != nil }.sorted { $0.date > $1.date } ?? []) { session in
                                    Text(L10n.hebrewDate(session.date) + " · " + (session.type.map(L10n.label(for:)) ?? L10n.sessionTypeNone)).tag(session.databaseID!.queryValue)
                                }
                            }.pickerStyle(.menu)
                            if payload?.hasNotes == true { Text(L10n.wwAppendWarning).font(.footnote) }
                        }
                        if target == 2 {
                            DatePicker(L10n.sessionDateTitle, selection: $sessionDate, displayedComponents: .date)
                            Picker(L10n.sessionTypeLabel, selection: $sessionType) {
                                Text(L10n.wwChooseType).tag(SessionType?.none)
                                ForEach(SessionType.allCases, id: \.self) { Text(L10n.label(for: $0)).tag(Optional.some($0)) }
                            }.pickerStyle(.menu)
                        }
                    }
                }
                Section { Text(L10n.wwDiariesPatientLevel).font(.footnote) }
                if conflict { Text(L10n.wwConflict).foregroundStyle(Theme.error) }
            }
            if let error { Section { Text(error).foregroundStyle(Theme.error) } }
            if !closed {
                Button(locked == nil ? L10n.wwReview : L10n.wwRetryAssociation) { confirmation = locked ?? proposed }
                    .disabled(!valid || busy).accessibilityIdentifier("workspace.associate.review")
            }
            if busy { ProgressView() }
        }
        .disabled(busy)
        .navigationTitle(L10n.wwAssociate).themedScreen()
        .task { await refreshPatients() }
        .onChange(of: patientID) { _, _ in sessionID = ""; Task { await loadQuestionnaires() } }
        .sheet(isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } })) {
            NavigationStack {
                List {
                    if let request = confirmation { Text(summary(request)) }
                    Button(L10n.wwConfirm) {
                        guard let request = confirmation else { return }
                        confirmation = nil
                        Task { await submit(request) }
                    }.buttonStyle(.borderedProminent)
                    Button(L10n.cancel) { confirmation = nil }
                }.navigationTitle(L10n.wwReview).themedScreen()
            }.appTextSize()
        }
    }
    private func summary(_ r: WebAssociationRequest) -> String {
        let name = store.patients.first { $0.id.matches(r.p_patient_id) }?.displayName ?? L10n.unnamedPatient
        let session = store.patients.flatMap(\.sessions).first { $0.databaseID?.matches(r.p_existing_session_id ?? "") == true }
        let destination = r.p_create_session ? L10n.wwNewSession + ": " + (r.p_session_date ?? "") + " · " + (r.p_session_type.flatMap(SessionType.init(rawValue:)).map(L10n.label(for:)) ?? "") : session.map { L10n.wwExistingSession + ": " + L10n.hebrewDate($0.date) } ?? L10n.wwNoSession
        var lines = [L10n.wwPatient + ": " + name, L10n.wwDiariesPatientLevel, destination]
        if payload?.hasQuestionnaire == true || r.p_link_questionnaire { lines.append(r.p_link_questionnaire ? L10n.wwQuestionnaireToSession : L10n.wwQuestionnairePatientLevel) }
        if payload?.hasNotes == true { lines.append(L10n.wwNotesToSession) }
        if (payload?.hasNotes == true || payload == nil), r.p_existing_session_id != nil { lines.append(L10n.wwAppendWarning) }
        return lines.joined(separator: "\n\n")
    }
    private func refreshPatients() async {
        loadingPatients = true; defer { loadingPatients = false }
        do { try await store.loadPatients(); await loadQuestionnaires() }
        catch { self.error = L10n.wwLoadFailed }
    }
    private func loadQuestionnaires() async {
        guard let patient else { return }
        do { _ = try await store.loadQuestionnaires(for: patient) }
        catch { self.error = L10n.wwLoadFailed }
    }
    private func submit(_ request: WebAssociationRequest) async {
        do { try await workspaces.associate(request); onSuccess(); dismiss() }
        catch {
            let failure = error as? WebWorkspaceFailure ?? .uncertain
            self.error = failure.message
            if failure == .unavailable { closed = true }
            if failure == .patientMissing || failure == .sessionMissing || failure == .conflict { await refreshPatients() }
        }
    }
}

struct WebWorksheetPreview: View {
    let item: WebWorksheet
    var body: some View {
        List {
            Section { Text(WebWorkspaceDate.display(item.completed_at)); if let date = item.measurement_date { Text(L10n.wwMeasurementDate + date) } }
            switch item.content {
            case .questionnaire(let q):
                if q.flagsQuestionNine { Section { Label(L10n.wwQuestionNineFlag, systemImage: "exclamationmark.triangle").foregroundStyle(Theme.error) } }
                QuestionnaireSections(questionnaire: .constant(q.questionnaire), isEditable: false)
                if let notes = q.notes, !notes.isEmpty { Section(L10n.wwNotes) { Text(notes) } }
            case .diaryOne(let d), .diaryTwo(let d):
                section(L10n.diaryOneEventTitle, [d.event])
                section(L10n.diaryOneThoughtTitle, d.automatic_thoughts)
                section(L10n.diaryTwoFeelingsTitle, d.feelings.map { "\($0.name) — \($0.intensity)%" })
                if let behaviour = d.behaviour { section(L10n.diaryOneBehaviourTitle, [behaviour]) }
                if let physical = d.physical_symptoms, !physical.isEmpty { section(L10n.diaryOnePhysicalSymptomsTitle, [physical]) }
                if let errors = d.thinking_errors { section(L10n.diaryThinkingErrorsTitle, errors.map(\.title)) }
                if let alternatives = d.alternative_thoughts { section(L10n.diaryAlternativeThoughtsTitle, alternatives) }
            case .diaryThree(let d):
                // Read-only content uses the same renderer, without creating a clinical record or saving it.
                DiaryThreeEntryContent(entry: DiaryThreeEntry(id: UUID(uuidString: item.id)!, patientId: .text("preview"), therapistId: UUID(uuidString: item.id)!, createdBy: .therapist, situation: d.situation, automaticThoughts: d.automatic_thoughts, feelings: d.feelings, thinkingErrors: d.thinking_errors, alternativeThoughts: d.alternative_thoughts, createdAt: .distantPast, updatedAt: .distantPast))
            }
        }.navigationTitle(item.title).navigationBarTitleDisplayMode(.inline).themedScreen().textSelection(.enabled)
    }
    private func section(_ title: String, _ values: [String]) -> some View {
        Section(title) { ForEach(Array(values.enumerated()), id: \.offset) { Text($0.element) } }
    }
}
