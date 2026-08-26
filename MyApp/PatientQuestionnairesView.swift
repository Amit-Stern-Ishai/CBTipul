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
    /// Graphs are shown one beat after switching to them, so the charts'
    /// expensive first layout doesn't happen mid-transition and jitter.
    @State private var isPreparingGraphs = true

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
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.answeredDate, style: .date)
                        .font(.headline)
                    Text(L10n.gadPhqScores(gad7: record.questionnaire.gad7Score, phq9: record.questionnaire.phq9Score))
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
                    title: L10n.gad7Title,
                    entries: chartEntries(for: \.gad7Answers),
                    questionShortNames: L10n.gad7QuestionShortNames
                )
                QuestionnaireChart(
                    title: L10n.phq9Title,
                    entries: chartEntries(for: \.phq9Answers),
                    questionShortNames: L10n.phq9QuestionShortNames
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
    /// Short per-question names, one per question, shown in the picker.
    let questionShortNames: [String]

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
        case .total: return 0...(CombinedMoodQuestionnaire.answerValues.count - 1) * questionShortNames.count
        case .question: return 0...(CombinedMoodQuestionnaire.answerValues.count - 1)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Picker(L10n.metricPickerTitle, selection: $metric) {
                    Text(L10n.totalOptionLabel).tag(Metric.total)
                    ForEach(questionShortNames.indices, id: \.self) { index in
                        Text(questionShortNames[index]).tag(Metric.question(index))
                    }
                }
                .pickerStyle(.menu)
            }

            Chart(Array(points.enumerated()), id: \.offset) { item in
                LineMark(
                    x: .value(L10n.chartDateLabel, item.element.date),
                    y: .value(L10n.chartScoreLabel, item.element.value)
                )
                PointMark(
                    x: .value(L10n.chartDateLabel, item.element.date),
                    y: .value(L10n.chartScoreLabel, item.element.value)
                )
            }
            .chartYScale(domain: yDomain)
            .frame(height: 220)
            // Time series keep the conventional left-to-right time axis
            // even though the app's layout is right-to-left.
            .environment(\.layoutDirection, .leftToRight)
        }
    }
}

#Preview {
    let auth = AuthManager()
    NavigationStack {
        PatientQuestionnairesView(patient: Patient(id: .integer(1), firstName: "Alex", lastName: "Rivera"))
    }
    .environment(PatientStore(client: auth.client))
}
