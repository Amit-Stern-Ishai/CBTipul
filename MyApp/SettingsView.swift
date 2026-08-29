import SwiftUI
import WebKit

/// How the AI assistant reveals its answers.
enum AIResponseStyle: String, CaseIterable {
    /// Streams the answer in word by word, ChatGPT-style.
    case typing
    /// Shows the full answer at once.
    case regular
}

/// App-wide text size, applied on top of Dynamic Type from ContentView.
enum AppTextSize: String, CaseIterable {
    case small
    case standard
    case large
    case extraLarge
    case huge

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .small: .small
        case .standard: .large
        case .large: .xLarge
        case .extraLarge: .xxxLarge
        case .huge: .accessibility2
        }
    }

    var label: String {
        switch self {
        case .small: L10n.settingsTextSizeSmall
        case .standard: L10n.settingsTextSizeStandard
        case .large: L10n.settingsTextSizeLarge
        case .extraLarge: L10n.settingsTextSizeExtraLarge
        case .huge: L10n.settingsTextSizeHuge
        }
    }

    /// The body font at this size, resolved explicitly so previews show the
    /// real size regardless of the surrounding environment.
    var previewFont: Font {
        Font(UIFont.preferredFont(
            forTextStyle: .body,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        ))
    }
}

/// The app-wide appearance: the dark navy theme (default) or the light
/// mode built on the native iOS system palette.
enum AppAppearance: String, CaseIterable {
    case light
    case dark

    var label: String {
        switch self {
        case .light: L10n.appearanceLight
        case .dark: L10n.appearanceDark
        }
    }
}

/// Applies the app's global environment: the text-size setting, the
/// right-to-left layout the Hebrew UI requires, and the appearance setting
/// the theme resolves against. Needed at the root of every sheet and
/// full-screen cover (besides the app root), because presented screens
/// don't inherit the presenting view's environment overrides.
private struct AppTextSizeModifier: ViewModifier {
    @AppStorage("appTextSize") private var textSize: AppTextSize = .standard
    @AppStorage("appAppearance") private var appearance: AppAppearance = .dark

    private var resolvedScheme: ColorScheme {
        switch appearance {
        case .light: .light
        case .dark: .dark
        }
    }

    func body(content: Content) -> some View {
        content
            .dynamicTypeSize(textSize.dynamicTypeSize)
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.colorScheme, resolvedScheme)
            .tint(Theme.gold)
    }
}

extension View {
    func appTextSize() -> some View {
        modifier(AppTextSizeModifier())
    }
}

/// App-wide settings.
struct SettingsView: View {
    @AppStorage("aiResponseStyle") private var responseStyle: AIResponseStyle = .typing
    @AppStorage("appTextSize") private var textSize: AppTextSize = .standard
    @AppStorage("appAppearance") private var appearance: AppAppearance = .dark
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var auth
    @Environment(PatientStore.self) private var store

    @State private var presentedLink: OfficialLink?
    @State private var isShowingDeleteAccountConfirmation = false
    @State private var isShowingDeleteAccountCodeChallenge = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?

