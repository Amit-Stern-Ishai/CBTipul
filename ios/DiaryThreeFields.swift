import SwiftUI

struct DiaryThreeDraftFields: View {
    @Binding var draft: DiaryThreeEntryDraft
    var step: Int? = nil
    var didAttemptSave: Bool
    var errorMessage: String? = nil
    @State private var active = 1
    @State private var showingFeelings = false
    @State private var thoughtFocusRequest: UUID?
    @State private var thoughtFocusVersion = 0

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 16) {
                if step == nil {
                    DiaryEntryProgress(completed: (1...7).filter { PatientDiaryThreeDraft(entry: draft).validationMessage(for: $0) == nil }.count, total: 7)
                }
                if step == nil || step == 1 {
                    card(1, L10n.diaryThreeSituationTitle) {
                        NotesField(text: $draft.situation, placeholder: L10n.diaryOneEventQuestion, minLines: 3, maxLines: 8)
                    }
                }
                if step == nil || step == 2 {
                    card(2, L10n.diaryOneThoughtTitle) {
                        if step == nil { Text(L10n.diaryEntryThoughtHint).font(.subheadline).foregroundStyle(.secondary) }
                        ForEach($draft.automaticThoughts) { row in
                            DiaryThoughtRow(id: row.wrappedValue.id,
                                number: (draft.automaticThoughts.firstIndex { $0.id == row.wrappedValue.id } ?? 0) + 1,
                                title: L10n.diaryOneThoughtSingularTitle, text: row.text, focusRequest: thoughtFocusRequest, focusVersion: thoughtFocusVersion,
                                onRemove: { [id = row.wrappedValue.id] in draft.automaticThoughts.removeAll { $0.id == id } }) {
                                DiaryThreePercentageControl(title: L10n.diaryThreeBeliefBefore, value: row.beliefBefore)
                            }
                        }
                        if !draft.automaticThoughts.contains(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                            Button {
                                if let unfinished = draft.automaticThoughts.first(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                                    thoughtFocusRequest = unfinished.id
                                } else {
                                    let row = DiaryThreeAutomaticThoughtDraft()
                                    draft.automaticThoughts.append(row)
                                    thoughtFocusRequest = row.id
                                }
                                thoughtFocusVersion += 1
                            } label: { Label(L10n.diaryOneAddThoughtAction, systemImage: "plus.circle") }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                if step == nil || step == 3 {
                    card(3, L10n.diaryThreeFeelingsBefore) {
                        if draft.feelings.isEmpty { Text(L10n.diaryEntryFeelingsHint).font(.subheadline).foregroundStyle(.secondary) }
                        ForEach($draft.feelings) { row in
                            HStack {
                                Text(row.wrappedValue.name).fontWeight(.semibold)
                                Spacer()
                                remove(L10n.diaryThreeRemoveFeeling) { draft.feelings.removeAll { $0.id == row.wrappedValue.id } }
                            }
                            DiaryThreePercentageControl(title: L10n.diaryThreeIntensityBefore, value: row.intensityBefore, requiresExplicitChoice: false)
                            Divider()
                        }
                        Button { showingFeelings = true } label: { Label(L10n.diaryAddFeelingAction, systemImage: "plus.circle") }
                            .buttonStyle(.bordered)
                    }
                }
                if step == nil || step == 4 {
                    card(4, L10n.diaryThinkingErrorsTitle) {
                        DiaryOriginalThoughts(thoughts: draft.automaticThoughts.map(\.text).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                        DiaryThinkingErrorPicker(selection: $draft.thinkingErrors)
                    }
                }
                if step == nil || step == 5 {
                    card(5, L10n.diaryAlternativeThoughtsTitle) {
                        if step == nil { Text(L10n.diaryEntryAlternativeHint).font(.subheadline).foregroundStyle(.secondary) }
                        DiaryOriginalThoughts(thoughts: draft.automaticThoughts.map(\.text).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                        ForEach($draft.alternativeThoughts) { row in
                            DiaryThoughtRow(id: row.wrappedValue.id,
                                number: (draft.alternativeThoughts.firstIndex { $0.id == row.wrappedValue.id } ?? 0) + 1,
                                title: L10n.diaryAlternativeThoughtTitle, text: row.text, focusRequest: thoughtFocusRequest, focusVersion: thoughtFocusVersion,
                                onRemove: { [id = row.wrappedValue.id] in draft.alternativeThoughts.removeAll { $0.id == id } }) {
                                DiaryThreePercentageControl(title: L10n.diaryThreeBelief, value: row.belief)
                            }
                        }
                        if !draft.alternativeThoughts.contains(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                            Button {
                                if let unfinished = draft.alternativeThoughts.first(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                                    thoughtFocusRequest = unfinished.id
                                } else {
                                    let row = DiaryThreeAlternativeThoughtDraft()
                                    draft.alternativeThoughts.append(row)
                                    thoughtFocusRequest = row.id
                                }
                                thoughtFocusVersion += 1
                            } label: { Label(L10n.diaryAddAlternativeThought, systemImage: "plus.circle") }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                if step == nil || step == 6 {
                    card(6, L10n.diaryThreeThoughtsAfter) {
                        ForEach($draft.automaticThoughts) { row in
                            Text(row.wrappedValue.text.isEmpty ? L10n.diaryOneThoughtSingularTitle : row.wrappedValue.text)
                            if let before = row.wrappedValue.beliefBefore {
                                beforeRating(L10n.diaryThreeBeliefBefore, before)
                            }
                            DiaryThreePercentageControl(title: step == nil ? L10n.diaryThreeBeliefAfter : L10n.patientDiaryThreeBeliefNow, value: row.beliefAfter)
                            Divider()
                        }
                    }
                }
                if step == nil || step == 7 {
                    card(7, L10n.diaryThreeFeelingsAfter) {
                        ForEach($draft.feelings) { row in
                            Text(row.wrappedValue.name).fontWeight(.semibold)
                            if let before = row.wrappedValue.intensityBefore {
                                beforeRating(L10n.diaryThreeIntensityBefore, before)
                            }
                            DiaryThreePercentageControl(title: step == nil ? L10n.diaryThreeIntensityAfter : L10n.patientDiaryThreeIntensityNow, value: row.intensityAfter, requiresExplicitChoice: false)
                            Divider()
                        }
                    }
                }
                if didAttemptSave, let message = draft.validationMessage() { Text(message).foregroundStyle(Theme.error) }
                if let errorMessage { Text(errorMessage).foregroundStyle(Theme.error) }
            }
            .onChange(of: didAttemptSave) { _, attempted in
                if attempted, step == nil, let missing = PatientDiaryThreeDraft(entry: draft).firstInvalidStep { active = missing }
            }
            .onChange(of: active) { _, section in if section > 0 { proxy.scrollTo(section, anchor: .top) } }
        }
        .onAppear {
            for index in draft.feelings.indices {
                if draft.feelings[index].intensityBefore == nil { draft.feelings[index].intensityBefore = 80 }
                if draft.feelings[index].intensityAfter == nil { draft.feelings[index].intensityAfter = 80 }
            }
        }
        .sheet(isPresented: $showingFeelings) {
            DiaryFeelingPickerSheet(selectedNames: Set(draft.feelings.map(\.name))) { name in
                guard !draft.feelings.contains(where: { $0.name == name }) else { return }
                draft.feelings.append(.init(name: name))
            }
        }
    }
    private func beforeRating(_ title: String, _ value: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(L10n.diaryOneIntensityValue(value)).monospacedDigit().environment(\.layoutDirection, .leftToRight)
        }.font(.subheadline).foregroundStyle(Theme.textBody)
    }
    private func remove(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: "minus.circle").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel(title)
    }
    private func card<C: View>(_ number: Int, _ title: String, @ViewBuilder content: @escaping () -> C) -> some View {
        let summaries = [draft.situation, draft.automaticThoughts.map(\.text).joined(separator: " · "),
            draft.feelings.map(\.name).joined(separator: " · "), draft.thinkingErrors.map(\.title).joined(separator: " · "),
            draft.alternativeThoughts.map(\.text).joined(separator: " · "), "", ""]
        return Group {
            if step == nil {
                DiaryEntrySection(number: number, title: title, summary: summaries[number - 1],
                    issue: PatientDiaryThreeDraft(entry: draft).validationMessage(for: number), attempted: didAttemptSave,
                    active: $active, next: number < 7 ? { active = number + 1 } : nil, content: content)
            } else {
                VStack(alignment: .leading, spacing: 14) { Text(title).font(.headline); content() }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).themedCard()
            }
        }
    }
}

struct DiaryThreePercentageControl: View {
    let title: String
    @Binding var value: Int?
    var requiresExplicitChoice = true
    var body: some View {
        DiaryFeelingIntensityControl(intensity: $value, title: title, requiresExplicitChoice: requiresExplicitChoice)
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
    private func section<C: View>(_ title: String, @ViewBuilder content: @escaping () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) { Text(title).font(.headline); content() }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading).themedCard().textSelection(.enabled)
    }
}
