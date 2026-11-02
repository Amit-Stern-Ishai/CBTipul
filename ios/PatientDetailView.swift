import SwiftUI

/// Patient workspace with grouped sending actions, explicit connection guidance,
/// and a separate notes editor that retains voice transcription.
struct PatientDetailView: View {
    @Bindable var patient: Patient

    @Environment(AuthManager.self) private var auth
    @Environment(PatientStore.self) private var store
    @Environment(GettingStartedRouter.self) private var gettingStartedRouter
    @Environment(TherapistProfileService.self) private var therapistProfiles
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private enum RecordRoute: String, Identifiable {
        case sessions, graphs, diaries, questionnaires
        var id: String { rawValue }
    }
    @ScaledMetric(relativeTo: .title2) private var patientNameSize = 24.0
    @State private var headerBottom: CGFloat = 340
    @State private var recordRoute: RecordRoute?
    @State private var journeyRoute: PatientJourneyRoute?
    @State private var newSession: Session?
    @State private var latestSessionToOpen: Session?
    @State private var isSaving = false
    @State private var isShowingNotes = false
    @State private var isShowingSendOptions = false
    @State private var changingPatientAccess = false
    @State private var isShowingConnectionInfo = false
    @State private var pendingInvitationFromInfo = false
    @State private var pendingSendAction: PatientSendAction?
    @State private var isShowingNotesBackWarning = false
    /// Status line under the busy spinner; the anonymization notice during
    /// saves, nothing during deletes.
    @State private var busyLabel: String?
    @State private var errorMessage: String?
    @State private var isShowingBackWarning = false
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingDeleteCodeChallenge = false
    @State private var initialNotes: String?
    @State private var isEditingGoal = false
    @State private var goalDraft = ""
    @State private var isGoalExpanded = false
    @State private var isEditingName = false
    @State private var firstNameDraft = ""
    @State private var lastNameDraft = ""
    @State private var statusDraft: PatientStatus = .active
    @State private var voiceRecorder = VoiceNoteRecorder()
    @State private var isTranscribing = false
    /// True while a fresh transcript is being anonymized, before it may
    /// appear in the notes field.
    @State private var isAnonymizingTranscription = false
    @State private var isPreparing = false
    @State private var preparationResult: NextSessionPreparationResult?
    @State private var savedPreparation: SavedPreparation?
    /// Programmatic push into sessions from Getting Started.
    @State private var isShowingSessions = false
    @State private var sessionsInitialAction: SessionsInitialAction?
    @State private var isShowingPreparationInsufficient = false
    @State private var preparationMissingAction: PreparationMissingAction = .addSession
    @State private var isCreatingInvitation = false
    @State private var isShowingDisplayNameForInvite = false
    @State private var pendingInvitationAfterDisplayName = false
    @State private var invitationError: String?
    @State private var invitationShare: InvitationSharePayload?
    @State private var isShowingMessageComposer = false
    @State private var isSendingToPatient = false
    @State private var sendFeedbackTitle: String?
    @State private var sendFeedbackMessage: String?
    @State private var refreshedConnectionState: PatientConnectionState?

    private var connectionState: PatientConnectionState {
        guard !store.isDemoMode, !DemoData.isDemoID(patient.id), let patientId = patient.id.uuidValue else {
            return .unavailable
        }
        if let connected = assignmentService().cachedPatientConnection(patientId: patientId) {
            return connected ? .connected : .notConnected
        }
        return refreshedConnectionState ?? .checking
    }

    /// A saved preparation goes stale once a session dated after its
    /// generation has already taken place — i.e. the session it prepared
    /// for is in the past. A session merely scheduled for a future date
    /// (or today) doesn't outdate it. Session dates are date-only, so
    /// "passed" means any day before today.
    private var isSavedPreparationOutdated: Bool {
        guard let savedPreparation else { return false }
        let startOfToday = Calendar.current.startOfDay(for: .now)
        return patient.sessions.contains {
            $0.date > savedPreparation.generatedAt && $0.date < startOfToday
        }
    }

    /// Whether anything would be lost by leaving without saving: edited
    /// notes or a voice note that hasn't been transcribed yet. Status saves
    /// immediately. The treatment goal is not included — its edit sheet
    /// saves immediately.
    private var hasUnsavedChanges: Bool {
        if let initialNotes, initialNotes != patient.notes { return true }
        if voiceRecorder.recordingURL != nil { return true }
        return false
    }

    /// The formulation's treatment goal, edited directly on the patient's
    /// formulation so the header and My Formulation stay in sync.
    private var treatmentGoal: Binding<String> {
        Binding(
            get: { patient.formulation?.treatmentGoal ?? "" },
            set: { newValue in
                var formulation = patient.formulation ?? .empty
                formulation.treatmentGoal = newValue.isEmpty ? nil : newValue
                patient.formulation = formulation
            }
        )
    }

    /// The patient's identity color — the exact color of their list avatar.
    /// Used only for patient-specific accents; gold remains the color of
    /// app actions and navigation, navy the primary surfaces.
    private var patientColor: Color {
        PatientAvatarColor.background(for: patient.id)
    }

    /// This screen's group outlines, in the patient's identity color.
    private func groupBorderedRow(_ position: GroupRowPosition) -> some View {
        CBTipul.groupBorderedRow(position, accent: patientColor)
    }

    /// Whether the pending-recording controls row is showing under the notes.
    private var isRecordingRetryRowVisible: Bool {
        voiceRecorder.recordingURL != nil && !isTranscribing && !isAnonymizingTranscription
    }

    /// Whether the transcription/anonymization spinner row is showing.
    private var isTranscribeSpinnerVisible: Bool {
        isTranscribing || isAnonymizingTranscription
    }

