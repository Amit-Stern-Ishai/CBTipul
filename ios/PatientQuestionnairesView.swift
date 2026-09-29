import SwiftUI
import Charts

/// A notification result owns its loading state independently of the history screen behind it.
struct NotificationQuestionnaireView: View {
    let patient: Patient
    let questionnaireID: DatabaseID
    @Environment(PatientStore.self) private var store
    @State private var isLoading = true
    @State private var loadError: String?

    private var records: [CompletedQuestionnaire] {
        store.cachedQuestionnaires(for: patient) ?? []
    }

    var body: some View {
        Group {
            if let record = records.first(where: { $0.databaseID.isSameIdentity(as: questionnaireID) }) {
                CompletedQuestionnaireView(
                    record: record,
                    patient: patient,
                    previous: records.filter { $0.answeredDate < record.answeredDate }
                        .max(by: { $0.answeredDate < $1.answeredDate }),
                    accent: PatientAvatarColor.background(for: patient.id)
                )
            } else if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .themedScreen()
            } else if let loadError {
                ContentUnavailableView {
                    Label(L10n.loadErrorTitle, systemImage: "exclamationmark.triangle")
                } description: {
                    Text(loadError)
                } actions: {
                    Button(L10n.retry) { Task { await load() } }
                }
                .themedScreen()
            } else {
                ContentUnavailableView {
                    Label(L10n.notificationTargetUnavailable, systemImage: "doc.questionmark")
                }
                .themedScreen()
            }
        }
        .task(id: questionnaireID) { await load() }
    }

    private func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            _ = try await store.loadQuestionnaires(for: patient)
        } catch is CancellationError {
            return
        } catch {
            loadError = error.localizedDescription
        }
    }
}

/// Separate history and graph destinations sharing the same questionnaire data.
/// The destination is fixed when opened; there is no in-screen mode switch.
struct PatientQuestionnairesView: View {
    let patient: Patient

    @Environment(PatientStore.self) private var store

    @State private var questionnaires: [CompletedQuestionnaire]
    @State private var isLoading = false
    @State private var loadError: String?
    /// Graphs are shown one beat after opening, so the charts'
    /// expensive first layout doesn't happen mid-transition and jitter.
    @State private var isPreparingGraphs = true

    /// Selects the graph destination instead of questionnaire history.
    private let startsOnGraphs: Bool

