import SwiftUI

/// A thought is one labelled input, with its optional ratings kept in the same card.
struct DiaryThoughtRow<Content: View>: View {
    let id: UUID
    let number: Int
    let title: String
    @Binding var text: String
    var focusRequest: UUID?
    var focusVersion: Int = 0
    let onRemove: () -> Void
    @ViewBuilder var content: () -> Content
    @FocusState private var focused: Bool
    @State private var confirmingRemoval = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.diaryThoughtNumber(title, number)).font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { onRemove() }
                    else { confirmingRemoval = true }
                } label: {
                    Image(systemName: "trash").frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .accessibilityLabel(L10n.diaryRemoveThoughtNumber(title, number))
            }
            TextField(title, text: $text, axis: .vertical)
                .lineLimit(2...6)
                .focused($focused)
                .padding(12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(focused ? Theme.gold : Theme.borderDefault))
                .accessibilityLabel(L10n.diaryThoughtNumber(title, number))
                .task(id: focusVersion) { if focusRequest == id { focused = true } }
            content()
        }
        .padding(12)
        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 14))
        .confirmationDialog(L10n.diaryRemoveThoughtConfirm, isPresented: $confirmingRemoval, titleVisibility: .visible) {
            Button(L10n.diaryRemoveThoughtAction, role: .destructive, action: onRemove)
            Button(L10n.cancel, role: .cancel) {}
        }
    }
}

struct DiaryThoughtsEditor: View {
    @Binding var rows: [DiaryAutomaticThoughtDraft]
    let title: String
    let addTitle: String
    @State private var focusRequest: UUID?
    @State private var focusVersion = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach($rows) { row in
                DiaryThoughtRow(id: row.wrappedValue.id,
                    number: (rows.firstIndex { $0.id == row.wrappedValue.id } ?? 0) + 1,
                    title: title, text: row.text, focusRequest: focusRequest, focusVersion: focusVersion,
                    onRemove: { [id = row.wrappedValue.id] in rows.removeAll { $0.id == id } }) { EmptyView() }
            }
            if !rows.contains(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                Button {
                    if let unfinished = rows.first(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                        focusRequest = unfinished.id
                    } else {
                        let row = DiaryAutomaticThoughtDraft()
                        rows.append(row)
                        focusRequest = row.id
                    }
                    focusVersion += 1
                } label: { Label(addTitle, systemImage: "plus.circle") }
                .buttonStyle(.bordered)
            }
        }
    }
}
