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

    @State private var recovery = DeviceFormDraft<SessionRecovery>()
    @State private var recoveryClosed = false
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
    @State private var acceptedAnalysisSource: String?
    @State private var generatedAnalysisSource: String?
    @State private var initialType: SessionType?
    @State private var initialStructuredNotes: WhisperService.CBTSessionAnalysis?
    @State private var isRequestingRecording = false
    @State private var isLoadingQuestionnaire = false
    @State private var isRefreshingQuestionnaire = false
    @State private var questionnaireRefreshFailed = false
    @State private var voiceRecorder = VoiceNoteRecorder()
    @State private var isTranscribing = false
    /// True while a fresh transcript is being anonymized, before it may
    /// appear in the notes field.
    @State private var isAnonymizingTranscription = false
    @State private var isAnalyzing = false
    @State private var analysisResult: SessionAnalysisResult?
    @State private var isShowingAllFollowUps = false
    @State private var showingNotesEditor = false
    @State private var notesAtEditorOpen = ""
    @State private var confirmLeavingNotes = false
    @FocusState private var notesEditorFocused: Bool

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

    private var recoveryValue: SessionRecovery {
        SessionRecovery(date: session.date, notes: session.notes, type: session.type, structuredNotes: session.structuredNotes, selectedPatientID: selectedPatientID)
    }

    private func persistRecovery() {
        guard recovery.hasLoaded, !recoveryClosed else { return }
        // A failed read must never clear the previous recoverable text.
        guard !recovery.hasError || hasUnsavedChanges else { return }
        recovery.save(recoveryValue, isEmpty: !hasUnsavedChanges && !isNew || (isNew && session.notes.isEmpty && session.type == nil && session.structuredNotes == nil))
    }

    private var isWorking: Bool {
        isSaving || isRequestingRecording || voiceRecorder.isRecording
            || isTranscribing || isAnonymizingTranscription || isAnalyzing
    }

    private var canSave: Bool {
        EntitlementState.shared.canWrite &&
        storePatient != nil && !isWorking && voiceRecorder.recordingURL == nil && (isNew || hasUnsavedChanges)
    }

    private var saveStatus: String? {
        if voiceRecorder.isRecording { return L10n.sessionRecordingInProgress }
        if isTranscribing { return L10n.transcribingLabel }
        if isAnonymizingTranscription { return L10n.anonymizingStatusLabel }
        if isSaving { return L10n.sessionSaving }
        if isAnalyzing { return L10n.analyzingLabel }
        if isWorking { return L10n.sessionProcessing }
        if voiceRecorder.recordingURL != nil { return L10n.sessionRecordingNeedsTranscription }
        if storePatient == nil { return L10n.sessionChoosePatientHelp }
        if isNew { return L10n.sessionNotCreated }
        return nil
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
                if recovery.hasError, let feedback = recovery.feedback {
                    Section { DeviceDraftFeedback(message: feedback, isError: true) }
                }
                if isNew && patient == nil {
                    Section {
                        patientPicker
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .disabled(isWorking || !EntitlementState.shared.canWrite)
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
                    DatePicker(L10n.sessionDateTitle, selection: $session.date, displayedComponents: [.date]).entitlementWriteControl()
                        .environment(\.locale, Locale(identifier: "he_IL"))
                        .disabled(isWorking || !EntitlementState.shared.canWrite)
                        .accessibilityIdentifier("session.date")
                        .listRowBackground(groupBorderedRow(.first))
                    typePicker
                        .disabled(isWorking || !EntitlementState.shared.canWrite)
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
                        Button { showingNotesEditor = true } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(session.notes.isEmpty ? L10n.sessionSummaryFieldPlaceholder : session.notes)
                                    .foregroundStyle(session.notes.isEmpty ? Theme.textBody : Theme.textBright)
                                    .lineLimit(6)
                                    .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
                                    .padding(16)
                                    .background(Theme.base, in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.borderFaint, lineWidth: 1))
                                Label(session.notes.isEmpty ? L10n.sessionWriteNotes : L10n.sessionReadNotes, systemImage: session.notes.isEmpty ? "square.and.pencil" : "arrow.up.left.and.arrow.down.right")
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.gold)
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(isWorking)
                            .accessibilityIdentifier("session.notes")
                        Divider()
                        recordControl
                        if session.notes.isEmpty {
                            Text(L10n.sessionRecordingHelp).font(.footnote).foregroundStyle(.secondary)
                        }
                        if !session.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (session.structuredNotes == nil || session.notes != acceptedAnalysisSource) {
                            Divider()
                            if isAnalyzing {
                                HStack { ProgressView(); Text(L10n.analyzingLabel).font(.subheadline) }
                            } else {
                                Button { analyze() } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "sparkles").font(.title3)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(L10n.aiSummaryAction).font(.subheadline.weight(.semibold))
                                            Text(L10n.sessionAIHint).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.forward").font(.caption)
                                    }.padding(.vertical, 6).contentShape(Rectangle())
                                }.buttonStyle(.plain).foregroundStyle(Theme.gold)
                                    .disabled(isWorking || voiceRecorder.recordingURL != nil)
                            }
                        }
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

                }

                if let structuredNotes = session.structuredNotes {
                    Section(L10n.structuredSummarySection) {
                        HStack(alignment: .top, spacing: 12) {
                            Button {
                                analysisResult = SessionAnalysisResult(analysis: structuredNotes, requiresSaveDecision: false)
                            } label: {
                                Text(structuredNotes.sessionSummary).lineLimit(6)
                                    .foregroundStyle(Theme.textBright)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.plain).disabled(isWorking)
                            Menu {
                                Button(L10n.sessionRegenerate) { analyze() }
                                    .disabled(isWorking || session.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || voiceRecorder.recordingURL != nil)
                            } label: { Image(systemName: "ellipsis").padding(8) }
                                .accessibilityLabel(L10n.sessionRegenerate)
                        }.listRowBackground(groupBorderedRow(.first))
                        Button {
                            analysisResult = SessionAnalysisResult(analysis: structuredNotes,
                                                                   requiresSaveDecision: false)
                        } label: {
                            Label(L10n.sessionViewEditSummary, systemImage: "doc.text.magnifyingglass")
                        }
                        .disabled(isWorking || !EntitlementState.shared.canWrite)
                        .listRowBackground(groupBorderedRow(.last))
                    }
                }

                if !isNew {
                    questionnaireSection
                        .disabled(isWorking || !EntitlementState.shared.canWrite)
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
                        .disabled(isWorking || !EntitlementState.shared.canWrite)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if let saveStatus {
                        Label(saveStatus,
                              systemImage: voiceRecorder.isRecording ? "mic.fill"
                                : (isWorking ? "hourglass" : "pencil.circle"))
                            .font(.footnote)
                            .foregroundStyle(voiceRecorder.isRecording ? Theme.error : Theme.textBody)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("session.saveStatus")
                    }
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
                if voiceRecorder.recordingURL == nil {
                    Button(L10n.keepDraftAndLeave) {
                        persistRecovery()
                        guard !recovery.hasError else { return }
                        recoveryClosed = true
                        if let initialDate { session.date = initialDate }
                        if let initialNotes { session.notes = initialNotes }
                        session.type = initialType
                        session.structuredNotes = initialStructuredNotes
                        dismiss()
                    }
                }
                Button(L10n.discardChangesAction, role: .destructive) {
                    guard recovery.discard() else { return }
                    recoveryClosed = true
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
            .fullScreenCover(isPresented: $showingNotesEditor) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(storePatient?.displayName ?? "")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text(L10n.hebrewDate(session.date)).font(.caption)
                        }
                        .foregroundStyle(Theme.textBody)
                        .padding(.horizontal, 24).padding(.vertical, 14)
                        Divider().overlay(Theme.borderFaint)
                        ZStack(alignment: .topLeading) {
                            if session.notes.isEmpty {
                                Text(L10n.sessionSummaryFieldPlaceholder)
                                    .font(.body).foregroundStyle(Theme.textFaint)
                                    .padding(.horizontal, 29).padding(.top, 24)
                                    .allowsHitTesting(false)
                            }
                            EntitlementTextEditor(text: $session.notes)
                                .font(.body).lineSpacing(7)
                                .foregroundStyle(Theme.textBright)
                                .tint(Theme.gold)
                                .focused($notesEditorFocused)
                                .onAppear { notesAtEditorOpen = session.notes; notesEditorFocused = EntitlementState.shared.canWrite }
                                .disabled(isWorking)
                                .onDisappear { notesEditorFocused = false }
                                .scrollContentBackground(.hidden)
                                .scrollDismissesKeyboard(.interactively)
                                .padding(.horizontal, 24).padding(.vertical, 16)
                        }
                        if let saveStatus {
                            Text(saveStatus)
                                .font(.caption).foregroundStyle(Theme.textBody)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 24).padding(.vertical, 12)
                        }
                    }
                    .background(Theme.surface)
                    .navigationTitle(L10n.sessionSummarySection)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(Theme.surface, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.back) {
                                if session.notes != notesAtEditorOpen { confirmLeavingNotes = true }
                                else { showingNotesEditor = false }
                            }.disabled(isWorking)
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            if (hasUnsavedChanges || isNew) && EntitlementState.shared.canWrite {
                                Button(L10n.saveSessionAction) { save() }
                                    .fontWeight(.semibold).disabled(!canSave)
                            } else {
                                Button(L10n.closeAction) {
                                    if session.notes != notesAtEditorOpen { confirmLeavingNotes = true }
                                    else { showingNotesEditor = false }
                                }
                                    .fontWeight(.semibold).disabled(isWorking)
                            }
                        }
                    }
                    .onChange(of: initialNotes) { _, value in
                        if let value { notesAtEditorOpen = value }
                    }
                    .safeAreaInset(edge: .bottom) {
                        if let errorMessage {
                            Text(errorMessage).font(.callout).foregroundStyle(Theme.error).padding()
                        }
                    }
                    .busyOverlay(isSaving, label: busyLabel)
                    .alert(L10n.saveSummaryPrompt, isPresented: $confirmLeavingNotes) {
                        Button(L10n.saveSessionAction) { save() }.disabled(!canSave)
                        Button(L10n.discardChangesAction, role: .destructive) {
                            session.notes = notesAtEditorOpen
                            showingNotesEditor = false
                        }
                        Button(L10n.keepEditingAction, role: .cancel) {}
                    }
                    .interactiveDismissDisabled(session.notes != notesAtEditorOpen || isWorking)
                    .demoModeChrome()
                }
                .environment(\.layoutDirection, .rightToLeft)
                .appTextSize()
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
                    acceptedAnalysisSource = session.notes
                    initialType = session.type
                    initialStructuredNotes = session.structuredNotes
                    let target = isNew ? "new:\(patient?.id.queryValue ?? "global")" : "session:\(session.databaseID?.queryValue ?? session.id.uuidString)"
                    if let saved = recovery.restore(userID: auth.currentUserId, kind: store.isDemoMode ? "demo-session" : "therapist-session", target: target) {
                        session.date = saved.date
                        session.notes = saved.notes
                        session.type = saved.type
                        session.structuredNotes = saved.structuredNotes
                        selectedPatientID = saved.selectedPatientID
                    }
                }
                gettingStartedRouter.setPlacement(.sessionEditor, viewingPatientID: storePatient?.id)
                gettingStartedRouter.refresh(using: store)
            }
            .task(id: recoveryValue) {
                do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                persistRecovery()
            }
            .onDisappear { persistRecovery() }
            .task { await refreshQuestionnaireState() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshQuestionnaireState() } }
                else { persistRecovery() }
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
                            Button(L10n.closeAction) { isShowingAllFollowUps = false }
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
                guard EntitlementState.shared.allowMutation(allowLocalDemo: false) else { return }
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
        guard EntitlementState.shared.allowMutation(allowLocalDemo: false) else { return }
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
        guard EntitlementState.shared.allowMutation(allowLocalDemo: false) else { return }
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
                generatedAnalysisSource = anonymizedNotes
                analysisResult = SessionAnalysisResult(analysis: analysis, requiresSaveDecision: true)
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
        guard EntitlementState.shared.canWrite else { return }
        defer { isSaving = false }
        errorMessage = nil
        busyLabel = L10n.anonymizingStatusLabel
        do {
            try await store.updateSession(session)
            recovery.discard()
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
        guard EntitlementState.shared.allowMutation() else { return }
        guard let storePatient else { return }
        errorMessage = nil
        busyLabel = nil
        isSaving = true
        Task {
            do {
                try await store.deleteSession(session, for: storePatient)
                recoveryClosed = true
                recovery.discard()
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
        guard EntitlementState.shared.allowMutation() else { return }
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

    /// Accepts the review into the editor draft; Save Session persists it.
    private func saveStructuredNotes(_ analysis: WhisperService.CBTSessionAnalysis) {
        guard EntitlementState.shared.allowMutation() else { return }
        if analysisResult?.requiresSaveDecision == true {
            acceptedAnalysisSource = generatedAnalysisSource
        }
        session.structuredNotes = analysis

    }

    private func appendNotesBlock(_ block: String) {
        guard EntitlementState.shared.allowMutation() else { return }
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

    private var questionnaireSection: some View {
        Section(L10n.questionnaireSectionTitle) {
            if questionnaireRefreshFailed {
                Text(L10n.questionnaireRefreshFailed).foregroundStyle(Theme.error)
                Button(L10n.questionnaireRefreshAction) { Task { await refreshQuestionnaireState() } }
                    .disabled(isRefreshingQuestionnaire)
            }
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
                if let patient = storePatient {
                    QuestionnaireAccessControl(patient: patient)
                        .listRowBackground(groupBorderedRow(.last))
                }
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

    private func refreshQuestionnaireState() async {
        guard !isNew, !isRefreshingQuestionnaire else { return }
        isRefreshingQuestionnaire = true
        defer { isRefreshingQuestionnaire = false }
        questionnaireRefreshFailed = !(await loadQuestionnaire())
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
            // Preserve cached session answers when the background refresh fails.
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
        guard EntitlementState.shared.allowMutation() else { return }
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
                    recoveryClosed = true
                    recovery.discard()
                    showingNotesEditor = false
                    gettingStartedRouter.refresh(using: store)
                    dismiss()
                } else {
                    try await store.updateSession(session)
                    recovery.discard()
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

struct SessionRecovery: Codable, Equatable {
    var date: Date
    var notes: String
    var type: SessionType?
    var structuredNotes: WhisperService.CBTSessionAnalysis?
    var selectedPatientID: DatabaseID?
}
