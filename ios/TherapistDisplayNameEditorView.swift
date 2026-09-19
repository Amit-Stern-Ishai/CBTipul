import SwiftUI

/// Shared editor for the patient-facing therapist display name.
/// Optional mode is the one-time post-sign-in prompt; required mode is
/// Settings (and later, patient invitations).
struct TherapistDisplayNameEditorView: View {
    let requirement: TherapistDisplayNameRequirement
    /// When false, the caller already provides a `NavigationStack`
    /// (Settings `NavigationLink`). Sheets and the post-login gate wrap one.
    var embedsInNavigationStack: Bool = true
    var onOptionalFinished: (() -> Void)? = nil

    @Environment(TherapistProfileService.self) private var profiles
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var trimmedName: String {
        TherapistProfile.normalized(displayName)
    }

    private var canSave: Bool {
        TherapistProfile.isValid(trimmedName) && !isSaving && !isLoading
    }

    var body: some View {
        Group {
            if embedsInNavigationStack {
                NavigationStack { editor }
            } else {
                editor
            }
        }
        .appTextSize()
    }

    private var editor: some View {
        Form {
            Section {
                Text(L10n.therapistDisplayNamePromptExplanation)
                    .font(.body)
                    .foregroundStyle(Theme.textBody)
                    .listRowBackground(Color.clear)
            }

            Section {
                TextField(
                    L10n.therapistDisplayNamePlaceholder,
                    text: $displayName,
                    prompt: Text("")
                )
                .stablePlaceholder(
                    L10n.therapistDisplayNamePlaceholder,
                    isShown: displayName.isEmpty
                )
                .textContentType(.name)
                .disabled(isLoading || isSaving)
            }
            .listRowBackground(Theme.surface)

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Theme.error)
                }
                .listRowBackground(Theme.surface)
            }
        }
        .themedScreen()
        .dismissesKeyboardOnTap()
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .navigationTitle(L10n.therapistDisplayNamePromptTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if requirement == .required, embedsInNavigationStack {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                        .disabled(isSaving)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button(action: save) {
                    Group {
                        if isSaving {
                            ProgressView()
                                .tint(Theme.textOnAccent)
                        } else {
                            Text(L10n.save)
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.pressableProminent)
                .disabled(!canSave)

                if requirement == .optional {
                    Button(action: skip) {
                        Text(L10n.therapistDisplayNameSkipAction)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Theme.textBody)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                }
            }
            .padding(24)
        }
        .busyOverlay(isSaving || isLoading)
        .task { await loadExistingName() }
    }

    private func loadExistingName() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            if let profile = try await profiles.getCurrentProfile(),
               profile.hasValidDisplayName {
                displayName = profile.displayName
            }
        } catch {
            errorMessage = L10n.therapistDisplayNameLoadError
        }
    }

    private func save() {
        errorMessage = nil
        isSaving = true
        Task {
            do {
                _ = try await profiles.saveDisplayName(trimmedName)
                finishAfterSave()
            } catch {
                errorMessage = error.userFacingMessage
                isSaving = false
            }
        }
    }

    private func skip() {
        onOptionalFinished?()
    }

    private func finishAfterSave() {
        switch requirement {
        case .optional:
            onOptionalFinished?()
        case .required:
            dismiss()
        }
    }
}
