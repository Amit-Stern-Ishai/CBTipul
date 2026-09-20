import OSLog
import SwiftUI

/// Patient Mode create-only Diary 1. No history, edit, or delete.
struct PatientDiaryOneEntryView: View {
    var onSubmitted: () async -> Void
    var onDiaryInactive: () async -> Void

    @Environment(AuthManager.self) private var auth
    @Environment(AppContextService.self) private var appContext
    @Environment(\.dismiss) private var dismiss

    @State private var draft = DiaryOneEntryDraft.empty
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
        .themedScreen()
        .dismissesKeyboardOnTap()
        .navigationTitle(L10n.diaryOneTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .busyOverlay(isBusy, label: L10n.patientDiaryOneSubmitting)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await submit() }
            } label: {
                Text(L10n.patientDiaryOneSaveAction)
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
        .interactiveDismissDisabled(hasUnsavedChanges || isBusy)
    }

    private func submit() async {
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
        do {
            try await PatientDiaryOneService(client: auth.client).submitEntry(
                event: draft.event.trimmingCharacters(in: .whitespacesAndNewlines),
                thought: draft.thought.trimmingCharacters(in: .whitespacesAndNewlines),
                feelings: feelings,
                behaviour: draft.behaviour.trimmingCharacters(in: .whitespacesAndNewlines),
                physicalSymptoms: symptoms.isEmpty ? nil : symptoms
            )
            initialSnapshot = draft.comparableSnapshot
            await onSubmitted()
            dismiss()
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
