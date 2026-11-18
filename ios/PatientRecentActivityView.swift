import SwiftUI

/// Clinical submissions, independent of notification read/seen state.
struct PatientRecentActivityView: View {
    let patient: Patient
    @Environment(NotificationStore.self) private var notifications
    @Environment(PatientStore.self) private var store
    @Environment(AuthManager.self) private var auth
    @Environment(DiaryOneStore.self) private var diaryOne
    @Environment(DiaryTwoStore.self) private var diaryTwo
    @Environment(DiaryThreeStore.self) private var diaryThree
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var failed = false
    @State private var dismissed = false
    @State private var activityDismissals = RecentActivityDismissals.shared
    @State private var showAll = false
    @State private var collapsed = false
    @State private var visitIdentity: String?
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
    private var visibleSubmissions: [Submission] { collapsed ? [] : Array(submissions.prefix(showAll ? count : 2)) }

    private func unread(_ submission: Submission) -> Bool {
        let resource: String; let id: UUID
        switch submission {
        case .questionnaire: return false
        case .diaryOne(let entry): resource = "diary_one_entry"; id = entry.id
        case .diaryTwo(let entry): resource = "diary_two_entry"; id = entry.id
        case .diaryThree(let entry): resource = "diary_three_entry"; id = entry.id
        }
        guard let key = DiaryNotificationKey(patientID: patient.id.queryValue, resourceType: resource, entryID: id.uuidString) else { return false }
        return DiaryNotificationReadState.unreadKeys(notifications.notifications).contains(key)
    }

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
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Text(cutoff == nil ? L10n.recentPatientSubmissions : L10n.sinceLastSession)
                            .font(BrandTypography.headline).foregroundStyle(Theme.textBright)
                        if count > 0 {
                            Text("\(count)").font(BrandTypography.subheadline.bold()).foregroundStyle(Theme.textOnAccent)
                                .padding(7).background(Theme.accentFill, in: Circle())
                                .accessibilityLabel(L10n.recentSubmissionCount(count))
                        }
                        Spacer(minLength: 0)
                        if count > 0 {
                            Button { if collapsed { collapsed = false; showAll = true } else if !showAll && count > 2 { showAll = true } else { collapsed = true; showAll = false } } label: {
                                Image(systemName: collapsed || (!showAll && count > 2) ? "chevron.down" : "chevron.up").frame(width: 44, height: 44)
                            }
                            .accessibilityLabel(collapsed || (!showAll && count > 2) ? L10n.recentShowAll(count) : L10n.recentShowLess)
                            .accessibilityIdentifier("patient.recent.showAll")
                        }
                        Menu {
                            Button(L10n.closeAction) {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                                    activityDismissals.dismiss(submissions.map(\.id), owner: activityOwner, patientID: patient.id)
                                    dismissed = true
                                }
                            }.accessibilityIdentifier("patient.recent.dismiss")
                        } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                        .accessibilityLabel(L10n.recentPatientSubmissions)
                    }
                    .accessibilityHint(cutoff.map { L10n.recentSinceDate(L10n.hebrewDate($0)) } ?? "")
                    ForEach(visibleSubmissions) { submission in
                        Divider().overlay(Theme.borderDefault)
                        NavigationLink { destination(submission) } label: {
                            HStack {
                                if unread(submission) {
                                    Circle().fill(Theme.gold).frame(width: 7, height: 7)
                                        .accessibilityLabel(L10n.notificationUnreadAccessibility)
                                        .accessibilityIdentifier("diary.unread.\(submission.id)")
                                }
                                row(submission.title, icon: submission.icon, date: submission.date)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.forward").font(BrandTypography.caption).foregroundStyle(Theme.textBody)
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                    if failed {
                        Text(L10n.recentRefreshFailed).font(BrandTypography.footnote).foregroundStyle(Theme.error)
                        Button(L10n.retry) { revision += 1 }.frame(minHeight: 44)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.borderFaint, lineWidth: 1) }
            }
        }
        .task(id: "\(auth.currentUserId ?? "")/\(patient.id.queryValue)") {
            let identity = "\(auth.currentUserId ?? "")/\(patient.id.queryValue)"
            guard visitIdentity != identity, !store.isDemoMode, let owner = auth.currentUserId,
                  EntitlementState.shared.role == .therapist else { return }
            visitIdentity = identity
            collapsed = FeatureDiscovery.shared.beginPatientVisit(account: owner, patient: patient.id)
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
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(PatientAvatarColor.background(for: patient.id))
                .frame(width: 24).accessibilityHidden(true)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(spacing: 8))
            layout {
                Text(title).font(BrandTypography.subheadline.weight(.semibold)).foregroundStyle(Theme.textBright)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                Text(L10n.hebrewDateTime(date)).font(BrandTypography.caption).foregroundStyle(.secondary)
            }
        }.frame(minHeight: 44)
    }
}
