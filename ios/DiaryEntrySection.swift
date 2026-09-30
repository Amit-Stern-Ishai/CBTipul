import SwiftUI

/// Compact sections preserve the full entry while keeping one editing task in view.
struct DiaryEntrySection<Content: View>: View {
    let number: Int
    let title: String
    let summary: String
    let issue: String?
    var optional = false
    var attempted = false
    @Binding var active: Int
    var next: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content
    @State private var triedNext = false

    private var expanded: Bool { active == number }
    private var showIssue: Bool { (attempted || triedNext) && issue != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                resignCurrentKeyboard()
                active = expanded ? 0 : number
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Theme.goldGhost).frame(width: 32, height: 32)
                        if issue == nil && !optional {
                            Image(systemName: "checkmark").font(.subheadline.weight(.bold))
                        } else {
                            Text(number.formatted()).font(.subheadline.weight(.semibold)).monospacedDigit()
                        }
                    }.foregroundStyle(Theme.gold)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.headline).foregroundStyle(Theme.textBright)
                        if optional { Text(L10n.diaryOneOptionalHint).font(.caption).foregroundStyle(Theme.textBody) }
                        if !expanded && !summary.isEmpty {
                            Text(summary).font(.subheadline).foregroundStyle(Theme.textBody).lineLimit(2)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption.weight(.semibold)).foregroundStyle(Theme.textBody)
                }.frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(expanded ? L10n.diarySectionClose : L10n.diarySectionOpen)
            .accessibilityValue(issue == nil && !optional ? L10n.diarySectionComplete : "")
            if expanded { content() }
            if showIssue, let issue {
                Label(issue, systemImage: "exclamationmark.circle")
                    .font(.footnote).foregroundStyle(Theme.error).fixedSize(horizontal: false, vertical: true)
            }
            if expanded, let next {
                Button {
                    triedNext = true
                    guard issue == nil else { return }
                    resignCurrentKeyboard()
                    next()
                } label: { Label(L10n.diarySectionNext, systemImage: "chevron.forward") }
                .buttonStyle(.bordered).frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).themedCard()
        .id(number)
    }
}

struct DiaryEntryProgress: View {
    let completed: Int
    let total: Int
    var lastPartOptional = false
    private var requiredTotal: Int { total - (lastPartOptional ? 1 : 0) }
    private var progressTitle: String { lastPartOptional ? L10n.diaryFivePartsOptional : L10n.diaryEntryProgress(completed, total) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(progressTitle).font(.subheadline.weight(.semibold))
            ProgressView(value: Double(completed), total: Double(requiredTotal)).tint(Theme.gold)
                .accessibilityLabel(progressTitle)
            Text(completed == requiredTotal ? L10n.diaryReadyToSave : L10n.diaryEntryGuide)
                .font(.footnote).foregroundStyle(Theme.textBody)
        }.padding(.vertical, 4)
    }
}

struct DiaryOriginalThoughts: View {
    let thoughts: [String]
    var body: some View {
        if !thoughts.isEmpty {
            DisclosureGroup(L10n.diaryOriginalThoughts) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(thoughts.enumerated()), id: \.offset) { _, thought in
                        Text(thought).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(.top, 8)
            }
            .font(.subheadline).tint(Theme.gold)
            .padding(12).background(Theme.elevated, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
