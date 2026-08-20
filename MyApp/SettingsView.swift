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
        case .small: QuestionnaireText.settingsTextSizeSmall
        case .standard: QuestionnaireText.settingsTextSizeStandard
        case .large: QuestionnaireText.settingsTextSizeLarge
        case .extraLarge: QuestionnaireText.settingsTextSizeExtraLarge
        case .huge: QuestionnaireText.settingsTextSizeHuge
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

/// Applies the app's text-size setting. Needed at the root of every sheet
/// and full-screen cover (besides the app root), because presented screens
/// don't inherit the presenting view's dynamic-type override.
private struct AppTextSizeModifier: ViewModifier {
    @AppStorage("appTextSize") private var textSize: AppTextSize = .standard

    func body(content: Content) -> some View {
        content.dynamicTypeSize(textSize.dynamicTypeSize)
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(QuestionnaireText.settingsAISectionTitle) {
                    Picker(selection: $responseStyle) {
                        Text(QuestionnaireText.settingsResponseStyleTyping).tag(AIResponseStyle.typing)
                        Text(QuestionnaireText.settingsResponseStyleRegular).tag(AIResponseStyle.regular)
                    } label: {
                        Label {
                            Text(QuestionnaireText.settingsResponseStyleTitle)
                        } icon: {
                            Image(systemName: "text.cursor")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(Color.purple.gradient, in: RoundedRectangle(cornerRadius: 7))
                        }
                    }
                }

                Section(QuestionnaireText.settingsAccessibilitySectionTitle) {
                    NavigationLink {
                        TextSizePickerView()
                    } label: {
                        HStack {
                            Label {
                                Text(QuestionnaireText.settingsTextSizeTitle)
                            } icon: {
                                Image(systemName: "textformat.size")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 7))
                            }
                            Spacer()
                            Text(textSize.label)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(QuestionnaireText.settingsTitle)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(QuestionnaireText.settingsDoneAction) { dismiss() }
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
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(QuestionnaireText.settingsTextSizeTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
}
