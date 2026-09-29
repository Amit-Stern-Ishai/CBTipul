import SwiftUI

/// A short, self-contained introduction. Illustrations use no patient data.
struct AppIntroductionView: View {
    var isReview = false
    var onTrySample: () -> Void
    var onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @AccessibilityFocusState private var focusedPage: Int?

    private let pageCount = 5
    private var isLastPage: Bool { page == pageCount - 1 }
    private func title(for index: Int) -> String {
        switch index {
        case 0: L10n.introductionPatientTitle
        case 1: L10n.introductionSessionTitle
        case 2: L10n.introductionConnectTitle
        case 3: L10n.introductionProgressTitle
        default: L10n.introductionSampleTitle
        }
    }
    private func explanation(for index: Int) -> String {
        switch index {
        case 0: L10n.introductionPatientBody
        case 1: L10n.introductionSessionBody
        case 2: L10n.introductionConnectBody
        case 3: L10n.introductionProgressBody
        default: L10n.introductionSampleBody
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $page) {
                // Keep UIKit's pager LTR and reverse its visual order so a
                // rightward swipe advances through this Hebrew introduction.
                slide(4).tag(4)
                slide(3).tag(3)
                slide(2).tag(2)
                slide(1).tag(1)
                slide(0).tag(0)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .environment(\.layoutDirection, .leftToRight)
            .onChange(of: page) { _, newPage in focusedPage = newPage }
            footer
        }
        .background {
            Theme.base.ignoresSafeArea()
                .overlay(alignment: .top) {
                    RadialGradient(colors: [Theme.gold.opacity(0.09), .clear],
                                   center: .top, startRadius: 20, endRadius: 440)
                        .ignoresSafeArea()
                }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func slide(_ index: Int) -> some View {
        ScrollView {
            VStack(spacing: 28) {
                illustration(for: index)
                    .frame(maxWidth: 360)
                    .padding(.top, 20)
                    .accessibilityHidden(true)
                VStack(spacing: 14) {
                    Text(title(for: index))
                        .font(.largeTitle.bold())
                        .foregroundStyle(Theme.textBright)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($focusedPage, equals: index)
                    Text(explanation(for: index))
                        .font(.body)
                        .foregroundStyle(Theme.textBody)
                        .lineSpacing(4)
                    if index == pageCount - 1 {
                        Text(L10n.introductionSampleHint)
                            .font(.callout)
                            .foregroundStyle(Theme.textBody)
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(Theme.goldGhost, in: RoundedRectangle(cornerRadius: 18))
                    }
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .environment(\.layoutDirection, .rightToLeft)
        .accessibilityHidden(index != page)
    }

    private var header: some View {
        VStack(spacing: 18) {
            HStack {
                Text(L10n.appTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.gold)
                    .accessibilityHidden(true)
                Spacer()
                Button(isReview ? L10n.done : L10n.introductionSkip, action: onContinue)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.gold)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier(isReview ? "introduction.close" : "introduction.skip")
            }
            HStack(spacing: 7) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index <= page ? Theme.gold : Theme.borderDefault)
                        .frame(height: 4)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.introductionPage(page + 1, total: pageCount))
            .accessibilityIdentifier("introduction.page.\(page + 1)")
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var footer: some View {
        // Keep every control slot measured on every page, including at larger
        // text sizes. Changing the pager's height during a swipe makes it jump.
        VStack(spacing: 6) {
            ZStack {
                Button { go(to: page + 1) } label: {
                    HStack {
                        Spacer()
                        Text(L10n.introductionNext)
                        Image(systemName: "arrow.forward")
                        Spacer()
                    }
                }
                .buttonStyle(.pressableProminent)
                .opacity(isLastPage ? 0 : 1)
                .allowsHitTesting(!isLastPage)
                .accessibilityHidden(isLastPage)
                .accessibilityIdentifier("introduction.next")

                Button(action: onTrySample) {
                    Label(L10n.introductionSampleAction, systemImage: "person.2.crop.square.stack")
                }
                .buttonStyle(.pressableProminent)
                .opacity(isLastPage ? 1 : 0)
                .allowsHitTesting(isLastPage)
                .accessibilityHidden(!isLastPage)
                .accessibilityIdentifier("introduction.sample")
            }
            Button(isReview ? L10n.introductionReturn : L10n.introductionStart, action: onContinue)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.gold)
                .frame(maxWidth: .infinity, minHeight: 48)
                .opacity(isLastPage ? 1 : 0)
                .allowsHitTesting(isLastPage)
                .accessibilityHidden(!isLastPage)
                .accessibilityIdentifier("introduction.continue")

            Button(L10n.back) { go(to: page - 1) }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textBody)
                .frame(maxWidth: .infinity, minHeight: 44)
                .opacity(page > 0 ? 1 : 0)
                .allowsHitTesting(page > 0)
                .accessibilityHidden(page == 0)
                .accessibilityIdentifier("introduction.back")
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(maxWidth: 540)
        .transaction { $0.animation = nil }
    }

    private func go(to newPage: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { page = newPage }
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 26, weight: .medium))
            .foregroundStyle(Theme.gold)
            .frame(width: 58, height: 58)
            .background(Theme.goldGhost, in: RoundedRectangle(cornerRadius: 18))
    }

    private func illustrationRow(_ text: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Theme.gold).frame(width: 24)
            Text(text).font(.subheadline.weight(.medium)).foregroundStyle(Theme.textBright)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.elevated.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func illustration(for index: Int) -> some View {
        VStack(spacing: 14) {
            switch index {
            case 0:
                HStack(spacing: 14) {
                    icon("person.crop.rectangle")
                    Text(L10n.patientRecordsTitle).font(.headline).foregroundStyle(Theme.textBright)
                    Spacer()
                }
                illustrationRow(L10n.introductionGoal, symbol: "scope")
                HStack(spacing: 10) {
                    illustrationRow(L10n.therapistTabSessions, symbol: "calendar")
                    illustrationRow(L10n.patientDiariesTitle, symbol: "book.closed")
                }
            case 1:
                HStack(spacing: 14) {
                    icon("waveform")
                    Text(L10n.introductionSessionNotes).font(.headline).foregroundStyle(Theme.textBright)
                    Spacer()
                }
                HStack(spacing: 10) {
                    illustrationRow(L10n.introductionWrite, symbol: "pencil")
                    illustrationRow(L10n.introductionRecord, symbol: "mic")
                }
                illustrationRow(L10n.introductionAI, symbol: "sparkles")
            case 2:
                Text(L10n.introductionConnected).font(.caption.weight(.semibold)).foregroundStyle(Theme.gold)
                illustrationRow(L10n.introductionMessage, symbol: "bubble.left")
                illustrationRow(L10n.introductionQuestionnaire, symbol: "list.clipboard")
                illustrationRow(L10n.introductionDiary, symbol: "book.closed")
            case 3:
                HStack {
                    icon("chart.xyaxis.line")
                    Spacer()
                    Text(L10n.introductionTrend).font(.headline).foregroundStyle(Theme.textBright)
                }
                GeometryReader { geometry in
                    let points: [CGFloat] = [0.22, 0.39, 0.32, 0.61, 0.58, 0.79]
                    ZStack {
                        ForEach(0..<3) { row in
                            Path { path in
                                let y = geometry.size.height * CGFloat(row + 1) / 4
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                            }
                            .stroke(Theme.borderFaint, style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
                        }
                        Path { path in
                            for (index, value) in points.enumerated() {
                                let point = CGPoint(x: geometry.size.width * CGFloat(index) / 5,
                                                    y: geometry.size.height * value)
                                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                            }
                        }
                        .stroke(Theme.gold, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        ForEach(points.indices, id: \.self) { index in
                            Circle().fill(Theme.gold).frame(width: 8, height: 8)
                                .position(x: geometry.size.width * CGFloat(index) / 5,
                                          y: geometry.size.height * points[index])
                        }
                    }
                }
                .frame(height: 115)
                .padding(.horizontal, 8)
                .environment(\.layoutDirection, .leftToRight)
            default:
                HStack(spacing: 14) {
                    icon("person.2.crop.square.stack")
                    Text(L10n.introductionSampleBadge).font(.headline).foregroundStyle(Theme.gold)
                    Spacer()
                }
                illustrationRow(L10n.introductionSamplePatient, symbol: "person.crop.circle")
                HStack(spacing: 10) {
                    illustrationRow(L10n.therapistTabSessions, symbol: "calendar")
                    illustrationRow(L10n.introductionDiary, symbol: "book.closed")
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Theme.borderFaint, lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 24, y: 10)
    }
}

#Preview {
    AppIntroductionView(onTrySample: {}, onContinue: {})
        .appTextSize()
}
