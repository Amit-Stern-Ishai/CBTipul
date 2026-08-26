import SwiftUI
import Charts

/// A patient's saved questionnaires, shown either as a list (newest first,
/// tap to view read-only) or as score-over-time graphs for GAD-7 and PHQ-9.
struct PatientQuestionnairesView: View {
    let patient: Patient

    @Environment(PatientStore.self) private var store

    private enum Mode: Hashable {
        case list
        case graphs
    }

    @State private var mode: Mode = .list
    @State private var questionnaires: [CompletedQuestionnaire]
    @State private var isLoading = false
    @State private var loadError: String?
    /// Graphs are shown one beat after switching to them, so the charts'
    /// expensive first layout doesn't happen mid-transition and jitter.
    @State private var isPreparingGraphs = true

    /// `previewQuestionnaires` seeds the list so previews have data to show;
    /// the app always starts empty and loads from the cache/server.
    init(patient: Patient, previewQuestionnaires: [CompletedQuestionnaire] = []) {
        self.patient = patient
        _questionnaires = State(initialValue: previewQuestionnaires)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(L10n.modePickerTitle, selection: $mode) {
                Text(L10n.listModeTitle).tag(Mode.list)
                Text(L10n.graphsModeTitle).tag(Mode.graphs)
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.25), value: isLoading)
                .animation(.easeInOut(duration: 0.25), value: mode)
                .animation(.easeInOut(duration: 0.25), value: isPreparingGraphs)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(L10n.questionnairesTitle)
        .navigationSubtitle(patient.displayName)
        .task(id: mode) {
            guard mode == .graphs else { return }
            isPreparingGraphs = true
            try? await Task.sleep(for: .milliseconds(300))
            isPreparingGraphs = false
        }
        .task {
            // Show the cache instantly, then refresh from the server.
            if let cached = store.cachedQuestionnaires(for: patient) {
                questionnaires = cached
            }
            await load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && questionnaires.isEmpty {
            ProgressView()
        } else if let loadError, questionnaires.isEmpty {
            ContentUnavailableView {
                Label(L10n.loadErrorTitle, systemImage: "exclamationmark.triangle")
            } description: {
                Text(loadError)
            } actions: {
                Button(L10n.retryAction) {
                    Task { await load() }
                }
                .buttonStyle(.borderedProminent)
            }
        } else if questionnaires.isEmpty {
            ContentUnavailableView {
                Label(L10n.noQuestionnairesMessage, systemImage: "list.clipboard")
            }
        } else {
            switch mode {
            case .list:
                questionnaireList
            case .graphs:
                if isPreparingGraphs {
                    ProgressView()
                } else {
                    graphs
                }
            }
        }
    }

    /// The most recent questionnaire answered before the given one.
    private func previousQuestionnaire(before record: CompletedQuestionnaire) -> CompletedQuestionnaire? {
        questionnaires.first { $0.id != record.id && $0.answeredDate < record.answeredDate }
    }

