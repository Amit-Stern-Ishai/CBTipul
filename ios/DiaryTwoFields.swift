import SwiftUI

struct DiaryTwoDraftFields: View {
    @Binding var draft: DiaryTwoEntryDraft
    var didAttemptSave: Bool
    var errorMessage: String? = nil
    var initialSection = 1
    @State private var active = 1

    private var issues: [String?] {
        var feelingIssue: String?
        if draft.feelings.isEmpty { feelingIssue = L10n.diaryOneValidationFeelingsRequired }
        else if let missing = draft.feelings.first(where: { $0.trimmedName.isEmpty || $0.intensity.map { !(0...100).contains($0) } ?? true }) {
            feelingIssue = L10n.diaryOneValidationFeelingIntensity(missing.trimmedName)
        } else if Set(draft.feelings.map(\.trimmedName)).count != draft.feelings.count { feelingIssue = L10n.diaryFeelingAlreadySelected }
        return [
            draft.event.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? L10n.diaryOneValidationEvent : nil,
            draft.persistedAutomaticThoughts.isEmpty ? L10n.diaryOneValidationThought : nil,
            feelingIssue,
            draft.thinkingErrors.isEmpty ? L10n.diaryTwoValidationErrors : nil,
            draft.persistedAlternativeThoughts.isEmpty ? L10n.diaryTwoValidationAlternatives : nil
        ]
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 16) {
                Color.clear.frame(height: 0).onAppear { active = initialSection; proxy.scrollTo(initialSection, anchor: .top) }
                DiaryEntryProgress(completed: issues.filter { $0 == nil }.count, total: issues.count)
                section(1, L10n.diaryOneEventTitle, draft.event) {
                    NotesField(text: $draft.event, placeholder: L10n.diaryOneEventQuestion, minLines: 3, maxLines: 8)
                }
                section(2, L10n.diaryOneThoughtTitle, draft.persistedAutomaticThoughts.joined(separator: " · ")) {
                    Text(L10n.diaryEntryThoughtHint).font(.subheadline).foregroundStyle(Theme.textBody)
                    DiaryThoughtsEditor(rows: $draft.automaticThoughts, title: L10n.diaryOneThoughtSingularTitle, addTitle: L10n.diaryOneAddThoughtAction)
                }
                section(3, L10n.diaryFeelingsTitle, draft.feelings.map(\.name).joined(separator: " · ")) {
                    DiaryFeelingsEditor(drafts: $draft.feelings, highlightIncomplete: didAttemptSave)
                }
                section(4, L10n.diaryThinkingErrorsTitle, draft.thinkingErrors.map(\.title).joined(separator: " · ")) {
                    DiaryOriginalThoughts(thoughts: draft.persistedAutomaticThoughts)
                    DiaryThinkingErrorPicker(selection: $draft.thinkingErrors)
                }
                section(5, L10n.diaryAlternativeThoughtsTitle, draft.persistedAlternativeThoughts.joined(separator: " · ")) {
                    Text(L10n.diaryEntryAlternativeHint).font(.subheadline).foregroundStyle(Theme.textBody)
                    DiaryOriginalThoughts(thoughts: draft.persistedAutomaticThoughts)
                    DiaryThoughtsEditor(rows: $draft.alternativeThoughts, title: L10n.diaryAlternativeThoughtTitle, addTitle: L10n.diaryAddAlternativeThought)
                }
                if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(Theme.error) }
            }
            .onChange(of: didAttemptSave) { _, attempted in
                if attempted, let missing = issues.firstIndex(where: { $0 != nil }) { active = missing + 1 }
            }
            .onChange(of: active) { _, section in
                if section > 0 { proxy.scrollTo(section, anchor: .top) }
            }
        }
    }

    private func section<C: View>(_ number: Int, _ title: String, _ summary: String, @ViewBuilder content: @escaping () -> C) -> some View {
        DiaryEntrySection(number: number, title: title, summary: summary, issue: issues[number - 1],
            attempted: didAttemptSave, active: $active, next: number < 5 ? { active = number + 1 } : nil, content: content)
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
                    Text(entry.createdBy == .patient ? L10n.patientSubmissionReadOnly : L10n.diaryEntryTherapistSource)
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
            if let entry, entry.createdBy == .therapist {
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
