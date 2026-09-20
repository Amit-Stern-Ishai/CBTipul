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
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isEnabled ? Theme.elevated : Theme.elevated.opacity(0.5))
                )
                .overlay(
                    Capsule().stroke(Theme.borderDefault, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct DiaryFeelingIntensityControl: View {
    @Binding var intensity: Int?
    @State private var knob: Double
    @State private var hasExplicitValue: Bool

    init(intensity: Binding<Int?>) {
        _intensity = intensity
        if let value = intensity.wrappedValue, (0...100).contains(value) {
            _knob = State(initialValue: Double(value))
            _hasExplicitValue = State(initialValue: true)
        } else {
            _knob = State(initialValue: 50)
            _hasExplicitValue = State(initialValue: false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.diaryOneFeelingIntensityTitle)
                Spacer()
                Text(label)
                    .fontWeight(.semibold)
                    .foregroundStyle(hasExplicitValue ? Theme.textBright : Theme.textFaint)
            }
            Slider(value: $knob, in: 0...100, step: 1) { isEditing in
                if isEditing {
                    hasExplicitValue = true
                    intensity = Int(knob.rounded())
                } else if hasExplicitValue {
                    intensity = Int(knob.rounded())
                }
            }
            .tint(Theme.gold)
        }
    }

    private var label: String {
        if hasExplicitValue {
            return L10n.diaryOneIntensityValue(Int(knob.rounded()))
        }
        return L10n.diaryOneIntensityUnset
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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
                isEnteringCustom = true
            } label: {
                Label(L10n.diaryOtherFeelingAction, systemImage: "plus")
                    .fontWeight(.semibold)
            }
            if isEnteringCustom {
                TextField(L10n.diaryCustomFeelingPlaceholder, text: $customText)
                    .textFieldStyle(.roundedBorder)
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
            ForEach($drafts) { $draft in
                feelingBlock($draft)
            }
            Button {
                isShowingPicker = true
            } label: {
                Label(L10n.diaryAddFeelingAction, systemImage: "plus")
                    .font(.body.weight(.semibold))
            }
            .padding(.top, drafts.isEmpty ? 0 : 4)
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
                if drafts.count > 1 {
                    Button {
                        drafts.removeAll { $0.id == draft.wrappedValue.id }
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(Theme.textBody)
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
    }
}

/// Guided Diary 1 fields shared by therapist and Patient Mode.
struct DiaryOneDraftFields: View {
    @Binding var draft: DiaryOneEntryDraft
    var didAttemptSave: Bool
    var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepCard(
                title: L10n.diaryOneEventTitle,
                question: L10n.diaryOneEventQuestion,
                text: $draft.event,
                incompleteMessage: didAttemptSave && draft.event.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? L10n.diaryOneValidationEvent : nil
            )
            stepCard(
                title: L10n.diaryOneThoughtTitle,
                question: L10n.diaryOneThoughtQuestion,
                text: $draft.thought,
                incompleteMessage: didAttemptSave && draft.thought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? L10n.diaryOneValidationThought : nil
            )
            feelingsCard
            stepCard(
                title: L10n.diaryOneBehaviourTitle,
                question: L10n.diaryOneBehaviourQuestion,
                text: $draft.behaviour,
                incompleteMessage: didAttemptSave && draft.behaviour.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? L10n.diaryOneValidationBehaviour : nil
            )
            stepCard(
                title: L10n.diaryOnePhysicalSymptomsTitle,
                question: L10n.diaryOnePhysicalSymptomsQuestion,
                text: $draft.physicalSymptoms,
                optionalHint: L10n.diaryOneOptionalHint
            )
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Theme.error)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var feelingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.diaryFeelingsTitle)
                .font(.headline)
            DiaryFeelingsEditor(
                drafts: $draft.feelings,
                highlightIncomplete: didAttemptSave
            )
            if didAttemptSave, draft.feelings.isEmpty {
                Text(L10n.diaryOneValidationFeelingsRequired)
                    .font(.footnote)
                    .foregroundStyle(Theme.error)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private func stepCard(
        title: String,
        question: String,
        text: Binding<String>,
        optionalHint: String? = nil,
        incompleteMessage: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                if let optionalHint {
                    Text(optionalHint)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textFaint)
                }
            }
            Text(question)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            NotesField(text: text, placeholder: question, minLines: 3, maxLines: 8)
            if let incompleteMessage {
                Text(incompleteMessage)
                    .font(.footnote)
                    .foregroundStyle(Theme.error)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }
}
