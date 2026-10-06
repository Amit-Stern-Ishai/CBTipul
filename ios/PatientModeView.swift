import SwiftUI
import OSLog

/// Patient Mode home: open assignments for the connected anonymous patient.
struct PatientModeView: View {
    @Environment(NotificationStore.self) private var inbox
    @Environment(AuthManager.self) private var auth
    @Environment(AppContextService.self) private var appContext
    @Environment(PatientModeMessageCoordinator.self) private var messageCoordinator
    @Environment(\.scenePhase) private var scenePhase

    private enum LoadState {
        case loading
        case loaded
        case failed
    }

    @State private var inboxFailed = false
    @State private var refreshingHome = false
    @State private var refreshHomeAgain = false
    @State private var unavailableItem = false
    @State private var openedAssignmentID: UUID?
    @State private var acknowledgedAssignments: Set<UUID> = []
    private var inboxItems: [PatientInboxItem] {
        guard let id = appContext.current?.patientId else { return [] }
        return PatientInboxItem.items(patientID: id, messages: messages, notifications: inbox.notifications)
    }
    @State private var resumableTypes: Set<PatientAssignmentType> = []
    @State private var lastQuestionnaireDate: Date?
    @State private var homeSnapshot = PatientHomeSnapshot()
    @State private var manualRefreshing = false
    @State private var refreshingTools = false
    @State private var refreshToolsAgain = false
    @State private var showingDiaryOneHistory = false
    @State private var loadState: LoadState = .loading
    @State private var assignments: [PatientAssignment] = []
    @State private var messages: [PatientMessage] = []
    @State private var isShowingMessages = false
    @State private var openedMessageID: UUID?
    @State private var isShowingQuestionnaireHub = false
    @State private var questionnaireFormRequest: UUID?
    @State private var didSubmitDiaryOne = false
    @AppStorage("patientIntroductionCompleted.v1") private var patientIntroductionCompleted = false
    @State private var showPatientIntroduction = false
    @State private var isShowingSettings = false
    @State private var isShowingDiaryOneEntry = false
    @State private var isShowingDiaryTwoHub = false
    @State private var isShowingDiaryThreeHub = false
    @State private var isShowingDiaryThreeEntry = false
    @State private var isDiaryThreeWizardVisible = false
    @State private var didSubmitDiaryThree = false
    @State private var isShowingDiaryTwoEntry = false
    @State private var didSubmitDiaryTwo = false

    private var openAssignments: [PatientAssignment] {
        assignments.filter { ($0.type == .diaryTwo || $0.type == .diaryThree) ? $0.cancelledAt == nil : $0.isOpen }
    }

    private var homeMessagePreviews: [PatientMessage] {
        PatientModeHomeMessages.previews(in: messages)
    }

    private var remainingUnreadCount: Int {
        PatientModeHomeMessages.remainingUnreadCount(in: messages)
    }

