import SwiftUI

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

/// The app-wide appearance: the dark navy theme, its light counterpart, or
/// the native iOS system palette (which follows the device's light/dark
/// setting).
enum AppAppearance: String, CaseIterable {
    case system
    case light
    case dark

    var label: String {
        switch self {
        case .system: L10n.appearanceSystem
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
    /// The scheme inherited from the system, used when appearance is `system`.
    @Environment(\.colorScheme) private var systemScheme

    private var resolvedScheme: ColorScheme {
        switch appearance {
        case .system: systemScheme
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
            // Theme colors read the palette inside their dynamic providers;
            // re-identifying the tree on a palette change forces every
            // cached color to re-resolve immediately.
            .id(appearance)
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
                .listRowBackground(Theme.surface)

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
                .listRowBackground(Theme.surface)

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
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label {
                            Text(L10n.privacyPolicyTitle)
                        } icon: {
                            Image(systemName: "hand.raised")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.gold)
                                .frame(width: 28, height: 28)
                                .background(Theme.goldGhost, in: RoundedRectangle(cornerRadius: 7))
                        }
                    }
                }
                .listRowBackground(Theme.surface)

                Section {
                    Button(role: .destructive) {
                        store.clearAllCaches()
                        auth.signOut()
                    } label: {
                        Text(L10n.signOutAction)
                            .frame(maxWidth: .infinity)
                    }
                }
                .listRowBackground(Theme.surface)
            }
            .themedScreen()
            .navigationTitle(L10n.settingsTitle)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.settingsDoneAction) { dismiss() }
                }
            }
        }
        .appTextSize()
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
                }
            }
            .listRowBackground(Theme.surface)
        }
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
