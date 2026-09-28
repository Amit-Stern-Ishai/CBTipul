import SwiftUI
import OSLog

/// Therapist composer. Sends only through `send-patient-message`.
struct SendPatientMessageComposerView: View {
    let patient: Patient
    var onSent: () -> Void

    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var bodyText = ""
    @State private var deviceDraft = DeviceFormDraft<String>()
    @State private var isShowingLeaveWarning = false
    @State private var didSend = false
    @State private var isSending = false
    @State private var errorMessage: String?

    private var canSend: Bool {
        PatientMessageDraft.canSend(bodyText) && !isSending && !didSend
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(patient.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Section {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $bodyText)
                            .frame(minHeight: 180)
                            .disabled(isSending || didSend)
                            .accessibilityIdentifier("message.draft")
                        if bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(L10n.sendPatientMessagePlaceholder)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                }

                Section {
                    Text(L10n.messageCharacterCount(bodyText.count, maximum: PatientMessageDraft.maxLength))
                        .font(.footnote)
                        .foregroundStyle(bodyText.count > PatientMessageDraft.maxLength ? Theme.error : Theme.textBody)
                    if bodyText.count > PatientMessageDraft.maxLength {
                        Text(L10n.sendPatientMessageTooLong).foregroundStyle(Theme.error)
                    }
                    DeviceDraftFeedback(message: deviceDraft.feedback, isError: deviceDraft.hasError)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Theme.error)
                    }
                }
            }
            .themedScreen()
            .navigationTitle(L10n.sendPatientMessageAction)
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isSending || !bodyText.isEmpty)
            .busyOverlay(isSending, label: L10n.sendPatientMessageSending)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) {
                        if didSend { finishSentMessage() }
                        else if bodyText.isEmpty { dismiss() }
                        else { isShowingLeaveWarning = true }
                    }
                        .disabled(isSending)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(didSend ? L10n.done : L10n.sendMessageAction) {
                        if didSend { finishSentMessage() }
                        else { Task { await send() } }
                    }
                    .disabled(isSending || (!didSend && !canSend))
                }
            }
            .onAppear {
                if let saved = deviceDraft.restore(userID: auth.currentUserId, kind: "therapist-message", target: patient.id.queryValue) {
                    bodyText = saved
                }
            }
            .onChange(of: bodyText) { _, _ in
                if deviceDraft.hasLoaded, !didSend { persistDraft() }
            }
            .alert(L10n.leaveDraftTitle, isPresented: $isShowingLeaveWarning) {
                Button(L10n.keepDraftAndLeave) { if persistDraft() { dismiss() } }
                Button(L10n.discardDraftAction, role: .destructive) { if deviceDraft.discard() { dismiss() } }
                Button(L10n.keepEditingAction, role: .cancel) {}
            }
        }
        .appTextSize()
    }

    @discardableResult
    private func persistDraft() -> Bool {
        deviceDraft.save(bodyText, isEmpty: bodyText.isEmpty)
    }

    private func finishSentMessage() {
        didSend = true
        isSending = false
        guard deviceDraft.discard() else {
            errorMessage = L10n.messageSentDraftCleanup
            return
        }
        onSent()
        dismiss()
    }

    private func send() async {
        guard !isSending, !didSend else { return }
        guard let patientId = patient.id.uuidValue else {
            errorMessage = L10n.patientInvitationInvalidPatientError
            return
        }
        guard SendPatientMessageRequestFactory.make(
            patientId: patientId,
            rawBody: bodyText
        ) != nil else {
            let trimmed = PatientMessageDraft.normalizedBody(bodyText)
            errorMessage = trimmed.isEmpty
                ? L10n.sendPatientMessageEmpty
                : L10n.sendPatientMessageTooLong
            return
        }
        isSending = true
        errorMessage = nil
        do {
            try await PatientMessageService(client: auth.client)
                .send(patientId: patientId, rawBody: bodyText)
            finishSentMessage()
        } catch let error as PatientMessageSendError {
            errorMessage = error.errorDescription ?? L10n.sendPatientMessageFailed
            isSending = false
        } catch {
            errorMessage = L10n.sendPatientMessageFailed
            isSending = false
        }
    }
}

/// Therapist sent-message history for one patient. Not a chat.
struct TherapistPatientMessagesView: View {
    let patient: Patient

    @Environment(AuthManager.self) private var auth
    @Environment(PatientStore.self) private var store

    @State private var messages: [PatientMessage] = []
    @State private var isLoading = false
    @State private var didFail = false

