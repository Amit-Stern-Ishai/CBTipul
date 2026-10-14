import SwiftUI

/// Clinical submissions, independent of notification read/seen state.
struct PatientRecentActivityView: View {
    let patient: Patient
    @Environment(PatientStore.self) private var store
    @Environment(AuthManager.self) private var auth
    @Environment(DiaryOneStore.self) private var diaryOne
    @Environment(DiaryTwoStore.self) private var diaryTwo
    @Environment(DiaryThreeStore.self) private var diaryThree
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var failed = false
    @State private var dismissed = false
    @State private var activityDismissals = RecentActivityDismissals.shared
    @State private var showAll = false
    @State private var revision = 0

    private var cutoff: Date? { patient.sessions.map(\.date).filter { $0 <= .now }.max() }
    private func recent(_ date: Date) -> Bool { cutoff.map { date > $0 } ?? true }
    private var one: [DiaryOneEntry] { diaryOne.entries(for: patient.id).filter { $0.createdBy == .patient && recent($0.createdAt) } }
    private var two: [DiaryTwoEntry] { diaryTwo.entries(for: patient.id).filter { $0.createdBy == .patient && recent($0.createdAt) } }
    private var three: [DiaryThreeEntry] { diaryThree.entries(for: patient.id).filter { $0.createdBy == .patient && recent($0.createdAt) } }
    private var questionnaires: [CompletedQuestionnaire] { (store.cachedQuestionnaires(for: patient) ?? []).filter { $0.isPatientSubmitted && recent($0.answeredDate) } }
    /// Keep heterogeneous submissions together in time order, with stable route identities.
    private enum Submission: Identifiable {
        case questionnaire(CompletedQuestionnaire)
        case diaryOne(DiaryOneEntry)
        case diaryTwo(DiaryTwoEntry)
        case diaryThree(DiaryThreeEntry)

        var id: String {
            switch self {
            case .questionnaire(let entry): "questionnaire-\(entry.id.queryValue)"
            case .diaryOne(let entry): "diary-one-\(entry.id.uuidString)"
            case .diaryTwo(let entry): "diary-two-\(entry.id.uuidString)"
            case .diaryThree(let entry): "diary-three-\(entry.id.uuidString)"
            }
        }
        var date: Date {
            switch self {
            case .questionnaire(let entry): entry.answeredDate
            case .diaryOne(let entry): entry.createdAt
            case .diaryTwo(let entry): entry.createdAt
            case .diaryThree(let entry): entry.createdAt
            }
        }
        var title: String {
            switch self {
            case .questionnaire: L10n.questionnaireItemTitle
            case .diaryOne: L10n.diaryOneTitle
            case .diaryTwo: L10n.diaryTwoTitle
            case .diaryThree: L10n.diaryThreeTitle
            }
        }
        var icon: String {
            if case .questionnaire = self { return "list.clipboard" }
            return "book.closed"
        }
    }
    private var allSubmissions: [Submission] {
        (questionnaires.map(Submission.questionnaire) + one.map(Submission.diaryOne)
            + two.map(Submission.diaryTwo) + three.map(Submission.diaryThree)).sorted {
                $0.date == $1.date ? $0.id < $1.id : $0.date > $1.date
            }
    }
    private var activityOwner: String? { store.isDemoMode ? "local-demo" : auth.currentUserId }
    private var submissions: [Submission] {
        allSubmissions.filter { !activityDismissals.contains($0.id, owner: activityOwner, patientID: patient.id) }
    }
    private var count: Int { submissions.count }
    private var visibleSubmissions: [Submission] { Array(submissions.prefix(showAll ? count : 3)) }

    @ViewBuilder
    private func destination(_ submission: Submission) -> some View {
        switch submission {
        case .questionnaire(let record): CompletedQuestionnaireView(record: record, patient: patient)
        case .diaryOne(let entry): PatientDiaryOneDetailView(entry: entry, therapistViewing: true)
        case .diaryTwo(let entry): DiaryTwoEntryDetailView(patient: patient, entryID: entry.id)
        case .diaryThree(let entry): DiaryThreeEntryDetailView(patient: patient, entryID: entry.id)
        }
    }

    var body: some View {
        Group {
            if count > 0 || (!dismissed && failed) {
                Section {
                    if let cutoff { Text(L10n.recentSinceDate(L10n.hebrewDate(cutoff))).font(.caption).foregroundStyle(.secondary) }
                    if count > 0 {
                        Text(L10n.recentSubmissionCount(count))
                            .font(.headline).foregroundStyle(Theme.textBright)
                    }
                    ForEach(visibleSubmissions) { submission in
                        NavigationLink { destination(submission) } label: {
                            row(submission.title, icon: submission.icon, date: submission.date)
                        }
                    }
                    if count > 3 {
                        Button(showAll ? L10n.recentShowLess : L10n.recentShowAll(count)) {
                            showAll.toggle()
                        }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("patient.recent.showAll")
                    }
                    if failed {
                        Text(L10n.recentRefreshFailed).font(.footnote).foregroundStyle(Theme.error)
                        Button(L10n.retry) { revision += 1 }
                    }
                } header: {
                    HStack {
                        Text(cutoff == nil ? L10n.recentPatientSubmissions : L10n.sinceLastSession)
                        Spacer(minLength: 8)
                        Button {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                                activityDismissals.dismiss(submissions.map(\.id), owner: activityOwner, patientID: patient.id)
                                dismissed = true
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.semibold))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.closeAction)
                        .accessibilityIdentifier("patient.recent.dismiss")
                    }
                }
                .listRowBackground(Theme.surface)
            }
        }
        .task(id: revision) {
            guard !store.isDemoMode else { return }
            failed = false
            do { _ = try await store.loadQuestionnaires(for: patient) } catch { failed = true }
            do { _ = try await diaryOne.loadEntries(for: patient.id) } catch { failed = true }
            do { _ = try await diaryTwo.loadEntries(for: patient.id) } catch { failed = true }
            do { _ = try await diaryThree.loadEntries(for: patient.id) } catch { failed = true }
        }
    }

    private func row(_ title: String, icon: String, date: Date) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Theme.gold).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(L10n.hebrewDateTime(date)).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
