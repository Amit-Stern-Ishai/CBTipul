import SwiftUI

/// Patient-safe Settings. Reuses app-level rows; no therapist account tools.
struct PatientSettingsView: View {
    @AppStorage("appTextSize") private var textSize: AppTextSize = .standard
    @AppStorage("appAppearance") private var appearance: AppAppearance = .dark
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var auth
    @Environment(AppContextService.self) private var appContext

    @State private var presentedLink: SettingsOfficialLink?
    @State private var isConfirmingLeave = false
    @State private var isLeaving = false
    @State private var leaveError: String?

    private var appVersionLine: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return L10n.appVersionLabel(version: version, build: build)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.settingsAccessibilitySectionTitle) {
                    NavigationLink {
                        TextSizePickerView()
                    } label: {
                        HStack {
                            Label {
                                Text(L10n.settingsTextSizeTitle)
                            } icon: {
                                settingsGlyph("textformat.size")
                            }
                            Spacer()
                            Text(textSize.label)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(groupBorderedRow(.first, accent: Theme.gold))

                    NavigationLink {
                        AppearancePickerView()
                    } label: {
                        HStack {
                            Label {
                                Text(L10n.settingsAppearanceTitle)
                            } icon: {
                                settingsGlyph("circle.lefthalf.filled")
                            }
                            Spacer()
                            Text(appearance.label)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(groupBorderedRow(.last, accent: Theme.gold))
                }

                Section {
                    NavigationLink {
                        TermsView()
                    } label: {
                        Label {
                            Text(L10n.termsTitle)
                        } icon: {
                            settingsGlyph("doc.plaintext")
                        }
                    }
                    .listRowBackground(groupBorderedRow(.first, accent: Theme.gold))
                    externalLink(
                        L10n.privacyPolicyTitle,
                        icon: "hand.raised",
                        url: URL(string: "https://cbtipul.com/privacy")!
                    )
                    .listRowBackground(groupBorderedRow(.middle, accent: Theme.gold))
                    externalLink(
                        L10n.settingsSupportTitle,
                        icon: "questionmark.circle",
                        url: URL(string: "https://cbtipul.com/support")!
                    )
                    .listRowBackground(groupBorderedRow(.middle, accent: Theme.gold))
                    externalLink(
                        L10n.settingsPrivacyChoicesTitle,
                        icon: "slider.horizontal.3",
                        url: URL(string: "https://cbtipul.com/privacy-choices")!
                    )
                    .listRowBackground(groupBorderedRow(.last, accent: Theme.gold))
                }

                Section {
                    Button(role: .destructive) {
                        isConfirmingLeave = true
                    } label: {
                        Text(L10n.patientLeaveModeAction)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(isLeaving)
                }
                .listRowBackground(groupBorderedRow(.only, accent: Theme.gold))

                Section {
                    Text(appVersionLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)
            }
            .patientAtmosphere(Theme.gold)
            .themedScreen()
            .navigationTitle(L10n.settingsTitle)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.settingsDoneAction) { dismiss() }
                        .disabled(isLeaving)
                }
            }
            .alert(L10n.patientLeaveModeConfirmTitle, isPresented: $isConfirmingLeave) {
                Button(L10n.patientLeaveModeConfirmAction, role: .destructive) {
                    Task { await leavePatientMode() }
                }
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                Text(L10n.patientLeaveModeConfirmMessage)
            }
            .alert(L10n.patientLeaveModeFailed, isPresented: Binding(
                get: { leaveError != nil },
                set: { if !$0 { leaveError = nil } }
            )) {
                Button(L10n.ok, role: .cancel) {}
            } message: {
                Text(leaveError ?? "")
            }
            .sheet(item: $presentedLink) { link in
                NavigationStack {
                    OfficialLinkWebView(url: link.url)
                        .navigationTitle(link.title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button {
                                    presentedLink = nil
                                } label: {
                                    Image(systemName: "chevron.backward")
                                }
                                .tint(.black)
                                .accessibilityLabel(L10n.back)
                            }
                        }
                        .toolbarColorScheme(.light, for: .navigationBar)
                }
                .appTextSize()
            }
            .busyOverlay(isLeaving)
            .interactiveDismissDisabled(isLeaving)
        }
        .appTextSize()
    }

    private func settingsGlyph(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.gold)
            .frame(width: 28, height: 28)
            .background(Theme.goldGhost, in: RoundedRectangle(cornerRadius: 7))
    }

    private func externalLink(_ title: String, icon: String, url: URL) -> some View {
        Button {
            presentedLink = SettingsOfficialLink(title: title, url: url)
        } label: {
            HStack {
                Label {
                    Text(title)
                        .foregroundStyle(.primary)
                } icon: {
                    settingsGlyph(icon)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func leavePatientMode() async {
        guard !isLeaving else { return }
        guard auth.isAnonymous, !auth.isTherapistAuthenticated else {
            leaveError = L10n.patientLeaveModeFailed
            return
        }
        isLeaving = true
        leaveError = nil
        do {
            try await auth.signOutPatientMode()
            appContext.clear()
        } catch {
            leaveError = L10n.patientLeaveModeFailed
            isLeaving = false
        }
    }
}

private struct SettingsOfficialLink: Identifiable {
    let title: String
    let url: URL
    var id: URL { url }
}
