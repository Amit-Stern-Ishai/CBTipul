import SwiftUI

/// The entry shows its selections; the full catalogue lives in a dedicated picker.
struct DiaryThinkingErrorPicker: View {
    @Binding var selection: [ThinkingError]
    @State private var showingPicker = false
    @State private var explaining: ThinkingError?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(selection) { error in
                HStack(spacing: 12) {
                    Text(error.title).frame(maxWidth: .infinity, alignment: .leading)
                    Button { selection.removeAll { $0 == error } } label: {
                        Image(systemName: "minus.circle").frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .accessibilityLabel(L10n.diaryRemoveThinkingError(error.title))
                }
            }
            Button { showingPicker = true } label: {
                Label(selection.isEmpty ? L10n.diaryChooseThinkingErrors : L10n.diaryEditThinkingErrors,
                      systemImage: selection.isEmpty ? "plus.circle" : "slider.horizontal.3")
            }.buttonStyle(.bordered)
        }
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.diaryThinkingChoose).font(.subheadline).foregroundStyle(.secondary)
                        ForEach(ThinkingError.allCases) { error in
                            HStack(spacing: 8) {
                                Button {
                                    if selection.contains(error) { selection.removeAll { $0 == error } }
                                    else { selection.append(error) }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: selection.contains(error) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(Theme.gold)
                                        Text(error.title)
                                            .foregroundStyle(Theme.textBright)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
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
                            Divider()
                        }
                    }.padding(20)
                }
                .themedScreen()
                .navigationTitle(L10n.diaryChooseThinkingErrors)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.confirmSelectionAction) { showingPicker = false }
                    }
                }
                .alert(explaining?.title ?? "", isPresented: Binding(get: { explaining != nil }, set: { if !$0 { explaining = nil } })) {
                    Button(L10n.ok, role: .cancel) { explaining = nil }
                } message: { Text(explaining?.explanation ?? "") }
            }
            .environment(\.layoutDirection, .rightToLeft)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}
