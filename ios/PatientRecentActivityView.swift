import SwiftUI

/// Clinical submissions, independent of notification read/seen state.
struct PatientRecentActivityView: View {
    let patient: Patient
    @Environment(PatientStore.self) private var store
    @Environment(DiaryOneStore.self) private var diaryOne
    @Environment(DiaryTwoStore.self) private var diaryTwo
    @Environment(DiaryThreeStore.self) private var diaryThree
    @State private var failed = false
    @State private var dismissed = false
    @State private var expanded = false
    @State private var revision = 0

    private var cutoff: Date? { patient.sessions.map(\.date).filter { $0 <= .now }.max() }
    private func recent(_ date: Date) -> Bool { cutoff.map { date > $0 } ?? true }
    private var one: [DiaryOneEntry] { diaryOne.entries(for: patient.id).filter { $0.createdBy == .patient && recent($0.createdAt) } }
    private var two: [DiaryTwoEntry] { diaryTwo.entries(for: patient.id).filter { $0.createdBy == .patient && recent($0.createdAt) } }
    private var three: [DiaryThreeEntry] { diaryThree.entries(for: patient.id).filter { $0.createdBy == .patient && recent($0.createdAt) } }
    private var questionnaires: [CompletedQuestionnaire] { (store.cachedQuestionnaires(for: patient) ?? []).filter { $0.isPatientSubmitted && recent($0.answeredDate) } }
    private var count: Int { one.count + two.count + three.count + questionnaires.count }

    var body: some View {
        Group {
            if count > 0 && !dismissed {
                Section {
                    if let cutoff { Text(L10n.recentSinceDate(L10n.hebrewDate(cutoff))).font(.caption).foregroundStyle(.secondary) }
                    DisclosureGroup(L10n.recentSubmissionCount(count), isExpanded: $expanded) {
                        ForEach(questionnaires) { record in
                            NavigationLink {
                                CompletedQuestionnaireView(record: record, patient: patient)
                            } label: { row(L10n.questionnairesTitle, date: record.answeredDate) }
                        }
                        ForEach(one) { entry in
                            NavigationLink { PatientDiaryOneDetailView(entry: entry, therapistViewing: true) }
                            label: { row(L10n.diaryOneTitle, date: entry.createdAt) }
                        }
                        ForEach(two) { entry in
                            NavigationLink { DiaryTwoEntryDetailView(patient: patient, entryID: entry.id) }
                            label: { row(L10n.diaryTwoTitle, date: entry.createdAt) }
                        }
                        ForEach(three) { entry in
                            NavigationLink { DiaryThreeEntryDetailView(patient: patient, entryID: entry.id) }
                            label: { row(L10n.diaryThreeTitle, date: entry.createdAt) }
                        }
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
                            withAnimation(.easeInOut(duration: 0.2)) { dismissed = true }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.semibold))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.closeAction)
                    }
                }
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

    private func row(_ title: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            Text(date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
        }
    }
}
