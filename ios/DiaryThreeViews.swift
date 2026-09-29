import SwiftUI
import OSLog

/// A patient's Diary 3 entries, newest first. Therapist-only for this step.
struct PatientDiaryThreeView: View {
    let patient: Patient

    @Environment(DiaryThreeStore.self) private var diary
    @Environment(AuthManager.self) private var auth
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PatientStore.self) private var store

    private enum LoadState {
        case loading
        case loaded
        case failed
    }

    private enum PatientModeStatus {
        case loading
        case connected
        case notConnected
        case inactive
        case active
        case failed
    }

    @State private var loadState: LoadState = .loading
    @State private var refreshedPatientModeStatus: PatientModeStatus = .loading
    @State private var modeRefreshRevision = 0

    private var cachedPatientModeStatus: PatientModeStatus? {
        if store.isDemoMode || DemoData.isDemoID(patient.id) { return .notConnected }
        guard let id = patient.id.uuidValue, let connected = assignmentService().cachedPatientConnection(patientId: id) else { return nil }
        guard connected else { return .notConnected }
        guard let snapshot = assignmentService().cachedOngoingAssignment(patientId: id, type: .diaryThree) else { return .connected }
        return snapshot.assignmentId == nil ? .inactive : .active
    }

    private var patientModeStatus: PatientModeStatus {
        get { refreshedPatientModeStatus == .loading ? cachedPatientModeStatus ?? .loading : refreshedPatientModeStatus }
        nonmutating set { refreshedPatientModeStatus = newValue }
    }
    @State private var activeAssignmentId: UUID?
    @State private var isUpdatingAssignment = false
    @State private var assignmentError: String?
    @State private var isShowingStopConfirmation = false

    private var entries: [DiaryThreeEntry] {
        diary.entries(for: patient.id)
    }

    private var patientColor: Color {
        PatientAvatarColor.background(for: patient.id)
    }

    private var addDiaryEntryCTA: some View {
        NavigationLink {
            DiaryThreeEntryFormView(patient: patient, mode: .create)
                .id("diary-three-create-\(patient.id.queryValue)")
        } label: {
            Text(entries.isEmpty ? L10n.emptyDiaryOnePrimaryAction : L10n.diaryOneAddEntryAction)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.pressableProminent)
        .controlSize(.large)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Theme.base)
    }

    var body: some View {
        entryList
        .patientAtmosphere(patientColor)
        .themedScreen()
        .navigationTitleWithSubtitle(L10n.diaryThreeTitle, subtitle: patient.displayName)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            addDiaryEntryCTA
        }
        .demoModeChrome()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    DiaryThreeEntryFormView(patient: patient, mode: .create)
                        .id("diary-three-create-\(patient.id.queryValue)")
                } label: {
                    Label(L10n.diaryOneAddEntryAction, systemImage: "plus")
                }
            }
        }
        .task(id: patient.id) {
            async let mode: Void = loadPatientModeState()
            await loadEntries()
            await mode
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await loadPatientModeState() } }
        }
        .alert(L10n.diaryPatientModeStopConfirmTitle, isPresented: $isShowingStopConfirmation) {
            Button(L10n.diaryPatientModeStopConfirmAction, role: .destructive) {
                Task { await stopDiaryThree() }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.diaryPatientModeStopConfirmMessage)
        }
    }

    private var entryList: some View {
        List {
            Section {
                patientModeControl
                    .listRowBackground(groupBorderedRow(.only))
            }

            if loadState == .loading && entries.isEmpty {
                ProgressView()
                    .tint(Theme.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .listRowBackground(groupBorderedRow(.only))
            } else if case .failed = loadState {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.diaryThreeLoadFailed)
                        .font(.footnote)
                        .foregroundStyle(Theme.error)
                    Button(L10n.retryAction) {
                        Task { await loadEntries() }
                    }
                }
                .listRowBackground(groupBorderedRow(.only))
            }

            if !entries.isEmpty {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    NavigationLink {
                        DiaryThreeEntryDetailView(patient: patient, entryID: entry.id)
                            .id(entry.id)
                    } label: {
                        diarySummary(entry)
                    }
                    .listRowBackground(groupBorderedRow(
                        .at(index, of: entries.count)
                    ))
                }
            } else if loadState == .loaded {
                VStack(spacing: 12) {
                    Text(L10n.diaryThreeEmptyTitle)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text(L10n.diaryOneEmptyBody)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .listRowBackground(groupBorderedRow(.only))
            }
        }
        .refreshable {
            async let mode: Void = loadPatientModeState()
            await loadEntries()
            await mode
        }
    }

    @ViewBuilder
    private var patientModeControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.diaryPatientModeTitle)
                .font(.subheadline.weight(.semibold))
            switch patientModeStatus {
            case .loading:
                ProgressView()
                    .tint(Theme.gold)
                    .controlSize(.small)
            case .connected:
                Text(L10n.patientConnectedStatus).font(.footnote).foregroundStyle(.secondary)
            case .notConnected:
                Text(L10n.diaryPatientModeNotConnected)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .inactive:
                Text(L10n.diaryPatientModeInactiveBody)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Task { await activateDiaryThree() }
                } label: {
                    Text(L10n.diaryPatientModeActivateAction)
                        .fontWeight(.semibold)
                }
                .disabled(isUpdatingAssignment)
            case .active:
                HStack(spacing: 8) {
                    Circle()
                        .fill(Theme.success)
                        .frame(width: 8, height: 8)
                    Text(L10n.diaryPatientModeActive)
                        .font(.footnote.weight(.semibold))
                }
                Button(role: .destructive) {
                    isShowingStopConfirmation = true
                } label: {
                    Text(L10n.diaryPatientModeStopAction)
                        .font(.footnote)
                }
                .disabled(isUpdatingAssignment)
            case .failed:
                Text(assignmentError ?? L10n.patientConnectionCheckError)
                    .font(.footnote)
                    .foregroundStyle(Theme.error)
                    .fixedSize(horizontal: false, vertical: true)
                Button(L10n.retryAction) {
                    Task { await loadPatientModeState() }
                }
                .disabled(isUpdatingAssignment)
            }
            if let assignmentError, patientModeStatus == .inactive || patientModeStatus == .active {
                Text(assignmentError)
                    .font(.footnote)
                    .foregroundStyle(Theme.error)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }

    private func diarySummary(_ entry: DiaryThreeEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.createdAt.formatted(date: .numeric, time: .shortened))
                .font(.headline)
            labeledLine(L10n.diaryThreeSituationTitle, entry.situation)
            labeledLine(L10n.diaryOneThoughtTitle, entry.automaticThoughtsPreview)
            Text(entry.createdBy == .patient ? L10n.diaryEntryPatientSource : L10n.diaryEntryTherapistSource)
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func labeledLine(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .lineLimit(2)
        }
    }

    private func groupBorderedRow(_ position: GroupRowPosition) -> some View {
        CBTipul.groupBorderedRow(position, accent: patientColor)
    }

    private func loadEntries() async {
        if entries.isEmpty {
            loadState = .loading
        }
        do {
            _ = try await diary.loadEntries(for: patient.id)
            loadState = .loaded
        } catch {
            loadState = .failed
        }
    }

    private func assignmentService() -> PatientAssignmentService {
        PatientAssignmentService(client: auth.client)
    }

    private func loadPatientModeState(showLoading: Bool = true) async {
        if showLoading && isUpdatingAssignment { return }
        if showLoading { assignmentError = nil }
        modeRefreshRevision += 1
        let revision = modeRefreshRevision
        if let cached = cachedPatientModeStatus { patientModeStatus = cached }
        if store.isDemoMode || DemoData.isDemoID(patient.id) {
            patientModeStatus = .notConnected
            return
        }
        guard let patientId = patient.id.uuidValue else {
            patientModeStatus = .failed
            assignmentError = L10n.patientConnectionCheckError
            return
        }
        activeAssignmentId = assignmentService().cachedOngoingAssignment(patientId: patientId, type: .diaryThree)?.assignmentId
        do {
            let connected = try await assignmentService().isPatientConnected(patientId: patientId)
            guard revision == modeRefreshRevision else { return }
            guard connected else {
                activeAssignmentId = nil
                patientModeStatus = .notConnected
                return
            }
            patientModeStatus = cachedPatientModeStatus ?? .connected
            _ = try await assignmentService().activeOngoingAssignment(patientId: patientId, type: .diaryThree)
            guard revision == modeRefreshRevision else { return }
            activeAssignmentId = assignmentService().cachedOngoingAssignment(patientId: patientId, type: .diaryThree)?.assignmentId
            patientModeStatus = cachedPatientModeStatus ?? .connected
        } catch is CancellationError {
            return
        } catch {
            guard revision == modeRefreshRevision else { return }
            // A failed background refresh does not erase a known usable status.
            if let cached = cachedPatientModeStatus, cached != .connected {
                patientModeStatus = cached
            } else {
                patientModeStatus = .failed
                assignmentError = L10n.patientConnectionCheckError
            }
        }
    }

    private func activateDiaryThree() async {
        guard !isUpdatingAssignment, patientModeStatus == .inactive else { return }
        guard let patientId = patient.id.uuidValue else {
            assignmentError = L10n.diaryPatientModeActivateFailed
            return
        }
        isUpdatingAssignment = true
        modeRefreshRevision += 1
        assignmentError = nil
        defer { isUpdatingAssignment = false }
        do {
            let active = try await assignmentService().activateOngoingAssignment(
                patientId: patientId,
                type: .diaryThree
            )
            activeAssignmentId = active.id
            await loadPatientModeState(showLoading: false)
        } catch PatientAssignmentError.patientNotConnected {
            patientModeStatus = .notConnected
        } catch {
            assignmentError = L10n.diaryPatientModeActivateFailed
            await loadPatientModeState(showLoading: false)
        }
    }

    private func stopDiaryThree() async {
        guard !isUpdatingAssignment, let assignmentId = activeAssignmentId else { return }
        isUpdatingAssignment = true
        modeRefreshRevision += 1
        assignmentError = nil
        defer { isUpdatingAssignment = false }
        do {
            try await assignmentService().cancelOngoingAssignment(id: assignmentId)
            await loadPatientModeState(showLoading: false)
        } catch {
            assignmentError = L10n.diaryPatientModeStopFailed
            await loadPatientModeState(showLoading: false)
        }
    }
}

