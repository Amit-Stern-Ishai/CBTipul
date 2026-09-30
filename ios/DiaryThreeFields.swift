import SwiftUI

struct DiaryThreeDraftFields: View {
    @Binding var draft: DiaryThreeEntryDraft
    var step: Int? = nil
    var didAttemptSave: Bool
    var errorMessage: String? = nil
    @State private var showingFeelings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if step == nil || step == 1 {
                card(L10n.diaryThreeSituationTitle) {
                    NotesField(text: $draft.situation, placeholder: L10n.diaryOneEventQuestion, minLines: 3, maxLines: 8)
                }
            }
            if step == nil || step == 2 {
                card(L10n.diaryOneThoughtTitle) {
                    if step == nil { Text(L10n.diaryEntryThoughtHint).font(.subheadline).foregroundStyle(.secondary) }
                    ForEach($draft.automaticThoughts) { row in
                        HStack(alignment: .top) {
                            NotesField(text: row.text, placeholder: L10n.diaryOneThoughtSingularTitle, minLines: 2, maxLines: 6)
                            if draft.automaticThoughts.count > 1 {
                                remove(L10n.diaryOneRemoveThoughtAction) { draft.automaticThoughts.removeAll { $0.id == row.wrappedValue.id } }
                            }
                        }
                        DiaryThreePercentageControl(title: L10n.diaryThreeBeliefBefore, value: row.beliefBefore)
                        Divider()
                    }
                    Button(L10n.diaryOneAddThoughtAction) { draft.automaticThoughts.append(.init()) }
                }
            }
            if step == nil || step == 3 {
                card(L10n.diaryThreeFeelingsBefore) {
                    if draft.feelings.isEmpty { Text(L10n.diaryEntryFeelingsHint).font(.subheadline).foregroundStyle(.secondary) }
                    ForEach($draft.feelings) { row in
                        HStack {
                            Text(row.wrappedValue.name).fontWeight(.semibold)
                            Spacer()
                            remove(L10n.diaryThreeRemoveFeeling) { draft.feelings.removeAll { $0.id == row.wrappedValue.id } }
                        }
                        DiaryThreePercentageControl(title: L10n.diaryThreeIntensityBefore, value: row.intensityBefore)
                        Divider()
                    }
                    Button(L10n.diaryFeelingPickTitle) { showingFeelings = true }
                }
            }
            if step == nil || step == 4 {
                card(L10n.diaryThinkingErrorsTitle) {
                    DiaryThinkingErrorPicker(selection: $draft.thinkingErrors)
                }
            }
            if step == nil || step == 5 {
                card(L10n.diaryAlternativeThoughtsTitle) {
                    if step == nil { Text(L10n.diaryEntryAlternativeHint).font(.subheadline).foregroundStyle(.secondary) }
                    ForEach($draft.alternativeThoughts) { row in
                        HStack(alignment: .top) {
                            NotesField(text: row.text, placeholder: L10n.diaryAlternativeThoughtTitle, minLines: 2, maxLines: 6)
                            if draft.alternativeThoughts.count > 1 {
                                remove(L10n.diaryOneRemoveThoughtAction) { draft.alternativeThoughts.removeAll { $0.id == row.wrappedValue.id } }
                            }
                        }
                        DiaryThreePercentageControl(title: L10n.diaryThreeBelief, value: row.belief)
                        Divider()
                    }
                    Button(L10n.diaryOneAddThoughtAction) { draft.alternativeThoughts.append(.init()) }
                }
            }
            if step == nil || step == 6 {
                card(L10n.diaryThreeThoughtsAfter) {
                    ForEach($draft.automaticThoughts) { row in
                        Text(row.wrappedValue.text.isEmpty ? L10n.diaryOneThoughtSingularTitle : row.wrappedValue.text)
                        if step != nil, let before = row.wrappedValue.beliefBefore {
                            Text(L10n.diaryThreeBeliefBefore + ": " + L10n.diaryOneIntensityValue(before)).font(.subheadline).foregroundStyle(Theme.textBody)
                        }
                        DiaryThreePercentageControl(title: step == nil ? L10n.diaryThreeBeliefAfter : L10n.patientDiaryThreeBeliefNow, value: row.beliefAfter)
                        Divider()
                    }
                }
            }
            if step == nil || step == 7 {
                card(L10n.diaryThreeFeelingsAfter) {
                    ForEach($draft.feelings) { row in
                        Text(row.wrappedValue.name).fontWeight(.semibold)
                        if step != nil, let before = row.wrappedValue.intensityBefore {
                            Text(L10n.diaryThreeIntensityBefore + ": " + L10n.diaryOneIntensityValue(before)).font(.subheadline).foregroundStyle(Theme.textBody)
                        }
                        DiaryThreePercentageControl(title: step == nil ? L10n.diaryThreeIntensityAfter : L10n.patientDiaryThreeIntensityNow, value: row.intensityAfter)
                        Divider()
                    }
                }
            }
            if didAttemptSave, let message = draft.validationMessage() { Text(message).foregroundStyle(Theme.error) }
            if let errorMessage { Text(errorMessage).foregroundStyle(Theme.error) }
        }
        .sheet(isPresented: $showingFeelings) {
            DiaryFeelingPickerSheet(selectedNames: Set(draft.feelings.map(\.name))) { name in
                guard !draft.feelings.contains(where: { $0.name == name }) else { return }
                draft.feelings.append(.init(name: name))
            }
        }
    }
    private func remove(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: "minus.circle").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel(title)
    }
    private func card<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 14) { Text(title).font(.headline); content() }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading).themedCard()
    }
}

