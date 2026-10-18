import SwiftUI

struct WebWorkspaceRoute: Hashable { let id: String }
struct WebWorkspaceInboxRoute: Hashable {}

struct WebWorkspaceInboxView: View {
    @Environment(WebWorkspaceStore.self) private var workspaces
    var body: some View {
        List {
            Group {
            if workspaces.associationSaved { Section { Label(L10n.wwDone, systemImage: "checkmark.circle") } }
            if workspaces.refreshFailed { Section { Text(L10n.wwRefreshFailed); Button(L10n.retry) { Task { await workspaces.refreshAfterSuccess() } } } }
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
            }.listRowBackground(Theme.surface).listRowSeparatorTint(Theme.borderFaint)
        }
        .navigationTitle(L10n.wwInbox).webWorkspaceStyle()
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
    var initialPatientID: String? = nil
    @Environment(WebWorkspaceStore.self) private var workspaces
    @State private var workspace: WebWorkspace?
    @State private var loading = false
    @State private var error: String?
    @State private var confirmDiscard = false
    @State private var unavailable = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Group {
            if unavailable && workspaces.requests[id] == nil {
                ContentUnavailableView {
                    Label(L10n.wwUnavailable, systemImage: "tray")
                } actions: { Button(L10n.back) { dismiss() } }
                .navigationTitle(L10n.wwPreview).navigationBarTitleDisplayMode(.inline).webWorkspaceStyle()
            } else {
                WebWorkspaceAssociationView(id: id, payload: workspace?.payload, initialPatientID: initialPatientID, context: workspace,
                    contentError: error, reloadContent: { await load() }, onSuccess: { dismiss() })
                    .id(id)
            }
        }
        .task { await load() }
        .toolbar {
            if workspace != nil && workspaces.requests[id] == nil {
                Menu {
                    Button(L10n.wwDiscard, role: .destructive) { confirmDiscard = true }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel(L10n.wwDiscard)
                .disabled(workspaces.busyIDs.contains(id))
            }
        }
        .confirmationDialog(L10n.wwDiscard, isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button(L10n.wwDiscard, role: .destructive) { Task {
                do { try await workspaces.discard(id); dismiss() }
                catch { self.error = WebWorkspaceFailure.classify(error).message }
            } }
        } message: { Text(L10n.wwDiscardConfirm) }
    }
    private func load() async {
        guard !loading else { return }
        loading = true; defer { loading = false }
        do { workspace = try await workspaces.load(id); error = nil; unavailable = false }
        catch {
            if Task.isCancelled { return }
            unavailable = WebWorkspaceFailure.classify(error) == .unavailable
            self.error = unavailable ? L10n.wwUnavailable : L10n.wwContentLoadingFailed
            if unavailable && workspaces.requests[id] == nil {
                workspaces.markUnavailable(id)
                await workspaces.refresh()
            }
        }
    }
}

struct WebWorkspaceAssociationView: View {
    let id: String
    let payload: WebWorkspacePayload?
    var initialPatientID: String? = nil
    var initialSessionID: String? = nil
    var initialLinkQuestionnaire = false
    var context: WebWorkspace? = nil
    var contentError: String? = nil
    var reloadContent: (() async -> Void)? = nil
    // Dependency injection for native rendering/tests; production uses PatientStore.
    var refreshPatientsAction: (() async throws -> Void)? = nil
    let onSuccess: () -> Void
    @Environment(WebWorkspaceStore.self) private var workspaces
    @Environment(PatientStore.self) private var store
    @State private var initialized = false
    @State private var patientID = ""
    @State private var sessionID = ""
    @State private var createSession = false
    @State private var sessionDate = Date()
    @State private var sessionType: SessionType?
    @State private var linkQuestionnaire = false
    @State private var error: String?
    @State private var loadingPatients = false
    @State private var closed = false
    @State private var submitting = false
    @State private var preview: WebAssociationPreview?
    @State private var previewFor: WebAssociationTarget?
    @State private var previewGeneration = 0
    @State private var previewLoading = false
    @State private var choice: WebQuestionnaireChoice?
    @State private var choiceWasExplicit = false
    @State private var inspected: WebAssociationCandidate?
    @State private var showContent = false
    @State private var entitlement = EntitlementState.shared
    private var locked: WebAssociationRequest? { workspaces.requests[id] }
    private var busy: Bool { submitting || workspaces.busyIDs.contains(id) }
    private var patient: Patient? { store.patients.first { $0.id.matches(patientID) } }
    private var hasNotes: Bool { preview?.has_notes ?? payload?.hasNotes ?? false }
    private var needsSession: Bool { hasNotes || linkQuestionnaire }
    private var base: WebAssociationRequest {
        WebAssociationRequest(p_workspace_id: id, p_patient_id: patientID,
            p_existing_session_id: needsSession && !createSession && !sessionID.isEmpty ? sessionID : nil,
            p_create_session: needsSession && createSession, p_link_questionnaire: linkQuestionnaire,
            p_session_date: needsSession && createSession ? WebWorkspaceDate.dateOnly(sessionDate) : nil,
            p_session_type: needsSession && createSession ? sessionType?.rawValue : nil)
    }
    private var targetReady: Bool {
        guard payload != nil || preview != nil, patient != nil, base.target.isValid else { return false }
        if needsSession && !createSession { return patient?.sessions.contains { $0.databaseID?.matches(sessionID) == true } == true }
        return true
    }
    private var readyPreview: WebAssociationPreview? { previewFor == base.target && !previewLoading ? preview : nil }
    private var valid: Bool {
        guard !closed, !workspaces.closedIDs.contains(id), entitlement.access == .full else { return false }
        if locked != nil { return true }
        guard targetReady, let preview = readyPreview, !linkQuestionnaire || choice != nil else { return false }
        return (try? base.validate(hasNotes: hasNotes, hasQuestionnaire: payload?.hasQuestionnaire == true)) != nil && (try? preview.prepare(base, choice: choice)) != nil
    }
    var body: some View {
        Form {
            Group {
            if let payload {
                Section {
                    WebWorkspaceContext(context: context, payload: payload)
                    Button(L10n.wwPreview) { showContent = true }.accessibilityIdentifier("workspace.associate.content")
                }
            }
            if let locked {
                Section { Text(L10n.wwUncertain); Text(destination(locked)).font(.subheadline); if locked.p_acknowledge_existing_notes { Text(L10n.wwAppendExistingNotes) } }
            } else {
                Section(L10n.wwPatient) {
                    HStack {
                        Picker(L10n.wwPatient, selection: $patientID) {
                            Text(L10n.wwChoosePatient).tag("")
                            ForEach(store.patients) { Text($0.displayName).tag($0.id.queryValue) }
                        }.pickerStyle(.menu).accessibilityIdentifier("workspace.associate.patient")
                        if loadingPatients || previewLoading && !needsSession { ProgressView().accessibilityLabel(L10n.wwPreviewLoading) }
                    }
                }
                if payload?.hasQuestionnaire == true || hasNotes && (preview?.eligibleQuestionnaires.isEmpty == false || linkQuestionnaire) {
                    Section {
                        Toggle(L10n.wwLinkOptional, isOn: $linkQuestionnaire)
                        if !linkQuestionnaire { Text(L10n.wwQuestionnairePatientLevel).font(.footnote).foregroundStyle(Theme.textBody) }
                    }
                }
                if needsSession { sessionSection }
                if let p = readyPreview {
                    if p.notes_will_append {
                        Section {
                            Text(L10n.wwAppendExistingNotes)
                            DisclosureGroup(L10n.wwAnalysisHelp) { Text(L10n.wwRegenerateAnalysis).font(.footnote).foregroundStyle(Theme.textBody) }
                        }
                    }
                    if linkQuestionnaire { questionnaireSection(p) }
                }
            }
            if let contentError, locked == nil { Section { Text(contentError).foregroundStyle(Theme.error); Button(L10n.retry) { Task { await reloadContent?() } } } }
            else if payload == nil && locked == nil { Section { ProgressView().accessibilityLabel(L10n.wwPreviewLoading) } }
            if let error { Section { Text(error).foregroundStyle(Theme.error); if locked == nil { Button(L10n.retry) { Task { await refreshPatients(); _ = await loadPreview() } } } } }
            }.listRowBackground(Theme.surface).listRowSeparatorTint(Theme.borderFaint)
            if !closed {
                Section {
                    Button {
                        guard !busy, valid else { return }
                        let request: WebAssociationRequest
                        if let locked { request = locked }
                        else { guard let p = readyPreview, let prepared = try? p.prepare(base, choice: choice), let confirmed = try? p.confirmed(prepared) else { return }; request = confirmed }
                        // The one final action acknowledges the inline append message already visible above.
                        submitting = true; error = nil
                        Task { await submit(request, appendWasVisible: readyPreview?.notes_will_append == true || locked?.p_acknowledge_existing_notes == true) }
                    } label: { HStack { if busy { ProgressView().tint(Theme.textOnAccent) }; Text(busy ? L10n.wwSavingToFile : L10n.wwAssociate).frame(maxWidth: .infinity) } }
                    .buttonStyle(.pressableProminent).disabled(!valid || busy).accessibilityIdentifier("workspace.associate.save")
                }.listRowBackground(Color.clear)
            }
        }
        .disabled(busy)
        .navigationTitle(L10n.wwAssociate).navigationBarTitleDisplayMode(.inline).navigationBarBackButtonHidden(busy).webWorkspaceStyle()
        .task {
            guard !initialized else { return }
            initialized = true
            workspaces.associationSaved = false
            if let locked { restore(locked) }
            else { patientID = initialPatientID ?? ""; sessionID = initialSessionID ?? ""; linkQuestionnaire = initialLinkQuestionnaire }
            await refreshPatients()
            _ = await loadPreview()
        }
        .task(id: base.target) { error = nil; _ = await loadPreview() }
        .onChange(of: payload?.hasNotes) { _, _ in Task { _ = await loadPreview() } }
        .onChange(of: patientID) { _, _ in
            if locked == nil {
                choiceWasExplicit = false
                if let patient, !createSession, !sessionID.isEmpty, !patient.sessions.contains(where: { $0.databaseID?.matches(sessionID) == true }) { sessionID = "" }
            }
        }
        .onChange(of: linkQuestionnaire) { _, _ in if locked == nil { choiceWasExplicit = false; if let p = readyPreview { choice = p.resolvedChoice(nil) } } }
        .onChange(of: locked) { _, request in if let request { restore(request) } }
        .sheet(item: $inspected) { candidate in NavigationStack { WebAssociationCandidateAnswers(candidate: candidate) }.appTextSize() }
        .sheet(isPresented: $showContent) { if let payload { NavigationStack { WebWorkspaceContentView(payload: payload) }.appTextSize() } }
    }
    private var sessionSelection: Binding<String> { Binding(get: { createSession ? "new" : sessionID }, set: { value in createSession = value == "new"; if !createSession { sessionID = value } }) }
    private var sessionSection: some View {
        Section(L10n.wwSessionTarget) {
            HStack {
                Picker(L10n.wwChooseSession, selection: sessionSelection) {
                    Text(L10n.wwChooseSession).tag("")
                    ForEach(patient?.sessions.filter { $0.databaseID != nil }.sorted { $0.date > $1.date } ?? []) { session in
                        Text(L10n.hebrewDate(session.date) + " · " + (session.type.map(L10n.label(for:)) ?? L10n.sessionTypeNone)).tag(session.databaseID!.queryValue)
                    }
                    Text(L10n.wwNewSession).tag("new")
                }.pickerStyle(.menu)
                if previewLoading { ProgressView().accessibilityLabel(L10n.wwPreviewLoading) }
            }
            if createSession {
                DatePicker(L10n.sessionDateTitle, selection: $sessionDate, displayedComponents: .date)
                Picker(L10n.sessionTypeLabel, selection: $sessionType) {
                    Text(L10n.wwChooseType).tag(SessionType?.none)
                    ForEach(SessionType.allCases, id: \.self) { Text(L10n.label(for: $0)).tag(Optional.some($0)) }
                }.pickerStyle(.menu)
            }
        }
    }
    @ViewBuilder private func questionnaireSection(_ p: WebAssociationPreview) -> some View {
        if p.eligibleQuestionnaires.count > 1 {
            Section(L10n.wwChooseResult) {
                Text(L10n.wwPreserveResults).font(.footnote).foregroundStyle(Theme.textBody)
                ForEach(p.questionnaires) { candidate in
                    WebAssociationCandidateRow(candidate: candidate, selected: choice == candidate.choice, choose: {
                        choice = candidate.choice; choiceWasExplicit = true; error = nil
                    }, inspect: { inspected = candidate })
                }
            }
        } else if let candidate = p.eligibleQuestionnaires.first {
            Section { WebAssociationCandidateRow(candidate: candidate, selected: true, choose: nil, inspect: { inspected = candidate }); Text(L10n.wwPreserveResults).font(.footnote).foregroundStyle(Theme.textBody) }
        } else { Section { Text(L10n.wwNoLinkedQuestionnaire).foregroundStyle(Theme.error) } }
    }
    private func restore(_ request: WebAssociationRequest) {
        patientID = request.p_patient_id
        sessionID = request.p_existing_session_id ?? ""
        createSession = request.p_create_session
        linkQuestionnaire = request.p_link_questionnaire
        sessionType = request.p_session_type.flatMap(SessionType.init(rawValue:))
        choice = request.p_questionnaire_choice; choiceWasExplicit = choice != nil
        if let raw = request.p_session_date {
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.calendar = Calendar(identifier: .gregorian); formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: raw) { sessionDate = date }
        }
    }
    private func destination(_ request: WebAssociationRequest) -> String {
        let name = store.patients.first { $0.id.matches(request.p_patient_id) }?.displayName ?? L10n.unnamedPatient
        if request.p_create_session { return name + " · " + L10n.wwNewSession + " · " + (request.p_session_date ?? "") }
        let session = store.patients.flatMap(\.sessions).first { $0.databaseID?.matches(request.p_existing_session_id ?? "") == true }
        return name + (session.map { " · " + L10n.hebrewDate($0.date) } ?? "")
    }
    private func refreshPatients() async {
        loadingPatients = true; defer { loadingPatients = false }
        do {
            if let refreshPatientsAction { try await refreshPatientsAction() } else { try await store.loadPatients() }
            if !sessionID.isEmpty && !createSession && patient?.sessions.contains(where: { $0.databaseID?.matches(sessionID) == true }) != true { sessionID = "" }
        } catch { self.error = L10n.wwLoadFailed }
    }
    @discardableResult private func loadPreview(rejectedRequest: WebAssociationRequest? = nil) async -> WebAssociationPreview? {
        previewGeneration += 1; let generation = previewGeneration
        guard locked == nil, rejectedRequest?.target.isValid == true || targetReady else { previewLoading = false; return nil }
        let intended = rejectedRequest?.target ?? base.target
        let explicit = choiceWasExplicit ? choice : nil
        previewFor = intended; previewLoading = true; preview = nil
        defer { if generation == previewGeneration { previewLoading = false } }
        do {
            let result = try await workspaces.preview(intended)
            guard !Task.isCancelled, generation == previewGeneration, rejectedRequest != nil || base.target == intended else { return nil }
            preview = result; choice = result.resolvedChoice(explicit)
            choiceWasExplicit = result.eligibleQuestionnaires.count > 1 && choice != nil && explicit != nil
            return result
        } catch {
            guard !Task.isCancelled, generation == previewGeneration else { return nil }
            self.error = WebWorkspaceFailure.classify(error) == .uncertain ? L10n.wwLoadFailed : WebWorkspaceFailure.classify(error).message
            return nil
        }
    }
    private func submit(_ request: WebAssociationRequest, appendWasVisible: Bool) async {
        defer { submitting = false }
        do {
            do { try await workspaces.associate(request) }
            catch {
                let failure = WebWorkspaceFailure.classify(error)
                guard failure == .previewChanged else { throw failure }
                guard let fresh = await loadPreview(rejectedRequest: request) else { return }
                guard fresh.canContinueSaving(request, choice: choice, appendWasVisible: appendWasVisible) else {
                    self.error = fresh.notes_will_append && !appendWasVisible ? L10n.wwSummaryChanged : request.p_link_questionnaire && choice != request.p_questionnaire_choice ? L10n.wwChoiceChanged : L10n.wwPreviewChanged
                    return
                }
                let next = try fresh.confirmed(fresh.prepare(request, choice: choice))
                try await workspaces.associate(next)
            }
            closed = true
            onSuccess()
        } catch {
            let failure = WebWorkspaceFailure.classify(error)
            self.error = failure.message
            if failure == .unavailable { closed = true }
            if failure == .invalidSelection || failure == .questionnaireChanged || failure == .previewChanged { _ = await loadPreview() }
            if failure == .patientMissing || failure == .sessionMissing { await refreshPatients(); _ = await loadPreview() }
        }
    }
}

