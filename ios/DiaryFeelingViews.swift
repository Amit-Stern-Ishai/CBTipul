import SwiftUI

/// Wrapping chip row that follows available width and Hebrew RTL.
struct DiaryFeelingChipFlow: Layout {
    var spacing: CGFloat = 8
    var rightToLeft: Bool = true

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        arrange(maxWidth: proposal.width ?? proposal.replacingUnspecifiedDimensions().width, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let frames = arrange(maxWidth: bounds.width, subviews: subviews).frames
        for (subview, frame) in zip(subviews, frames) {
            let x = rightToLeft
                ? bounds.maxX - frame.maxX
                : bounds.minX + frame.minX
            subview.place(
                at: CGPoint(x: x, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(
        maxWidth: CGFloat,
        subviews: Subviews
    ) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            usedWidth = max(usedWidth, x - spacing)
        }

        return (CGSize(width: usedWidth, height: y + rowHeight), frames)
    }
}

struct DiaryFeelingChip: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isEnabled ? Theme.textBright : Theme.textFaint)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(
                    Capsule().fill(isEnabled ? Theme.elevated : Theme.elevated.opacity(0.5))
                )
                .overlay(
                    Capsule().stroke(Theme.gold.opacity(0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct DiaryFeelingIntensityControl: View {
    @Binding var intensity: Int?
    var title: String = L10n.diaryOneFeelingIntensityTitle
    var requiresExplicitChoice = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                if let current = intensity ?? (requiresExplicitChoice ? nil : 80) {
                    Text(L10n.diaryOneIntensityValue(current))
                        .fontWeight(.semibold).monospacedDigit()
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
            if let current = intensity ?? (requiresExplicitChoice ? nil : 80), (0...100).contains(current) {
                Slider(value: Binding(get: { Double(intensity ?? current) }, set: { intensity = Int($0.rounded()) }), in: 0...100, step: 1)
                    .tint(Theme.gold)
                    .environment(\.layoutDirection, .rightToLeft)
                    .accessibilityLabel(title)
                HStack {
                    Text(L10n.diaryOneIntensityValue(0)).environment(\.layoutDirection, .leftToRight)
                    Spacer()
                    Text(L10n.diaryOneIntensityValue(100)).environment(\.layoutDirection, .leftToRight)
                }.font(.caption).foregroundStyle(.secondary).environment(\.layoutDirection, .rightToLeft)
                Text(L10n.diaryRatingAdjust).font(.caption).foregroundStyle(Theme.textBody)
            } else {
                Text(L10n.diaryRatingChoose).font(.footnote).foregroundStyle(.secondary)
                DiaryFeelingChipFlow(rightToLeft: false) {
                    ForEach([0, 25, 50, 75, 100], id: \.self) { value in
                        Button { intensity = value } label: {
                            Text(L10n.diaryOneIntensityValue(value)).font(.subheadline.weight(.semibold))
                                .monospacedDigit().frame(minWidth: 44, minHeight: 44)
                                .padding(.horizontal, 4)
                                .background(Theme.goldGhost, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain).foregroundStyle(Theme.gold)
                        .accessibilityLabel(title + ": " + L10n.diaryOneIntensityValue(value))
                    }
                }.environment(\.layoutDirection, .leftToRight)
            }
        }
    }
}

/// Grouped chip picker plus optional custom feeling. Reusable by Patient Mode.
struct DiaryFeelingPickerSheet: View {
    let selectedNames: Set<String>
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var layoutDirection

    @State private var query = ""
    @State private var isEnteringCustom = false
    @State private var customText = ""
    @State private var customError: String?
    @FocusState private var customFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(L10n.diaryFeelingsPickerHint).font(.subheadline).foregroundStyle(Theme.textBody)
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        groupedVocabulary
                    } else {
                        searchResults
                    }
                    customFeelingSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.base.ignoresSafeArea())
            .navigationTitle(L10n.diaryFeelingPickTitle)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: L10n.diaryFeelingSearchPrompt)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
        }
        .themedScreen()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var groupedVocabulary: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(DiaryFeelingVocabulary.groups) { group in
                let available = group.feelings.filter { !selectedNames.contains($0) }
                if !available.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(group.title)
                            .font(.headline)
                            .foregroundStyle(Theme.textBright)
                        chipFlow(available)
                    }
                }
            }
        }
    }

    private var searchResults: some View {
        let matches = DiaryFeelingVocabulary.matching(query)
            .filter { !selectedNames.contains($0) }
        return Group {
            if matches.isEmpty {
                Text(L10n.diaryFeelingSearchEmpty)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                chipFlow(matches)
            }
        }
    }

    private func chipFlow(_ names: [String]) -> some View {
        DiaryFeelingChipFlow(rightToLeft: layoutDirection == .rightToLeft) {
            ForEach(names, id: \.self) { name in
                DiaryFeelingChip(title: name) {
                    pick(name)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var customFeelingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                customText = query.trimmingCharacters(in: .whitespacesAndNewlines)
                isEnteringCustom = true
                customFocused = true
            } label: {
                Label(L10n.diaryOtherFeelingAction, systemImage: "plus")
                    .fontWeight(.semibold)
            }
            if isEnteringCustom {
                TextField(L10n.diaryCustomFeelingPlaceholder, text: $customText)
                    .textFieldStyle(.roundedBorder)
                    .focused($customFocused)
                    .submitLabel(.done)
                    .onSubmit { submitCustom() }
                    .onChange(of: customText) { _, _ in customError = nil }
                if let customError {
                    Text(customError)
                        .font(.footnote)
                        .foregroundStyle(Theme.error)
                }
                Button(L10n.diaryCustomFeelingConfirmAction) {
                    submitCustom()
                }
                .buttonStyle(.pressableProminent)
                .disabled(customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
        .padding(.top, 8)
    }

    private func pick(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !selectedNames.contains(trimmed) else { return }
        onPick(trimmed)
        dismiss()
    }

    private func submitCustom() {
        let trimmed = customText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            customError = L10n.diaryCustomFeelingEmpty
            return
        }
        if selectedNames.contains(trimmed) {
            customError = L10n.diaryFeelingAlreadySelected
            return
        }
        onPick(trimmed)
        dismiss()
    }
}

/// Multiple feelings with per-feeling intensity. Reusable by Patient Mode.
struct DiaryFeelingsEditor: View {
    @Binding var drafts: [DiaryFeelingDraft]
    var highlightIncomplete: Bool = false

    @State private var isShowingPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if drafts.isEmpty { Text(L10n.diaryEntryFeelingsHint).font(.subheadline).foregroundStyle(.secondary) }
            ForEach($drafts) { $draft in
                feelingBlock($draft)
            }
            Button {
                isShowingPicker = true
            } label: {
                Label(L10n.diaryAddFeelingAction, systemImage: "plus")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .padding(.top, drafts.isEmpty ? 0 : 4)
        }
        .onAppear {
            for index in drafts.indices where drafts[index].intensity == nil { drafts[index].intensity = 80 }
        }
        .sheet(isPresented: $isShowingPicker) {
            DiaryFeelingPickerSheet(selectedNames: selectedNames) { name in
                drafts.append(DiaryFeelingDraft(name: name))
            }
        }
    }

    private var selectedNames: Set<String> {
        Set(drafts.map(\.trimmedName).filter { !$0.isEmpty })
    }

    private func feelingBlock(_ draft: Binding<DiaryFeelingDraft>) -> some View {
        let isIncomplete = highlightIncomplete
            && (draft.wrappedValue.trimmedName.isEmpty || draft.wrappedValue.intensity == nil)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(draft.wrappedValue.name)
                    .font(.headline)
                Spacer()
                if !drafts.isEmpty {
                    Button {
                        drafts.removeAll { $0.id == draft.wrappedValue.id }
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(Theme.textBody).frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.diaryRemoveFeelingAction)
                }
            }
            DiaryFeelingIntensityControl(intensity: draft.intensity)
                .id(draft.wrappedValue.id)
            if isIncomplete {
                Text(L10n.diaryOneValidationFeelingIntensity(draft.wrappedValue.trimmedName))
                    .font(.footnote)
                    .foregroundStyle(Theme.error)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1)
        )
    }
}

/// Guided Diary 1 fields shared by therapist and Patient Mode.
struct DiaryOneDraftFields: View {
    @Binding var draft: DiaryOneEntryDraft
    var didAttemptSave: Bool
    var errorMessage: String? = nil
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
            draft.behaviour.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? L10n.diaryOneValidationBehaviour : nil
        ]
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 16) {
                DiaryEntryProgress(completed: issues.filter { $0 == nil }.count, total: 5, lastPartOptional: true)
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
                section(4, L10n.diaryOneBehaviourTitle, draft.behaviour) {
                    NotesField(text: $draft.behaviour, placeholder: L10n.diaryOneBehaviourQuestion, minLines: 3, maxLines: 8)
                }
                DiaryEntrySection(number: 5, title: L10n.diaryOnePhysicalSymptomsTitle, summary: draft.physicalSymptoms,
                    issue: nil, optional: true, active: $active) {
                    NotesField(text: $draft.physicalSymptoms, placeholder: L10n.diaryOnePhysicalSymptomsQuestion, minLines: 2, maxLines: 8)
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