    private var patientScreenContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 6) {
                    patientIdentity
                    goalOverview
                    PatientJourneySection(patient: patient, inHeader: true) { journeyRoute = PatientJourneyRoute(groupID: $0) }
                }
                .padding(.horizontal, 16).padding(.bottom, 8)
                .padding(.horizontal, -12)
                .onGeometryChange(for: CGFloat.self) { geometry in
                    geometry.frame(in: .global).maxY
                } action: { headerBottom = $0 }
                connectionCard
                    .padding(.horizontal, 10)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.borderDefault, lineWidth: 1) }
                    .padding(.top, Theme.isPaper ? 2 : 10).padding(.bottom, Theme.isPaper ? 2 : 10)
                PatientRecentActivityView(patient: patient)
                VStack(spacing: 8) {
                    sessionActions
                    if let latest = latestRecordedSession {
                        Button { latestSessionToOpen = latest } label: {
                            HStack(spacing: 8) {
                                Label(L10n.patientLatestSessionAction, systemImage: "clock.arrow.circlepath")
                                    .font(.subheadline.weight(.semibold))
                                Spacer(minLength: 4)
                                Text(L10n.hebrewDate(latest.date)).font(.caption).foregroundStyle(Theme.textBody)
                                Image(systemName: "chevron.forward").font(.caption.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .padding(.horizontal, 12)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.borderDefault))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("patient.latestSession")
                    }
                }
                .padding(.vertical, 12)
                VStack(alignment: .leading, spacing: 4) {
                sectionHeading(L10n.patientRecordsTitle)
                recordActions
                NavigationLink { PatientAIView(patient: patient) } label: {
                    recordLabel("sparkles", L10n.patientAICompact, emphasized: true)
                        .accessibilityLabel(L10n.aiChatNavigationTitle)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("patient.aiChat")
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
                layout {
                    Button { errorMessage = nil; isShowingNotes = true } label: {
                        recordLabel("note.text", L10n.patientNotesCompact).accessibilityLabel(L10n.patientNotesTitle)
                    }.accessibilityIdentifier("patient.notes")
                    NavigationLink { TherapistPatientMessagesView(patient: patient) } label: {
                        recordLabel("envelope", L10n.messagesTitle)
                    }.accessibilityIdentifier("patient.messages")
                }
                .buttonStyle(.plain)
                }
                .padding(8)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.borderFaint, lineWidth: 1) }
                if let savedPreparation {
                    Button {
                        preparationResult = NextSessionPreparationResult(response: savedPreparation.response,
                                                                          isOutdated: isSavedPreparationOutdated)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            recordLabel("doc.text.magnifyingglass", L10n.lastPreparationAction)
                            Text(L10n.hebrewDate(savedPreparation.generatedAt)).font(.caption)
                            if isSavedPreparationOutdated { Text(L10n.outdatedBadge).font(.caption).foregroundStyle(Theme.warning) }
                        }
                    }.buttonStyle(.plain)
                }
                if let errorMessage { AIUsageNotice(message: errorMessage) }
            }
            .padding(.horizontal, 12).padding(.bottom, 16)
        }
        .background {
            GeometryReader { geometry in
                PatientHeaderBackdrop(accent: patientColor)
                    .frame(height: max(0, headerBottom - geometry.frame(in: .global).minY))
                    .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 24, bottomTrailingRadius: 24))
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    var body: some View {
        patientScreenContent
        .navigationDestination(item: $recordRoute) { route in
            switch route {
            case .sessions: PatientSessionsView(patient: patient)
            case .graphs: PatientQuestionnairesView(patient: patient, startsOnGraphs: true)
            case .diaries: diaryDirectory
            case .questionnaires: PatientQuestionnairesView(patient: patient)
            }
        }
        .navigationDestination(item: $journeyRoute) { _ in
            PatientJourneyHistory(patient: patient)
        }
        .patientAtmosphere(patientColor)
        .themedScreen()
        .scrollDismissesKeyboard(.interactively)
        .dismissesKeyboardOnTap()
        .demoModeChrome()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(Theme.isPaper ? .light : .dark, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .background(EnablesSwipeBack(isEnabled: !hasUnsavedChanges && !isSaving))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if hasUnsavedChanges {
                        isShowingBackWarning = true
                    } else {
                        dismiss()
                    }
                } label: {
                    Label(L10n.back, systemImage: "chevron.backward")
                }
                .disabled(isSaving)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button(L10n.editPatientDetailsAction) { startEditingName() }
                    if connectionState == .connected {
                        Button(L10n.patientReinviteAction) { isShowingConnectionInfo = true }
                            .entitlementCreateControl()
                            .accessibilityIdentifier("patient.reinvite")
                            .disabled(isSendingToPatient)
                    }
                    Picker(L10n.statusLabel, selection: Binding(
                        get: { patient.status }, set: { savePatientStatus($0) }
                    )) {
                        ForEach(PatientStatus.allCases) { status in
                            Text(L10n.patientStatus(status)).tag(status)
                        }
                    }
                    .entitlementCreateControl()
                    Button(L10n.deletePatientAction, role: .destructive) {
                        isShowingDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                }
                .disabled(isSaving || isCreatingInvitation)
            }
        }
        .alert(L10n.deletePatientConfirmTitle,
               isPresented: $isShowingDeleteConfirmation) {
            Button(L10n.deletePatientAction, role: .destructive) {
                isShowingDeleteCodeChallenge = true
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.deletePatientConfirmMessage)
        }
        .deleteCodeChallenge(isPresented: $isShowingDeleteCodeChallenge) { deletePatient() }
        .sheet(isPresented: $isEditingName) {
            NavigationStack {
                Form {
                    Section(L10n.patientSectionTitle) {
                        // Explicit leading (visual right) alignment: with the
                        // default natural alignment the caret side follows the
                        // keyboard language, landing left under an English
                        // keyboard.
                        TextField(L10n.firstNamePlaceholder, text: $firstNameDraft, prompt: Text("")).entitlementWriteControl()
                            .multilineTextAlignment(.leading)
                            .stablePlaceholder(L10n.firstNamePlaceholder, isShown: firstNameDraft.isEmpty)
                        TextField(L10n.lastNamePlaceholder, text: $lastNameDraft, prompt: Text("")).entitlementWriteControl()
                            .multilineTextAlignment(.leading)
                            .stablePlaceholder(L10n.lastNamePlaceholder, isShown: lastNameDraft.isEmpty)
                    }
                    .listRowBackground(Theme.surface)
                    Section {
                        Picker(L10n.statusLabel, selection: $statusDraft) {
                            ForEach(PatientStatus.allCases) { Text(L10n.patientStatus($0)).tag($0) }
                        }
                    }
                    .listRowBackground(Theme.surface)
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(Theme.error)
                    }

                }
                .themedScreen()
                .demoModeChrome()
                .navigationTitle(L10n.editPatientDetailsAction)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.cancel) { isEditingName = false }
                            .disabled(isSaving)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.save) { saveEditedName() }
                            .disabled(isSaving || (firstNameDraft.trimmingCharacters(in: .whitespaces).isEmpty
                                      && lastNameDraft.trimmingCharacters(in: .whitespaces).isEmpty))
                    }
                }
            }
            .disabled(isSaving)
            .interactiveDismissDisabled(isSaving)
            .appTextSize()
            .presentationDetents([.medium, .large])
        }
        // An alert, not a confirmation dialog: iPad popover dialogs hide
        // cancel-role buttons, and Keep Editing must always be offered.
        .alert(L10n.discardChangesTitle,
               isPresented: $isShowingBackWarning) {
            Button(L10n.saveChangesAction) { save(thenDismiss: true) }
            Button(L10n.discardChangesAction, role: .destructive) {
                // The patient object is shared, so revert the edits instead
                // of leaving them in memory unsaved.
                if let initialNotes { patient.notes = initialNotes }
                voiceRecorder.discard()
                dismiss()
            }
            Button(L10n.keepEditingAction, role: .cancel) {}
        }
        .sheet(item: $preparationResult) { result in
            NextSessionPreparationView(response: result.response, accent: patientColor)
        }
        .sheet(isPresented: $isEditingGoal) {
            NavigationStack {
                Form {
                    Section {
                        TextField(L10n.noTreatmentGoalPlaceholder, text: $goalDraft, axis: .vertical).entitlementWriteControl()
                            .disabled(isSaving)
                        if isSaving { ProgressView() }
                        if let errorMessage { Text(errorMessage).foregroundStyle(Theme.error) }
                    }
                    .listRowBackground(Theme.surface)
                }
                // Same chrome as the edit-name sheet: without themedScreen
                // the form shows the system grey grouped background, which
                // then flips appearance when the keyboard focuses the field.
                .themedScreen()
                .demoModeChrome()
                .navigationTitle(L10n.treatmentGoalSection)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.cancel) { isEditingGoal = false }.disabled(isSaving)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.save) { saveGoal() }.disabled(isSaving)
                    }
                }
            }
            .presentationDetents([.medium])
            .interactiveDismissDisabled(isSaving)
            .appTextSize()
        }
        .busyOverlay(isSaving || isCreatingInvitation || isSendingToPatient, label: busyLabel)
        .alert(L10n.patientInvitationFailedTitle,
               isPresented: .init(
                get: { invitationError != nil },
                set: { if !$0 { invitationError = nil } }
               )) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(invitationError ?? "")
        }
        .sheet(isPresented: $isShowingConnectionInfo, onDismiss: {
            guard pendingInvitationFromInfo else { return }
            pendingInvitationFromInfo = false
            guard connectionState == .notConnected || connectionState == .connected else { return }
            startPatientInvitation()
        }) {
            connectionInfoSheet
        }
        .sheet(isPresented: $isShowingDisplayNameForInvite, onDismiss: {
            resumeInvitationAfterDisplayNameIfNeeded()
        }) {
            TherapistDisplayNameEditorView(requirement: .required)
        }
        .sheet(item: $invitationShare, onDismiss: {
            Task { await refreshConnectionState() }
        }) { payload in
            ActivityShareSheet(
                items: [
                    InvitationShareActivityItem(body: payload.text, subject: payload.subject, htmlBody: payload.html, emailBody: payload.emailText)
                ]
            )
                .presentationDetents([.medium])
        }
        .subtleAnimation(value: errorMessage)
        .subtleAnimation(value: isTranscribing)
        .subtleAnimation(value: isAnonymizingTranscription)
        .sheet(item: $latestSessionToOpen) { session in
            SessionEditorView(session: session, patient: patient, isNew: false,
                              sessionNumber: patient.sessions.sorted { $0.date < $1.date }.firstIndex { $0.id == session.id }.map { $0 + 1 })
                .appTextSize()
        }
        .sheet(item: $newSession) { session in
            SessionEditorView(session: session, patient: patient, isNew: true).appTextSize()
        }
        .navigationDestination(isPresented: $isShowingSessions) {
            PatientSessionsView(patient: patient, initialAction: sessionsInitialAction)
        }
        .sheet(isPresented: $isShowingPreparationInsufficient) {
            PreparationInsufficientSheet(action: preparationMissingAction) {
                isShowingPreparationInsufficient = false
                handlePreparationMissingAction(preparationMissingAction)
            }
            .presentationDetents([.medium])
            .appTextSize()
        }
        .onAppear {
            if initialNotes == nil {
                initialNotes = patient.notes
            }
            if savedPreparation == nil {
                savedPreparation = SavedPreparation.load(for: patient.id)
            }
            // Always re-assert: returning from sessions must update the coach
            // path for this screen again.
            gettingStartedRouter.setPlacement(.patientDetail, viewingPatientID: patient.id)
            gettingStartedRouter.refresh(using: store)
            applyGettingStartedFocusIfNeeded()
        }
        .onChange(of: isShowingSessions) { _, showing in
            if showing {
                gettingStartedRouter.setPlacement(.sessions, viewingPatientID: patient.id)
            } else {
                gettingStartedRouter.setPlacement(.patientDetail, viewingPatientID: patient.id)
            }
            gettingStartedRouter.refresh(using: store)
        }
        .onChange(of: patient.sessions.count) { _, _ in
            gettingStartedRouter.refresh(using: store)
        }
        .sheet(isPresented: $isShowingSendOptions, onDismiss: performPendingSendAction) {
            sendOptionsSheet
        }
        .sheet(isPresented: $isShowingMessageComposer) {
            SendPatientMessageComposerView(patient: patient) {
                presentSendFeedback(
                    title: L10n.sendPatientMessageAction,
                    message: L10n.sendPatientMessageSuccess
                )
            }
            .appTextSize()
        }
        .alert(
            sendFeedbackTitle ?? "",
            isPresented: .init(
                get: { sendFeedbackTitle != nil },
                set: { if !$0 { sendFeedbackTitle = nil; sendFeedbackMessage = nil } }
            )
        ) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            if let sendFeedbackMessage {
                Text(sendFeedbackMessage)
            }
        }
        .sheet(isPresented: $isShowingNotes) {
            notesEditor
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refreshConnectionState() }
            }
        }
        .refreshable { await refreshConnectionState() }
        .task {
            await refreshConnectionState()
            if store.cachedQuestionnaires(for: patient) == nil {
                _ = try? await store.loadQuestionnaires(for: patient)
            }
        }
    }

    private var notesBusy: Bool {
        isSaving || voiceRecorder.isRecording || isTranscribing || isAnonymizingTranscription
    }

    private var notesEditor: some View {
        NavigationStack {
            List {
                notesSection
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(Theme.error)
                }
            }
            .themedScreen()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(L10n.patientNotesTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.back) {
                        if hasUnsavedChanges {
                            isShowingNotesBackWarning = true
                        } else {
                            isShowingNotes = false
                        }
                    }
                    .disabled(notesBusy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) { save(closeNotes: true) }
                        .disabled(notesBusy || !hasUnsavedChanges || voiceRecorder.recordingURL != nil)
                }
            }
            .alert(L10n.discardChangesTitle, isPresented: $isShowingNotesBackWarning) {
                if voiceRecorder.recordingURL == nil {
                    Button(L10n.saveChangesAction) { save(closeNotes: true) }
                }
                Button(L10n.discardChangesAction, role: .destructive) {
                    if let initialNotes { patient.notes = initialNotes }
                    voiceRecorder.discard()
                    isShowingNotes = false
                }
                Button(L10n.keepEditingAction, role: .cancel) {}
            }
            .busyOverlay(isSaving, label: busyLabel)
        }
        .interactiveDismissDisabled(hasUnsavedChanges || notesBusy)
        .appTextSize()
    }

    private var notesSection: some View {
        Section(L10n.notesSection) {
            VStack(alignment: .leading, spacing: 16) {
                NotesField(text: $patient.notes, placeholder: L10n.patientNotesFieldPlaceholder,
                           minLines: 5, maxLines: 12,
                           isEditable: !notesBusy)
                recordControl
                    .disabled(isSaving)
            }
            .listRowBackground(groupBorderedRow(
                isRecordingRetryRowVisible || isTranscribeSpinnerVisible
                    || voiceRecorder.errorMessage != nil ? .first : .only))
            // Transcription starts automatically when recording stops,
            // so this row only ever appears after a failed transcription
            // — the recording survives for a retry.
            if voiceRecorder.recordingURL != nil, !isTranscribing, !isAnonymizingTranscription {
                HStack(spacing: 16) {
                    Button {
                        voiceRecorder.togglePlayback()
                    } label: {
                        Label(voiceRecorder.isPlaying
                              ? L10n.stopPlaybackAction
                              : L10n.playRecordingAction,
                              systemImage: voiceRecorder.isPlaying
                              ? "stop.circle"
                              : "play.circle")
                    }
                    Spacer()
                    Button(L10n.transcribeAction) { transcribe() }
                        .fontWeight(.semibold)
                    Button(role: .destructive) {
                        voiceRecorder.discard()
                    } label: {
                        Label(L10n.discardRecordingAction, systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityLabel(L10n.discardRecordingAction)
                }
                .font(.subheadline)
                .buttonStyle(.borderless)
                .listRowBackground(groupBorderedRow(
                    voiceRecorder.errorMessage != nil ? .middle : .last))
            }

            if isTranscribing || isAnonymizingTranscription {
                HStack {
                    ProgressView()
                    Text(isTranscribing ? L10n.transcribingLabel : L10n.anonymizingStatusLabel)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(groupBorderedRow(
                    voiceRecorder.errorMessage != nil ? .middle : .last))
            }

            if let recorderError = voiceRecorder.errorMessage {
                Text(recorderError)
                    .font(.footnote)
                    .foregroundStyle(Theme.error)
                    .listRowBackground(groupBorderedRow(.last))
            }
        }
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title).font(.headline).foregroundStyle(Theme.textBright)
            .textCase(nil)
    }

    private var patientHeaderSurface: Color {
        PatientAvatarColor.headerBackground(for: patient.id)
    }

    private var patientIdentity: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(patient.displayName.split(separator: " ").prefix(2).compactMap(\.first)))
                .font(.title2.bold())
                .foregroundStyle(PatientAvatarColor.foreground(for: patient.id))
                .frame(width: 48, height: 48)
                .background(LinearGradient(colors: [patientColor, patientColor.opacity(0.68)], startPoint: .topTrailing, endPoint: .bottomLeading), in: Circle())
                .overlay { Circle().strokeBorder(.white.opacity(0.24), lineWidth: 1) }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(patient.displayName).font(.system(size: patientNameSize, weight: .bold)).foregroundStyle(Theme.headerInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(L10n.patientStatus(patient.status)).font(.caption).foregroundStyle(Theme.headerInk)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.black.opacity(0.22), in: Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 0)
    }

    private var goalOverview: some View {
        HStack(alignment: .center, spacing: 4) {
            Button { isGoalExpanded.toggle() } label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(L10n.treatmentGoalSection).font(.caption)
                        Spacer(minLength: 4)
                        if !dynamicTypeSize.isAccessibilitySize {
                            Image(systemName: isGoalExpanded ? "chevron.up" : "chevron.down").font(.caption2)
                        }
                    }.foregroundStyle(Theme.headerInk.opacity(0.85))
                    Text(treatmentGoal.wrappedValue.isEmpty ? L10n.noTreatmentGoalPlaceholder : treatmentGoal.wrappedValue)
                        .font(.subheadline.weight(.medium)).foregroundStyle(Theme.headerInk)
                        .lineLimit(isGoalExpanded || dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("patient.treatmentGoal")
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isGoalExpanded ? L10n.patientGoalCollapse : L10n.patientGoalExpand)
            .accessibilityIdentifier("patient.goal.expand")
            Button {
                guard EntitlementState.shared.allowMutation() else { return }
                goalDraft = treatmentGoal.wrappedValue
                isEditingGoal = true
            } label: { Image(systemName: "pencil").frame(width: 44, height: 44) }
                .buttonStyle(.plain).foregroundStyle(Theme.headerInk)
                .accessibilityLabel(L10n.editTreatmentGoalAction)
        }
        .padding(.leading, 10).padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial)
                .environment(\.colorScheme, Theme.isPaper ? .light : .dark).opacity(0.25)
        }
        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.headerLine, lineWidth: 1) }
    }

    private var latestRecordedSession: Session? {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now
        return patient.sessions.filter { $0.date < tomorrow }.max { $0.date < $1.date }
    }

    private var sessionActions: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            Button {
                if EntitlementState.shared.allowMutation() { newSession = Session() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus").accessibilityHidden(true)
                    Text(L10n.wwNewSession)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(Theme.textOnAccent)
                .background(Theme.accentFill, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain).entitlementCreateControl()
            .accessibilityIdentifier("patient.newSession")
            Button { requestPrepareNextSession() } label: {
                HStack {
                    if isPreparing { ProgressView().controlSize(.small) }
                    Text(L10n.prepareNextSessionAction).font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 8)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.borderStrong, lineWidth: 1) }
            }
            .buttonStyle(.plain).entitlementCreateControl().disabled(isPreparing)
            .accessibilityIdentifier("patient.prepareSession")
        }
    }

    private var recordActions: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8),
                                count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 4) {
            Button { recordRoute = .sessions } label: {
                recordLabel("calendar", L10n.sessionsTitle)
            }.accessibilityIdentifier("patient.sessions")
                .tutorialPulse(gettingStartedRouter.shouldPulse(.sessionsEntry)
                    && patient.id == gettingStartedRouter.progress.focusPatientID)
            Button { recordRoute = .graphs } label: {
                recordLabel("chart.xyaxis.line", L10n.graphsAndTrendsTitle)
            }.accessibilityIdentifier("patient.questionnaireGraphs")
            Button { recordRoute = .diaries } label: {
                recordLabel("book.closed", L10n.patientDiariesTitle)
            }.accessibilityIdentifier("patient.diaries")
            Button { recordRoute = .questionnaires } label: {
                recordLabel("list.clipboard", L10n.patientRecordQuestionnaires)
            }.accessibilityIdentifier("patient.questionnaireHistory")
        }
        .buttonStyle(.borderless)
    }

    private func recordLabel(_ icon: String, _ title: String, emphasized: Bool = false) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 20)).foregroundStyle(emphasized ? Color.purple : patientColor)
                .frame(width: 24).accessibilityHidden(true)
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textBright)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "chevron.forward").font(.caption).foregroundStyle(Theme.textBody).accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.horizontal, 10)
        .background(emphasized ? Color.purple.opacity(0.14) : Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(emphasized ? Color.purple.opacity(0.65) : Theme.borderDefault, lineWidth: 1) }
        .contentShape(Rectangle())
    }

    private var diaryDirectory: some View {
        List {
            Section {
                NavigationLink { PatientDiaryOneView(patient: patient) } label: {
                    diaryDirectoryLabel(L10n.diaryOneTitle)
                }
                .accessibilityIdentifier("patient.diaryOne")
                NavigationLink { PatientDiaryTwoView(patient: patient) } label: {
                    diaryDirectoryLabel(L10n.diaryTwoTitle)
                }
                .accessibilityIdentifier("patient.diaryTwo")
                NavigationLink { PatientDiaryThreeView(patient: patient) } label: {
                    diaryDirectoryLabel(L10n.diaryThreeTitle)
                }
                .accessibilityIdentifier("patient.diaryThree")
            }
            .listRowBackground(Theme.surface)
            .listRowSeparatorTint(Theme.borderFaint)
        }
        .listStyle(.insetGrouped)
        .themedScreen()
        .navigationTitle(L10n.patientDiariesTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func diaryDirectoryLabel(_ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.title3)
                .foregroundStyle(Theme.gold)
                .frame(width: 40, height: 40)
                .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.textBright)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 48)
        .padding(.vertical, 4)
    }

    private var connectionStatusTitle: String {
        switch connectionState {
        case .connected: L10n.patientConnectedStatus
        case .notConnected: L10n.patientNotConnectedStatus
        case .unavailable: L10n.patientInvitationDemoStatus
        case .checking: L10n.patientConnectionChecking
        case .failed: L10n.patientConnectionUnavailableStatus
        }
    }

    private var connectionStatusIcon: String {
        switch connectionState {
        case .connected: "checkmark.circle.fill"
        case .checking: "hourglass"
        case .failed: "exclamationmark.circle"
        default: "lock"
        }
    }

    private var connectionActionTitle: String {
        switch connectionState {
        case .connected, .checking: L10n.sendToPatientAction
        case .failed: L10n.retry
        default: L10n.patientInviteToAppAction
        }
    }

    private var connectionCard: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            connectionSummary
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            connectionAction
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("patient.connection")
    }

    private var connectionSummary: some View {
        HStack(spacing: 8) {
            if connectionState == .checking { ProgressView().controlSize(.small) }
            else { Image(systemName: connectionStatusIcon).accessibilityHidden(true) }
            Text(connectionState == .connected ? L10n.patientConnectedCompact : connectionStatusTitle).font(.caption)
                .accessibilityLabel(connectionStatusTitle)
        }
        .foregroundStyle(connectionState == .connected ? Theme.success : Theme.textBody)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var connectionAction: some View {
        if connectionState != .checking {
            Button {
                if connectionState == .failed { Task { await refreshConnectionState() } }
                else if EntitlementState.shared.allowMutation() {
                    if connectionState == .connected {
                        pendingSendAction = nil
                        isShowingSendOptions = true
                    } else { isShowingConnectionInfo = true }
                }
            } label: {
                Label(connectionState == .connected ? L10n.patientSendCompact : connectionActionTitle, systemImage: connectionState == .connected ? "paperplane" : "person.crop.circle.badge.plus")
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 10)
                    .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.gold, lineWidth: 1) }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Theme.gold)
            .disabled(isCreatingInvitation || isSaving || isSendingToPatient)
            .accessibilityLabel(connectionActionTitle)
            .accessibilityIdentifier(connectionState == .connected ? "patient.sending" : "patient.connectionInfo")

        }
    }

    private var connectionInfoSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(patient.displayName)
                        .font(.title2.bold())
                    if connectionState != .connected { Text(L10n.patientConnectDescription) }
                    switch connectionState {
                    case .notConnected, .connected:
                        Text(connectionState == .connected ? L10n.patientReinviteExplanation : L10n.patientShareInvitationExplanation)
                            .foregroundStyle(.secondary)
                        Button {
                            pendingInvitationFromInfo = true
                            isShowingConnectionInfo = false
                        } label: {
                            Label(L10n.patientShareInvitationAction, systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity, minHeight: 30)
                        }
                        .buttonStyle(.pressableProminent)
                        .accessibilityIdentifier("patient.shareInvitation")
                        .entitlementCreateControl()
                    case .unavailable:
                        Text(L10n.patientInvitationUnavailableExplanation)
                            .foregroundStyle(.secondary)
                    case .checking:
                        ProgressView(L10n.patientConnectionChecking)
                    case .failed:
                        Text(L10n.patientConnectionCheckError)
                        Button(L10n.retry) { Task { await refreshConnectionState() } }
                    }
                    if connectionState != .connected {
                        Text(L10n.patientConnectionOptionalExplanation)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(24)
            }
            .themedScreen()
            .navigationTitle(connectionState == .connected ? L10n.patientReinviteAction : L10n.patientInviteToAppAction)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.closeAction) { isShowingConnectionInfo = false }
                        .accessibilityIdentifier("patient.connectionInfo.done")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .appTextSize()
    }

    private enum PatientSendAction {
        case message, diaryOne, diaryTwo, diaryThree
    }

    private var sendingUnavailableNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L10n.patientSendingUnavailableTitle, systemImage: "lock.fill")
                .font(.subheadline.weight(.semibold))
            Text(sendingUnavailableDescription)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("patient.sendingUnavailable")
    }

    private var sendingUnavailableDescription: String {
        switch connectionState {
        case .notConnected: L10n.patientSendingRequiresConnection
        case .unavailable: L10n.patientSendingUnavailableHere
        case .checking: L10n.patientConnectionChecking
        case .failed: L10n.patientConnectionCheckError
        case .connected: L10n.patientSendingDescription
        }
    }

    private var sendOptionsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.messageRecipient(patient.displayName))
                            .font(.title3.bold())
                        Text(L10n.patientChooseSendAction)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if connectionState == .connected {
                        sendOption(.message, icon: "envelope", title: L10n.writePatientMessageAction,
                                   detail: L10n.patientSendMessageDescription)
                            .disabled(changingPatientAccess)
                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.accessToolsTitle).font(.headline)
                            Text(L10n.accessToolsExplanation).font(.subheadline).foregroundStyle(.secondary)
                        }
                        ForEach([PatientAssignmentType.questionnaire, .diaryOne, .diaryTwo] +
                                (PatientAssignmentType.diaryThreeSendingEnabled ? [.diaryThree] : []), id: \.rawValue) { type in
                            PatientToolAccessControl(patient: patient, type: type, parentBusy: changingPatientAccess,
                                                     onBusyChanged: { changingPatientAccess = $0 })
                                .padding(18)
                                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                        }
                    } else {
                        sendingUnavailableNotice
                    }
                }
                .padding(20)
            }
            .themedScreen()
            .navigationTitle(L10n.sendToPatientAction)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { isShowingSendOptions = false }.disabled(changingPatientAccess)
                }
            }
        }
        .interactiveDismissDisabled(changingPatientAccess)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .appTextSize()
    }

    private func sendOption(_ action: PatientSendAction, icon: String, title: String, detail: String) -> some View {
        Button {
            pendingSendAction = action
            isShowingSendOptions = false
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Theme.gold)
                    .frame(width: 40, height: 40)
                    .background(Theme.goldGhost, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Theme.textBright)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(18)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.borderFaint)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(isSendingToPatient || isSaving)
        .entitlementCreateControl()
    }

    /// Wait for the selector to dismiss before presenting the composer or feedback.
    private func performPendingSendAction() {
        guard let action = pendingSendAction else { return }
        pendingSendAction = nil
        guard connectionState == .connected else {
            presentSendFeedback(title: L10n.patientSendingUnavailableTitle,
                                message: sendingUnavailableDescription)
            return
        }
        switch action {
        case .message: isShowingMessageComposer = true
        case .diaryOne: sendDiaryOne()
        case .diaryTwo: sendDiaryTwo()
        case .diaryThree: sendDiaryThree()
        }
    }

    private func diaryPlaceholder(_ title: String) -> some View {
        HStack {
            Label(title, systemImage: "book.closed")
            Spacer()
            Text(L10n.diaryComingSoon)
                .font(.subheadline)
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    /// Consumes a one-shot Getting Started request into sessions.
    private func applyGettingStartedFocusIfNeeded() {
        guard let action = gettingStartedRouter.consumeSessionsAction() else { return }
        sessionsInitialAction = action
        isShowingSessions = true
    }

    private func assignmentService() -> PatientAssignmentService {
        PatientAssignmentService(client: auth.client)
    }

    private func refreshConnectionState() async {
        if store.isDemoMode || DemoData.isDemoID(patient.id) {
            refreshedConnectionState = .unavailable
            return
        }
        guard let patientId = patient.id.uuidValue else {
            refreshedConnectionState = .unavailable
            return
        }
        do {
            refreshedConnectionState = try await assignmentService().isPatientConnected(patientId: patientId)
                ? .connected
                : .notConnected
        } catch is CancellationError {
            return
        } catch {
            refreshedConnectionState = .failed
        }
    }

    private func sendDiaryOne() {
        guard EntitlementState.shared.allowMutation() else { return }
        guard !isSendingToPatient else { return }
        if store.isDemoMode || DemoData.isDemoID(patient.id) {
            presentSendFeedback(
                title: L10n.patientNotConnectedTitle,
                message: L10n.patientNotConnectedBody
            )
            return
        }
        guard let patientId = patient.id.uuidValue else {
            presentSendFeedback(
                title: L10n.diaryPatientModeTitle,
                message: L10n.patientInvitationInvalidPatientError
            )
            return
        }
        isSendingToPatient = true
        Task {
            defer { isSendingToPatient = false }
            try? await Task.sleep(for: .milliseconds(250))
            do {
                _ = try await assignmentService().activateOngoingAssignment(
                    patientId: patientId,
                    type: .diaryOne
                )
                presentSendFeedback(
                    title: L10n.diaryOneTitle,
                    message: L10n.diaryOneSentToPatient
                )
            } catch PatientAssignmentError.patientNotConnected {
                presentSendFeedback(
                    title: L10n.patientNotConnectedTitle,
                    message: L10n.patientNotConnectedBody
                )
            } catch {
                presentSendFeedback(
                    title: L10n.diaryPatientModeTitle,
                    message: L10n.diaryPatientModeActivateFailed
                )
            }
        }
    }

    private func sendDiaryTwo() {
        guard EntitlementState.shared.allowMutation() else { return }
        guard !isSendingToPatient else { return }
        if store.isDemoMode || DemoData.isDemoID(patient.id) {
            presentSendFeedback(
                title: L10n.patientNotConnectedTitle,
                message: L10n.patientNotConnectedBody
            )
            return
        }
        guard let patientId = patient.id.uuidValue else {
            presentSendFeedback(
                title: L10n.diaryPatientModeTitle,
                message: L10n.patientInvitationInvalidPatientError
            )
            return
        }
        isSendingToPatient = true
        Task {
            defer { isSendingToPatient = false }
            try? await Task.sleep(for: .milliseconds(250))
            do {
                _ = try await assignmentService().activateOngoingAssignment(
                    patientId: patientId,
                    type: .diaryTwo
                )
                presentSendFeedback(
                    title: L10n.diaryTwoTitle,
                    message: L10n.diaryTwoSentToPatient
                )
            } catch PatientAssignmentError.patientNotConnected {
                presentSendFeedback(
                    title: L10n.patientNotConnectedTitle,
                    message: L10n.patientNotConnectedBody
                )
            } catch {
                presentSendFeedback(
                    title: L10n.diaryPatientModeTitle,
                    message: L10n.diaryPatientModeActivateFailed
                )
            }
        }
    }

    private func sendDiaryThree() {
        guard EntitlementState.shared.allowMutation() else { return }
        guard !isSendingToPatient else { return }
        if store.isDemoMode || DemoData.isDemoID(patient.id) {
            presentSendFeedback(
                title: L10n.patientNotConnectedTitle,
                message: L10n.patientNotConnectedBody
            )
            return
        }
        guard let patientId = patient.id.uuidValue else {
            presentSendFeedback(
                title: L10n.diaryPatientModeTitle,
                message: L10n.patientInvitationInvalidPatientError
            )
            return
        }
        isSendingToPatient = true
        Task {
            defer { isSendingToPatient = false }
            try? await Task.sleep(for: .milliseconds(250))
            do {
                _ = try await assignmentService().activateOngoingAssignment(
                    patientId: patientId,
                    type: .diaryThree
                )
                presentSendFeedback(
                    title: L10n.diaryThreeTitle,
                    message: L10n.diaryThreeSentToPatient
                )
            } catch PatientAssignmentError.patientNotConnected {
                presentSendFeedback(
                    title: L10n.patientNotConnectedTitle,
                    message: L10n.patientNotConnectedBody
                )
            } catch {
                presentSendFeedback(
                    title: L10n.diaryPatientModeTitle,
                    message: L10n.diaryPatientModeActivateFailed
                )
            }
        }
    }

    private func presentSendFeedback(title: String, message: String) {
        sendFeedbackTitle = title
        sendFeedbackMessage = message
    }

    /// Gates preparation behind useful clinical input and a one-time tip.
    private func requestPrepareNextSession() {
        guard EntitlementState.shared.allowMutation() else { return }
        errorMessage = nil
        Task {
            let questionnaires: [CompletedQuestionnaire]
            if let cached = store.cachedQuestionnaires(for: patient) {
                questionnaires = cached
            } else {
                questionnaires = (try? await store.loadQuestionnaires(for: patient)) ?? []
            }
            if !GettingStartedProgress.hasUsefulPreparationInput(
                patient: patient,
                questionnaires: questionnaires
            ) {
                preparationMissingAction = GettingStartedProgress.missingPreparationAction(for: patient)
                isShowingPreparationInsufficient = true
                return
            }
            prepareNextSession()
        }
    }

    private func handlePreparationMissingAction(_ action: PreparationMissingAction) {
        switch action {
        case .addSession:
            sessionsInitialAction = .addSession
            isShowingSessions = true
        case .addSessionSummary:
            sessionsInitialAction = .editLatestForSummary
            isShowingSessions = true
        case .addQuestionnaire:
            sessionsInitialAction = .addQuestionnaire
            isShowingSessions = true
        }
    }

    @ViewBuilder
    private var recordControl: some View {
        if voiceRecorder.isRecording {
            HStack(spacing: 6) {
                Text(formattedDuration)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Theme.error)
                Button {
                    voiceRecorder.stopRecording()
                    // Transcribing is the only reason to record, so it
                    // starts immediately — no intermediate controls.
                    transcribe()
                } label: {
                    Label(L10n.stopPatientNotesRecording, systemImage: "stop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.error)
                }
                .buttonStyle(.plain)
            }
        } else {
            Button {
                Task { await voiceRecorder.startRecording() }
            } label: {
                Label(L10n.recordVoiceNoteAction, systemImage: "mic.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
            }.entitlementCreateControl()
            .buttonStyle(.plain)
            .disabled(isTranscribing || isAnonymizingTranscription || voiceRecorder.recordingURL != nil)
        }
    }

    private var formattedDuration: String {
        Duration.seconds(voiceRecorder.duration)
            .formatted(.time(pattern: .minuteSecond))
    }

    /// Sends the recorded voice note to Whisper and appends the resulting
    /// text to the notes field, wrapped in marker lines.
    private func transcribe() {
        guard EntitlementState.shared.allowMutation(allowLocalDemo: false) else { return }
        guard let fileURL = voiceRecorder.recordingURL else { return }
        let whisperService = WhisperService(client: auth.client)
        voiceRecorder.errorMessage = nil
        isTranscribing = true
        Task {
            do {
                let text = try await whisperService.transcribe(fileURL: fileURL)
                isTranscribing = false
                // The raw transcript never reaches the notes field: the whole
                // notes value — existing text plus the transcript, with no
                // header line — is anonymized first and only then shown.
                isAnonymizingTranscription = true
                let existing = patient.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                let combined = existing.isEmpty ? text : patient.notes + "\n\n" + text
                let anonymized = try await store.prepareSummaryForStorage(combined, patientNotes: true)
                patient.notes = anonymized
                voiceRecorder.discard()
                isAnonymizingTranscription = false
                // Silently persist the transcription; the silent save is the
                // new baseline, so leaving afterwards doesn't warn.
                isSaving = true
                do {
                    try await store.updatePatientNotes(patient)
                    initialNotes = patient.notes
                } catch {
                    errorMessage = error.userFacingMessage
                }
                isSaving = false
            } catch {
                voiceRecorder.errorMessage = error.userFacingMessage
                isTranscribing = false
                isAnonymizingTranscription = false
                // The recording stays pending, so the inline row reappears
                // and the transcription (or anonymization) can be retried.
            }
        }
    }

    /// Builds the compact patient context and asks the AI to prepare the
    /// next session, then presents the result.
    private func prepareNextSession() {
        guard EntitlementState.shared.allowMutation(allowLocalDemo: false) else { return }
        errorMessage = nil
        isPreparing = true
        Task {
            do {
                let questionnaires: [CompletedQuestionnaire]
                if let cached = store.cachedQuestionnaires(for: patient) {
                    questionnaires = cached
                } else {
                    questionnaires = try await store.loadQuestionnaires(for: patient)
                }
                let context = PatientContext.make(for: patient, questionnaires: questionnaires)
                // Assignments come only from the immediately previous
                // completed session (dated today or earlier, same rule as
                // `sessionsUpToTodayCount`) — never aggregated across older
                // sessions. Omitted entirely when that session has none.
                let startOfToday = Calendar.current.startOfDay(for: .now)
                let startOfTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday)
                    ?? startOfToday
                let lastSessionAssignments = patient.sessions
                    .filter { $0.date < startOfTomorrow }
                    .max { $0.date < $1.date }?
                    .structuredNotes?.assignmentsForNextWeek
                let response = try await WhisperService(client: auth.client)
                    .prepareNextSession(
                        patientContext: context,
                        lastSessionAssignments: lastSessionAssignments?.isEmpty == false
                            ? lastSessionAssignments : nil
                    )
                savedPreparation = SavedPreparation.save(response, for: patient.id)
                preparationResult = NextSessionPreparationResult(response: response)
            } catch {
                errorMessage = error.userFacingMessage
            }
            isPreparing = false
        }
    }

    /// Deletes the patient (after the confirmation alert) and leaves the screen.
    /// Opens the name editor with the stored name split into first name and
    /// the rest (the store keeps one full-name string).
    private func startEditingName() {
        guard EntitlementState.shared.allowMutation() else { return }
        let parts = (patient.localName ?? "")
            .split(separator: " ", maxSplits: 1)
            .map(String.init)
        errorMessage = nil
        statusDraft = patient.status
        firstNameDraft = parts.first ?? ""
        lastNameDraft = parts.count > 1 ? parts[1] : ""
        isEditingName = true
    }

    private func savePatientStatus(_ status: PatientStatus) {
        guard EntitlementState.shared.allowMutation(), !isSaving, status != patient.status else { return }
        let previousStatus = patient.status
        errorMessage = nil
        busyLabel = nil
        isSaving = true
        patient.status = status
        Task {
            defer { isSaving = false }
            do {
                try await store.updatePatientStatus(patient)
            } catch {
                patient.status = previousStatus
                errorMessage = error.userFacingMessage
            }
        }
    }

    private func saveEditedName() {
        guard EntitlementState.shared.allowMutation() else { return }
        guard !isSaving else { return }
        errorMessage = nil
        isSaving = true
        let previousStatus = patient.status
        Task {
            defer { isSaving = false }
            do {
                try store.renamePatient(patient, firstName: firstNameDraft, lastName: lastNameDraft)
                if statusDraft != previousStatus {
                    patient.status = statusDraft
                    try await store.updatePatientStatus(patient)
                }
                isEditingName = false
            } catch {
                patient.status = previousStatus
                errorMessage = error.userFacingMessage
            }
        }
    }

    private func deletePatient() {
        guard EntitlementState.shared.allowMutation() else { return }
        errorMessage = nil
        busyLabel = nil
        isSaving = true
        Task {
            do {
                try await store.deletePatient(patient)
                dismiss()
            } catch {
                errorMessage = error.userFacingMessage
            }
            isSaving = false
        }
    }

    /// Writes the edited goal to the formulation and persists it right away.
    private func saveGoal() {
        guard EntitlementState.shared.allowMutation() else { return }
        guard !isSaving else { return }
        errorMessage = nil
        // Only promise anonymization when the formulation carries text that
        // may actually be sent to the anonymizer.
        var formulation = patient.formulation ?? .empty
        let goal = goalDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        formulation.treatmentGoal = goal.isEmpty ? nil : goal
        let texts = [formulation.treatmentGoal, formulation.coreBelief, formulation.therapistHypothesis]
            .compactMap { $0 } + formulation.keyAutomaticThoughts + formulation.maintainingBehaviors
        let hasText = formulation.keyCBTCycle != nil
            || texts.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        busyLabel = hasText ? L10n.anonymizingStatusLabel : nil
        isSaving = true
        Task {
            do {
                try await store.saveFormulation(formulation, for: patient)
                isEditingGoal = false
            } catch {
                errorMessage = error.userFacingMessage
            }
            isSaving = false
        }
    }

    private func save(thenDismiss: Bool = false, closeNotes: Bool = false) {
        guard EntitlementState.shared.allowMutation() else { return }
        errorMessage = nil
        // Only promise anonymization when there are notes that may actually
        // be sent to the anonymizer; otherwise show a plain spinner.
        let hasText = !patient.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        busyLabel = hasText ? L10n.anonymizingStatusLabel : nil
        isSaving = true
        Task {
            do {
                try await store.updatePatientNotes(patient)
                initialNotes = patient.notes
                if closeNotes { isShowingNotes = false }
                if thenDismiss { dismiss() }
            } catch {
                errorMessage = error.userFacingMessage
            }
            isSaving = false
        }
    }

    private struct InvitationSharePayload: Identifiable {
        let id = UUID()
        let text: String
        let html: String
        let emailText: String
        let subject: String
    }

    private func startPatientInvitation() {
        guard EntitlementState.shared.allowMutation(allowLocalDemo: false) else { return }
        guard !isCreatingInvitation else { return }
        Task { await createPatientInvitationIfAllowed() }
    }

    private func resumeInvitationAfterDisplayNameIfNeeded() {
        guard pendingInvitationAfterDisplayName else { return }
        pendingInvitationAfterDisplayName = false
        Task {
            if (try? await therapistProfiles.hasValidDisplayName()) == true {
                await createPatientInvitationIfAllowed()
            }
        }
    }

    private func createPatientInvitationIfAllowed() async {
        guard EntitlementState.shared.allowMutation(allowLocalDemo: false) else { return }
        guard !isCreatingInvitation else { return }
        invitationError = nil
        guard let patientId = UUID(uuidString: patient.id.queryValue) else {
            invitationError = L10n.patientInvitationInvalidPatientError
            return
        }

        isCreatingInvitation = true
        do {
            let profile = try await therapistProfiles.getCurrentProfile()
            let therapistName = profile.flatMap { TherapistProfile.isValid($0.displayName) ? TherapistProfile.normalized($0.displayName) : nil }
            guard let therapistName else {
                isCreatingInvitation = false
                pendingInvitationAfterDisplayName = true
                isShowingDisplayNameForInvite = true
                return
            }

            let connected = try await assignmentService().isPatientConnected(patientId: patientId)
            let invitation = try await PatientInvitationService(client: auth.client)
                .createPatientInvitation(patientId: patientId, kind: connected ? .replacement : .initial)
            isCreatingInvitation = false
            invitationShare = InvitationSharePayload(
                text: L10n.patientInvitationShareMessage(
                    therapistName: therapistName,
                    invitationUrl: invitation.invitationUrl
                ),
                html: L10n.patientInvitationEmailHTML(
                    therapistName: therapistName,
                    invitationUrl: invitation.invitationUrl
                ),
                emailText: L10n.patientInvitationEmailMessage(
                    therapistName: therapistName,
                    invitationUrl: invitation.invitationUrl
                ),
                subject: L10n.patientInvitationShareSubject
            )
        } catch {
            isCreatingInvitation = false
            invitationError = error.userFacingMessage
        }
    }

    /// Neutral record icons leave the gold accent for primary actions.
    private func iconChip(_ systemImage: String, title: String) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textBody)
                .frame(width: 28, height: 28)
                .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 7))
        }
    }
}

