import SwiftUI

/// How the AI assistant reveals its answers.
enum AIResponseStyle: String, CaseIterable {
    /// Streams the answer in word by word, ChatGPT-style.
    case typing
    /// Shows the full answer at once.
    case regular
}

/// App-wide settings.
struct SettingsView: View {
    @AppStorage("aiResponseStyle") private var responseStyle: AIResponseStyle = .typing
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
            }
            .navigationTitle(QuestionnaireText.settingsTitle)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(QuestionnaireText.settingsDoneAction) { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
