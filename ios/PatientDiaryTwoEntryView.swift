import SwiftUI
import OSLog

/// Patient Mode create-only Diary 2. No history, edit, or delete.
struct PatientDiaryTwoEntryView: View {
    var onSubmitted: () async -> Void
    var onDiaryInactive: () async -> Void

    @Environment(AuthManager.self) private var auth
    @Environment(AppContextService.self) private var appContext
    @Environment(\.dismiss) private var dismiss

    @State private var draft = DiaryTwoEntryDraft.empty
    @State private var deviceDraft = DeviceFormDraft<DiaryTwoEntryDraft>()
    @State private var didSubmit = false
    @State private var initialSnapshot = DiaryTwoEntryDraft.empty.comparableSnapshot
    @State private var didAttemptSave = false
    @State private var isSaving = false
    @State private var isShowingValidationAlert = false
    @State private var isShowingBackWarning = false
    @State private var isShowingInactiveAlert = false
    @State private var errorMessage: String?
    @State private var validationMessage: String?
    @State private var inactiveMessage: String = L10n.patientDiaryTwoNotActive

    private var isBusy: Bool { isSaving }

    private var hasUnsavedChanges: Bool {
        draft.comparableSnapshot != initialSnapshot
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                PatientDiaryGuide(isDiaryTwo: true)
                DeviceDraftFeedback(message: deviceDraft.feedback, isError: deviceDraft.hasError)
                DiaryTwoDraftFields(
                draft: $draft,
                didAttemptSave: didAttemptSave,
                errorMessage: errorMessage
                )
                .disabled(isBusy || didSubmit)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .patientAtmosphere(Theme.gold)
        .themedScreen()
        .dismissesKeyboardOnTap()
        .navigationTitle(L10n.diaryTwoTitle)
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
                Text(didSubmit ? L10n.done : L10n.patientDiaryOneSaveAction)
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
                    _ = deviceDraft.discard()
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
            if let saved = deviceDraft.restore(userID: auth.currentUserId, kind: "patient-diary-two", target: patientID.uuidString) {
                draft = saved
            }
        }
        .onChange(of: draft) { _, _ in
            if deviceDraft.hasLoaded, !didSubmit { persistDraft() }
        }
    }

    @discardableResult
    private func persistDraft() -> Bool {
        deviceDraft.save(draft, isEmpty: draft.comparableSnapshot == DiaryTwoEntryDraft.empty.comparableSnapshot)
    }

    private func finishSuccessfully() async {
        didSubmit = true
        guard deviceDraft.discard() else {
            errorMessage = L10n.submittedDraftCleanup
            isSaving = false
            return
        }
        draft = .empty
        initialSnapshot = draft.comparableSnapshot
        await onSubmitted()
        dismiss()
    }

    private func submit() async {
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
        do {
            _ = try await PatientDiaryTwoService(client: auth.client).submitEntry(
                event: draft.event.trimmingCharacters(in: .whitespacesAndNewlines),
                automaticThoughts: draft.persistedAutomaticThoughts,
                feelings: feelings,
                thinkingErrors: draft.thinkingErrors,
                alternativeThoughts: draft.persistedAlternativeThoughts
            )
            await finishSuccessfully()
        } catch let PatientDiaryTwoSubmitError.notActive(message) {
            isSaving = false
            inactiveMessage = message
            isShowingInactiveAlert = true
        } catch let PatientDiaryTwoSubmitError.accessDenied(message) {
            errorMessage = message
            isSaving = false
            await refreshPatientContext()
            if appContext.current?.isActivePatient != true {
                dismiss()
            }
        } catch let error as PatientDiaryTwoSubmitError {
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
            AppLog.store.error("Patient context refresh after Diary 2 submit failed")
        }
    }
}