    private var questionnaireList: some View {
        List(questionnaires) { record in
            NavigationLink {
                CompletedQuestionnaireView(
                    record: record,
                    patientName: patient.displayName,
                    previous: previousQuestionnaire(before: record)
                )
            } label: {
                questionnaireRow(record)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable { await load() }
    }

    /// A row's date plus both scores as severity-tinted capsules, each with
    /// an arrow showing the change since the previous questionnaire
    /// (up = worse = red, down = better = green).
    private func questionnaireRow(_ record: CompletedQuestionnaire) -> some View {
        let previous = previousQuestionnaire(before: record)?.questionnaire
        return VStack(alignment: .leading, spacing: 8) {
            Text(record.answeredDate, style: .date)
                .font(.headline)
            HStack(spacing: 8) {
                ScoreCapsule(
                    text: L10n.scoreBadge(name: L10n.gad7ShortName, score: record.questionnaire.gad7Score),
                    color: record.questionnaire.gad7Severity.color,
                    delta: previous.map { record.questionnaire.gad7Score - $0.gad7Score }
                )
                ScoreCapsule(
                    text: L10n.scoreBadge(name: L10n.phq9ShortName, score: record.questionnaire.phq9Score),
                    color: record.questionnaire.phq9Severity.color,
                    delta: previous.map { record.questionnaire.phq9Score - $0.phq9Score }
                )
            }
        }
        .padding(.vertical, 4)
    }

    private var graphs: some View {
        ScrollView {
            VStack(spacing: 16) {
                QuestionnaireChart(
                    name: L10n.gad7ShortName,
                    subtitle: L10n.gad7Title,
                    entries: chartEntries(for: \.gad7Answers),
                    questionShortNames: L10n.gad7QuestionShortNames,
                    tint: .indigo,
                    totalScoreColor: { GAD7Severity(score: $0).color }
                )
                QuestionnaireChart(
                    name: L10n.phq9ShortName,
                    subtitle: L10n.phq9Title,
                    entries: chartEntries(for: \.phq9Answers),
                    questionShortNames: L10n.phq9QuestionShortNames,
                    tint: .teal,
                    totalScoreColor: { PHQ9Severity(score: $0).color }
                )
            }
            .padding()
        }
    }

    /// Chart entries oldest-first so the time axis reads left to right.
    private func chartEntries(for answers: KeyPath<CombinedMoodQuestionnaire, [Int?]>) -> [QuestionnaireChart.Entry] {
        questionnaires
            .sorted { $0.answeredDate < $1.answeredDate }
            .map { QuestionnaireChart.Entry(date: $0.answeredDate, answers: $0.questionnaire[keyPath: answers]) }
    }

    private func load() async {
        isLoading = true
        loadError = nil
        do {
            questionnaires = try await store.loadQuestionnaires(for: patient)
        } catch is CancellationError {
            // View went away mid-load; nothing to show.
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}

/// A small severity-tinted score badge, e.g. "GAD-7: 12" on a soft
/// green/yellow/orange/red background, with an optional trend arrow.
private struct ScoreCapsule: View {
    let text: String
    let color: Color
    var delta: Int? = nil

    var body: some View {
        HStack(spacing: 3) {
            Text(text)
                .foregroundStyle(color)
            if let delta, delta != 0 {
                Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(delta > 0 ? .red : .green)
            }
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
    }
}

/// A card with a line chart of one questionnaire's results over time, and a
/// picker to switch between the total score and each question's answer.
private struct QuestionnaireChart: View {
    struct Entry {
        let date: Date
        let answers: [Int?]
    }

    private enum Metric: Hashable {
        case total
        case question(Int)
    }

    let name: String
    let subtitle: String
    let entries: [Entry]
    /// Short per-question names, one per question, shown in the picker.
    let questionShortNames: [String]
    /// The chart's identity color, used for the header, line and area fill.
    let tint: Color
    /// Severity color for a total score, so points are color coded.
    let totalScoreColor: (Int) -> Color

    @State private var metric: Metric = .total

    /// Color code of a single answer value (0–3), mildest to worst.
    private static let answerColors: [Color] = [.green, .yellow, .orange, .red]

    private func pointColor(for value: Double) -> Color {
        switch metric {
        case .total:
            return totalScoreColor(Int(value))
        case .question:
            let index = min(max(Int(value), 0), Self.answerColors.count - 1)
            return Self.answerColors[index]
        }
    }

    private var points: [(date: Date, value: Double)] {
        entries.compactMap { entry in
            switch metric {
            case .total:
                let answered = entry.answers.compactMap { $0 }
                guard !answered.isEmpty else { return nil }
                return (entry.date, Double(answered.reduce(0, +)))
            case .question(let index):
                guard entry.answers.indices.contains(index), let value = entry.answers[index] else { return nil }
                return (entry.date, Double(value))
            }
        }
    }

    /// Y-axis range: the full score range for totals, 0–3 for one question.
    private var yDomain: ClosedRange<Int> {
        switch metric {
        case .total: return 0...(CombinedMoodQuestionnaire.answerValues.count - 1) * questionShortNames.count
        case .question: return 0...(CombinedMoodQuestionnaire.answerValues.count - 1)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(tint.gradient, in: RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 8) {
                        Text(name)
                            .font(.headline)
                        // The latest total, color coded, so the current level
                        // is readable without decoding the chart.
                        if metric == .total, let latest = points.last {
                            Text("\(Int(latest.value))")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(totalScoreColor(Int(latest.value)))
                        }
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Picker(L10n.metricPickerTitle, selection: $metric) {
                    Text(L10n.totalOptionLabel).tag(Metric.total)
                    ForEach(questionShortNames.indices, id: \.self) { index in
                        Text(questionShortNames[index]).tag(Metric.question(index))
                    }
                }
                .pickerStyle(.menu)
                .tint(tint)
            }

            Chart(Array(points.enumerated()), id: \.offset) { item in
                AreaMark(
                    x: .value(L10n.chartDateLabel, item.element.date),
                    y: .value(L10n.chartScoreLabel, item.element.value)
                )
                .foregroundStyle(
                    LinearGradient(colors: [tint.opacity(0.25), tint.opacity(0.02)],
                                   startPoint: .top, endPoint: .bottom)
                )
                LineMark(
                    x: .value(L10n.chartDateLabel, item.element.date),
                    y: .value(L10n.chartScoreLabel, item.element.value)
                )
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 2))
                PointMark(
                    x: .value(L10n.chartDateLabel, item.element.date),
                    y: .value(L10n.chartScoreLabel, item.element.value)
                )
                .foregroundStyle(pointColor(for: item.element.value))
            }
            .chartYScale(domain: yDomain)
            .frame(height: 220)
            // Time series keep the conventional left-to-right time axis
            // even though the app's layout is right-to-left.
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    let auth = AuthManager()

    func record(id: Int, daysAgo: Int, gad7: Int, phq9: Int) -> CompletedQuestionnaire {
        func answers(total: Int, count: Int) -> [Int?] {
            var remaining = total
            return (0..<count).map { _ in
                let value = min(3, remaining)
                remaining -= value
                return value
            }
        }
        var questionnaire = CombinedMoodQuestionnaire()
        questionnaire.gad7Answers = answers(total: gad7, count: L10n.gad7Questions.count)
        questionnaire.phq9Answers = answers(total: phq9, count: L10n.phq9Questions.count)
        return CompletedQuestionnaire(
            databaseID: .integer(id),
            sessionID: nil,
            answeredDate: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!,
            questionnaire: questionnaire
        )
    }

    return NavigationStack {
        PatientQuestionnairesView(
            patient: Patient(id: .integer(1), firstName: "Alex", lastName: "Rivera"),
            previewQuestionnaires: [
                record(id: 6, daysAgo: 2, gad7: 6, phq9: 9),
                record(id: 5, daysAgo: 9, gad7: 9, phq9: 8),
                record(id: 4, daysAgo: 16, gad7: 8, phq9: 13),
                record(id: 3, daysAgo: 23, gad7: 12, phq9: 16),
                record(id: 2, daysAgo: 30, gad7: 15, phq9: 15),
                record(id: 1, daysAgo: 37, gad7: 17, phq9: 21),
            ]
        )
    }
    .environment(PatientStore(client: auth.client))
    .appTextSize()
}
