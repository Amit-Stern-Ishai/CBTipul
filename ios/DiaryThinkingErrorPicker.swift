import SwiftUI

/// Selection stays separate from explanation, so reading help never changes the entry.
struct DiaryThinkingErrorPicker: View {
    @Binding var selection: [ThinkingError]
    @State private var explaining: ThinkingError?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.diaryThinkingChoose).font(.footnote).foregroundStyle(.secondary)
            ForEach(ThinkingError.allCases) { error in
                HStack(spacing: 8) {
                    Button {
                        if selection.contains(error) { selection.removeAll { $0 == error } }
                        else { selection.append(error) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selection.contains(error) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(Theme.gold)
                            Text(error.title).foregroundStyle(Theme.textBright)
                            Spacer(minLength: 0)
                        }.frame(minHeight: 48).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection.contains(error) ? .isSelected : [])
                    Button { explaining = error } label: {
                        Image(systemName: "info.circle").frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain).foregroundStyle(Theme.gold)
                    .accessibilityLabel(L10n.diaryThinkingAbout(error.title))
                }
            }
        }
        .alert(explaining?.title ?? "", isPresented: Binding(get: { explaining != nil }, set: { if !$0 { explaining = nil } })) {
            Button(L10n.ok, role: .cancel) { explaining = nil }
        } message: { Text(explaining?.explanation ?? "") }
    }
}
