import SwiftUI

/// Local record of which accounts accepted the terms and conditions.
enum TermsAcceptance {
    private static func key(for email: String) -> String {
        "hasAcceptedTerms-\(email)"
    }

    static func hasAccepted(email: String) -> Bool {
        UserDefaults.standard.bool(forKey: key(for: email))
    }

    static func setAccepted(email: String) {
        UserDefaults.standard.set(true, forKey: key(for: email))
    }
}

/// The terms and conditions text. Read-only when opened from Settings;
/// when `onAgree` is set it becomes a blocking acceptance screen with an
/// Agree button (shown after sign-up, before the app can be used).
struct TermsView: View {
    /// Set when acceptance is required; called when the user agrees.
    var onAgree: (() -> Void)? = nil

    var body: some View {
        LegalDocumentView(text: L10n.termsBody)
            .navigationTitle(L10n.termsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if let onAgree {
                    Button {
                        onAgree()
                    } label: {
                        Text(L10n.termsAgreeAction)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.pressableProminent)
                    .padding()
                    .background(Theme.surface)
                }
            }
    }
}

/// Renders a long legal document (terms / privacy) as a styled screen
/// instead of one continuous text blob: the document title and update date
/// up top, then each numbered section in its own card with an accented
/// heading and semicolon-run lines shown as bullets. The wording itself is
/// untouched — only the presentation is structured.
struct LegalDocumentView: View {
    private let document: LegalDocument

    init(text: String) {
        document = LegalDocument(text: text)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    if let title = document.title {
                        Text(title)
                            .font(.title2.bold())
                    }
                    if let updated = document.updated {
                        Text(updated)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 4)

                ForEach(document.sections.indices, id: \.self) { index in
                    sectionCard(document.sections[index])
                }
            }
            .padding()
        }
        .background(Theme.base.ignoresSafeArea())
    }

    private func sectionCard(_ section: LegalDocument.Section) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let heading = section.heading {
                Text(heading)
                    .font(.headline)
                    .foregroundStyle(Theme.gold)
            }
            ForEach(section.blocks.indices, id: \.self) { index in
                switch section.blocks[index] {
                case .paragraph(let text):
                    Text(text)
                        .font(.subheadline)
                        .lineSpacing(3)
                case .bullet(let text):
                    Text(L10n.bulleted(text))
                        .font(.subheadline)
                        .lineSpacing(3)
                        .padding(.leading, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .themedCard()
    }
}

/// The parsed structure of a legal document body: title line, update-date
/// line, and numbered sections of paragraphs and bullet lines.
private struct LegalDocument {
    enum Block {
        case paragraph(String)
        case bullet(String)
    }

    struct Section {
        var heading: String?
        var blocks: [Block] = []
    }

    var title: String?
    var updated: String?
    var sections: [Section] = []

    init(text: String) {
        var current = Section()
        var paragraph: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            current.blocks.append(.paragraph(paragraph.joined(separator: " ")))
            paragraph = []
        }
        func flushSection() {
            flushParagraph()
            if current.heading != nil || !current.blocks.isEmpty {
                sections.append(current)
            }
        }

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flushParagraph()
                continue
            }
            if title == nil {
                title = line
                continue
            }
            if updated == nil, line.hasPrefix("עודכן לאחרונה") {
                updated = line
                continue
            }
            if Self.isHeading(line) {
                flushSection()
                current = Section(heading: line)
                continue
            }
            if line.hasSuffix(";") {
                flushParagraph()
                current.blocks.append(.bullet(String(line.dropLast())))
                continue
            }
            paragraph.append(line)
        }
        flushSection()
    }

    /// A numbered section title like "3. אחריות מקצועית" — digits, a dot,
    /// and a short line (so numbered sentences don't count as headings).
    private static func isHeading(_ line: String) -> Bool {
        guard let dotIndex = line.firstIndex(of: "."), line.count < 60 else { return false }
        let number = line[line.startIndex..<dotIndex]
        return !number.isEmpty && number.allSatisfy(\.isNumber)
    }
}

#Preview("Acceptance") {
    NavigationStack {
        TermsView(onAgree: {})
    }
}

#Preview("Read-only") {
    NavigationStack {
        TermsView()
    }
}
