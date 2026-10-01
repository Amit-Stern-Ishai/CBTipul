import SwiftUI

struct QuestionnaireTrendsView: View {
    let patient: Patient
    let records: [CompletedQuestionnaire]
    @State private var selectedTrend: QuestionnaireTrend = .improving
    @State private var selectedQuestionID: String?
    @State private var showingTrends = false
    @State private var showingQuestions = false

    private struct Question: Identifiable {
        let id: String
        let title: String
        let scale: String
        let number: Int
        let observations: [(date: Date, answer: Int?)]
        var trend: QuestionnaireTrend { .classify(observations.map(\.answer)) }
    }

    private var chronological: [CompletedQuestionnaire] { records.sorted { $0.answeredDate < $1.answeredDate } }
    private var questions: [Question] {
        func make(_ names: [String], scale: String, answers: KeyPath<CombinedMoodQuestionnaire, [Int?]>) -> [Question] {
            names.indices.map { index in
                Question(id: "\(scale)-\(index)", title: names[index], scale: scale, number: index + 1,
                         observations: chronological.map { record in
                    let values = record.questionnaire[keyPath: answers]
                    let value = values.indices.contains(index) ? values[index] : nil
                    return (record.answeredDate, value.flatMap { (0...3).contains($0) ? $0 : nil })
                })
            }
        }
        return make(L10n.gad7Questions, scale: L10n.gad7ShortName, answers: \.gad7Answers)
            + make(L10n.phq9Questions, scale: L10n.phq9ShortName, answers: \.phq9Answers)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.questionTrendsHelp).font(.subheadline)
                if let first = chronological.first, let last = chronological.last {
                    Text(L10n.questionTrendsCount(records.count) + " · " + L10n.hebrewDate(first.answeredDate)
                         + " – " + L10n.hebrewDate(last.answeredDate))
                        .font(.caption).foregroundStyle(.secondary)
                }
                let matches = questions.filter { $0.trend == selectedTrend }
                let selectedQuestion = matches.first { $0.id == selectedQuestionID } ?? matches.first
                Button { showingTrends = true } label: {
                    pickerLabel(L10n.questionTrendsTrendPicker) {
                        HStack(spacing: 12) {
                            Text(selectedTrend.title).font(.body.weight(.medium))
                            Spacer(minLength: 0)
                            countBadge(matches.count)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("trends.trendPicker")
                .onChange(of: selectedTrend) { _, _ in selectedQuestionID = nil }
                Text(selectedTrend.explanation).font(.caption).foregroundStyle(.secondary)
                Button { showingQuestions = true } label: {
                    pickerLabel(L10n.questionTrendsQuestionPicker) {
                        if let question = selectedQuestion {
                            questionLabel(question)
                        } else {
                            Text(L10n.questionTrendsNoQuestions)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(matches.isEmpty)
                .accessibilityIdentifier("trends.questionPicker")
                if let question = selectedQuestion {
                    QuestionnaireChart(
                        name: L10n.questionTrendsGraphTitle,
                        subtitle: question.title,
                        entries: question.observations.map { .init(date: $0.date, answers: [$0.answer]) },
                        questionShortNames: [question.title],
                        tint: Theme.gold,
                        totalScoreColor: { _ in Theme.gold },
                        chartHeight: 220,
                        fixedQuestionIndex: 0
                    )
                    Text(L10n.questionnaireGraphHelp).font(.caption).foregroundStyle(.secondary)
                }
                Text(L10n.questionTrendsMissing).font(.footnote).foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .themedScreen()
        .demoModeChrome()
        .navigationTitleWithSubtitle(L10n.questionTrendsTitle, subtitle: patient.displayName, patient: patient)
        .sheet(isPresented: $showingTrends) {
            NavigationStack {
                List {
                    ForEach(QuestionnaireTrend.allCases, id: \.self) { trend in
                        Button {
                            selectedTrend = trend
                            showingTrends = false
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: trend.icon).foregroundStyle(Theme.gold).frame(width: 24)
                                Text(trend.title).foregroundStyle(Theme.textBright)
                                Spacer(minLength: 8)
                                countBadge(questions.filter { $0.trend == trend }.count)
                                selectionMark(trend == selectedTrend)
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .listRowBackground(Theme.surface)
                    }
                }
                .scrollContentBackground(.hidden)
                .themedScreen()
                .navigationTitle(L10n.questionTrendsTrendPicker)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.done) { showingTrends = false } } }
            }
            .environment(\.layoutDirection, .rightToLeft)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingQuestions) {
            let matches = questions.filter { $0.trend == selectedTrend }
            NavigationStack {
                List(matches) { question in
                    Button {
                        selectedQuestionID = question.id
                        showingQuestions = false
                    } label: {
                        HStack(alignment: .top, spacing: 16) {
                            questionLabel(question)
                            selectionMark(question.id == (selectedQuestionID ?? matches.first?.id))
                                .padding(.top, 2)
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .listRowBackground(Theme.surface)
                }
                .scrollContentBackground(.hidden)
                .themedScreen()
                .navigationTitle(L10n.questionTrendsQuestionPicker)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.done) { showingQuestions = false } } }
            }
            .environment(\.layoutDirection, .rightToLeft)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private func countBadge(_ count: Int) -> some View {
        Text(L10n.questionTrendsMatchingCount(count))
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(Theme.gold)
            .frame(minWidth: 28)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Theme.gold.opacity(0.12), in: Capsule())
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel(L10n.questionTrendsMatchingCount(count))
    }

    private func selectionMark(_ selected: Bool) -> some View {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(selected ? Theme.gold : Theme.textFaint)
            .font(.title3)
            .accessibilityHidden(true)
    }

    private func questionLabel(_ question: Question) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(question.title)
                .font(.body.weight(.medium)).foregroundStyle(Theme.textBright)
                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                Text(L10n.questionTrendsQuestionPicker)
                Text(question.number, format: .number).monospacedDigit()
                Spacer(minLength: 12)
                Text(question.scale)
                    .font(.caption.weight(.semibold).monospaced())
                    .environment(\.layoutDirection, .leftToRight)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Theme.gold.opacity(0.08), in: Capsule())
            }
            .font(.caption).foregroundStyle(Theme.textBody)
        }
    }

    private func pickerLabel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 16) {
                content().frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.down").font(.footnote.weight(.semibold)).foregroundStyle(Theme.gold)
            }
            .foregroundStyle(Theme.textBright)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .themedCard()
    }

}

private extension QuestionnaireTrend {
    var title: String {
        switch self {
        case .improving: L10n.questionTrendImproving
        case .worsening: L10n.questionTrendWorsening
        case .unchanged: L10n.questionTrendUnchanged
        case .betterThanBeginning: L10n.questionTrendBetter
        case .worseThanBeginning: L10n.questionTrendWorse
        case .insufficient: L10n.questionTrendInsufficient
        }
    }
    var explanation: String {
        switch self {
        case .improving: L10n.questionTrendImprovingHelp
        case .worsening: L10n.questionTrendWorseningHelp
        case .unchanged: L10n.questionTrendUnchangedHelp
        case .betterThanBeginning: L10n.questionTrendBetterHelp
        case .worseThanBeginning: L10n.questionTrendWorseHelp
        case .insufficient: L10n.questionTrendInsufficientHelp
        }
    }
    var icon: String {
        switch self {
        case .improving: "arrow.down.right"
        case .worsening: "arrow.up.right"
        case .unchanged: "equal"
        case .betterThanBeginning: "arrow.down.right"
        case .worseThanBeginning: "arrow.up.right"
        case .insufficient: "questionmark.circle"
        }
    }
}