private enum PatientConnectionState {
    case checking
    case connected
    case notConnected
    case unavailable
    case failed
}

#Preview {
    let auth = AuthManager()
    NavigationStack {
        PatientDetailView(patient: Patient(id: .integer(1), firstName: "ישראלה", lastName: "ישראלית", sessions: [Session()]))
    }
    .environment(auth)
    .environment(DiaryOneStore(client: auth.client))
    .environment(DiaryTwoStore(client: auth.client))
    .environment(DiaryThreeStore(client: auth.client))
    .environment(PatientStore(client: auth.client))
    .environment(GettingStartedRouter())
    .environment(OnboardingStore.shared)
    .environment(TherapistProfileService(client: auth.client))
}

/// The approved header uses visible translucent planes over a patient-colored
/// light source, rather than a single tinted rectangle. No clinical imagery.
private struct PatientHeaderBackdrop: View {
    let accent: Color
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if Theme.isPaper {
                    Theme.patientHomeHeader
                    accent.opacity(0.08)
                } else {
                // A tinted native material lets the underlying surface show through.
                // Keep the material dark for the white header labels in both appearances.
                if reduceTransparency {
                    Color(uiColor: UIColor(hex: 0x0C1420))
                } else {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                }
                Color(uiColor: UIColor(hex: 0x0C1420)).opacity(0.5)
                LinearGradient(colors: [accent.opacity(0.46), accent.opacity(0.15)],
                               startPoint: .topTrailing, endPoint: .bottomLeading)
                RadialGradient(colors: [accent.opacity(0.30), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: geometry.size.width * 1.1)
                // Preserve white-label contrast when the underlying page is light.
                Color.black.opacity(colorScheme == .light ? 0.17 : 0)
                LinearGradient(colors: [.white.opacity(0.05), .white.opacity(0.0175)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                if !reduceTransparency {
                    Canvas { context, size in
                        func plane(_ points: [CGPoint], opacity: Double) {
                            var path = Path()
                            path.addLines(points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) })
                            path.closeSubpath()
                            context.fill(path, with: .color(.white.opacity(opacity)))
                        }
                        plane([.init(x: 0.12, y: 0), .init(x: 0.43, y: 0), .init(x: 0.76, y: 1), .init(x: 0.36, y: 1)], opacity: 0.045)
                        plane([.init(x: 0.62, y: 0), .init(x: 1, y: 0), .init(x: 0.46, y: 1), .init(x: 0.19, y: 1)], opacity: 0.035)
                        plane([.init(x: 0, y: 0.18), .init(x: 0.21, y: 1), .init(x: 0, y: 1)], opacity: 0.05)
                    }
                }
                LinearGradient(colors: [.clear, .black.opacity(0.09)], startPoint: .top, endPoint: .bottom)
                }
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
