import SwiftUI

struct DiaryTwoDraftFields: View {
    @Binding var draft: DiaryTwoEntryDraft
    var didAttemptSave: Bool
    var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            card(L10n.diaryOneEventTitle) {
                NotesField(text: $draft.event, placeholder: L10n.diaryOneEventQuestion, minLines: 3, maxLines: 8)
            }
            card(L10n.diaryOneThoughtTitle) {
                thoughts($draft.automaticThoughts, placeholder: L10n.diaryOneThoughtSingularTitle)
            }
            card(L10n.diaryTwoFeelingsTitle) {
                DiaryFeelingsEditor(drafts: $draft.feelings, highlightIncomplete: didAttemptSave)
            }
            card(L10n.diaryThinkingErrorsTitle) {
                ForEach(ThinkingError.allCases) { error in
                    Button {
                        if draft.thinkingErrors.contains(error) { draft.thinkingErrors.removeAll { $0 == error } }
                        else { draft.thinkingErrors.append(error) }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: draft.thinkingErrors.contains(error) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(Theme.gold)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(error.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textBright)
                                Text(error.explanation).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(draft.thinkingErrors.contains(error) ? .isSelected : [])
                }
            }
            card(L10n.diaryAlternativeThoughtsTitle) {
                thoughts($draft.alternativeThoughts, placeholder: L10n.diaryAlternativeThoughtTitle)
            }
            if didAttemptSave, let message = draft.validationMessage() {
                Text(message).font(.footnote).foregroundStyle(Theme.error)
            }
            if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(Theme.error) }
        }
    }

    private func thoughts(_ rows: Binding<[DiaryAutomaticThoughtDraft]>, placeholder: String) -> some View {
        VStack(spacing: 12) {
            ForEach(rows) { row in
                HStack(alignment: .top) {
                    NotesField(text: row.text, placeholder: placeholder, minLines: 2, maxLines: 6)
                    if rows.wrappedValue.count > 1 {
                        Button {
                            rows.wrappedValue.removeAll { $0.id == row.wrappedValue.id }
                        } label: { Image(systemName: "minus.circle") }
                        .accessibilityLabel(L10n.diaryOneRemoveThoughtAction)
                    }
                }
            }
            Button(L10n.diaryOneAddThoughtAction) { rows.wrappedValue.append(DiaryAutomaticThoughtDraft()) }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline)
            content()
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).themedCard()
    }
}

struct DiaryTwoEntryDetailView: View {
    let patient: Patient
    let entryID: UUID
    @Environment(DiaryTwoStore.self) private var diary
    @Environment(\.dismiss) private var dismiss
    private var entry: DiaryTwoEntry? { diary.entries(for: patient.id).first { $0.id == entryID } }

    var body: some View {
        ScrollView {
            if let entry {
                VStack(alignment: .leading, spacing: 20) {
                    Text(entry.createdAt.formatted(date: .numeric, time: .shortened)).font(.subheadline)
                    Text(entry.createdBy == .patient ? L10n.diaryEntryPatientSource : L10n.diaryEntryTherapistSource)
                        .font(.caption).foregroundStyle(.secondary)
                    section(L10n.diaryOneEventTitle, [entry.event])
                    section(L10n.diaryOneThoughtTitle, entry.automaticThoughts)
                    section(L10n.diaryTwoFeelingsTitle, entry.feelings.map { "\($0.name) — \($0.intensity)%" })
                    section(L10n.diaryThinkingErrorsTitle, entry.thinkingErrors.map(\.title))
                    section(L10n.diaryAlternativeThoughtsTitle, entry.alternativeThoughts)
                }.padding(20)
            }
        }
        .themedScreen().demoModeChrome()
        .navigationTitle(L10n.diaryTwoTitle)
        .toolbar {
            if let entry {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        DiaryTwoEntryFormView(patient: patient, mode: .edit(entry)).id(entry.updatedAt)
                    } label: { Label(L10n.diaryEntryEdit, systemImage: "pencil") }
                }
            }
        }
        .onAppear { if entry == nil { dismiss() } }
    }

    private func section(_ title: String, _ values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Text(value).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).themedCard()
    }
}
