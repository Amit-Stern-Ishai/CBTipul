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

                messagesSection

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
                    .font(.body)
                    .foregroundStyle(Theme.textBody)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .themedCard()
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
                PatientDiaryOneEntryView(
                    onSubmitted: {
                        didSubmitDiaryOne = true
                        await loadAssignments()
                    },
                    onDiaryInactive: {
                        await loadAssignments()
                    }
                )
            } label: {
                Text(L10n.diaryOneAddEntryAction)
                    .fontWeight(.semibold)
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
    @State private var isSubmitting = false
    @State private var isShowingIncompleteAlert = false
    @State private var errorMessage: String?

    private var isReadyToSubmit: Bool {
        guard questionnaire.isComplete,
              let interference = questionnaire.interferenceLevel else { return false }
        let gad7 = questionnaire.gad7Answers.compactMap { $0 }
        let phq9 = questionnaire.phq9Answers.compactMap { $0 }
        let valid = CombinedMoodQuestionnaire.answerValues
        return gad7.count == L10n.gad7Questions.count
            && phq9.count == L10n.phq9Questions.count
            && gad7.allSatisfy { valid.contains($0) }
            && phq9.allSatisfy { valid.contains($0) }
            && valid.contains(interference)
    }

    var body: some View {
        Form {
            QuestionnaireSections(
                questionnaire: $questionnaire,
                isEditable: !isSubmitting,
                previous: nil,
                accent: Theme.gold,
                showsTherapistNotes: false
            )

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Theme.error)
                }
            }
        }
        .patientAtmosphere(Theme.gold)
        .themedScreen()
        .navigationTitle(L10n.patientQuestionnaireCardTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isSubmitting)
        .interactiveDismissDisabled(isSubmitting)
        .busyOverlay(isSubmitting, label: L10n.patientQuestionnaireSubmitting)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.patientQuestionnaireSubmitAction) {
                    if isReadyToSubmit {
                        Task { await submit() }
                    } else {
                        isShowingIncompleteAlert = true
                    }
                }
                .disabled(isSubmitting)
            }
        }
        .alert(L10n.questionnaireIncompleteTitle, isPresented: $isShowingIncompleteAlert) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(L10n.questionnaireIncompleteMessage)
        }
    }

    private func submit() async {
        guard !isSubmitting else { return }
        guard isReadyToSubmit,
              let interference = questionnaire.interferenceLevel else {
            isShowingIncompleteAlert = true
            return
        }
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
        await onSubmitted()
        dismiss()
    }
}