struct DiaryThreePercentageControl: View {
    let title: String
    @Binding var value: Int?
    var body: some View {
        DiaryFeelingIntensityControl(intensity: $value, title: title)
    }
}

struct DiaryThreeEntryDetailView: View {
    let patient: Patient
    let entryID: UUID
    @Environment(DiaryThreeStore.self) private var diary
    @Environment(\.dismiss) private var dismiss
    private var entry: DiaryThreeEntry? { diary.entries(for: patient.id).first { $0.id == entryID } }
    var body: some View {
        ScrollView {
            if let entry {
                VStack(alignment: .leading, spacing: 20) {
                    Text(entry.createdAt.formatted(date: .numeric, time: .shortened)).font(.subheadline)
                    Text(entry.createdBy == .patient ? L10n.diaryEntryPatientSource : L10n.diaryEntryTherapistSource).font(.caption).foregroundStyle(.secondary)
                    DiaryThreeEntryContent(entry: entry)
                }.padding(20)
            }
        }.themedScreen().demoModeChrome().navigationTitle(L10n.diaryThreeTitle)
        .toolbar {
            if let entry {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink { DiaryThreeEntryFormView(patient: patient, mode: .edit(entry)).id(entry.updatedAt) }
                    label: { Label(L10n.diaryEntryEdit, systemImage: "pencil") }
                }
            }
        }
        .onAppear { if entry == nil { dismiss() } }
    }
}

struct DiaryThreeEntryContent: View {
    let entry: DiaryThreeEntry
    var body: some View {
        section(L10n.diaryThreeSituationTitle) { Text(entry.situation) }
        section(L10n.diaryOneThoughtTitle) {
            ForEach(Array(entry.automaticThoughts.enumerated()), id: \.offset) { _, thought in
                Text(thought.text)
                comparison(thought.beliefBefore, thought.beliefAfter, beforeLabel: L10n.diaryThreeBeliefBefore, afterLabel: L10n.diaryThreeBeliefAfter)
            }
        }
        section(L10n.diaryTwoFeelingsTitle) {
            ForEach(Array(entry.feelings.enumerated()), id: \.offset) { _, feeling in
                Text(feeling.name).fontWeight(.semibold)
                comparison(feeling.intensityBefore, feeling.intensityAfter, beforeLabel: L10n.diaryThreeIntensityBefore, afterLabel: L10n.diaryThreeIntensityAfter)
            }
        }
        section(L10n.diaryThinkingErrorsTitle) { ForEach(entry.thinkingErrors) { Text($0.title) } }
        section(L10n.diaryAlternativeThoughtsTitle) {
            ForEach(Array(entry.alternativeThoughts.enumerated()), id: \.offset) { _, thought in
                Text(thought.text)
                Text(L10n.diaryThreeBelief + ": " + L10n.diaryOneIntensityValue(thought.belief)).font(.subheadline).foregroundStyle(Theme.textBody)
            }
        }
    }
    private func comparison(_ before: Int, _ after: Int, beforeLabel: String, afterLabel: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            rating(beforeLabel, before)
            rating(afterLabel, after)
        }.padding(12).background(Theme.elevated, in: RoundedRectangle(cornerRadius: 12))
    }
    private func rating(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(Theme.textBody)
            Text(L10n.diaryOneIntensityValue(value)).font(.title3.weight(.semibold)).monospacedDigit().environment(\.layoutDirection, .leftToRight)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) { Text(title).font(.headline); content() }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading).themedCard().textSelection(.enabled)
    }
}