struct WebWorkspaceContext: View {
    let context: WebWorkspace?
    let payload: WebWorkspacePayload
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(context?.reference_label.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 } ?? L10n.wwUntitled).font(.headline)
            if let context {
                Text(L10n.wwStarted + WebWorkspaceDate.display(context.started_at)).font(.caption)
                if let finished = context.finished_at { Text(L10n.wwFinished + WebWorkspaceDate.display(finished)).font(.caption) }
            }
            Text(L10n.wwActivityCount(payload.items.count, notes: payload.hasNotes)).font(.subheadline).foregroundStyle(Theme.textBody)
            if payload.hasNotes {
                Text(L10n.wwNotes).font(.subheadline.weight(.semibold))
                Text(payload.notes).lineLimit(3).textSelection(.enabled)
            }
            ForEach(payload.items.prefix(3)) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.subheadline.weight(.semibold))
                    switch item.content {
                    case .diaryOne(let d), .diaryTwo(let d): Text(d.event).lineLimit(2)
                    case .diaryThree(let d): Text(d.situation).lineLimit(2)
                    case .questionnaire(let q):
                        if let date = item.measurement_date { Text(L10n.wwMeasurementDate + date).font(.caption) }
                        HStack { ScoreCapsule.gad7(q.questionnaire); ScoreCapsule.phq9(q.questionnaire) }
                        if q.flagsQuestionNine { Text(L10n.wwQuestionNineFlag).font(.footnote).foregroundStyle(Theme.error) }
                    }
                }
            }
        }.accessibilityIdentifier("workspace.context")
    }
}

