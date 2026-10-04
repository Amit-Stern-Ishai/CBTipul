import SwiftUI

/// A short, self-contained introduction. Illustrations use no patient data.
struct AppIntroductionView: View {
    var isReview = false
    var isPatientMode = false
    var onTrySample: () -> Void
    var onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var showSampleGate = false
    @State private var startSampleAfterGate = false
    @AccessibilityFocusState private var focusedPage: Int?

    private var pageCount: Int { isPatientMode ? 4 : 5 }
    private var isLastPage: Bool { page == pageCount - 1 }
    private func title(for index: Int) -> String {
        if isPatientMode { return [L10n.patientIntroWelcomeTitle, L10n.patientIntroQuestionnairesTitle, L10n.patientIntroDiariesTitle, L10n.patientIntroUpdatesTitle][index] }
        return switch index {
        case 0: L10n.introductionPatientTitle
        case 1: L10n.introductionSessionTitle
        case 2: L10n.introductionConnectTitle
        case 3: L10n.introductionProgressTitle
        default: L10n.introductionSampleTitle
        }
    }
    private func topic(for index: Int) -> String {
        if isPatientMode { return [L10n.patientIntroWelcomeTitle, L10n.patientIntroQuestionnairesTitle, L10n.patientIntroDiariesTitle, L10n.patientIntroUpdatesTitle][index] }
        return switch index {
        case 0: L10n.introductionTopicPatient
        case 1: L10n.introductionTopicSession
        case 2: L10n.introductionTopicConnect
        case 3: L10n.introductionTopicProgress
        default: L10n.introductionTopicSample
        }
    }
    private func explanation(for index: Int) -> String {
        if isPatientMode { return [L10n.patientIntroWelcomeBody, L10n.patientIntroQuestionnairesBody, L10n.patientIntroDiariesBody, L10n.patientIntroUpdatesBody][index] }
        return switch index {
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
                if !isPatientMode { slide(4).tag(4) }
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
        .sheet(isPresented: $showSampleGate, onDismiss: {
            guard startSampleAfterGate else { return }
            startSampleAfterGate = false
            onTrySample()
        }) {
            SampleDataPreviewView {
                startSampleAfterGate = true
                showSampleGate = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .appTextSize()
        }
    }

    private func slide(_ index: Int) -> some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: geometry.size.height < 520 ? 12 : 18) {
                    Group {
                        if isPatientMode {
                            Image(systemName: ["person.2.fill", "list.clipboard", "book.closed", "bell.badge"][index])
                                .font(.system(size: 86, weight: .light))
                                .foregroundStyle(Theme.gold)
                                .frame(maxWidth: .infinity)
                                .frame(height: min(230, geometry.size.height * 0.45))
                                .background(Theme.goldGhost, in: RoundedRectangle(cornerRadius: 28))
                        } else { illustration(for: index) }
                    }
                        .frame(maxWidth: 420)
                        .accessibilityHidden(true)
                    VStack(spacing: 10) {
                        Text(title(for: index))
                            .font(.title.bold())
                            .foregroundStyle(Theme.textBright)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($focusedPage, equals: index)
                        Text(explanation(for: index))
                            .font(.body)
                            .foregroundStyle(Theme.textBody)
                            .lineSpacing(2)
                        if !isPatientMode && index == pageCount - 1 {
                            Text(L10n.introductionSampleHint)
                                .font(.callout)
                                .foregroundStyle(Theme.textBody)
                                .padding(12)
                                .frame(maxWidth: .infinity)
                                .background(Theme.goldGhost, in: RoundedRectangle(cornerRadius: 18))
                        }
                    }
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .accessibilityHidden(index != page)
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button { go(to: page - 1) } label: {
                    Image(systemName: "chevron.backward")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .foregroundStyle(Theme.gold)
                .opacity(page > 0 ? 1 : 0)
                .allowsHitTesting(page > 0)
                .accessibilityHidden(page == 0)
                .accessibilityLabel(L10n.back)
                .accessibilityIdentifier("introduction.back")
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.appTitle).font(.title3.weight(.bold)).foregroundStyle(Theme.gold)
                    Text(L10n.introductionPage(page + 1, total: pageCount))
                        .font(.caption).foregroundStyle(Theme.textBody)
                        .accessibilityIdentifier("introduction.page.\(page + 1)")
                }
                Spacer()

            }
            HStack(spacing: 7) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Button { go(to: index) } label: {
                        Capsule()
                            .fill(index == page ? Theme.gold : Theme.borderDefault)
                            .frame(height: 4)
                            .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(topic(for: index)), \(L10n.introductionPage(index + 1, total: pageCount))")
                    .accessibilityAddTraits(index == page ? .isSelected : [])
                    .accessibilityIdentifier("introduction.topic.\(index + 1)")
                }
            }

        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
    }

    private var footer: some View {
        // One stable row on every slide leaves more height for illustrations.
        HStack(spacing: 12) {
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

                Button { if isPatientMode { onContinue() } else { showSampleGate = true } } label: {
                    Label(isPatientMode ? L10n.patientIntroStart : L10n.introductionSampleAction, systemImage: isPatientMode ? "checkmark" : "person.2.crop.square.stack")
                }
                .buttonStyle(.pressableProminent)
                .opacity(isLastPage ? 1 : 0)
                .allowsHitTesting(isLastPage)
                .accessibilityHidden(!isLastPage)
                .accessibilityIdentifier("introduction.sample")
            }
            Button(L10n.introductionSkip, action: onContinue)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textBody)
                .frame(minWidth: 48, minHeight: 48)
                .accessibilityIdentifier("introduction.skip")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
        .frame(maxWidth: 540)
        .transaction { $0.animation = nil }
    }

    private func go(to newPage: Int) {
        guard (0..<pageCount).contains(newPage), newPage != page else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { page = newPage }
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 32, weight: .medium))
            .foregroundStyle(Theme.gold)
            .frame(width: 64, height: 64)
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
        VStack(spacing: 16) {
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
                .frame(height: 125)
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
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 240)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Theme.borderFaint, lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 24, y: 10)
    }
}

#Preview {
    AppIntroductionView(onTrySample: {}, onContinue: {})
        .appTextSize()
}
