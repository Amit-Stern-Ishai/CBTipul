import SwiftUI
import OSLog

/// Patient Mode home: open assignments for the connected anonymous patient.
struct PatientModeView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(AppContextService.self) private var appContext
    @Environment(PatientModeMessageCoordinator.self) private var messageCoordinator
    @Environment(\.scenePhase) private var scenePhase

    private enum LoadState {
        case loading
        case loaded
        case failed
    }

    @State private var resumableTypes: Set<PatientAssignmentType> = []
    @State private var lastQuestionnaireDate: Date?
    @State private var showingDiaryOneHistory = false
    @State private var loadState: LoadState = .loading
    @State private var assignments: [PatientAssignment] = []
    @State private var messages: [PatientMessage] = []
    @State private var isShowingMessages = false
    @State private var openedMessageID: UUID?
    @State private var isShowingQuestionnaireHub = false
    @State private var questionnaireFormRequest: UUID?
    @State private var didSubmitDiaryOne = false
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
            Group {
                switch loadState {
                case .loading where assignments.isEmpty:
                    loading
                case .failed where assignments.isEmpty:
                    errorState
                case .loading, .loaded, .failed:
                    taskList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .patientAtmosphere(Theme.gold)
            .background(Theme.base.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $isShowingQuestionnaireHub) {
                if let patientId = appContext.current?.patientId {
                    PatientQuestionnaireHubView(patientId: patientId, openFormRequest: $questionnaireFormRequest,
                        onAssignmentsChanged: { await loadAssignments() })
                }
            }
            .navigationDestination(isPresented: $isShowingMessages) {
                if let patientId = appContext.current?.patientId {
                    PatientMessagesInboxView(
                        messages: $messages,
                        patientId: patientId,
                        onMarkedRead: applyRead
                    )
                }
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
                        Task { await refreshPatientHome() }
                    } label: {
                        Label(L10n.patientTasksRefreshAction, systemImage: "arrow.clockwise")
                    }
                    .disabled(loadState == .loading)
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                PatientSettingsView()
            }
            .task {
                messageCoordinator.markReady()
                await refreshPatientHome()
                await applyPendingMessageRoute()
            }
            .onChange(of: messageCoordinator.pendingRevision) { _, _ in
                Task { await applyPendingMessageRoute() }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await refreshPatientHome() }
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
        .onDisappear { messageCoordinator.markNotReady() }
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
            VStack(alignment: .leading, spacing: 20) {
                Text(L10n.appTitle)
                    .font(.title.bold())
                    .foregroundStyle(Theme.textBright)

                if !resumableTypes.isEmpty {
                    Text(L10n.patientAttentionTitle).font(.title2.weight(.semibold))
                    ForEach(openAssignments.filter { resumableTypes.contains($0.type ?? .diaryThree) }, id: \.id) { assignment in
                        Button { resume(assignment) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(resumeTitle(assignment.type)).font(.headline)
                                Text(L10n.patientLocalOnly).font(.caption).foregroundStyle(Theme.textBody)
                                Label(L10n.patientResumeAction, systemImage: "arrow.forward.circle.fill").font(.subheadline.weight(.semibold))
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(16).themedCard()
                        }.buttonStyle(.plain)
                    }
                }
                if !homeMessagePreviews.isEmpty { messagesSection }
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.patientAvailableTitle).font(.title2.weight(.semibold))
                    Text(L10n.patientAvailableHelp).font(.subheadline).foregroundStyle(Theme.textBody)
                }
                questionnaireCard

                if openAssignments.contains(where: { $0.type == .diaryOne }) {
                    diaryOneCard
                } else {
                    inactiveDiaryCard(title: L10n.patientDiaryOnePurpose, subtitle: L10n.diaryOneTitle) { showingDiaryOneHistory = true }
                }
                if openAssignments.contains(where: { $0.type == .diaryTwo }) {
                    diaryTwoCard
                } else {
                    inactiveDiaryCard(title: L10n.patientDiaryTwoPurpose, subtitle: L10n.diaryTwoTitle) { isShowingDiaryTwoHub = true }
                }
                diaryThreeCard
                ForEach(openAssignments.filter { $0.type == nil }, id: \.id) { assignment in
                    assignmentCard(assignment)
                }

                if homeMessagePreviews.isEmpty { messagesSection }

                if case .failed = loadState {
                    Text(L10n.patientTasksLoadError)
                        .font(.footnote)
                        .foregroundStyle(Theme.error)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { refreshDrafts() }
        .refreshable { await refreshPatientHome() }
    }

    private var messagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.messagesTitle)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.textBright)

            if homeMessagePreviews.isEmpty {
                Text(messages.isEmpty ? L10n.patientMessagesEmptyTitle : L10n.noNewMessagesTitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textBody)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 12) {
                    ForEach(homeMessagePreviews) { message in
                        PatientModeMessageCard(message: message, kind: .home) {
                            openedMessageID = message.id
                        }
                    }
                }
                if remainingUnreadCount > 0 {
                    Button {
                        isShowingMessages = true
                    } label: {
                        Text(L10n.moreUnreadMessages(remainingUnreadCount))
                            .font(.subheadline)
                            .foregroundStyle(Theme.textBody)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.moreUnreadMessages(remainingUnreadCount))
                }
            }

            if !messages.isEmpty {
                allMessagesButton
            }
        }
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
            Text(L10n.patientDiaryOnePurpose)
                .font(.headline)
                .foregroundStyle(Theme.textBright)
            Text(L10n.diaryOneTitle).font(.caption).foregroundStyle(Theme.textBody)
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
            Text(L10n.patientDiaryTwoPurpose).font(.headline).foregroundStyle(Theme.textBright)
            Text(L10n.diaryTwoTitle).font(.caption).foregroundStyle(Theme.textBody)
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
        case .diaryOne: L10n.patientDiaryOnePurpose
        case .diaryTwo: L10n.patientDiaryTwoPurpose
        default: L10n.patientQuestionnaireCardTitle
        }
    }

    private func resume(_ assignment: PatientAssignment) {
        switch assignment.type {
        case .questionnaire: questionnaireFormRequest = assignment.id; isShowingQuestionnaireHub = true
        case .diaryOne: isShowingDiaryOneEntry = true
        case .diaryTwo: isShowingDiaryTwoEntry = true
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
        if assignments.isEmpty {
            loadState = .loading
        }
        do {
            assignments = try await PatientAssignmentService(client: auth.client)
                .patientAssignments(patientId: appContext.current?.patientId)
            loadState = .loaded
        } catch {
            loadState = .failed
        }
        refreshDrafts()
        if let patientID = appContext.current?.patientId,
           let history = try? await PatientQuestionnaireHistoryService(client: auth.client).history(patientId: patientID) {
            lastQuestionnaireDate = history.map(\.answeredDate).max()
        }
    }

    private func loadMessages() async {
        guard let patientId = appContext.current?.patientId else { return }
        do {
            messages = try await PatientMessageService(client: auth.client)
                .messages(patientId: patientId)
        } catch {
            #if DEBUG
            AppLog.store.debug("patient messages refresh failed")
            #endif
        }
    }

    private func refreshPatientHome() async {
        await loadAssignments()
        await loadMessages()
        refreshDrafts()
    }

    private func applyRead(_ updated: PatientMessage) {
        if let index = messages.firstIndex(where: { $0.id == updated.id }) {
            messages[index] = updated
        }
    }

    private func applyPendingMessageRoute() async {
        guard let destination = messageCoordinator.consumePending() else { return }
        switch destination {
        case .none:
            break
        case .messages(let messagesDestination):
            await loadMessages()
            await applyMessageDestination(messagesDestination)
        case .questionnaireAssigned(let payload):
            guard let patientId = appContext.current?.patientId else { return }
            let assignment = await PatientQuestionnaireAssignedRouter.resolve(payload: payload, patientId: patientId) {
                let loaded = try await PatientAssignmentService(client: auth.client).patientAssignments(patientId: patientId)
                assignments = loaded
                return loaded
            }
            guard appContext.current?.patientId == patientId, let assignment else { return }
            openedMessageID = nil
            isShowingMessages = false
            isShowingDiaryOneEntry = false
            isShowingDiaryTwoHub = false
            isShowingDiaryThreeHub = false
            isShowingDiaryTwoEntry = false
            isShowingDiaryThreeEntry = false
            isShowingSettings = false
            questionnaireFormRequest = assignment.id
            isShowingQuestionnaireHub = true
        case .diaryTwoAssigned(let payload):
            guard let patientId = appContext.current?.patientId else { return }
            let assignment = await PatientDiaryTwoAssignedRouter.resolve(payload: payload, patientId: patientId) {
                let loaded = try await PatientAssignmentService(client: auth.client).patientAssignments(patientId: patientId)
                assignments = loaded
                return loaded
            }
            guard appContext.current?.patientId == patientId else { return }
            openedMessageID = nil
            isShowingMessages = false
            isShowingDiaryOneEntry = false
            isShowingDiaryTwoHub = false
            isShowingSettings = false
            isShowingDiaryTwoEntry = assignment != nil
        case .diaryThreeAssigned(let payload):
            guard let patientId = appContext.current?.patientId else { return }
            let assignment = await PatientDiaryThreeAssignedRouter.resolve(payload: payload, patientId: patientId) {
                let loaded = try await PatientAssignmentService(client: auth.client).patientAssignments(patientId: patientId)
                assignments = loaded
                return loaded
            }
            guard appContext.current?.patientId == patientId else { return }
            if PatientAssignmentType.diaryThreeSendingEnabled && assignment != nil && isDiaryThreeWizardVisible { return }
            openedMessageID = nil
            isShowingMessages = false
            isShowingDiaryOneEntry = false
            isShowingDiaryTwoEntry = false
            isShowingDiaryTwoHub = false
            isShowingSettings = false
            isShowingDiaryThreeEntry = assignment != nil && PatientAssignmentType.diaryThreeSendingEnabled
            isShowingDiaryThreeHub = assignment != nil && !PatientAssignmentType.diaryThreeSendingEnabled
        case .diaryOneAssigned(let diaryDestination):
            await loadAssignments()
            applyDiaryOneAssignedDestination(diaryDestination)
        }
    }

    private func applyMessageDestination(_ destination: PatientMessageDestination) async {
        switch destination {
        case .none:
            break
        case .list:
            openedMessageID = nil
            isShowingDiaryOneEntry = false
            isShowingMessages = true
        case .exact(let id):
            isShowingDiaryOneEntry = false
            if messages.contains(where: { $0.id == id }) == false,
               let fetched = try? await PatientMessageService(client: auth.client).message(id: id) {
                messages.insert(fetched, at: 0)
            }
            isShowingMessages = false
            if messages.contains(where: { $0.id == id }) {
                openedMessageID = id
            } else {
                openedMessageID = nil
                isShowingMessages = true
            }
        }
    }

    private func applyDiaryOneAssignedDestination(_ destination: PatientDiaryOneAssignedDestination) {
        switch destination {
        case .none:
            break
        case .entryForm(let assignmentId):
            guard let assignmentId,
                  PatientDiaryOneAssignedRouter.matchingAssignment(
                    in: assignments,
                    assignmentId: assignmentId
                  ) != nil
            else { return }
            openedMessageID = nil
            isShowingMessages = false
            isShowingDiaryOneEntry = true
        }
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
                    Button(didSubmit ? L10n.done : L10n.patientQuestionnaireSubmitAction) {
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
