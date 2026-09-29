import SwiftUI

/// Editor for a session's date and notes.
///
/// Saving a new session inserts a row into the Supabase `Sessions` table;
/// saving an existing one updates its row (date and notes). For existing
/// sessions the saved questionnaire, if any, is shown as a compact row that
/// opens the full read-only questionnaire.
struct SessionEditorView: View {
    @Bindable var session: Session
    let patient: Patient?
    var isNew: Bool
    /// The session's 1-based number in the patient's history, shown in the
    /// title when editing an existing session.
    var sessionNumber: Int? = nil
    
    @Environment(AuthManager.self) private var auth
    @Environment(PatientStore.self) private var store
    @Environment(GettingStartedRouter.self) private var gettingStartedRouter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var isSaving = false
    @State private var selectedPatientID: DatabaseID?
    /// Status line under the busy spinner; the anonymization notice during
    /// saves, nothing during deletes.
    @State private var busyLabel: String?
    @State private var errorMessage: String?
    @State private var isShowingCancelWarning = false
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingDeleteCodeChallenge = false
    @State private var initialDate: Date?
    @State private var initialNotes: String?
    @State private var initialType: SessionType?
    @State private var initialStructuredNotes: WhisperService.CBTSessionAnalysis?
    @State private var isRequestingRecording = false
    @State private var isLoadingQuestionnaire = false
    @State private var isRefreshingQuestionnaire = false
    @State private var refreshedAssignmentStatus: QuestionnaireAssignmentStatus = .loading
    private var cachedAssignmentStatus: QuestionnaireAssignmentStatus? {
        guard let patient = storePatient else { return nil }
        if store.isDemoMode || DemoData.isDemoID(patient.id) { return .demo }
        guard let patientId = patient.id.uuidValue,
              let connected = assignmentService().cachedPatientConnection(patientId: patientId) else { return nil }
        guard connected else { return .notConnected }
        guard let sessionId = session.databaseID?.uuidValue,
              let snapshot = assignmentService().cachedQuestionnaireAssignment(sessionId: sessionId) else { return .connected }
        return snapshot.assignmentId == nil ? .available : .pending
    }
    private var assignmentStatus: QuestionnaireAssignmentStatus {
        get { refreshedAssignmentStatus == .loading ? cachedAssignmentStatus ?? .loading : refreshedAssignmentStatus }
        nonmutating set { refreshedAssignmentStatus = newValue }
    }
    @State private var isSendingQuestionnaire = false
    @State private var didSendQuestionnaire = false
    @State private var voiceRecorder = VoiceNoteRecorder()
    @State private var isTranscribing = false
    /// True while a fresh transcript is being anonymized, before it may
    /// appear in the notes field.
    @State private var isAnonymizingTranscription = false
    @State private var isAnalyzing = false
    @State private var analysisResult: SessionAnalysisResult?
    @State private var isShowingAllFollowUps = false

    /// Whether anything would be lost by dismissing without saving: an edited
    /// date or notes, or a voice note that hasn't been transcribed into the
    /// notes yet.
    private var hasUnsavedChanges: Bool {
        if selectedPatientID != nil { return true }
        if let initialDate, let initialNotes,
           initialDate != session.date || initialNotes != session.notes
            || initialType != session.type || initialStructuredNotes != session.structuredNotes {
            return true
        }
        if voiceRecorder.recordingURL != nil { return true }
        return false
    }

    private var isWorking: Bool {
        isSaving || isRequestingRecording || voiceRecorder.isRecording
            || isTranscribing || isAnonymizingTranscription || isAnalyzing || isSendingQuestionnaire
    }

    private var canSave: Bool {
        storePatient != nil && !isWorking && voiceRecorder.recordingURL == nil && (isNew || hasUnsavedChanges)
    }