/// Therapist editor; the original source and creation metadata remain unchanged.
struct DiaryThreeEntryFormView: View {
    let patient: Patient
    let mode: DiaryThreeEditorMode

    @Environment(DiaryThreeStore.self) private var diary
    @Environment(\.dismiss) private var dismiss

    @State private var draft: DiaryThreeEntryDraft
    @State private var initialSnapshot: DiaryThreeEntryDraft.Snapshot
    @State private var didAttemptSave = false
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var isShowingValidationAlert = false
    @State private var isShowingBackWarning = false
    @State private var isShowingDeleteConfirmation = false
    @State private var errorMessage: String?
    @State private var validationMessage: String?

    private var patientColor: Color {
        PatientAvatarColor.background(for: patient.id)
    }

    private var isBusy: Bool { isSaving || isDeleting }
    private var existing: DiaryThreeEntry? { mode.existing }

    private var hasUnsavedChanges: Bool {
        draft.comparableSnapshot != initialSnapshot
    }

    init(patient: Patient, mode: DiaryThreeEditorMode) {
        self.patient = patient
        self.mode = mode
        let hydrated: DiaryThreeEntryDraft
        switch mode {
        case .create:
            hydrated = .empty
        case .edit(let entry):
            hydrated = .from(entry)
        }
        _draft = State(initialValue: hydrated)
        _initialSnapshot = State(initialValue: hydrated.comparableSnapshot)
    }

