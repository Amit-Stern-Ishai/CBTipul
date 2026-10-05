import SwiftUI
import OSLog

/// Patient Mode create-only Diary 3. No history, edit, or delete.
struct PatientDiaryThreeEntryView: View {
    var onSubmitted: () async -> Void
    var onDiaryInactive: () async -> Void
    var onVisibilityChange: (Bool) -> Void = { _ in }

    @Environment(AuthManager.self) private var auth
    @Environment(AppContextService.self) private var appContext
    @Environment(\.dismiss) private var dismiss

    @State private var draft = PatientDiaryThreeDraft()
    @State private var deviceDraft = DeviceFormDraft<PatientDiaryThreeDraft>()
    @State private var editSection = 1
    @State private var didSubmit = false
    @State private var isSaving = false
    @State private var isShowingValidationAlert = false
    @State private var isShowingBackWarning = false
    @State private var isShowingInactiveAlert = false
    @State private var errorMessage: String?
    @State private var validationMessage: String?
    @State private var inactiveMessage: String = L10n.patientDiaryThreeNotActive

    private var isBusy: Bool { isSaving }

    private var hasUnsavedChanges: Bool {
        draft.hasMeaningfulContent
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                DeviceDraftFeedback(message: deviceDraft.feedback, isError: deviceDraft.hasError)
                Text(L10n.patientDiaryThreeStepHints[draft.currentStep - 1])
                    .foregroundStyle(Theme.textBody).fixedSize(horizontal: false, vertical: true)
                DiaryThreeDraftFields(draft: $draft.entry, step: draft.currentStep, didAttemptSave: false, errorMessage: errorMessage)
                    .id(draft.currentStep)
                .disabled(isBusy || didSubmit || !EntitlementState.shared.canPatientWrite)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .id(draft.currentStep)
        .scrollDismissesKeyboard(.interactively)
        .patientAtmosphere(Theme.gold)
        .themedScreen()
        .dismissesKeyboardOnTap()
        .navigationTitle(L10n.diaryThreeTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .busyOverlay(isBusy, label: L10n.patientDiaryOneSubmitting)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.patientDiaryThreeProgress(draft.currentStep)).font(.subheadline.weight(.semibold))
                ProgressView(value: Double(draft.currentStep), total: 7).tint(Theme.gold)
            }.padding(.horizontal, 20).padding(.vertical, 12).background(Theme.base)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                if draft.currentStep > 1 && !didSubmit {
                    Button(L10n.diaryPreviousStep) { draft.back(); errorMessage = nil }
                        .frame(minHeight: 44).disabled(isBusy)
                }
                Button {
                    Task {
                        if didSubmit { await finishSuccessfully() }
                        else if draft.currentStep < 7 { advance() }
                        else { await submit() }
                    }
                } label: {
                    Text(didSubmit ? L10n.retryAction : (draft.currentStep == 7 ? L10n.patientDiaryOneSaveAction : L10n.introductionNext))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.pressableProminent)
                .disabled(isBusy)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Theme.base.opacity(0.95))
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    if didSubmit {
                        Task { await finishSuccessfully() }
                    } else if draft.currentStep > 1 {
                        draft.back()
                        errorMessage = nil
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
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    if didSubmit { Task { await finishSuccessfully() } }
                    else if hasUnsavedChanges { isShowingBackWarning = true }
                    else { dismiss() }
                } label: { Image(systemName: "xmark").accessibilityLabel(L10n.welcomeInfoDoneAction) }
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
                    dismiss()
                }
            }
        } message: {
            Text(inactiveMessage)
        }
        .interactiveDismissDisabled(hasUnsavedChanges || isBusy || didSubmit)
        .onDisappear { onVisibilityChange(false) }
        .onAppear {
            onVisibilityChange(true)
            guard let patientID = appContext.current?.patientId else { return }
            if let saved = deviceDraft.restore(userID: auth.currentUserId, kind: "patient-diary-three", target: patientID.uuidString) {
                draft = saved
                draft.currentStep = min(7, max(1, saved.currentStep))
            }
        }
        .onChange(of: draft.currentStep) { _, _ in resignCurrentKeyboard() }
        .onChange(of: draft) { _, _ in
            if deviceDraft.hasLoaded, !didSubmit { persistDraft() }
        }
    }

    @discardableResult
    private func persistDraft() -> Bool {
        deviceDraft.save(draft, isEmpty: !draft.hasMeaningfulContent)
    }

    private func finishSuccessfully() async {
        didSubmit = true
        guard deviceDraft.discard() else {
            errorMessage = L10n.submittedDraftCleanup
            isSaving = false
            return
        }
        draft = PatientDiaryThreeDraft()
        await onSubmitted()
        dismiss()
    }

    private func advance() {
        if let message = draft.validationMessage() {
            validationMessage = message
            isShowingValidationAlert = true
        } else {
            _ = draft.advance()
            errorMessage = nil
        }
    }

    private func submit() async {
        guard EntitlementState.shared.allowMutation() else { return }
        guard !isBusy, !didSubmit else { return }
        if let step = draft.firstInvalidStep {
            draft.currentStep = step
            validationMessage = draft.validationMessage()
            isShowingValidationAlert = true
            return
        }
        guard let feelings = draft.entry.persistedFeelings() else {
            validationMessage = L10n.diaryOneValidationMessage
            isShowingValidationAlert = true
            return
        }
        isSaving = true
        errorMessage = nil
        do {
            _ = try await PatientDiaryThreeService(client: auth.client).submitEntry(
                situation: draft.entry.situation.trimmingCharacters(in: .whitespacesAndNewlines),
                automaticThoughts: draft.entry.persistedAutomaticThoughts,
                feelings: feelings,
                thinkingErrors: draft.entry.thinkingErrors,
                alternativeThoughts: draft.entry.persistedAlternativeThoughts
            )
            await finishSuccessfully()
        } catch let PatientDiaryThreeSubmitError.notActive(message) {
            isSaving = false
            inactiveMessage = message
            isShowingInactiveAlert = true
            await onDiaryInactive()
        } catch let PatientDiaryThreeSubmitError.accessDenied(message) {
            inactiveMessage = message
            isShowingInactiveAlert = true
            isSaving = false
            await onDiaryInactive()
            await refreshPatientContext()
            if appContext.current?.isActivePatient != true {
                dismiss()
            }
        } catch let error as PatientDiaryThreeSubmitError {
            validationMessage = error.errorDescription ?? L10n.patientDiaryOneSubmitError
            isShowingValidationAlert = true
            isSaving = false
        } catch {
            validationMessage = L10n.patientDiaryOneSubmitError
            isShowingValidationAlert = true
            isSaving = false
        }
    }

    private func refreshPatientContext() async {
        do {
            _ = try await appContext.getCurrentAppContext()
        } catch {
            AppLog.store.error("Patient context refresh after Diary 3 submit failed")
        }
    }
}
