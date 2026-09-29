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

    @State private var isSaving = false
    @State private var isShowingNotes = false
    @State private var areDiariesExpanded = false
    @State private var isShowingSendOptions = false
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
    @State private var connectionState: PatientConnectionState = .checking

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

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
                        Text(patient.displayName)
                            .font(.title.bold())
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            startEditingName()
                        } label: {
                            Image(systemName: "pencil")
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel(L10n.editPatientDetailsAction)
                        .buttonStyle(.borderless)
                    }
                    .frame(maxWidth: .infinity)
                    HStack(spacing: 8) {
                        Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
                        Text(treatmentGoal.wrappedValue.isEmpty
                             ? L10n.noTreatmentGoalPlaceholder
                             : treatmentGoal.wrappedValue)
                            .font(.subheadline)
                            .foregroundStyle(treatmentGoal.wrappedValue.isEmpty ? .secondary : .primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            goalDraft = treatmentGoal.wrappedValue
                            isEditingGoal = true
                        } label: {
                            Image(systemName: "pencil")
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel(L10n.editTreatmentGoalAction)
                        .buttonStyle(.borderless)
                    }
                    .frame(maxWidth: .infinity)
                    StatusBadge(status: patient.status)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("patient.header")
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                connectionCard
                    .listRowBackground(groupBorderedRow(connectionState == .connected ? .first : .only))
                if connectionState == .connected {
                    sendingActions
                        .listRowBackground(groupBorderedRow(.last))
                }
            }

            Section(L10n.patientRecordsTitle) {
                NavigationLink {
                    PatientSessionsView(patient: patient)
                } label: {
                    workspaceRow("calendar", title: L10n.sessionsTitle, detail: sessionSummary)
                        .tutorialPulse(
                            gettingStartedRouter.shouldPulse(.sessionsEntry)
                                && patient.id == gettingStartedRouter.progress.focusPatientID
                        )
                }
                .accessibilityIdentifier("patient.sessions")
                .listRowBackground(groupBorderedRow(.first))

                DisclosureGroup(isExpanded: $areDiariesExpanded) {
                    NavigationLink {
                        PatientDiaryOneView(patient: patient)
                    } label: {
                        workspaceRow("book.closed", title: L10n.diaryOneTitle,
                                     detail: L10n.patientDiaryDescription)
                    }
                    .accessibilityIdentifier("patient.diaryOne")
                    diaryPlaceholder(L10n.diaryTwoTitle)
                    diaryPlaceholder(L10n.diaryThreeTitle)
                } label: {
                    workspaceRow("books.vertical", title: L10n.patientDiariesTitle,
                                 detail: L10n.patientDiariesDescription)
                }
                .accessibilityIdentifier("patient.diaries")
                .listRowBackground(groupBorderedRow(.middle))

                NavigationLink {
                    PatientQuestionnairesView(patient: patient)
                } label: {
                    workspaceRow("list.clipboard", title: L10n.questionnaireHistoryTitle,
                                 detail: L10n.patientQuestionnairesDescription)
                }
                .accessibilityIdentifier("patient.questionnaireHistory")
                .listRowBackground(groupBorderedRow(.middle))

                NavigationLink {
                    PatientQuestionnairesView(patient: patient, startsOnGraphs: true)
                } label: {
                    workspaceRow("chart.xyaxis.line", title: L10n.graphsAndTrendsTitle,
                                 detail: L10n.patientGraphsDescription)
                }
                .accessibilityIdentifier("patient.questionnaireGraphs")
                .listRowBackground(groupBorderedRow(.middle))

                NavigationLink {
                    TherapistPatientMessagesView(patient: patient)
                } label: {
                    workspaceRow("envelope", title: L10n.messagesTitle,
                                 detail: L10n.patientMessagesDescription)
                }
                .listRowBackground(groupBorderedRow(.middle))

                Button {
                    errorMessage = nil
                    isShowingNotes = true
                } label: {
                    workspaceRow("note.text", title: L10n.patientNotesTitle,
                                 detail: patient.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? L10n.patientNotesDescription : patient.notes)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("patient.notes")
                .listRowBackground(groupBorderedRow(.last))
            }

            Section(L10n.additionalAssistanceTitle) {
                NavigationLink {
                    PatientAIView(patient: patient)
                } label: {
                    workspaceRow("sparkles", title: L10n.patientAIAssistanceTitle,
                                 detail: L10n.patientAIAssistanceDescription)
                }
                .listRowBackground(groupBorderedRow(.first))

                Button {
                    requestPrepareNextSession()
                } label: {
                    HStack {
                        iconChip("wand.and.stars", title: L10n.prepareNextSessionAction)
                        if isPreparing {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isPreparing)
                .listRowBackground(groupBorderedRow(savedPreparation == nil ? .last : .middle))

                if let savedPreparation {
                    Button {
                        preparationResult = NextSessionPreparationResult(
                            response: savedPreparation.response,
                            isOutdated: isSavedPreparationOutdated
                        )
                    } label: {
                        HStack {
                            iconChip("doc.text.magnifyingglass", title: L10n.lastPreparationAction)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(L10n.hebrewDate(savedPreparation.generatedAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if isSavedPreparationOutdated {
                                    Text(L10n.outdatedBadge)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Theme.warning)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Theme.warning.opacity(0.12)))
                                }
                            }
                        }
                    }
                    .listRowBackground(groupBorderedRow(.last))
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Theme.error)
                }
                .listRowBackground(groupBorderedRow(.only))
            }
        }
        .patientAtmosphere(patientColor)
        .themedScreen()
        .listSectionSpacing(16)
        .contentMargins(.top, 12, for: .scrollContent)
        .scrollDismissesKeyboard(.interactively)
        .dismissesKeyboardOnTap()
        .demoModeChrome()
        .navigationTitle(patient.displayName)
        .navigationBarTitleDisplayMode(.inline)
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
                        TextField(L10n.firstNamePlaceholder, text: $firstNameDraft, prompt: Text(""))
                            .multilineTextAlignment(.leading)
                            .stablePlaceholder(L10n.firstNamePlaceholder, isShown: firstNameDraft.isEmpty)
                        TextField(L10n.lastNamePlaceholder, text: $lastNameDraft, prompt: Text(""))
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
                        TextField(L10n.noTreatmentGoalPlaceholder, text: $goalDraft, axis: .vertical)
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
                        Button(L10n.cancel) { isEditingGoal = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.save) { saveGoal() }
                    }
                }
            }
            .presentationDetents([.medium])
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
            guard connectionState == .notConnected else { return }
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
            ActivityShareSheet(items: [payload.text])
                .presentationDetents([.medium])
        }
        .subtleAnimation(value: areDiariesExpanded)
        .subtleAnimation(value: errorMessage)
        .subtleAnimation(value: isTranscribing)
        .subtleAnimation(value: isAnonymizingTranscription)
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

    private var sessionSummary: String {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
        guard let latest = patient.sessions.filter({ $0.date < tomorrow }).max(by: { $0.date < $1.date }) else {
            return L10n.patientSessionsDescription
        }
        return L10n.patientLatestSession(L10n.hebrewDate(latest.date))
    }

    private func workspaceRow(_ icon: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            iconChip(icon, title: title)
                .foregroundStyle(Theme.textBright)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Theme.textBody)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch connectionState {
            case .checking:
                ProgressView(L10n.patientConnectionChecking)
            case .connected:
                Label(L10n.patientConnectedStatus, systemImage: "checkmark.circle.fill")
                    .font(.headline)
                Text(L10n.patientConnectionReadyDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .notConnected, .unavailable:
                Button {
                    isShowingConnectionInfo = true
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(L10n.patientInviteToAppAction, systemImage: "person.crop.circle.badge.plus")
                                .font(.headline)
                                .foregroundStyle(Theme.gold)
                            Text(connectionState == .notConnected
                                 ? L10n.patientNotConnectedStatus : L10n.patientInvitationDemoStatus)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isCreatingInvitation || isSaving)
                .accessibilityIdentifier("patient.connectionInfo")
            case .failed:
                Text(L10n.patientConnectionCheckError)
                    .font(.subheadline)
                Button(L10n.retry) {
                    Task { await refreshConnectionState() }
                }
                .buttonStyle(.bordered)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 6)
        .accessibilityIdentifier("patient.connection")
    }

    private var connectionInfoSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(patient.displayName)
                        .font(.title2.bold())
                    Text(L10n.patientConnectDescription)
                    switch connectionState {
                    case .notConnected:
                        Text(L10n.patientShareInvitationExplanation)
                            .foregroundStyle(.secondary)
                        Button {
                            pendingInvitationFromInfo = true
                            isShowingConnectionInfo = false
                        } label: {
                            Label(L10n.patientShareInvitationAction, systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity, minHeight: 30)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("patient.shareInvitation")
                    case .unavailable:
                        Text(L10n.patientInvitationUnavailableExplanation)
                            .foregroundStyle(.secondary)
                    case .connected:
                        Label(L10n.patientConnectedStatus, systemImage: "checkmark.circle.fill")
                    case .checking:
                        ProgressView(L10n.patientConnectionChecking)
                    case .failed:
                        Text(L10n.patientConnectionCheckError)
                        Button(L10n.retry) { Task { await refreshConnectionState() } }
                    }
                    Text(L10n.patientConnectionOptionalExplanation)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(24)
            }
            .themedScreen()
            .navigationTitle(L10n.patientInviteToAppAction)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) { isShowingConnectionInfo = false }
                        .accessibilityIdentifier("patient.connectionInfo.done")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .appTextSize()
    }

    private enum PatientSendAction {
        case message, questionnaire, diaryOne
    }

    @ViewBuilder
    private var sendingActions: some View {
        if connectionState == .connected {
            Button {
                pendingSendAction = nil
                isShowingSendOptions = true
            } label: {
                HStack(spacing: 12) {
                    workspaceRow("paperplane", title: L10n.sendToPatientAction,
                                 detail: L10n.patientSendingDescription)
                    Image(systemName: "chevron.forward")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isSendingToPatient || isSaving)
            .accessibilityIdentifier("patient.sending")
        } else {
            sendingUnavailableNotice
        }
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
                        sendOption(.questionnaire, icon: "list.clipboard", title: L10n.sendQuestionnaireToPatientAction,
                                   detail: L10n.patientQuestionnaireRequestDescription)
                        sendOption(.diaryOne, icon: "book.closed", title: L10n.patientEnableDiaryOneAction,
                                   detail: L10n.patientSendDiaryOneDescription)
                        VStack(spacing: 0) {
                            diaryPlaceholder(L10n.diaryTwoTitle)
                            Divider()
                            diaryPlaceholder(L10n.diaryThreeTitle)
                        }
                        .padding(.horizontal, 16)
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
                    Button(L10n.cancel) { isShowingSendOptions = false }
                }
            }
        }
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
        case .questionnaire: sendStandaloneQuestionnaire()
        case .diaryOne: sendDiaryOne()
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
            connectionState = .unavailable
            return
        }
        guard let patientId = patient.id.uuidValue else {
            connectionState = .unavailable
            return
        }
        connectionState = .checking
        do {
            connectionState = try await assignmentService().isPatientConnected(patientId: patientId)
                ? .connected
                : .notConnected
        } catch {
            connectionState = .failed
        }
    }

    private func sendStandaloneQuestionnaire() {
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
                title: L10n.patientInvitationFailedTitle,
                message: L10n.patientInvitationInvalidPatientError
            )
            return
        }
        isSendingToPatient = true
        Task {
            defer { isSendingToPatient = false }
            try? await Task.sleep(for: .milliseconds(250))
            do {
                _ = try await assignmentService().sendQuestionnaireAssignment(
                    patientId: patientId,
                    sessionId: nil
                )
                presentSendFeedback(
                    title: L10n.sendQuestionnaireToPatientAction,
                    message: L10n.questionnaireSentToPatient
                )
            } catch PatientAssignmentError.patientNotConnected {
                presentSendFeedback(
                    title: L10n.patientNotConnectedTitle,
                    message: L10n.patientNotConnectedBody
                )
            } catch {
                presentSendFeedback(
                    title: L10n.sendQuestionnaireToPatientAction,
                    message: L10n.questionnaireAssignmentSendError
                )
            }
        }
    }

    private func sendDiaryOne() {
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

    private func presentSendFeedback(title: String, message: String) {
        sendFeedbackTitle = title
        sendFeedbackMessage = message
    }

    /// Gates preparation behind useful clinical input and a one-time tip.
    private func requestPrepareNextSession() {
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
            }
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
                let anonymized = try await store.anonymizedText(combined)
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
                    errorMessage = error.localizedDescription
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
        let parts = (patient.localName ?? "")
            .split(separator: " ", maxSplits: 1)
            .map(String.init)
        errorMessage = nil
        statusDraft = patient.status
        firstNameDraft = parts.first ?? ""
        lastNameDraft = parts.count > 1 ? parts[1] : ""
        isEditingName = true
    }

    private func saveEditedName() {
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
        errorMessage = nil
        busyLabel = nil
        isSaving = true
        Task {
            do {
                try await store.deletePatient(patient)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }

    /// Writes the edited goal to the formulation and persists it right away.
    private func saveGoal() {
        treatmentGoal.wrappedValue = goalDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        isEditingGoal = false
        errorMessage = nil
        // Only promise anonymization when the formulation carries text that
        // may actually be sent to the anonymizer.
        let formulation = patient.formulation ?? .empty
        let texts = [formulation.treatmentGoal, formulation.coreBelief, formulation.therapistHypothesis]
            .compactMap { $0 } + formulation.keyAutomaticThoughts + formulation.maintainingBehaviors
        let hasText = formulation.keyCBTCycle != nil
            || texts.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        busyLabel = hasText ? L10n.anonymizingStatusLabel : nil
        isSaving = true
        Task {
            do {
                try await store.saveFormulation(patient.formulation ?? .empty, for: patient)
            } catch {
                errorMessage = error.userFacingMessage
            }
            isSaving = false
        }
    }

    private func save(thenDismiss: Bool = false, closeNotes: Bool = false) {
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
    }

    private func startPatientInvitation() {
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

            let invitation = try await PatientInvitationService(client: auth.client)
                .createPatientInvitation(patientId: patientId)
            isCreatingInvitation = false
            invitationShare = InvitationSharePayload(
                text: L10n.patientInvitationShareMessage(
                    therapistName: therapistName,
                    invitationUrl: invitation.invitationUrl
                )
            )
        } catch {
            isCreatingInvitation = false
            invitationError = error.userFacingMessage
        }
    }

    /// A Settings-style row label: a small gold-tinted icon square next to
    /// the title. The color parameter is kept for call-site stability but the
    /// design system allows gold as the only accent.
    private func iconChip(_ systemImage: String, title: String) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.gold)
                .frame(width: 28, height: 28)
                .background(Theme.goldGhost, in: RoundedRectangle(cornerRadius: 7))
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
    .environment(PatientStore(client: auth.client))
    .environment(GettingStartedRouter())
    .environment(OnboardingStore.shared)
    .environment(TherapistProfileService(client: auth.client))
}
