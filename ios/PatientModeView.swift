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

    @State private var loadState: LoadState = .loading
    @State private var assignments: [PatientAssignment] = []
    @State private var messages: [PatientMessage] = []
    @State private var isShowingMessages = false
    @State private var openedMessageID: UUID?
    @State private var didSubmitQuestionnaire = false
    @State private var didSubmitDiaryOne = false
    @State private var isShowingSettings = false
    @State private var isShowingDiaryOneEntry = false

    private var openAssignments: [PatientAssignment] {
        assignments.filter(\.isOpen)
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
            .alert(L10n.patientQuestionnaireSubmittedTitle, isPresented: $didSubmitQuestionnaire) {
                Button(L10n.ok, role: .cancel) {}
            }
            .alert(L10n.patientDiaryOneSaved, isPresented: $didSubmitDiaryOne) {
                Button(L10n.ok, role: .cancel) {}
            }
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
            VStack(alignment: .leading, spacing: 20) {
                Text(L10n.appTitle)
                    .font(.title.bold())
                    .foregroundStyle(Theme.textBright)

                Text(L10n.patientTasksTitle)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.textBright)

                if openAssignments.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 12) {
                        ForEach(openAssignments, id: \.id) { assignment in
                            assignmentCard(assignment)
                        }
                    }
                }

                messagesSection

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
            questionnaireCard(assignment)
        case .diaryOne:
            diaryOneCard
        case .diaryTwo, nil:
            upcomingTaskCard
        }
    }

    private func questionnaireCard(_ assignment: PatientAssignment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.patientQuestionnaireCardTitle)
                .font(.headline)
                .foregroundStyle(Theme.textBright)
            Text(L10n.patientQuestionnaireCardBody)
                .font(.body)
                .foregroundStyle(Theme.textBody)
                .fixedSize(horizontal: false, vertical: true)
            NavigationLink {
                PatientQuestionnaireView(assignmentId: assignment.id) {
                    await loadAssignments()
                    didSubmitQuestionnaire = true
                }
            } label: {
                Text(L10n.patientQuestionnaireStartAction)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 24)
            }
            .buttonStyle(.pressableProminent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private var diaryOneCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.patientDiaryOneCardTitle)
                .font(.headline)
                .foregroundStyle(Theme.textBright)
            Text(L10n.patientDiaryOneCardBody)
                .font(.body)
                .foregroundStyle(Theme.textBody)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.patientDiaryOneOngoingHint)
                .font(.footnote)
                .foregroundStyle(Theme.textBody)
            NavigationLink {
                PatientDiaryOneHubView(
                    onEntrySubmitted: {
                        didSubmitDiaryOne = true
                        await loadAssignments()
                    }
                )
            } label: {
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

    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var questionnaire = CombinedMoodQuestionnaire()
    @State private var deviceDraft = DeviceFormDraft<CombinedMoodQuestionnaire>()
    @State private var isSubmitting = false
    @State private var didSubmit = false
    @State private var didAttemptSubmit = false
    @State private var isShowingLeaveWarning = false
    @State private var errorMessage: String?

    private var completion: QuestionnaireCompletion { QuestionnaireCompletion(questionnaire) }

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                QuestionnaireSections(
                    questionnaire: $questionnaire,
                    isEditable: !isSubmitting && !didSubmit,
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
                        else if completion.firstUnanswered == nil { Task { await submit() } }
                        else { revealUnanswered(using: proxy) }
                    }
                    .disabled(isSubmitting)
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
        } catch PatientQuestionnaireSubmitError.alreadyCompleted {
            await finishSuccessfully()
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
        await onSubmitted()
        dismiss()
    }
}