    private var saveStatus: String {
        if voiceRecorder.isRecording { return L10n.sessionRecordingInProgress }
        if isTranscribing { return L10n.transcribingLabel }
        if isAnonymizingTranscription { return L10n.anonymizingStatusLabel }
        if isSaving { return L10n.sessionSaving }
        if isAnalyzing { return L10n.analyzingLabel }
        if isWorking { return L10n.sessionProcessing }
        if voiceRecorder.recordingURL != nil { return L10n.sessionRecordingNeedsTranscription }
        if storePatient == nil { return L10n.sessionChoosePatientHelp }
        if isNew { return L10n.sessionNotCreated }
        return hasUnsavedChanges ? L10n.sessionNotSaved : L10n.sessionSaved
    }

    /// This session's saved questionnaire, read live from the store's cache
    /// so the section updates right after one is filled in and saved.
    private var questionnaire: CompletedQuestionnaire? {
        guard let patient = storePatient, let sessionID = session.databaseID else { return nil }
        return store.cachedQuestionnaires(for: patient)?.first { $0.sessionID == sessionID }
    }

    /// The store's current instance of this patient. Reloads replace the
    /// store's patient objects, so a view that was navigated to before a
    /// reload may hold a stale instance whose sessions miss recent data
    /// (e.g. structured notes); previous-session lookups must use the fresh one.
    private var storePatient: Patient? {
        guard let patient else {
            return store.patients.first { $0.id == selectedPatientID }
        }
        return store.patients.first { $0.id == patient.id } ?? patient
    }

    private var patientAccent: Color {
        storePatient.map { PatientAvatarColor.background(for: $0.id) } ?? Theme.gold
    }

    /// A follow-up question still marked "Follow up" in an earlier session's
    /// review, paired with that session so it can be marked discussed in place.
    private struct PendingFollowUp: Identifiable {
        let id: String
        let session: Session
        let questionIndex: Int
        let question: WhisperService.FollowUpQuestion
    }

    /// This screen's group outlines, in the patient's identity color.
    private func groupBorderedRow(_ position: GroupRowPosition) -> some View {
        CBTipul.groupBorderedRow(position, accent: patientAccent)
    }

    /// The patient's session immediately before this one, by date.
    private var previousSession: Session? {
        storePatient?.sessions
            .filter { $0.id != session.id && $0.date <= session.date }
            .sorted { $0.date > $1.date }
            .first
    }