    /// The app's marketing version and build number, e.g. "גרסה 1.0 (4)".
    private var appVersionLine: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return L10n.appVersionLabel(version: version, build: build)
    }

    var body: some View {
        NavigationStack {
            Form {
//                Section(L10n.settingsAISectionTitle) {
//                    Picker(selection: $responseStyle) {
//                        Text(L10n.settingsResponseStyleTyping).tag(AIResponseStyle.typing)
//                        Text(L10n.settingsResponseStyleRegular).tag(AIResponseStyle.regular)
//                    } label: {
//                        Label {
//                            Text(L10n.settingsResponseStyleTitle)
//                        } icon: {
//                            Image(systemName: "text.cursor")
//                                .font(.footnote.weight(.semibold))
//                                .foregroundStyle(.white)
//                                .frame(width: 28, height: 28)
//                                .background(Color.purple.gradient, in: RoundedRectangle(cornerRadius: 7))
//                        }
//                    }
//                }

                Section {
                    Picker(selection: $appearance) {
                        ForEach(AppAppearance.allCases, id: \.self) { option in
                            Text(option.label).tag(option)
                        }
                    } label: {
                        Label {
                            Text(L10n.settingsAppearanceTitle)
                        } icon: {
                            Image(systemName: "circle.lefthalf.filled")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.gold)
                                .frame(width: 28, height: 28)
                                .background(Theme.goldGhost, in: RoundedRectangle(cornerRadius: 7))
                        }
                    }
                }
                .listRowBackground(groupBorderedRow(.only, accent: Theme.gold))

                Section(L10n.settingsAccessibilitySectionTitle) {
                    NavigationLink {
                        TextSizePickerView()
                    } label: {
                        HStack {
                            Label {
                                Text(L10n.settingsTextSizeTitle)
                            } icon: {
                                Image(systemName: "textformat.size")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Theme.gold)
                                    .frame(width: 28, height: 28)
                                    .background(Theme.goldGhost, in: RoundedRectangle(cornerRadius: 7))
                            }
                            Spacer()
                            Text(textSize.label)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listRowBackground(groupBorderedRow(.only, accent: Theme.gold))

                Section {
                    NavigationLink {
                        TermsView()
                    } label: {
                        Label {
                            Text(L10n.termsTitle)
                        } icon: {
                            Image(systemName: "doc.plaintext")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.gold)
                                .frame(width: 28, height: 28)
                                .background(Theme.goldGhost, in: RoundedRectangle(cornerRadius: 7))
                        }
                    }
                    .listRowBackground(groupBorderedRow(.first, accent: Theme.gold))
                    externalLink(L10n.privacyPolicyTitle, icon: "hand.raised",
                                 url: URL(string: "https://cbtipul.com/privacy")!)
                        .listRowBackground(groupBorderedRow(.middle, accent: Theme.gold))
                    externalLink(L10n.settingsSupportTitle, icon: "questionmark.circle",
                                 url: URL(string: "https://cbtipul.com/support")!)
                        .listRowBackground(groupBorderedRow(.middle, accent: Theme.gold))
                    externalLink(L10n.settingsPrivacyChoicesTitle, icon: "slider.horizontal.3",
                                 url: URL(string: "https://cbtipul.com/privacy-choices")!)
                        .listRowBackground(groupBorderedRow(.last, accent: Theme.gold))
                }

                Section(L10n.settingsAccountSectionTitle) {
                    if let email = auth.currentUserEmail {
                        Label {
                            Text(email)
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: "person.crop.circle")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.gold)
                                .frame(width: 28, height: 28)
                                .background(Theme.goldGhost, in: RoundedRectangle(cornerRadius: 7))
                        }
                        .listRowBackground(groupBorderedRow(.first, accent: Theme.gold))
                    }
                    Button(role: .destructive) {
                        store.clearAllCaches()
                        auth.signOut()
                    } label: {
                        Text(L10n.signOutAction)
                            .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(groupBorderedRow(
                        auth.currentUserEmail == nil ? .only : .last, accent: Theme.gold))
                }

                // Account deletion sits alone at the bottom, clearly apart
                // from the routine sign-out.
                Section {
                    Button(role: .destructive) {
                        isShowingDeleteAccountConfirmation = true
                    } label: {
                        Text(L10n.deleteAccountAction)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(isDeletingAccount)
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
                }
            }
            .alert(L10n.deleteAccountConfirmTitle,
                   isPresented: $isShowingDeleteAccountConfirmation) {
                Button(L10n.deleteAccountAction, role: .destructive) {
                    isShowingDeleteAccountCodeChallenge = true
                }
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                Text(L10n.deleteAccountConfirmMessage)
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
                        // The web pages are light; a light bar keeps the
                        // title and back button black and readable in both
                        // app appearances.
                        .toolbarColorScheme(.light, for: .navigationBar)
                }
                .appTextSize()
            }
            .deleteCodeChallenge(isPresented: $isShowingDeleteAccountCodeChallenge) {
                deleteAccount()
            }
            .alert(L10n.deleteAccountFailedTitle,
                   isPresented: .init(get: { deleteAccountError != nil },
                                      set: { if !$0 { deleteAccountError = nil } })) {
                Button(L10n.ok, role: .cancel) {}
            } message: {
                Text(deleteAccountError ?? "")
            }
            .busyOverlay(isDeletingAccount)
        }
        .appTextSize()
    }

    /// One of the official cbtipul.com pages, shown in an in-app web view.
    private struct OfficialLink: Identifiable {
        let title: String
        let url: URL
        var id: URL { url }
    }

    /// A row that opens one of the official cbtipul.com pages in an in-app
    /// web view sheet.
    private func externalLink(_ title: String, icon: String, url: URL) -> some View {
        Button {
            presentedLink = OfficialLink(title: title, url: url)
        } label: {
            HStack {
                Label {
                    Text(title)
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: icon)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.gold)
                        .frame(width: 28, height: 28)
                        .background(Theme.goldGhost, in: RoundedRectangle(cornerRadius: 7))
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Deletes the account server-side, then wipes everything local. The
    /// sign-out happens inside `deleteAccount`, which drops the app back to
    /// the sign-in screen.
    private func deleteAccount() {
        isDeletingAccount = true
        Task {
            do {
                try await auth.deleteAccount()
                store.wipeLocalData()
                dismiss()
            } catch {
                deleteAccountError = error.localizedDescription
            }
            isDeletingAccount = false
        }
    }
}

/// An in-app browser for the official cbtipul.com pages, showing a busy
/// spinner while the page loads. SwiftUI's WebView exists only on iOS 26+,
/// so older systems (the app deploys to iOS 18.6) get a wrapped WKWebView
/// with the same loading treatment.
private struct OfficialLinkWebView: View {
    let url: URL

    var body: some View {
        if #available(iOS 26.0, *) {
            ModernOfficialLinkWebView(url: url)
        } else {
            LegacyOfficialLinkWebView(url: url)
        }
    }
}