    var body: some View {
        NavigationStack {
            taskList
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .patientAtmosphere(Theme.gold)
            .background(Theme.base.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $isShowingQuestionnaireHub) {
                if let patientId = appContext.current?.patientId {
                    PatientQuestionnaireHubView(patientId: patientId, openFormRequest: $questionnaireFormRequest,
                        onAssignmentsChanged: { await loadAssignments() })
                        .task(id: openedAssignmentID) { await acknowledgeOpenedAssignment(type: .questionnaire) }
                }
            }
            .sheet(isPresented: $isShowingMessages) {
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 8) {
                            if inboxFailed || inbox.didFailLastLoad { Text(L10n.patientInboxRefreshFailed).foregroundStyle(Theme.error) }
                            if inboxItems.isEmpty { Text(L10n.patientInboxEmpty).foregroundStyle(Theme.textBody) }
                            ForEach(inboxItems) { item in
                                PatientInboxRow(item: item) { Task { await openInboxItem(item) } }.themedCard()
                            }
                        }.padding(20)
                    }
                    .background(Theme.base).navigationTitle(L10n.patientInboxTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.closeAction) { isShowingMessages = false } } }
                    .refreshable { await refreshPatientHome() }
                }.appTextSize()
            }
            .navigationDestination(item: $openedMessageID) { id in
                if let message = messages.first(where: { $0.id == id }) {
                    PatientMessageDetailView(message: message) { updated in
                        applyRead(updated)
                    }
                } else {
                    ContentUnavailableView {
                        Label(L10n.patientMessagesEmptyTitle, systemImage: "envelope")
                    }
                }
            }
            .navigationDestination(isPresented: $showingDiaryOneHistory) {
                PatientDiaryOneHubView(
                    isActive: openAssignments.contains { $0.type == .diaryOne },
                    onAssignmentsRefresh: { await loadAssignments() },
                    onEntrySubmitted: { didSubmitDiaryOne = true; await loadAssignments() }
                )
                .task(id: openedAssignmentID) { await acknowledgeOpenedAssignment(type: .diaryOne) }
            }
            .navigationDestination(isPresented: $isShowingDiaryOneEntry) {
                PatientDiaryOneEntryView(
                    onSubmitted: {
                        didSubmitDiaryOne = true
                        await loadAssignments()
                    },
                    onDiaryInactive: {
                        await loadAssignments()
                    }
                )
                .task(id: openedAssignmentID) { await acknowledgeOpenedAssignment(type: .diaryOne) }
            }
            .navigationDestination(isPresented: $isShowingDiaryTwoEntry) {
                PatientDiaryTwoEntryView(
                    onSubmitted: { didSubmitDiaryTwo = true; await loadAssignments() },
                    onDiaryInactive: {
                        assignments.removeAll { $0.type == .diaryTwo }
                        await loadAssignments()
                    }
                )
                .id(appContext.current?.patientId)
                .task(id: openedAssignmentID) { await acknowledgeOpenedAssignment(type: .diaryTwo) }
            }
            .navigationDestination(isPresented: $isShowingDiaryThreeEntry) {
                PatientDiaryThreeEntryView(
                    onSubmitted: { didSubmitDiaryThree = true; await loadAssignments() },
                    onDiaryInactive: {
                        assignments.removeAll { $0.type == .diaryThree }
                        await loadAssignments()
                    },
                    onVisibilityChange: { isDiaryThreeWizardVisible = $0 }
                )
                .id(appContext.current?.patientId)
                .task(id: openedAssignmentID) { await acknowledgeOpenedAssignment(type: .diaryThree) }
            }
            .navigationDestination(isPresented: $isShowingDiaryTwoHub) {
                PatientDiaryTwoHubView(
                    isActive: assignments.contains { $0.type == .diaryTwo && $0.cancelledAt == nil },
                    onAssignmentsRefresh: { await loadAssignments() },
                    onDiaryInactive: {
                        assignments.removeAll { $0.type == .diaryTwo }
                        await loadAssignments()
                    }
                )
                .id(appContext.current?.patientId)
                .task(id: openedAssignmentID) { await acknowledgeOpenedAssignment(type: .diaryTwo) }
            }
            .navigationDestination(isPresented: $isShowingDiaryThreeHub) {
                PatientDiaryThreeHubView(
                    isActive: assignments.contains { $0.type == .diaryThree && $0.cancelledAt == nil },
                    onAssignmentsRefresh: { await loadAssignments() },
                    onDiaryInactive: {
                        assignments.removeAll { $0.type == .diaryThree }
                        await loadAssignments()
                    },
                    onEntryVisibilityChange: { isDiaryThreeWizardVisible = $0 }
                )
                .id(appContext.current?.patientId)
                .task(id: openedAssignmentID) { await acknowledgeOpenedAssignment(type: .diaryThree) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Label(L10n.settingsTitle, systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await manualRefresh() }
                    } label: {
                        if manualRefreshing { ProgressView() }
                        else { Label(L10n.patientTasksRefreshAction, systemImage: "arrow.clockwise") }
                    }
                    .accessibilityLabel(L10n.patientTasksRefreshAction)
                    .disabled(loadState == .loading || manualRefreshing)
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                PatientSettingsView()
            }
            .fullScreenCover(isPresented: $showPatientIntroduction) {
                AppIntroductionView(isPatientMode: true, onTrySample: {}, onContinue: {
                    patientIntroductionCompleted = true
                    showPatientIntroduction = false
                })
                .appTextSize()
            }
            .task {
                showPatientIntroduction = !patientIntroductionCompleted
                messageCoordinator.markReady()
                inbox.isDemoInbox = false
                await applyPendingMessageRoute()
            }
            .onReceive(NotificationCenter.default.publisher(for: .patientModePushReceived)) { _ in
                Task { await refreshPatientHome() }
            }
            .onChange(of: messageCoordinator.pendingRevision) { _, _ in
                Task { await applyPendingMessageRoute() }
            }
            .task(id: scenePhase) {
                inbox.patientModeActive = scenePhase == .active
                guard scenePhase == .active else { return }
                await ApplicationIconBadge.sync(count: 0)
                await inbox.markInboxSeen(force: true)
                await refreshPatientHome()
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(60)) } catch { return }
                    await refreshPatientHome(lightweight: true)
                }
            }
            .alert(L10n.patientInboxUnavailable, isPresented: $unavailableItem) {
                Button(L10n.closeAction, role: .cancel) {}
            }
            .alert(L10n.patientDiaryOneSaved, isPresented: $didSubmitDiaryThree) {
                Button(L10n.patientViewEntries) { isShowingDiaryThreeHub = true }
                Button(L10n.patientReturnHome, role: .cancel) {
                    showingDiaryOneHistory = false
                    isShowingDiaryTwoHub = false
                    isShowingDiaryThreeHub = false
                }
            } message: { Text(L10n.patientSharedHelp) }
            .alert(L10n.patientDiaryOneSaved, isPresented: $didSubmitDiaryTwo) {
                Button(L10n.patientViewEntries) { isShowingDiaryTwoHub = true }
                Button(L10n.patientReturnHome, role: .cancel) {
                    showingDiaryOneHistory = false
                    isShowingDiaryTwoHub = false
                    isShowingDiaryThreeHub = false
                }
            } message: { Text(L10n.patientSharedHelp) }
            .alert(L10n.patientDiaryOneSaved, isPresented: $didSubmitDiaryOne) {
                Button(L10n.patientViewEntries) { showingDiaryOneHistory = true }
                Button(L10n.patientReturnHome, role: .cancel) {
                    showingDiaryOneHistory = false
                    isShowingDiaryTwoHub = false
                    isShowingDiaryThreeHub = false
                }
            } message: { Text(L10n.patientSharedHelp) }
        }
        .onDisappear {
            messageCoordinator.markNotReady()
            inbox.patientModeActive = false
        }
        .appTextSize()
    }

    private var loading: some View {
        ProgressView()
            .tint(Theme.gold)
            .controlSize(.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.patientTasksLoadError)
                .font(.body)
                .foregroundStyle(Theme.textBody)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { await refreshPatientHome() }
            } label: {
                Text(L10n.patientActivationRetryAction)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.pressableProminent)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var taskList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                messagesSection
                if loadState == .loading { ProgressView() }
                VStack(alignment: .leading, spacing: 8) {
                    Divider().overlay(Theme.borderFaint)
                        .padding(.bottom, 4)
                    Text(L10n.patientToolsSectionTitle)
                        .font(.headline).foregroundStyle(Theme.textBright)
                        .accessibilityAddTraits(.isHeader)
                    Text(L10n.patientAvailableHelp)
                        .font(.footnote).foregroundStyle(Theme.textBody)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
                .padding(.bottom, 2)
                if !EntitlementState.shared.canPatientWrite {
                    Text(L10n.entitlementPatientUnavailable).font(.footnote).foregroundStyle(Theme.textBody)
                }
                ForEach([PatientAssignmentType.questionnaire, .diaryOne, .diaryTwo, .diaryThree], id: \.self) { type in
                    let active = openAssignments.contains { $0.type == type } && (type != .diaryThree || PatientAssignmentType.diaryThreeSendingEnabled)
                    if homeSnapshot.isVisible(type, active: active) {
                        compactToolRow(type, active: active)
                    }
                }
                if openAssignments.isEmpty && ![PatientAssignmentType.questionnaire, .diaryOne, .diaryTwo, .diaryThree].contains(where: { homeSnapshot.hasHistory($0) }) {
                    emptyState
                }
                if case .failed = loadState {
                    Text(L10n.patientTasksLoadError).font(.footnote).foregroundStyle(Theme.error)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .navigationTitle(L10n.appTitle)
        .onAppear { refreshDrafts() }
        .refreshable { await manualRefresh() }
    }

    private func lastSubmission(_ type: PatientAssignmentType) -> Date? {
        switch type {
        case .questionnaire: homeSnapshot.questionnaires?.map(\.answeredDate).max()
        case .diaryOne: homeSnapshot.diaryOne?.map(\.createdAt).max()
        case .diaryTwo: homeSnapshot.diaryTwo?.map(\.createdAt).max()
        case .diaryThree: homeSnapshot.diaryThree?.map(\.createdAt).max()
        }
    }

    private func compactToolRow(_ type: PatientAssignmentType, active: Bool) -> some View {
        HStack(spacing: 8) {
            Button {
                Task { await openDirectTool(type) }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: type == .questionnaire ? "list.clipboard" : "book.closed")
                        .font(.title3).foregroundStyle(active ? Theme.success : Theme.textBody).frame(width: 26)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(type == .questionnaire ? L10n.questionnairesTitle : type == .diaryOne ? L10n.diaryOneTitle : type == .diaryTwo ? L10n.diaryTwoTitle : L10n.diaryThreeTitle)
                            .font(.headline).foregroundStyle(Theme.textBright)
                        Text(type == .questionnaire ? L10n.toolQuestionnairePurpose : type == .diaryOne ? L10n.patientDiaryOnePurpose : type == .diaryTwo ? L10n.patientDiaryTwoPurpose : L10n.patientDiaryThreeDescription)
                            .font(.caption).foregroundStyle(Theme.textBody).lineLimit(2)
                        PatientToolStatusView(active: active)
                        if let last = lastSubmission(type) {
                            Text(L10n.toolLastSent(L10n.hebrewDate(last)))
                                .font(.caption).foregroundStyle(Theme.textBody)
                        }
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.forward").font(.footnote).foregroundStyle(Theme.textBody)
                }.frame(minHeight: 48).contentShape(Rectangle())
            }.buttonStyle(.plain)
            if active, resumableTypes.contains(type), let assignment = openAssignments.first(where: { $0.type == type }) {
                Button(L10n.patientResumeAction) { resume(assignment) }
                    .font(.subheadline.weight(.semibold)).buttonStyle(.bordered)
                    .entitlementCreateControl()
            }
        }.padding(14).themedCard()
    }

    private var messagesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.patientInboxTitle).font(.headline).foregroundStyle(Theme.textBright)
                    let unread = inboxItems.filter(\.isUnread).count
                    if unread > 0 { Text(L10n.patientInboxUnread(unread)).font(.caption).foregroundStyle(Theme.gold) }
                }
                Spacer()
                Button(L10n.patientInboxAll) { isShowingMessages = true }.frame(minHeight: 44)
            }.padding(.horizontal, 12)
            ForEach(inboxItems.filter(\.isUnread)) { item in
                Divider().overlay(Theme.borderFaint)
                PatientInboxRow(item: item) { Task { await openInboxItem(item) } }
            }
            if refreshingHome && inboxItems.isEmpty { ProgressView().padding(8) }
            if inboxFailed || inbox.didFailLastLoad {
                Text(L10n.patientInboxRefreshFailed).font(.footnote).foregroundStyle(Theme.error).padding(12)
            }
        }.themedCard()
    }

    private var allMessagesButton: some View {
        Button {
            isShowingMessages = true
        } label: {
            HStack(spacing: 6) {
                Text(L10n.allMessagesAction)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.gold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.allMessagesAction)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.patientTasksEmptyTitle)
                .font(.headline)
                .foregroundStyle(Theme.textBright)
            Text(L10n.patientTasksEmptyBody)
                .font(.body)
                .foregroundStyle(Theme.textBody)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    @ViewBuilder
    private func assignmentCard(_ assignment: PatientAssignment) -> some View {
        switch assignment.type {
        case .questionnaire:
            EmptyView()
        case .diaryOne:
            diaryOneCard
        case .diaryTwo:
            diaryTwoCard
        case .diaryThree:
            diaryThreeCard
        case nil:
            upcomingTaskCard
        }
    }

    private func availabilityLabel(_ active: Bool) -> some View {
        Label(active ? L10n.patientToolEnabled : L10n.patientToolDisabled,
              systemImage: active ? "checkmark.circle.fill" : "lock.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(active ? Theme.textBright : Theme.textBody)
    }

    private func inactiveDiaryCard(title: String, subtitle: String, openHistory: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).foregroundStyle(Theme.textBright)
            Text(subtitle).font(.caption).foregroundStyle(Theme.textBody)
            availabilityLabel(false)
            Text(L10n.patientToolActivationHelp).foregroundStyle(Theme.textBody)
            Button(L10n.diaryOneMyEntriesTitle, action: openHistory).buttonStyle(.bordered)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).themedCard()
    }

    private var questionnaireCard: some View {
        let active = openAssignments.contains { $0.type == .questionnaire }
        return VStack(alignment: .leading, spacing: 12) {
            Text(L10n.patientQuestionnaireCardTitle)
                .font(.headline)
                .foregroundStyle(Theme.textBright)
            availabilityLabel(active)
            Text(active ? L10n.patientQuestionnaireCardBody : L10n.patientQuestionnaireInactiveHint)
                .font(.body)
                .foregroundStyle(Theme.textBody)
                .fixedSize(horizontal: false, vertical: true)
            if let date = lastQuestionnaireDate {
                Text(L10n.patientLastQuestionnaire(date)).font(.caption).foregroundStyle(Theme.textBody)
            }
            if active {
                Button { isShowingQuestionnaireHub = true } label: {
                    Text(L10n.patientQuestionnaireOpenAction).fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 24)
                }.buttonStyle(.pressableProminent)
            } else {
                Button(L10n.patientQuestionnaireHistoryAction) { isShowingQuestionnaireHub = true }
                    .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private var diaryOneCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.diaryOneTitle)
                .font(.headline)
                .foregroundStyle(Theme.textBright)
            Text(L10n.patientDiaryOnePurpose).font(.caption).foregroundStyle(Theme.textBody)
            availabilityLabel(true)
            Text(L10n.patientDiaryOneCardBody)
                .font(.body)
                .foregroundStyle(Theme.textBody)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.patientDiaryOneOngoingHint)
                .font(.footnote)
                .foregroundStyle(Theme.textBody)
            Button { showingDiaryOneHistory = true } label: {
                Text(L10n.patientDiaryOneStartAction)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 24)
            }
            .buttonStyle(.pressableProminent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private var diaryTwoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.diaryTwoTitle).font(.headline).foregroundStyle(Theme.textBright)
            Text(L10n.patientDiaryTwoPurpose).font(.caption).foregroundStyle(Theme.textBody)
            availabilityLabel(true)
            Text(L10n.patientDiaryTwoCardBody).foregroundStyle(Theme.textBody)
            Text(L10n.patientDiaryOneOngoingHint).font(.footnote).foregroundStyle(Theme.textBody)
            Button { isShowingDiaryTwoHub = true } label: {
                Text(L10n.patientDiaryOneStartAction).fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 24)
            }.buttonStyle(.pressableProminent)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).themedCard()
    }

    private var diaryThreeCard: some View {
        let active = PatientAssignmentType.diaryThreeSendingEnabled && openAssignments.contains { $0.type == .diaryThree }
        return VStack(alignment: .leading, spacing: 12) {
            Text(L10n.diaryThreeTitle).font(.headline).foregroundStyle(Theme.textBright)
            availabilityLabel(active)
            Text(PatientAssignmentType.diaryThreeSendingEnabled ? L10n.patientDiaryThreeCardBody : L10n.diaryThreeSendingPaused).foregroundStyle(Theme.textBody)
            if active {
                Text(L10n.patientDiaryOneOngoingHint).font(.footnote).foregroundStyle(Theme.textBody)
            }
            Button { isShowingDiaryThreeHub = true } label: {
                Text(active ? L10n.patientDiaryOneStartAction : L10n.diaryOneMyEntriesTitle).fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 24)
            }.buttonStyle(.pressableProminent)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).themedCard()
    }

    private var upcomingTaskCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.patientUpcomingTaskTitle)
                .font(.headline)
                .foregroundStyle(Theme.textBright)
            Text(L10n.patientUpcomingTaskBody)
                .font(.body)
                .foregroundStyle(Theme.textBody)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private func resumeTitle(_ type: PatientAssignmentType?) -> String {
        switch type {
        case .diaryOne: L10n.diaryOneTitle
        case .diaryTwo: L10n.diaryTwoTitle
        default: L10n.patientQuestionnaireCardTitle
        }
    }

    private func resume(_ assignment: PatientAssignment) {
        openedAssignmentID = assignment.id
        switch assignment.type {
        case .questionnaire: guard EntitlementState.shared.allowMutation() else { return }; questionnaireFormRequest = assignment.id; isShowingQuestionnaireHub = true
        case .diaryOne: if EntitlementState.shared.allowMutation() { isShowingDiaryOneEntry = true }
        case .diaryTwo: if EntitlementState.shared.allowMutation() { isShowingDiaryTwoEntry = true }
        default: break
        }
    }

    private func refreshDrafts() {
        guard let userID = auth.currentUserId, let patientID = appContext.current?.patientId else {
            resumableTypes = []; return
        }
        let storage = DeviceDraftStorage()
        resumableTypes = Set(openAssignments.compactMap { assignment in
            let kind: String
            let target: String
            switch assignment.type {
            case .questionnaire: kind = "patient-questionnaire"; target = assignment.id.uuidString
            case .diaryOne: kind = "patient-diary"; target = patientID.uuidString
            case .diaryTwo: kind = "patient-diary-two"; target = patientID.uuidString
            default: return nil
            }
            guard let key = try? DeviceDraftStorage.key(userID: userID, kind: kind, target: target), storage.contains(key: key) else { return nil }
            return assignment.type
        })
    }

    private func loadAssignments() async {
        if refreshingTools { refreshToolsAgain = true; return }
        guard let userID = auth.currentUserId,
              let patientID = appContext.current?.patientId else { return }
        refreshingTools = true
        defer {
            refreshingTools = false
            if refreshToolsAgain {
                refreshToolsAgain = false
                Task { await refreshPatientHome() }
            }
        }
        let key = "\(userID):\(patientID.uuidString)"
        if homeSnapshot.assignments == nil { homeSnapshot = PatientHomeCache.read(key: key) }
        if loadState == .loading, assignments.isEmpty, let cached = homeSnapshot.assignments {
            assignments = cached
            loadState = .loaded
        }
        lastQuestionnaireDate = homeSnapshot.questionnaires?.map(\.answeredDate).max()
        let client = auth.client
        async let fetchedAssignments = try? PatientAssignmentService(client: client).patientAssignments(patientId: patientID)
        async let questionnaires = try? PatientQuestionnaireHistoryService(client: client).history(patientId: patientID)
        async let diaryOne = try? PatientDiaryOneService(client: client).loadPatientCreatedEntries(patientId: patientID)
        async let diaryTwo = try? PatientDiaryTwoService(client: client).loadPatientCreatedEntries(patientId: patientID)
        async let diaryThree = try? PatientDiaryThreeService(client: client).loadPatientCreatedEntries(patientId: patientID)
        let results = await (fetchedAssignments, questionnaires, diaryOne, diaryTwo, diaryThree)
        guard userID == auth.currentUserId, patientID == appContext.current?.patientId else { return }
        if let value = results.0 { assignments = value; homeSnapshot.assignments = value }
        if let value = results.1 { homeSnapshot.questionnaires = value }
        if let value = results.2 { homeSnapshot.diaryOne = value }
        if let value = results.3 { homeSnapshot.diaryTwo = value }
        if let value = results.4 { homeSnapshot.diaryThree = value }
        PatientHomeCache.save(homeSnapshot, key: key)
        lastQuestionnaireDate = homeSnapshot.questionnaires?.map(\.answeredDate).max()
        loadState = homeSnapshot.assignments == nil ? .failed : .loaded
        refreshDrafts()
    }

    private func loadMessages() async {
        guard let patientId = appContext.current?.patientId else { return }
        do {
            let loaded = try await PatientMessageService(client: auth.client).messages(patientId: patientId)
            guard appContext.current?.patientId == patientId else { return }
            messages = loaded
            inboxFailed = false
        } catch {
            inboxFailed = true
            #if DEBUG
            AppLog.store.debug("patient messages refresh failed")
            #endif
        }
    }

    private func manualRefresh() async {
        guard !manualRefreshing else { return }
        manualRefreshing = true
        defer { manualRefreshing = false }
        // If a silent refresh is running, wait and then fetch again for this request.
        while refreshingTools || refreshingHome {
            do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
        }
        guard !Task.isCancelled else { return }
        await refreshPatientHome()
    }

    private func refreshTools(lightweight: Bool) async {
        guard lightweight else { await loadAssignments(); return }
        guard let patientID = appContext.current?.patientId,
              let loaded = try? await PatientAssignmentService(client: auth.client).patientAssignments(patientId: patientID),
              patientID == appContext.current?.patientId else { return }
        assignments = loaded
        homeSnapshot.assignments = loaded
        if let userID = auth.currentUserId {
            PatientHomeCache.save(homeSnapshot, key: "\(userID):\(patientID.uuidString)")
        }
    }

    private func refreshPatientHome(lightweight: Bool = false) async {
        guard !refreshingHome else { refreshHomeAgain = true; return }
        refreshingHome = true
        defer {
            refreshingHome = false
            if refreshHomeAgain {
                refreshHomeAgain = false
                if scenePhase == .active && !Task.isCancelled { Task { await refreshPatientHome() } }
            }
        }
        async let tools: Void = refreshTools(lightweight: lightweight)
        async let updates: Void = inbox.refresh()
        async let personal: Void = loadMessages()
        _ = await (tools, updates, personal)
        guard let patientID = appContext.current?.patientId else { return }
        // Retry receipts after transient failures without treating previews as reads.
        for message in messages where !message.isUnread {
            await inbox.markPatientResourceRead(patientID: patientID, messageID: message.id)
        }
        for id in acknowledgedAssignments {
            await inbox.markPatientResourceRead(patientID: patientID, assignmentID: id)
        }
        refreshDrafts()
    }

    private func applyRead(_ updated: PatientMessage) {
        if let index = messages.firstIndex(where: { $0.id == updated.id }) {
            messages[index] = updated
        }
    }

    private func openDirectTool(_ type: PatientAssignmentType) async {
        if let current = openAssignments.first(where: { $0.type == type }) {
            guard let patientID = appContext.current?.patientId,
                  let fresh = try? await PatientAssignmentService(client: auth.client).patientAssignments(patientId: patientID),
                  patientID == appContext.current?.patientId,
                  fresh.contains(where: { $0.id == current.id && $0.type == type && $0.cancelledAt == nil })
            else { unavailableItem = true; return }
            assignments = fresh
            openedAssignmentID = current.id
        } else { openedAssignmentID = nil }
        showTool(type)
    }

    private func showTool(_ type: PatientAssignmentType) {
        openedMessageID = nil
        isShowingDiaryOneEntry = false
        isShowingDiaryTwoEntry = false
        isShowingDiaryThreeEntry = false
        isShowingQuestionnaireHub = type == .questionnaire
        showingDiaryOneHistory = type == .diaryOne
        isShowingDiaryTwoHub = type == .diaryTwo
        isShowingDiaryThreeHub = type == .diaryThree
    }

    private func showMessage(_ id: UUID) {
        isShowingQuestionnaireHub = false
        showingDiaryOneHistory = false
        isShowingDiaryTwoHub = false
        isShowingDiaryThreeHub = false
        isShowingDiaryOneEntry = false
        isShowingDiaryTwoEntry = false
        isShowingDiaryThreeEntry = false
        openedMessageID = id
    }

    private func acknowledgeOpenedAssignment(type: PatientAssignmentType) async {
        guard let id = openedAssignmentID, let patientID = appContext.current?.patientId,
              assignments.contains(where: { $0.id == id && $0.type == type && $0.cancelledAt == nil }) else { return }
        acknowledgedAssignments.insert(id)
        await inbox.markPatientResourceRead(patientID: patientID, assignmentID: id)
        if openedAssignmentID == id { openedAssignmentID = nil }
    }

    private func openInboxItem(_ item: PatientInboxItem) async {
        isShowingMessages = false
        if let message = item.message {
            guard let fetched = try? await PatientMessageService(client: auth.client).message(id: message.id),
                  fetched.patientId == appContext.current?.patientId else { unavailableItem = true; return }
            messages.removeAll { $0.id == fetched.id }
            messages.append(fetched)
            isShowingMessages = false
            showMessage(fetched.id)
        } else if let notification = item.notification {
            await openPayload(.from(notification: notification))
        }
    }

    private func applyPendingMessageRoute() async {
        guard let payload = messageCoordinator.consumePendingPayload() else { return }
        await openPayload(payload)
    }

    private func openPayload(_ payload: AppNotificationPayload) async {
        guard let patientID = appContext.current?.patientId,
              payload.patientId.flatMap(UUID.init(uuidString:)) == patientID else {
            unavailableItem = true; return
        }
        if payload.type == .messageReceived {
            guard payload.resourceType == "message", let id = payload.resourceId.flatMap(UUID.init(uuidString:)),
                  let message = try? await PatientMessageService(client: auth.client).message(id: id),
                  message.patientId == patientID else { unavailableItem = true; return }
            messages.removeAll { $0.id == message.id }
            messages.append(message)
            isShowingMessages = false
            showMessage(id)
            return
        }
        guard let loaded = try? await PatientAssignmentService(client: auth.client).patientAssignments(patientId: patientID),
              let assignment = PatientInboxItem.assignment(payload: payload, patientID: patientID, assignments: loaded),
              let type = assignment.type else { unavailableItem = true; return }
        guard appContext.current?.patientId == patientID else { return }
        assignments = loaded
        isShowingMessages = false
        openedAssignmentID = assignment.id
        showTool(type)
    }

}

