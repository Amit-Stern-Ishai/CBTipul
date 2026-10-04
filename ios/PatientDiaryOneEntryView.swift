import OSLog
import SwiftUI

/// Patient Mode Diary 1 hub: history of patient-created entries, plus new entry.
struct PatientDiaryOneHubView: View {
    var isActive: Bool
    var onAssignmentsRefresh: () async -> Void
    @State private var locallyInactive = false
    var onEntrySubmitted: () async -> Void

    @Environment(AuthManager.self) private var auth
    @Environment(AppContextService.self) private var appContext

    private enum LoadState {
        case loading
        case loaded
        case failed
    }

    @State private var loadState: LoadState = .loading
    @State private var entries: [DiaryOneEntry] = []

    var body: some View {
        Group {
            switch loadState {
            case .loading where entries.isEmpty:
                ProgressView()
                    .tint(Theme.gold)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed where entries.isEmpty:
                VStack(alignment: .leading, spacing: 16) {
                    Text(L10n.diaryOneLoadFailed)
                        .font(.body)
                        .foregroundStyle(Theme.textBody)
                    Button(L10n.retryAction) {
                        Task { await loadEntries() }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            case .loading, .loaded, .failed:
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        Text(L10n.diaryOneMyEntriesTitle)
                            .font(.headline)
                            .foregroundStyle(Theme.textBright)
                            .padding(.top, 8)

                        if !isActive || locallyInactive {
                            Text(L10n.patientDiaryOneNotActive).foregroundStyle(Theme.textBody)
                        }
                        if entries.isEmpty {
                            Text(L10n.diaryOneEmptyTitle)
                                .font(.body)
                                .foregroundStyle(Theme.textBody)
                        } else {
                            ForEach(entries) { entry in
                                NavigationLink {
                                    PatientDiaryOneDetailView(entry: entry)
                                } label: {
                                    patientHistoryRow(entry)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
        }
        .patientAtmosphere(Theme.gold)
        .themedScreen()
        .navigationTitle(L10n.diaryOneTitle)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if loadState == .loaded || !entries.isEmpty {
                NavigationLink {
                    PatientDiaryOneEntryView(
                        onSubmitted: {
                            await onEntrySubmitted()
                            await loadEntries()
                        },
                        onDiaryInactive: {
                            locallyInactive = true
                            await onAssignmentsRefresh()
                        }
                    )
                } label: {
                    Text(entries.isEmpty ? L10n.emptyDiaryOnePrimaryAction : L10n.diaryOneAddEntryAction)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 24)
                }
                .disabled(!isActive || locallyInactive)
                .entitlementCreateControl()
                .buttonStyle(.pressableProminent)
                .controlSize(.large)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Theme.base)
            }
        }
        .task { await onAssignmentsRefresh(); await loadEntries() }
    }

    private func patientHistoryRow(_ entry: DiaryOneEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.hebrewDateTime(entry.createdAt))
                .font(.headline)
                .foregroundStyle(Theme.textBright)
            Text(entry.event)
                .font(.body)
                .foregroundStyle(Theme.textBody)
                .lineLimit(2)
            if !entry.automaticThoughtsPreview.isEmpty {
                Text(entry.automaticThoughtsPreview)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textBody)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private func loadEntries() async {
        guard let patientId = appContext.current?.patientId else {
            loadState = .failed
            return
        }
        if entries.isEmpty {
            loadState = .loading
        }
        do {
            entries = try await PatientDiaryOneService(client: auth.client)
                .loadPatientCreatedEntries(patientId: patientId)
            loadState = .loaded
        } catch {
            loadState = .failed
        }
    }
}

/// Read-only submitted Diary 1 entry in Patient Mode.
struct PatientDiaryOneDetailView: View {
    let entry: DiaryOneEntry
    var therapistViewing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if therapistViewing { Label(L10n.patientSubmissionReadOnly, systemImage: "eye").font(.subheadline).foregroundStyle(Theme.textBody) }
                Text(L10n.hebrewDateTime(entry.createdAt))
                    .font(.headline)
                    .foregroundStyle(Theme.textBright)
                labeledBlock(L10n.diaryOneEventTitle, entry.event)
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.diaryOneThoughtTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(Array(entry.automaticThoughts.enumerated()), id: \.offset) { _, thought in
                        Text(thought)
                            .font(.body)
                            .foregroundStyle(Theme.textBright)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                labeledBlock(L10n.diaryFeelingsTitle, L10n.diaryFeelingsPreview(entry.feelings))
                labeledBlock(L10n.diaryOneBehaviourTitle, entry.behaviour)
                if let symptoms = entry.physicalSymptoms, !symptoms.isEmpty {
                    labeledBlock(L10n.diaryOnePhysicalSymptomsTitle, symptoms)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .patientAtmosphere(Theme.gold)
        .themedScreen()
        .navigationTitle(L10n.diaryOneTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func labeledBlock(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .foregroundStyle(Theme.textBright)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Patient Mode create-only Diary 1. No history, edit, or delete.
struct PatientDiaryOneEntryView: View {
    var onSubmitted: () async -> Void
    var onDiaryInactive: () async -> Void

    @Environment(AuthManager.self) private var auth
    @Environment(AppContextService.self) private var appContext
    @Environment(\.dismiss) private var dismiss

    @State private var draft = DiaryOneEntryDraft.empty
    @State private var deviceDraft = DeviceFormDraft<DiaryOneEntryDraft>()
    @State private var didSubmit = false
    @State private var initialSnapshot = DiaryOneEntryDraft.empty.comparableSnapshot
    @State private var didAttemptSave = false
    @State private var isSaving = false
    @State private var isShowingValidationAlert = false
    @State private var isShowingBackWarning = false
    @State private var isShowingInactiveAlert = false
    @State private var errorMessage: String?
    @State private var validationMessage: String?
    @State private var inactiveMessage: String = L10n.patientDiaryOneNotActive

    private var isBusy: Bool { isSaving }

    private var hasUnsavedChanges: Bool {
        draft.comparableSnapshot != initialSnapshot
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                PatientDiaryGuide(isDiaryTwo: false)
                DeviceDraftFeedback(message: deviceDraft.feedback, isError: deviceDraft.hasError)
                DiaryOneDraftFields(
                draft: $draft,
                didAttemptSave: didAttemptSave,
                errorMessage: errorMessage
                )
                .disabled(isBusy || didSubmit || !EntitlementState.shared.canPatientWrite)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .patientAtmosphere(Theme.gold)
        .themedScreen()
        .dismissesKeyboardOnTap()
        .navigationTitle(L10n.diaryOneTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .busyOverlay(isBusy, label: L10n.patientDiaryOneSubmitting)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task {
                    if didSubmit { await finishSuccessfully() }
                    else { await submit() }
                }
            } label: {
                Text(didSubmit ? L10n.retryAction : L10n.patientDiaryOneSaveAction)
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
                    if didSubmit {
                        Task { await finishSuccessfully() }
                    } else if hasUnsavedChanges {
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
        }
        .alert(L10n.diaryOneValidationTitle, isPresented: $isShowingValidationAlert) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(validationMessage ?? L10n.diaryOneValidationMessage)
        }
        .alert(L10n.leaveDraftTitle, isPresented: $isShowingBackWarning) {
            Button(L10n.keepDraftAndLeave) { if persistDraft() { dismiss() } }
            Button(L10n.discardDraftAction, role: .destructive) { if deviceDraft.discard() { dismiss() } }
            Button(L10n.keepEditingAction, role: .cancel) {}
        }
        .alert(L10n.patientDiaryOneNotActiveTitle, isPresented: $isShowingInactiveAlert) {
            Button(L10n.ok, role: .cancel) {
                Task {
                    await onDiaryInactive()
                    dismiss()
                }
            }
        } message: {
            Text(inactiveMessage)
        }
        .interactiveDismissDisabled(hasUnsavedChanges || isBusy || didSubmit)
        .onAppear {
            guard let patientID = appContext.current?.patientId else { return }
            if let saved = deviceDraft.restore(userID: auth.currentUserId, kind: "patient-diary", target: patientID.uuidString) {
                draft = saved
            }
        }
        .onChange(of: draft) { _, _ in
            if deviceDraft.hasLoaded, !didSubmit { persistDraft() }
        }
    }

    @discardableResult
    private func persistDraft() -> Bool {
        deviceDraft.save(draft, isEmpty: draft.comparableSnapshot == DiaryOneEntryDraft.empty.comparableSnapshot)
    }

    private func finishSuccessfully() async {
        didSubmit = true
        guard deviceDraft.discard() else {
            errorMessage = L10n.submittedDraftCleanup
            isSaving = false
            return
        }
        initialSnapshot = draft.comparableSnapshot
        await onSubmitted()
        dismiss()
    }

    private func submit() async {
        guard EntitlementState.shared.allowMutation() else { return }
        guard !isBusy, !didSubmit else { return }
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
        do {
            try await PatientDiaryOneService(client: auth.client).submitEntry(
                event: draft.event.trimmingCharacters(in: .whitespacesAndNewlines),
                automaticThoughts: draft.persistedAutomaticThoughts,
                feelings: feelings,
                behaviour: draft.behaviour.trimmingCharacters(in: .whitespacesAndNewlines),
                physicalSymptoms: symptoms.isEmpty ? nil : symptoms
            )
            await finishSuccessfully()
        } catch let PatientDiaryOneSubmitError.notActive(message) {
            isSaving = false
            inactiveMessage = message
            isShowingInactiveAlert = true
        } catch let PatientDiaryOneSubmitError.accessDenied(message) {
            errorMessage = message
            isSaving = false
            await refreshPatientContext()
            if appContext.current?.isActivePatient != true {
                dismiss()
            }
        } catch let error as PatientDiaryOneSubmitError {
            errorMessage = error.errorDescription ?? L10n.patientDiaryOneSubmitError
            isSaving = false
        } catch {
            errorMessage = L10n.patientDiaryOneSubmitError
            isSaving = false
        }
    }

    private func refreshPatientContext() async {
        do {
            _ = try await appContext.getCurrentAppContext()
        } catch {
            AppLog.store.error("Patient context refresh after Diary 1 submit failed")
        }
    }
}