    /// Follow-up questions from the previous session's structured summary.
    /// All questions are surfaced — no "Follow up" mark needed — until one
    /// is marked discussed or not relevant.
    private var pendingFollowUps: [PendingFollowUp] {
        guard let previous = previousSession,
              let questions = previous.structuredNotes?.followUpQuestions else { return [] }
        return questions.indices.compactMap { index in
            let question = questions[index]
            guard question.status != .discussed, question.status != .notRelevant else { return nil }
            return PendingFollowUp(id: "\(previous.id)-\(index)",
                                   session: previous,
                                   questionIndex: index,
                                   question: question)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if isNew && patient == nil {
                    Section {
                        patientPicker
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .disabled(isWorking)
                            .listRowBackground(groupBorderedRow(.only))
                    } header: {
                        Text(L10n.patientSectionTitle)
                    } footer: {
                        if storePatient == nil {
                            Text(store.patients.isEmpty ? L10n.noPatientsTitle : L10n.sessionChoosePatientHelp)
                        }
                    }
                } else if let patient = storePatient {
                    Section {
                        VStack(spacing: 6) {
                            Text(patient.displayName)
                                .font(.title2.bold())
                            if let sessionNumber {
                                Text(L10n.session(sessionNumber))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .listRowBackground(Color.clear)
                    }
                }

                Section {
                    DatePicker(L10n.sessionDateTitle, selection: $session.date, displayedComponents: [.date])
                        .environment(\.locale, Locale(identifier: "he_IL"))
                        .disabled(isWorking)
                        .accessibilityIdentifier("session.date")
                        .listRowBackground(groupBorderedRow(.first))
                    typePicker
                        .disabled(isWorking)
                        .accessibilityIdentifier("session.type")
                        .listRowBackground(groupBorderedRow(.last))
                }

//                if let firstFollowUp = pendingFollowUps.first {
//                    Section {
//                        followUpRow(firstFollowUp)
//                        if pendingFollowUps.count > 1 {
//                            Button {
//                                isShowingAllFollowUps = true
//                            } label: {
//                                Label(L10n.moreFollowUps(pendingFollowUps.count - 1),
//                                      systemImage: "ellipsis.circle")
//                            }
//                        }
//                    } header: {
//                        Label(L10n.fromLastSessionHeader, systemImage: "arrow.uturn.forward")
//                    }
//                }

                Section(L10n.sessionSummarySection) {
                    VStack(alignment: .leading, spacing: 16) {
                        NotesField(text: $session.notes, placeholder: L10n.sessionSummaryFieldPlaceholder,
                                   minLines: 4, maxLines: 10, isEditable: !isWorking)
                            .accessibilityIdentifier("session.notes")
                        recordControl
                        Text(L10n.sessionRecordingHelp)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(groupBorderedRow(.first))
                    // Transcription starts automatically when recording
                    // stops, so this row only ever appears after a failed
                    // transcription — the recording survives for a retry.
                    if voiceRecorder.recordingURL != nil, !isWorking {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.sessionPendingRecording)
                                .foregroundStyle(.secondary)
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
                            Button(L10n.transcribeAction) { transcribe() }
                                .fontWeight(.semibold)
                            Button(role: .destructive) {
                                voiceRecorder.discard()
                            } label: {
                                Label(L10n.discardRecordingAction, systemImage: "trash")
                            }
                            .accessibilityLabel(L10n.discardRecordingAction)
                        }
                        .font(.subheadline)
                        .buttonStyle(.borderless)
                        .listRowBackground(groupBorderedRow(.middle))
                    }

                    if isTranscribing || isAnonymizingTranscription {
                        HStack {
                            ProgressView()
                            Text(isTranscribing ? L10n.transcribingLabel : L10n.anonymizingStatusLabel)
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(groupBorderedRow(.middle))
                    }

                    if let recorderError = voiceRecorder.errorMessage {
                        Text(recorderError)
                            .font(.footnote)
                            .foregroundStyle(Theme.error)
                            .listRowBackground(groupBorderedRow(.middle))
                    }

                    Text(L10n.sessionNotesSaveHelp)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(groupBorderedRow(.last))
                }

                Section(L10n.sessionOptionalAI) {
                    Text(L10n.sessionAIHelp)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(groupBorderedRow(.first))
                    if isAnalyzing {
                        HStack {
                            ProgressView()
                            Text(L10n.analyzingLabel)
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(groupBorderedRow(.last))
                    } else {
                        Button {
                            analyze()
                        } label: {
                            Label(L10n.aiSummaryAction, systemImage: "sparkles")
                        }
                        .disabled(session.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  || isWorking || voiceRecorder.recordingURL != nil)
                        .tutorialPulse(gettingStartedRouter.shouldPulse(.aiSummary))
                        .listRowBackground(groupBorderedRow(.last))
                    }

                }

                if let structuredNotes = session.structuredNotes {
                    Section(L10n.structuredSummarySection) {
                        NotesField(text: .constant(structuredNotes.sessionSummary),
                                   placeholder: "",
                                   minLines: 3, maxLines: 8,
                                   isEditable: false)
                            .listRowBackground(groupBorderedRow(.first))
                        Button {
                            analysisResult = SessionAnalysisResult(analysis: structuredNotes,
                                                                   requiresSaveDecision: false)
                        } label: {
                            Label(L10n.showStructuredSummaryAction, systemImage: "doc.text.magnifyingglass")
                        }
                        .disabled(isWorking)
                        .listRowBackground(groupBorderedRow(.last))
                    }
                }

                if !isNew {
                    questionnaireSection
                        .disabled(isWorking)
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
            .listSectionSpacing(.compact)
            .patientAtmosphere(patientAccent)
            .themedScreen()
            .dismissesKeyboardOnTap()
            .navigationTitle(isNew
                             ? L10n.newSessionTitle
                             : L10n.sessionEditorTitle(sessionNumber))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if hasUnsavedChanges {
                            isShowingCancelWarning = true
                        } else {
                            dismiss()
                        }
                    } label: {
                        Label(L10n.back, systemImage: "chevron.backward")
                            .labelStyle(.titleAndIcon)
                    }
                    .disabled(isWorking)
                }
                if !isNew {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Menu {
                            Button(L10n.deleteSessionAction, role: .destructive) {
                                isShowingDeleteConfirmation = true
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .rotationEffect(.degrees(90))
                        }
                        .disabled(isWorking)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Label(saveStatus,
                          systemImage: voiceRecorder.isRecording ? "mic.fill"
                            : (isWorking ? "hourglass"
                               : (!isNew && !hasUnsavedChanges ? "checkmark.circle.fill" : "pencil.circle")))
                        .font(.footnote)
                        .foregroundStyle(voiceRecorder.isRecording ? Theme.error : Theme.textBody)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("session.saveStatus")
                    Button(action: { save() }) {
                        Text(L10n.saveSessionAction)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .accessibilityIdentifier("session.save")
                    .buttonStyle(.pressableProminent)
                    .disabled(!canSave)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.regularMaterial)
            }
            // Mission dock must be the outermost bottom inset so it sits at
            // the physical bottom of the screen.
            .demoModeChrome()
            .alert(L10n.deleteSessionConfirmTitle,
                   isPresented: $isShowingDeleteConfirmation) {
                Button(L10n.deleteSessionAction, role: .destructive) {
                    isShowingDeleteCodeChallenge = true
                }
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                Text(L10n.deleteSessionConfirmMessage)
            }
            .deleteCodeChallenge(isPresented: $isShowingDeleteCodeChallenge) { deleteSession() }
            // An alert, not a confirmation dialog: iPad popover dialogs hide
            // cancel-role buttons, and Keep Editing must always be offered.
            .alert(L10n.discardChangesTitle,
                   isPresented: $isShowingCancelWarning) {
                if canSave {
                    Button(L10n.saveChangesAction) { save(thenDismiss: true) }
                }
                Button(L10n.discardChangesAction, role: .destructive) {
                    // The session object is shared, so revert the edits
                    // instead of leaving them in memory unsaved.
                    if let initialDate { session.date = initialDate }
                    if let initialNotes { session.notes = initialNotes }
                    session.type = initialType
                    session.structuredNotes = initialStructuredNotes
                    voiceRecorder.discard()
                    dismiss()
                }
                Button(L10n.keepEditingAction, role: .cancel) {}
            }
            .interactiveDismissDisabled(hasUnsavedChanges || isWorking)
            .busyOverlay(isSaving, label: busyLabel)
            .subtleAnimation(value: errorMessage)
            .subtleAnimation(value: isTranscribing)
            .subtleAnimation(value: isAnonymizingTranscription)
            .onAppear {
                if initialDate == nil {
                    initialDate = session.date
                    initialNotes = session.notes
                    initialType = session.type
                    initialStructuredNotes = session.structuredNotes
                }
                gettingStartedRouter.setPlacement(.sessionEditor, viewingPatientID: storePatient?.id)
                gettingStartedRouter.refresh(using: store)
            }
            .task { await refreshQuestionnaireState() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshQuestionnaireState() } }
            }
            .alert(L10n.questionnaireSentToPatient, isPresented: $didSendQuestionnaire) {
                Button(L10n.ok, role: .cancel) {}
            }
            .sheet(isPresented: $isShowingAllFollowUps) {
                NavigationStack {
                    List {
                        ForEach(pendingFollowUps) { item in
                            followUpRow(item)
                        }
                    }
                    .navigationTitle(L10n.openQuestionsTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.done) { isShowingAllFollowUps = false }
                        }
                    }
                }
                .appTextSize()
            }
            .onChange(of: pendingFollowUps.isEmpty) { _, isEmpty in
                if isEmpty { isShowingAllFollowUps = false }
            }
            .sheet(item: $analysisResult) { result in
                SessionAnalysisView(analysis: result.analysis,
                                    requiresSaveDecision: result.requiresSaveDecision,
                                    onSave: { saveStructuredNotes($0) },
                                    accent: patientAccent)
            }
        }
        .appTextSize()
    }

    private var patientPicker: some View {
        Picker(L10n.patientSectionTitle, selection: $selectedPatientID) {
            Text(L10n.sessionChoosePatientPlaceholder).tag(DatabaseID?.none)
            ForEach(store.patients.filter { $0.status == .active }.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }) { patient in
                Text(patient.displayName).tag(DatabaseID?.some(patient.id))
            }
            let inactive = store.patients.filter { $0.status == .inactive }.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            if !inactive.isEmpty {
                Section(L10n.inactivePatientsSectionTitle) {
                    ForEach(inactive) { patient in
                        Text(patient.displayName).tag(DatabaseID?.some(patient.id))
                    }
                }
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("session.patient")
        .onChange(of: selectedPatientID) { _, _ in
            gettingStartedRouter.setPlacement(.sessionEditor, viewingPatientID: storePatient?.id)
        }
    }

    /// Optional protocol stage directly below the date.
    private var typePicker: some View {
        Picker(L10n.sessionTypeLabel, selection: $session.type) {
            Text(L10n.sessionTypeNone).tag(SessionType?.none)
            ForEach(SessionType.allCases, id: \.self) { type in
                Text(L10n.label(for: type)).tag(SessionType?.some(type))
            }
        }
        .pickerStyle(.menu)
    }

    /// Recording is explicitly labelled; stopping starts transcription automatically.
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
                        .frame(minHeight: 44)
                        .foregroundStyle(Theme.error)
                }
                .buttonStyle(.plain)
            }
        } else {
            Button {
                isRequestingRecording = true
                Task {
                    await voiceRecorder.startRecording()
                    isRequestingRecording = false
                }
            } label: {
                Label(L10n.recordSessionNotesAction, systemImage: "mic.fill")
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled(isWorking || voiceRecorder.recordingURL != nil)
            .tutorialPulse(gettingStartedRouter.shouldPulse(.recordNotes))
        }
    }

    private var formattedDuration: String {
        Duration.seconds(voiceRecorder.duration)
            .formatted(.time(pattern: .minuteSecond))
    }

    /// Sends the recorded voice note to Whisper and appends the resulting
    /// text to the notes field, wrapped in marker lines.
    private func transcribe() {
        guard !isWorking, let fileURL = voiceRecorder.recordingURL else { return }
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
                let existing = session.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                let combined = existing.isEmpty ? text : session.notes + "\n\n" + text
                let anonymized = try await store.anonymizedText(combined)
                session.notes = anonymized
                voiceRecorder.discard()
                isAnonymizingTranscription = false
                if session.databaseID != nil {
                    isSaving = true
                    await autosaveSession()
                }
            } catch {
                voiceRecorder.errorMessage = error.userFacingMessage
                isTranscribing = false
                isAnonymizingTranscription = false
                // The recording stays pending, so the inline row reappears
                // and the transcription can be retried or discarded.
            }
        }
    }

    /// Sends the notes text to the AI analysis Edge Function and presents
    /// the full response in a sheet.
    private func analyze() {
        guard !isWorking, voiceRecorder.recordingURL == nil else { return }
        isAnalyzing = true
        let whisperService = WhisperService(client: auth.client)
        errorMessage = nil
        Task {
            do {
                // No raw text may leave the device: the notes pass the same
                // anonymization gate as saving before they are sent for
                // analysis. Text that is already anonymized (loaded or
                // previously gated) skips the extra call, and the field
                // shows the anonymized version from here on.
                isAnonymizingTranscription = true
                let anonymizedNotes = try await store.anonymizedText(session.notes)
                session.notes = anonymizedNotes
                isAnonymizingTranscription = false
                isAnalyzing = true
                let analysis = try await whisperService.analyzeSession(sessionNotes: anonymizedNotes)
                // AI output is registered as server-provided so saving it
                // unedited skips anonymization; only fields the therapist
                // edits afterwards go through the Edge Function.
                store.registerAIAnalysis(analysis)
                // Finish persistence before opening the editable review, so
                // a second save cannot race the generated summary's save.
                session.structuredNotes = analysis
                if session.databaseID != nil {
                    isSaving = true
                    await autosaveSession()
                }
                analysisResult = SessionAnalysisResult(analysis: analysis,
                                                       requiresSaveDecision: false)
                gettingStartedRouter.refresh(using: store)
                gettingStartedRouter.beginShowcaseCountdownIfNeeded(using: store)
            } catch {
                errorMessage = error.userFacingMessage
            }
            isAnonymizingTranscription = false
            isAnalyzing = false
        }
    }

    /// Silently persists the session after automatic content lands
    /// (transcriptions), so it survives even if the editor is closed
    /// without saving. New sessions are skipped — they have no row until
    /// the first explicit save.
    private func autosaveSession() async {
        defer { isSaving = false }
        errorMessage = nil
        busyLabel = L10n.anonymizingStatusLabel
        do {
            try await store.updateSession(session)
            // The silent save is the new baseline, so backing out without
            // further edits no longer warns about unsaved changes.
            initialDate = session.date
            initialNotes = session.notes
            initialType = session.type
            initialStructuredNotes = session.structuredNotes
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    /// Deletes the session (after the confirmation alert) and closes the editor.
    private func deleteSession() {
        guard let storePatient else { return }
        errorMessage = nil
        busyLabel = nil
        isSaving = true
        Task {
            do {
                try await store.deleteSession(session, for: storePatient)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }

    /// One open question from the previous session, with add-to-notes and
    /// mark-discussed controls. Used in the editor and the Open Questions sheet.
    private func followUpRow(_ item: PendingFollowUp) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.question.question)
                    .font(.subheadline.weight(.semibold))
                if !item.question.reason.isEmpty {
                    Text(item.question.reason)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
//            Button {
//                appendNotesBlock(item.question.question)
//            } label: {
//                Image(systemName: "text.badge.plus")
//                    .font(.title3)
//            }
//            .buttonStyle(.borderless)
//            .accessibilityLabel("Add to notes")
            Button {
                markFollowUpDiscussed(item)
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.title3)
                    .foregroundStyle(Theme.positive)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(L10n.markDiscussedAccessibilityLabel)
        }
        .padding(.vertical, 2)
    }

    /// Marks a follow-up question of an earlier session as discussed and
    /// persists that session's review; the row leaves this editor's
    /// From Last Session list immediately.
    private func markFollowUpDiscussed(_ item: PendingFollowUp) {
        item.session.structuredNotes?.followUpQuestions[item.questionIndex].status = .discussed
        guard item.session.databaseID != nil else { return }
        Task {
            do {
                try await store.updateSession(item.session)
            } catch {
                errorMessage = error.userFacingMessage
            }
        }
    }

    /// Keeps a generated summary on the session and persists it. For a new
    /// session the summary is inserted together with the session on Save.
    private func saveStructuredNotes(_ analysis: WhisperService.CBTSessionAnalysis) {
        session.structuredNotes = analysis
        guard session.databaseID != nil else { return }
        isSaving = true
        Task { await autosaveSession() }
    }

    private func appendNotesBlock(_ block: String) {
        if session.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            session.notes = block
        } else {
            session.notes += "\n\n" + block
        }
    }

    /// The questionnaire answered most recently before this session's, for
    /// the score chips' trend arrows.
    private var previousQuestionnaireRecord: CompletedQuestionnaire? {
        guard let patient = storePatient, let current = questionnaire,
              let records = store.cachedQuestionnaires(for: patient) else { return nil }
        return records
            .filter { $0.id != current.id && $0.answeredDate <= current.answeredDate }
            .max { $0.answeredDate < $1.answeredDate }
    }

    private enum QuestionnaireAssignmentStatus: Equatable {
        case connected
        case loading
        case demo
        case notConnected
        case available
        case pending
        case failed(String)
    }

    private var questionnaireSection: some View {
        Section(L10n.questionnaireSectionTitle) {
            if let patient = storePatient, let questionnaire {
                // Opens the questionnaire pre-filled with the saved answers,
                // read-only until Edit is chosen; saving upserts the same row.
                NavigationLink {
                    CombinedMoodQuestionnaireView(patient: patient, session: session,
                                                  isExisting: true)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(L10n.questionnaireCompletedLabel, systemImage: "checkmark.circle")
                            .font(.subheadline)
                        Text(L10n.hebrewDate(questionnaire.answeredDate))
                            .font(.headline)
                        HStack(spacing: 8) {
                            ScoreCapsule.gad7(questionnaire.questionnaire,
                                              previous: previousQuestionnaireRecord?.questionnaire)
                            ScoreCapsule.phq9(questionnaire.questionnaire,
                                              previous: previousQuestionnaireRecord?.questionnaire)
                        }
                    }
                }
                .listRowBackground(groupBorderedRow(.only))
            } else {
                therapistQuestionnaireEntryRow
                    .listRowBackground(groupBorderedRow(.first))
                questionnaireAssignmentRow
                    .listRowBackground(groupBorderedRow(.last))
            }
        }
    }

    @ViewBuilder
    private var therapistQuestionnaireEntryRow: some View {
        if isLoadingQuestionnaire {
            ProgressView()
        } else if let patient = storePatient {
            NavigationLink {
                CombinedMoodQuestionnaireView(patient: patient, session: session)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Label(L10n.fillQuestionnaireHereAction, systemImage: "square.and.pencil")
                    Text(L10n.questionnaireSessionEntryHelp)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .tutorialPulse(gettingStartedRouter.shouldPulse(.fillQuestionnaire))
        }
    }

    @ViewBuilder
    private var questionnaireAssignmentRow: some View {
        switch assignmentStatus {
        case .connected:
            Text(L10n.patientConnectedStatus).font(.footnote).foregroundStyle(.secondary)
        case .loading:
            ProgressView()
        case .demo:
            Text(L10n.questionnaireDemoSendingUnavailable)
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .notConnected:
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.patientNotConnectedTitle)
                    .font(.subheadline.weight(.semibold))
                Text(L10n.patientNotConnectedBody)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .available:
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.questionnairePatientEntryHelp)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await sendQuestionnaireToPatient() }
                } label: {
                    if isSendingQuestionnaire {
                        ProgressView(L10n.questionnaireSendingLabel)
                    } else {
                        Label(L10n.sendQuestionnaireToPatientAction, systemImage: "paperplane")
                    }
                }
                .disabled(isSendingQuestionnaire || isRefreshingQuestionnaire)
            }
        case .pending:
            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.questionnaireAwaitingPatient, systemImage: "clock")
                    .font(.subheadline.weight(.semibold))
                Text(L10n.questionnairePendingExplanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button(L10n.questionnaireRefreshAction) {
                    Task { await refreshQuestionnaireState() }
                }
                .disabled(isRefreshingQuestionnaire)
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.error)
                    .fixedSize(horizontal: false, vertical: true)
                Button(L10n.questionnaireAssignmentRetryAction) {
                    Task { await refreshQuestionnaireState() }
                }
            }
        }
    }

    private func assignmentService() -> PatientAssignmentService {
        PatientAssignmentService(client: auth.client)
    }

    private func refreshQuestionnaireState() async {
        guard !isNew, !isRefreshingQuestionnaire, !isSendingQuestionnaire else { return }
        isRefreshingQuestionnaire = true
        defer { isRefreshingQuestionnaire = false }
        guard await loadQuestionnaire() else {
            assignmentStatus = .failed(L10n.questionnaireStatusRefreshFailed)
            return
        }
        await loadQuestionnaireAssignment()
    }

    /// Connection and open-assignment state for sending a questionnaire.
    /// Shows cached connection and assignment state while refreshing in the background.
    private func loadQuestionnaireAssignment() async {
        guard !isNew, let patient = storePatient else { return }
        if let cached = cachedAssignmentStatus { assignmentStatus = cached }
        guard questionnaire == nil else { return }
        if store.isDemoMode || DemoData.isDemoID(patient.id) {
            assignmentStatus = .demo
            return
        }
        guard let sessionId = session.databaseID?.uuidValue,
              let patientId = patient.id.uuidValue
        else {
            assignmentStatus = .failed(L10n.patientConnectionCheckError)
            return
        }
        do {
            let connected = try await assignmentService().isPatientConnected(patientId: patientId)
            guard connected else {
                assignmentStatus = .notConnected
                return
            }
            assignmentStatus = cachedAssignmentStatus ?? .connected
            _ = try await assignmentService().openQuestionnaireAssignment(sessionId: sessionId)
            assignmentStatus = cachedAssignmentStatus ?? .connected
        } catch is CancellationError {
            return
        } catch {
            if let cached = cachedAssignmentStatus, cached != .connected {
                assignmentStatus = cached
            } else {
                assignmentStatus = .failed(L10n.patientConnectionCheckError)
            }
        }
    }

    private func sendQuestionnaireToPatient() async {
        guard let patient = storePatient, questionnaire == nil, !isSendingQuestionnaire else { return }
        guard case .available = assignmentStatus else { return }
        guard let sessionId = session.databaseID?.uuidValue,
              let patientId = patient.id.uuidValue
        else {
            assignmentStatus = .failed(L10n.questionnaireAssignmentSendError)
            return
        }
        isSendingQuestionnaire = true
        defer { isSendingQuestionnaire = false }
        do {
            _ = try await assignmentService().sendQuestionnaireAssignment(
                patientId: patientId,
                sessionId: sessionId
            )
            assignmentStatus = .pending
            didSendQuestionnaire = true
        } catch PatientAssignmentError.patientNotConnected {
            assignmentStatus = .notConnected
        } catch {
            assignmentStatus = .failed(L10n.questionnaireAssignmentSendError)
        }
    }

    /// Refreshes the patient's questionnaire cache from the server; the
    /// cached value is already shown while this runs.
    private func loadQuestionnaire() async -> Bool {
        guard let patient = storePatient, !isNew, session.databaseID != nil else { return false }

        syncSessionQuestionnaire()
        defer { isLoadingQuestionnaire = false }
        if store.cachedQuestionnaires(for: patient) == nil {
            isLoadingQuestionnaire = true
        }
        do {
            _ = try await store.loadQuestionnaires(for: patient)
        } catch {
            // Preserve cached answers, but don't infer that another request
            // can be sent until both completion and assignment state are known.
            return false
        }
        syncSessionQuestionnaire()
        return true
    }

    /// Copies the saved answers onto the session's in-memory questionnaire so
    /// editing starts from what was filled in before. Never overwrites
    /// answers already entered in this run.
    private func syncSessionQuestionnaire() {
        if let record = questionnaire, session.questionnaire.isEmpty {
            session.questionnaire = record.questionnaire
        }
    }

    /// Saves the session. A creation sheet closes once the session exists;
    /// editing an existing one stays on screen — unless the save came from
    /// the leave-without-saving warning (`thenDismiss`), which continues
    /// backing out after a successful save.
    private func save(thenDismiss: Bool = false) {
        guard canSave, let patient = storePatient else { return }
        errorMessage = nil
        // Only promise anonymization when there is text that may actually be
        // sent to the anonymizer; otherwise show a plain spinner.
        let hasText = !session.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || session.structuredNotes != nil
        busyLabel = hasText ? L10n.anonymizingStatusLabel : nil
        isSaving = true
        Task {
            do {
                if isNew {
                    try await store.addSession(session, for: patient)
                    gettingStartedRouter.refresh(using: store)
                    dismiss()
                } else {
                    try await store.updateSession(session)
                    // The save is the new baseline, so backing out without
                    // further edits no longer warns about unsaved changes.
                    initialDate = session.date
                    initialNotes = session.notes
                    initialType = session.type
                    initialStructuredNotes = session.structuredNotes
                    gettingStartedRouter.refresh(using: store)
                    if thenDismiss { dismiss() }
                }
            } catch {
                errorMessage = error.userFacingMessage
            }
            isSaving = false
        }
    }
}

#Preview {
    let auth = AuthManager()
    SessionEditorView(session: Session(date: .now, type: .intake),
                      patient: Patient(id: .integer(1), firstName: "Alex"),
                      isNew: true)
        .environment(auth)
        .environment(PatientStore(client: auth.client))
        .environment(GettingStartedRouter())
        .appTextSize()
}