/// Patient-safe GAD-7 + PHQ-9. Submit goes through the Edge Function only.
struct PatientQuestionnaireView: View {
    let assignmentId: UUID
    var onSubmitted: () async -> Void
    var onInactive: () async -> Void = {}

    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var questionnaire = CombinedMoodQuestionnaire()
    @State private var deviceDraft = DeviceFormDraft<CombinedMoodQuestionnaire>()
    @State private var isSubmitting = false
    @State private var didSubmit = false
    @State private var inactive = false
    @State private var didAttemptSubmit = false
    @State private var isShowingLeaveWarning = false
    @State private var errorMessage: String?

    private var completion: QuestionnaireCompletion { QuestionnaireCompletion(questionnaire) }

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                QuestionnaireSections(
                    questionnaire: $questionnaire,
                    isEditable: !isSubmitting && !didSubmit && !inactive,
                    previous: nil,
                    accent: Theme.gold,
                    showsTherapistNotes: false,
                    marksUnanswered: didAttemptSubmit,
                    requiresInterferenceAnswer: true
                )
            }
            .patientAtmosphere(Theme.gold)
            .themedScreen()
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.questionnaireCompletion(completion.answered, total: completion.total))
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("questionnaire.progress")
                    ProgressView(value: Double(completion.answered), total: Double(completion.total))
                        .accessibilityLabel(L10n.questionnaireCompletion(completion.answered, total: completion.total))
                    if completion.firstUnanswered != nil {
                        Button(L10n.nextUnansweredAction) { revealUnanswered(using: proxy) }
                            .font(.subheadline)
                            .accessibilityIdentifier("questionnaire.nextUnanswered")
                    } else if !didSubmit {
                        Text(L10n.questionnaireReadyToSend).font(.footnote)
                    }
                    DeviceDraftFeedback(message: deviceDraft.feedback, isError: deviceDraft.hasError)
                    if let errorMessage {
                        Text(errorMessage).font(.footnote).foregroundStyle(Theme.error)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.base)
            }
            .navigationTitle(L10n.patientQuestionnaireCardTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .interactiveDismissDisabled(!questionnaire.isEmpty || isSubmitting)
            .busyOverlay(isSubmitting, label: L10n.patientQuestionnaireSubmitting)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.back) {
                        if didSubmit { Task { await finishSuccessfully() } }
                        else if questionnaire.isEmpty { dismiss() }
                        else { isShowingLeaveWarning = true }
                    }
                    .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(didSubmit ? L10n.retryAction : L10n.patientQuestionnaireSubmitAction) {
                        if didSubmit { Task { await finishSuccessfully() } }
                        else if !inactive && completion.firstUnanswered == nil { Task { await submit() } }
                        else { revealUnanswered(using: proxy) }
                    }
                    .disabled(isSubmitting || inactive)
                }
            }
        }
        .onAppear {
            if let saved = deviceDraft.restore(userID: auth.currentUserId, kind: "patient-questionnaire", target: assignmentId.uuidString) {
                questionnaire = saved.normalizedPatientDraft
            }
        }
        .onChange(of: questionnaire) { _, _ in
            if deviceDraft.hasLoaded, !didSubmit { persistDraft() }
        }
        .alert(L10n.leaveDraftTitle, isPresented: $isShowingLeaveWarning) {
            Button(L10n.keepDraftAndLeave) { if persistDraft() { dismiss() } }
            Button(L10n.discardDraftAction, role: .destructive) { if deviceDraft.discard() { dismiss() } }
            Button(L10n.keepEditingAction, role: .cancel) {}
        }
    }

    private func revealUnanswered(using proxy: ScrollViewProxy) {
        didAttemptSubmit = true
        guard let item = completion.firstUnanswered else { return }
        withAnimation { proxy.scrollTo(item, anchor: .top) }
    }

    @discardableResult
    private func persistDraft() -> Bool {
        deviceDraft.save(questionnaire, isEmpty: questionnaire.isEmpty)
    }

    private func submit() async {
        guard EntitlementState.shared.allowMutation() else { return }
        guard !isSubmitting, !didSubmit, completion.firstUnanswered == nil,
              let interference = questionnaire.interferenceLevel else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            try await PatientAssignmentService(client: auth.client)
                .submitPatientQuestionnaire(
                    assignmentId: assignmentId,
                    gad7Answers: questionnaire.gad7Answers.compactMap { $0 },
                    phq9Answers: questionnaire.phq9Answers.compactMap { $0 },
                    interferenceLevel: interference
                )
            await finishSuccessfully()
        } catch PatientQuestionnaireSubmitError.cancelled {
            inactive = true
            errorMessage = L10n.patientQuestionnaireCancelledError
            isSubmitting = false
            await onInactive()
        } catch let error as PatientQuestionnaireSubmitError {
            errorMessage = error.errorDescription ?? L10n.patientQuestionnaireSubmitError
            isSubmitting = false
        } catch {
            errorMessage = L10n.patientQuestionnaireSubmitError
            isSubmitting = false
        }
    }

    private func finishSuccessfully() async {
        didSubmit = true
        guard deviceDraft.discard() else {
            errorMessage = L10n.submittedDraftCleanup
            isSubmitting = false
            return
        }
        questionnaire = CombinedMoodQuestionnaire()
        await onSubmitted()
        dismiss()
    }
}