    var body: some View {
        Group {
            if isLoading && messages.isEmpty {
                ProgressView()
            } else if didFail && messages.isEmpty {
                ContentUnavailableView {
                    Label(L10n.patientMessagesLoadFailedTitle, systemImage: "exclamationmark.triangle")
                } actions: {
                    Button(L10n.retry) {
                        Task { await load() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if messages.isEmpty {
                ContentUnavailableView {
                    Label(L10n.patientMessagesEmptyTitle, systemImage: "envelope")
                }
            } else {
                List {
                    ForEach(messages) { message in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(PatientMessage.preview(message.body))
                                .font(.body)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(L10n.notificationTimestamp(message.createdAt))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(message.isUnread ? L10n.messageUnreadStatus : L10n.messageReadStatus)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(message.isUnread ? Theme.gold : .secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .patientAtmosphere(Theme.gold)
        .themedScreen()
        .navigationTitle(L10n.messagesTitle)
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        if store.isDemoMode || DemoData.isDemoID(patient.id) {
            messages = []
            didFail = false
            isLoading = false
            return
        }
        guard let patientId = patient.id.uuidValue else {
            messages = []
            didFail = true
            return
        }
        if messages.isEmpty { isLoading = true }
        didFail = false
        defer { isLoading = false }
        do {
            messages = try await PatientMessageService(client: auth.client)
                .messages(patientId: patientId)
        } catch {
            didFail = true
            if messages.isEmpty { messages = [] }
        }
    }
}

/// Latest-message / list row card matching Patient Mode task cards.
struct PatientModeMessageCard: View {
    enum Kind {
        case home
        case list
    }

    let message: PatientMessage
    let kind: Kind
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                if message.isUnread {
                    Text(kind == .home ? L10n.newMessageLabel : L10n.messageNewBadge)
                        .font(.headline)
                        .foregroundStyle(Theme.gold)
                }
                Text(message.body)
                    .font(.body)
                    .foregroundStyle(Theme.textBright)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(L10n.notificationTimestamp(message.createdAt))
                        .font(.footnote)
                        .foregroundStyle(Theme.textBody)
                    if kind == .list {
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.forward")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.gold)
                            .accessibilityHidden(true)
                    }
                }
                if kind == .home {
                    homeAffordance
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .themedCard()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(L10n.showMessageAction)
    }

    private var homeAffordance: some View {
        HStack(spacing: 6) {
            Text(L10n.showMessageAction)
                .fontWeight(.semibold)
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
        }
        .font(.body)
        .foregroundStyle(message.isUnread ? Theme.textOnAccent : Theme.gold)
        .padding(.vertical, message.isUnread ? 13 : 0)
        .padding(.horizontal, message.isUnread ? 16 : 0)
        .frame(maxWidth: message.isUnread ? .infinity : nil, alignment: .leading)
        .background {
            if message.isUnread {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.accentFill)
            }
        }
    }

    private var accessibilityLabel: String {
        var parts: [String] = []
        if message.isUnread {
            parts.append(kind == .home ? L10n.newMessageLabel : L10n.messageNewBadge)
        }
        parts.append(PatientMessage.preview(message.body))
        parts.append(L10n.notificationTimestamp(message.createdAt))
        return parts.joined(separator: ". ")
    }
}

/// Patient Mode inbox. Read is only marked from the detail screen.
struct PatientMessagesInboxView: View {
    @Binding var messages: [PatientMessage]
    let patientId: UUID
    var onMarkedRead: (PatientMessage) -> Void

    @Environment(AuthManager.self) private var auth

    @State private var isLoading = false
    @State private var didFail = false
    @State private var openedMessageID: UUID?

    var body: some View {
        Group {
            if isLoading && messages.isEmpty {
                ProgressView()
                    .tint(Theme.gold)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if didFail && messages.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L10n.patientMessagesLoadFailedTitle)
                        .font(.body)
                        .foregroundStyle(Theme.textBright)
                    Button(L10n.retry) {
                        Task { await load() }
                    }
                    .buttonStyle(.pressableProminent)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else if messages.isEmpty {
                Text(L10n.patientMessagesEmptyTitle)
                    .font(.body)
                    .foregroundStyle(Theme.textBody)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .themedCard()
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, 24)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(messages) { message in
                            PatientModeMessageCard(message: message, kind: .list) {
                                openedMessageID = message.id
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .patientAtmosphere(Theme.gold)
        .background(Theme.base.ignoresSafeArea())
        .navigationTitle(L10n.messagesTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $openedMessageID) { id in
            if let message = messages.first(where: { $0.id == id }) {
                PatientMessageDetailView(message: message) { updated in
                    if let index = messages.firstIndex(where: { $0.id == updated.id }) {
                        messages[index] = updated
                    }
                    onMarkedRead(updated)
                }
            } else {
                ContentUnavailableView {
                    Label(L10n.patientMessagesEmptyTitle, systemImage: "envelope")
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        if messages.isEmpty { isLoading = true }
        didFail = false
        defer { isLoading = false }
        do {
            messages = try await PatientMessageService(client: auth.client)
                .messages(patientId: patientId)
        } catch {
            didFail = true
        }
    }
}

struct PatientMessageDetailView: View {
    let message: PatientMessage
    var onMarkedRead: (PatientMessage) -> Void

    @Environment(AuthManager.self) private var auth

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.messageFromTherapist)
                    .font(.headline)
                    .foregroundStyle(Theme.textBright)
                Text(L10n.notificationTimestamp(message.createdAt))
                    .font(.footnote)
                    .foregroundStyle(Theme.textBody)
                Text(message.body)
                    .font(.body)
                    .foregroundStyle(Theme.textBright)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard()
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .patientAtmosphere(Theme.gold)
        .background(Theme.base.ignoresSafeArea())
        .navigationTitle(L10n.messageDetailTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await markReadIfNeeded() }
    }

    private func markReadIfNeeded() async {
        guard message.isUnread else { return }
        do {
            try await PatientMessageService(client: auth.client).markRead(id: message.id)
            onMarkedRead(message.markedRead(at: Date()))
        } catch {
            #if DEBUG
            AppLog.store.debug(
                "mark_patient_message_read failed id=\(message.id.uuidString, privacy: .public)"
            )
            #endif
        }
    }
}