@available(iOS 26.0, *)
private struct ModernOfficialLinkWebView: View {
    @State private var page: WebPage

    init(url: URL) {
        let page = WebPage()
        page.load(URLRequest(url: url))
        _page = State(initialValue: page)
    }

    var body: some View {
        WebView(page)
            // Hidden until loaded: the web view's blank first frame would
            // otherwise flash before the page renders. The pages are light,
            // so a white backdrop matches the loaded content, and the
            // loader stays light gray in both appearances instead of the
            // themed busy card (navy in dark mode).
            .opacity(page.isLoading ? 0 : 1)
            .background(Color.white.ignoresSafeArea())
            .overlay {
                if page.isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.gray)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: page.isLoading)
            .ignoresSafeArea(edges: .bottom)
    }
}

/// Pre-iOS 26 fallback: WKWebView with the same hidden-until-loaded look.
private struct LegacyOfficialLinkWebView: View {
    let url: URL
    @State private var isLoading = true

    var body: some View {
        LegacyWebView(url: url, isLoading: $isLoading)
            .opacity(isLoading ? 0 : 1)
            .background(Color.white.ignoresSafeArea())
            .overlay {
                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.gray)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isLoading)
            .ignoresSafeArea(edges: .bottom)
    }
}

private struct LegacyWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool

        init(isLoading: Binding<Bool>) {
            _isLoading = isLoading
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }

        func webView(_ webView: WKWebView,
                     didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }

        func webView(_ webView: WKWebView,
                     didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            isLoading = false
        }
    }
}

/// Text size selection, each option shown at the size it represents.
private struct TextSizePickerView: View {
    @AppStorage("appTextSize") private var textSize: AppTextSize = .standard

    var body: some View {
        Form {
            Section {
                ForEach(AppTextSize.allCases, id: \.self) { size in
                    Button {
                        textSize = size
                    } label: {
                        HStack {
                            Text(size.label)
                                .font(size.previewFont)
                                .foregroundStyle(.primary)
                            Spacer()
                            if textSize == size {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Theme.gold)
                            }
                        }
                    }
                    .listRowBackground(groupBorderedRow(
                        .at(AppTextSize.allCases.firstIndex(of: size) ?? 0,
                            of: AppTextSize.allCases.count),
                        accent: Theme.gold))
                }
            }
        }
        .patientAtmosphere(Theme.gold)
        .themedScreen()
        .navigationTitle(L10n.settingsTextSizeTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let auth = AuthManager()
    SettingsView()
        .environment(auth)
        .environment(PatientStore(client: auth.client))
}