    /// `previewQuestionnaires` seeds the list so previews have data to show;
    /// the app always starts empty and loads from the cache/server.
    init(
        patient: Patient,
        previewQuestionnaires: [CompletedQuestionnaire] = [],
        startsOnGraphs: Bool = false
    ) {
        self.patient = patient
        self.startsOnGraphs = startsOnGraphs
        _questionnaires = State(initialValue: previewQuestionnaires)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let loadError, !questionnaires.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.questionnaireRefreshFailed)
                        .font(.subheadline.weight(.semibold))
                    Text(loadError)
                        .font(.footnote)
                    Button(L10n.retry) { Task { await load() } }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .subtleAnimation(value: isLoading)
                .subtleAnimation(value: isPreparingGraphs)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !startsOnGraphs {
                addQuestionnaireCTA
            }
        }
        .patientAtmosphere(patientColor)
        .background(Theme.base.ignoresSafeArea())
        .demoModeChrome()
        .navigationTitleWithSubtitle(
            startsOnGraphs ? L10n.graphsAndTrendsTitle : L10n.questionnaireHistoryTitle,
            subtitle: patient.displayName
        )
        .onAppear {
            if let cached = store.cachedQuestionnaires(for: patient) {
                questionnaires = cached
            }
        }
        .task {
            guard startsOnGraphs else { return }
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
                Label(startsOnGraphs ? L10n.emptyQuestionnaireGraphsTitle : L10n.emptyQuestionnairesTitle,
                      systemImage: startsOnGraphs ? "chart.xyaxis.line" : "list.clipboard")
            } description: {
                Text(startsOnGraphs ? L10n.emptyQuestionnaireGraphsBody : L10n.emptyQuestionnairesBody)
            }
        } else if startsOnGraphs {
            if isPreparingGraphs {
                ProgressView()
            } else {
                graphs
            }
        } else {
            questionnaireList
        }
    }

    /// The most recent questionnaire answered before the given one.
    private func previousQuestionnaire(before record: CompletedQuestionnaire) -> CompletedQuestionnaire? {
        questionnaires.first { $0.id != record.id && $0.answeredDate < record.answeredDate }
    }

    /// This screen's group outlines, in the patient's identity color.
    private var patientColor: Color {
        PatientAvatarColor.background(for: patient.id)
    }

    private var addQuestionnaireCTA: some View {
        VStack(spacing: 8) {
            Text(L10n.questionnaireLocalEntryHelp)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            NavigationLink {
                PatientQuestionnaireEditorView(patient: patient)
            } label: {
                Label(L10n.fillQuestionnaireHereAction, systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Theme.base)
    }

    private var questionnaireList: some View {
        List(questionnaires) { record in
            NavigationLink {
                CompletedQuestionnaireView(
                    record: record,
                    patient: patient,
                    previous: previousQuestionnaire(before: record),
                    accent: patientColor
                )
            } label: {
                questionnaireRow(record)
            }
            .listRowBackground(groupBorderedRow(
                .at(questionnaires.firstIndex { $0.id == record.id } ?? 0,
                    of: questionnaires.count),
                accent: patientColor))
            .listRowSeparatorTint(Theme.borderFaint)
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
            Text(L10n.hebrewDate(record.answeredDate))
                .font(.headline)
            HStack(spacing: 8) {
                ScoreCapsule.gad7(record.questionnaire, previous: previous)
                ScoreCapsule.phq9(record.questionnaire, previous: previous)
            }
        }
        .padding(.vertical, 4)
    }

    private var graphs: some View {
        GeometryReader { geometry in
            // Keep both charts visible on ordinary phone sizes; allow scrolling for large text.
            let chartHeight = max(90, min(170, (geometry.size.height - 300) / 2))
            ScrollView {
                VStack(spacing: 12) {
                    QuestionnaireChart(
                        name: L10n.gad7GraphTitle,
                        subtitle: L10n.gad7Title,
                        entries: chartEntries(for: \.gad7Answers),
                        questionShortNames: L10n.gad7QuestionShortNames,
                        tint: Theme.accentFill,
                        totalScoreColor: { GAD7Severity(score: $0).color },
                        chartHeight: chartHeight
                    )
                    QuestionnaireChart(
                        name: L10n.phq9GraphTitle,
                        subtitle: L10n.phq9Title,
                        entries: chartEntries(for: \.phq9Answers),
                        questionShortNames: L10n.phq9QuestionShortNames,
                        tint: Theme.goldVivid,
                        totalScoreColor: { PHQ9Severity(score: $0).color },
                        chartHeight: chartHeight
                    )
                    NavigationLink {
                        QuestionnaireTrendsView(patient: patient, records: questionnaires)
                    } label: {
                        Label(L10n.questionTrendsTitle, systemImage: "list.bullet.clipboard")
                            .foregroundStyle(Theme.textOnAccent)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accentFill)
                    .controlSize(.large)
                    Text(L10n.questionnaireGraphHelp)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            }
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

/// A card with a line chart of one questionnaire's results over time, and a
/// picker to switch between the total score and each question's answer.
struct QuestionnaireChart: View {
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
    let chartHeight: CGFloat
    var fixedQuestionIndex: Int? = nil

    @State private var metric: Metric = .total
    private var displayedMetric: Metric { fixedQuestionIndex.map(Metric.question) ?? metric }

    /// Color code of a single answer value (0–3), mildest to worst.
    private static let answerColors: [Color] = [Theme.success, Theme.warning, Theme.warning, Theme.error]

    private func pointColor(for value: Double) -> Color {
        switch displayedMetric {
        case .total:
            return totalScoreColor(Int(value))
        case .question:
            let index = min(max(Int(value), 0), Self.answerColors.count - 1)
            return Self.answerColors[index]
        }
    }

    private var points: [(date: Date, value: Double)] {
        entries.compactMap { entry in
            switch displayedMetric {
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
        switch displayedMetric {
        case .total: return 0...(CombinedMoodQuestionnaire.answerValues.count - 1) * questionShortNames.count
        case .question: return 0...(CombinedMoodQuestionnaire.answerValues.count - 1)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(name).font(.headline).accessibilityLabel(subtitle)
                Spacer(minLength: 4)
                if fixedQuestionIndex == nil {
                Picker(L10n.metricPickerTitle, selection: $metric) {
                    Text(L10n.totalOptionLabel).tag(Metric.total)
                    ForEach(questionShortNames.indices, id: \.self) { index in
                        Text(questionShortNames[index]).tag(Metric.question(index))
                    }
                }
                .pickerStyle(.menu)
                .tint(tint)
                }
            }
            if let latest = points.last {
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.questionnaireGraphLatest(score: Int(latest.value), maximum: yDomain.upperBound))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(pointColor(for: latest.value))
                    Spacer(minLength: 4)
                    Text(points.count > 1
                         ? L10n.questionnaireGraphChangeShort(Int(latest.value - points[points.count - 2].value))
                         : L10n.questionnaireGraphSingleShort)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(L10n.questionnaireGraphLatest(score: Int(latest.value), maximum: yDomain.upperBound)
                    + ", " + L10n.hebrewDate(latest.date) + ", "
                    + (points.count > 1 ? L10n.questionnaireGraphChange(Int(latest.value - points[points.count - 2].value))
                       : L10n.questionnaireGraphSingleResponse))
            } else {
                Text(L10n.questionnaireGraphNoAnswers).font(.caption).foregroundStyle(.secondary)
            }

            if !points.isEmpty {
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
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.day().month(.twoDigits))
                }
            }
            .environment(\.locale, Locale(identifier: "he_IL"))
            .frame(height: chartHeight)
            // Time series keep the conventional left-to-right time axis
            // even though the app's layout is right-to-left.
            .environment(\.layoutDirection, .leftToRight)
            }
        }
        .padding(12)
        .themedCard()
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
