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
    @State private var questionnaires: [CompletedQuestionnaire] = []
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 0) {
            Label(patient.displayName, systemImage: "person")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.horizontal, .top])

            Picker(QuestionnaireText.modePickerTitle, selection: $mode) {
                Text(QuestionnaireText.listModeTitle).tag(Mode.list)
                Text(QuestionnaireText.graphsModeTitle).tag(Mode.graphs)
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(QuestionnaireText.questionnairesTitle)
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
                Label(QuestionnaireText.loadErrorTitle, systemImage: "exclamationmark.triangle")
            } description: {
                Text(loadError)
            } actions: {
                Button(QuestionnaireText.retryAction) {
                    Task { await load() }
                }
                .buttonStyle(.borderedProminent)
            }
        } else if questionnaires.isEmpty {
            ContentUnavailableView {
                Label(QuestionnaireText.noQuestionnairesMessage, systemImage: "list.clipboard")
            }
        } else {
            switch mode {
            case .list: questionnaireList
            case .graphs: graphs
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.answeredDate, style: .date)
                        .font(.headline)
                    Text("\(QuestionnaireText.gad7ShortName): \(record.questionnaire.gad7Score) · \(QuestionnaireText.phq9ShortName): \(record.questionnaire.phq9Score)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .refreshable { await load() }
    }

    private var graphs: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                QuestionnaireChart(
                    title: QuestionnaireText.gad7Title,
                    entries: chartEntries(for: \.gad7Answers),
                    questionCount: QuestionnaireText.gad7Questions.count
                )
                QuestionnaireChart(
                    title: QuestionnaireText.phq9Title,
                    entries: chartEntries(for: \.phq9Answers),
                    questionCount: QuestionnaireText.phq9Questions.count
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

/// A line chart of one questionnaire's results over time, with a picker to
/// switch between the total score and each individual question's answer.
private struct QuestionnaireChart: View {
    struct Entry {
        let date: Date
        let answers: [Int?]
    }

    private enum Metric: Hashable {
        case total
        case question(Int)
    }

    let title: String
    let entries: [Entry]
    let questionCount: Int

    @State private var metric: Metric = .total

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
        case .total: return 0...(CombinedMoodQuestionnaire.answerValues.count - 1) * questionCount
        case .question: return 0...(CombinedMoodQuestionnaire.answerValues.count - 1)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Picker(QuestionnaireText.metricPickerTitle, selection: $metric) {
                    Text(QuestionnaireText.totalOptionLabel).tag(Metric.total)
                    ForEach(0..<questionCount, id: \.self) { index in
                        Text(QuestionnaireText.questionOptionLabel(index + 1)).tag(Metric.question(index))
                    }
                }
                .pickerStyle(.menu)
            }

            Chart(Array(points.enumerated()), id: \.offset) { item in
                LineMark(
                    x: .value("Date", item.element.date),
                    y: .value("Score", item.element.value)
                )
                PointMark(
                    x: .value("Date", item.element.date),
                    y: .value("Score", item.element.value)
                )
            }
            .chartYScale(domain: yDomain)
            .frame(height: 220)
        }
    }
}

#Preview {
    let auth = AuthManager()
    NavigationStack {
        PatientQuestionnairesView(patient: Patient(firstName: "Alex", lastName: "Rivera"))
    }
    .environment(PatientStore(client: auth.client))
}
