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
                    Picker(QuestionnaireText.settingsResponseStyleTitle, selection: $responseStyle) {
                        Text(QuestionnaireText.settingsResponseStyleTyping).tag(AIResponseStyle.typing)
                        Text(QuestionnaireText.settingsResponseStyleRegular).tag(AIResponseStyle.regular)
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