struct WebWorkspaceContentView: View {
    let payload: WebWorkspacePayload
    var body: some View {
        List {
            ForEach(payload.items) { item in NavigationLink(item.title) { WebWorksheetPreview(item: item) } }.listRowBackground(Theme.surface)
            if payload.hasNotes { Section(L10n.wwNotes) { Text(payload.notes).textSelection(.enabled) }.listRowBackground(Theme.surface) }
        }.navigationTitle(L10n.wwPreview).navigationBarTitleDisplayMode(.inline).webWorkspaceStyle()
    }
}

struct WebWorksheetPreview: View {
    let item: WebWorksheet
    var body: some View {
        Group {
            if case .questionnaire(let q) = item.content {
                List {
                    Group {
                        Section { metadata }
                        if q.flagsQuestionNine { Section { Label(L10n.wwQuestionNineFlag, systemImage: "exclamationmark.triangle").foregroundStyle(Theme.error) } }
                        QuestionnaireSections(questionnaire: .constant(q.questionnaire), isEditable: false)
                        if let notes = q.notes, !notes.isEmpty { Section(L10n.wwNotes) { Text(notes) } }
                    }.listRowBackground(Theme.surface)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        metadata
                        diaryContent
                    }.padding(20)
                }
            }
        }.navigationTitle(item.title).navigationBarTitleDisplayMode(.inline).webWorkspaceStyle().textSelection(.enabled)
    }
    @ViewBuilder private var metadata: some View {
        Text(WebWorkspaceDate.display(item.completed_at)).font(.subheadline).foregroundStyle(Theme.textBody)
        if let date = item.measurement_date { Text(L10n.wwMeasurementDate + date).font(.subheadline) }
    }
    @ViewBuilder private var diaryContent: some View {
        switch item.content {
        case .diaryOne(let d):
            DiaryOneEntryContent(event: d.event, automaticThoughts: d.automatic_thoughts, feelings: d.feelings,
                behaviour: d.behaviour ?? "", physicalSymptoms: d.physical_symptoms)
        case .diaryTwo(let d):
            DiaryTwoEntryContent(event: d.event, automaticThoughts: d.automatic_thoughts, feelings: d.feelings,
                thinkingErrors: d.thinking_errors ?? [], alternativeThoughts: d.alternative_thoughts ?? [])
        case .diaryThree(let d):
            // Preview-only value; never inserted into a patient or diary store.
            DiaryThreeEntryContent(entry: DiaryThreeEntry(id: UUID(uuidString: item.id)!, patientId: .text("preview"), therapistId: UUID(uuidString: item.id)!, createdBy: .therapist, situation: d.situation, automaticThoughts: d.automatic_thoughts, feelings: d.feelings, thinkingErrors: d.thinking_errors, alternativeThoughts: d.alternative_thoughts, createdAt: .distantPast, updatedAt: .distantPast))
        case .questionnaire: EmptyView()
        }
    }
}

/// Resolve both native controls and custom surfaces from the app's appearance setting.
extension View {
    func webWorkspaceStyle() -> some View {
        self.themedScreen().patientAtmosphere(Theme.gold).appTextSize()
            .listSectionSpacing(.compact)
    }
}
