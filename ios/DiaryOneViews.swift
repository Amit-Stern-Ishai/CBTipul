import SwiftUI

/// A patient's Diary 1 entries, newest first. Therapist-only for this step.
struct PatientDiaryOneView: View {
    let patient: Patient

    @Environment(DiaryOneStore.self) private var diary
    @Environment(AuthManager.self) private var auth
    @Environment(PatientStore.self) private var store

    private enum LoadState {
        case loading
        case loaded
        case failed
    }

    private enum PatientModeStatus {
        case loading
        case notConnected
        case inactive
        case active
        case failed
    }

    @State private var loadState: LoadState = .loading
    @State private var patientModeStatus: PatientModeStatus = .loading
    @State private var activeAssignmentId: UUID?
    @State private var isUpdatingAssignment = false
    @State private var assignmentError: String?
    @State private var isShowingStopConfirmation = false

    private var entries: [DiaryOneEntry] {
        diary.entries(for: patient.id)
    }

    private var patientColor: Color {
        PatientAvatarColor.background(for: patient.id)
    }

    var body: some View {
        entryList
        .patientAtmosphere(patientColor)
        .themedScreen()
        .demoModeChrome()
        .navigationTitleWithSubtitle(L10n.diaryOneTitle, subtitle: patient.displayName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    DiaryOneEntryFormView(patient: patient, mode: .create)
                        .id("diary-one-create-\(patient.id.queryValue)")
                } label: {
                    Label(L10n.diaryOneAddEntryAction, systemImage: "plus")
                }
            }
        }
        .onAppear {
            Task { await loadEntries() }
            Task { await loadPatientModeState() }
        }
        .alert(L10n.diaryPatientModeStopConfirmTitle, isPresented: $isShowingStopConfirmation) {
            Button(L10n.diaryPatientModeStopConfirmAction, role: .destructive) {
                Task { await stopDiaryOne() }
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
                    Text(L10n.diaryOneLoadFailed)
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
                        DiaryOneEntryFormView(patient: patient, mode: .edit(entry))
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
                    Text(L10n.diaryOneEmptyTitle)
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
            await loadEntries()
            await loadPatientModeState()
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
                    Task { await activateDiaryOne() }
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

    private func diarySummary(_ entry: DiaryOneEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.hebrewNumericDate(entry.createdAt))
                .font(.headline)
            labeledLine(L10n.diaryOneEventTitle, entry.event)
            labeledLine(L10n.diaryOneThoughtTitle, entry.thought)
            labeledLine(
                L10n.diaryFeelingsTitle,
                L10n.diaryFeelingsPreview(entry.feelings)
            )
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
        if showLoading {
            patientModeStatus = .loading
            assignmentError = nil
            activeAssignmentId = nil
        }
        guard let patientId = patient.id.uuidValue else {
            patientModeStatus = .failed
            assignmentError = L10n.patientConnectionCheckError
            return
        }
        if store.isDemoMode || DemoData.isDemoID(patient.id) {
            patientModeStatus = .notConnected
            return
        }
        do {
            let connected = try await assignmentService().isPatientConnected(patientId: patientId)
            guard connected else {
                patientModeStatus = .notConnected
                return
            }
            if let active = try await assignmentService().activeOngoingAssignment(
                patientId: patientId,
                type: .diaryOne
            ) {
                activeAssignmentId = active.id
                patientModeStatus = .active
            } else {
                patientModeStatus = .inactive
            }
        } catch {
            patientModeStatus = .failed
            assignmentError = L10n.patientConnectionCheckError
        }
    }

    private func activateDiaryOne() async {
        guard !isUpdatingAssignment, patientModeStatus == .inactive else { return }
        guard let patientId = patient.id.uuidValue else {
            assignmentError = L10n.diaryPatientModeActivateFailed
            return
        }
        isUpdatingAssignment = true
        assignmentError = nil
        defer { isUpdatingAssignment = false }
        do {
            let active = try await assignmentService().activateOngoingAssignment(
                patientId: patientId,
                type: .diaryOne
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

    private func stopDiaryOne() async {
        guard !isUpdatingAssignment, let assignmentId = activeAssignmentId else { return }
        isUpdatingAssignment = true
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

/// Add or edit a Diary 1 entry. Physical symptoms are optional.
struct DiaryOneEntryFormView: View {
    let patient: Patient
    let mode: DiaryOneEditorMode

    @Environment(DiaryOneStore.self) private var diary
    @Environment(\.dismiss) private var dismiss

    @State private var draft: DiaryOneEntryDraft
    @State private var initialSnapshot: DiaryOneEntryDraft.Snapshot
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
    private var existing: DiaryOneEntry? { mode.existing }

    private var hasUnsavedChanges: Bool {
        draft.comparableSnapshot != initialSnapshot
    }

    init(patient: Patient, mode: DiaryOneEditorMode) {
        self.patient = patient
        self.mode = mode
        let hydrated: DiaryOneEntryDraft
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
            DiaryOneDraftFields(
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
        .navigationTitle(L10n.diaryOneTitle)
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
        let symptoms = draft.physicalSymptoms.trimmingCharacters(in: .whitespacesAndNewlines)
        let event = draft.event.trimmingCharacters(in: .whitespacesAndNewlines)
        let thought = draft.thought.trimmingCharacters(in: .whitespacesAndNewlines)
        let behaviour = draft.behaviour.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            switch mode {
            case .edit(let existing):
                _ = try await diary.updateEntry(
                    id: existing.id,
                    patientId: patient.id,
                    event: event,
                    thought: thought,
                    feelings: feelings,
                    behaviour: behaviour,
                    physicalSymptoms: symptoms
                )
            case .create:
                _ = try await diary.createEntry(
                    patientId: patient.id,
                    event: event,
                    thought: thought,
                    feelings: feelings,
                    behaviour: behaviour,
                    physicalSymptoms: symptoms
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