    var body: some View {
        ScrollView {
            DiaryThreeDraftFields(
                draft: $draft,
                didAttemptSave: didAttemptSave,
                errorMessage: errorMessage
            )
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .patientAtmosphere(patientColor)
        .themedScreen()
        .demoModeChrome()
        .dismissesKeyboardOnTap()
        .navigationTitle(L10n.diaryThreeTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .busyOverlay(isBusy)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await save() }
            } label: {
                Text(L10n.diaryOneSaveEntryAction)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.pressableProminent)
            .disabled(isBusy)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Theme.base.opacity(0.95))
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    if hasUnsavedChanges {
                        isShowingBackWarning = true
                    } else {
                        dismiss()
                    }
                } label: {
                    Label(L10n.back, systemImage: "chevron.backward")
                        .labelStyle(.titleAndIcon)
                }
                .disabled(isBusy)
            }
            if existing != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        isShowingDeleteConfirmation = true
                    } label: {
                        Label(L10n.diaryOneDeleteAction, systemImage: "trash")
                    }
                    .disabled(isBusy)
                }
            }
        }
        .alert(L10n.diaryOneValidationTitle, isPresented: $isShowingValidationAlert) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(validationMessage ?? L10n.diaryOneValidationMessage)
        }
        .alert(L10n.discardChangesTitle, isPresented: $isShowingBackWarning) {
            Button(L10n.discardChangesAction, role: .destructive) { dismiss() }
            Button(L10n.keepEditingAction, role: .cancel) {}
        }
        .alert(L10n.diaryOneDeleteConfirmTitle, isPresented: $isShowingDeleteConfirmation) {
            Button(L10n.diaryOneDeleteAction, role: .destructive) {
                Task { await deleteEntry() }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.diaryOneDeleteConfirmMessage)
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
    }

    private func save() async {
        guard !isBusy else { return }
        didAttemptSave = true
        if let message = draft.validationMessage() {
            validationMessage = message
            isShowingValidationAlert = true
            return
        }
        guard let feelings = draft.persistedFeelings() else {
            validationMessage = L10n.diaryOneValidationMessage
            isShowingValidationAlert = true
            return
        }
        isSaving = true
        errorMessage = nil
        let situation = draft.situation.trimmingCharacters(in: .whitespacesAndNewlines)
        let thoughts = draft.persistedAutomaticThoughts
        do {
            switch mode {
            case .edit(let existing):
                _ = try await diary.updateEntry(
                    id: existing.id,
                    patientId: patient.id,
                    situation: situation,
                    automaticThoughts: thoughts,
                    feelings: feelings,
                    thinkingErrors: draft.thinkingErrors,
                    alternativeThoughts: draft.persistedAlternativeThoughts
                )
            case .create:
                _ = try await diary.createEntry(
                    patientId: patient.id,
                    situation: situation,
                    automaticThoughts: thoughts,
                    feelings: feelings,
                    thinkingErrors: draft.thinkingErrors,
                    alternativeThoughts: draft.persistedAlternativeThoughts
                )
            }
            initialSnapshot = draft.comparableSnapshot
            dismiss()
        } catch {
            errorMessage = L10n.diaryOneSaveFailed
            isSaving = false
        }
    }

    private func deleteEntry() async {
        guard !isBusy, let existing else { return }
        isDeleting = true
        errorMessage = nil
        do {
            try await diary.deleteEntry(id: existing.id, patientId: patient.id)
            initialSnapshot = draft.comparableSnapshot
            dismiss()
        } catch {
            errorMessage = L10n.diaryOneDeleteFailed
            isDeleting = false
        }
    }
}
