import SwiftUI

/// Editor for a session's date and notes.
///
/// Saving a new session inserts a row into the Supabase `Sessions` table;
/// saving an existing one updates its row (date and notes). For existing
/// sessions the saved questionnaire, if any, is shown as a compact row that
/// opens the full read-only questionnaire.
struct SessionEditorView: View {
    @Bindable var session: Session
    let patient: Patient
    var isNew: Bool
    /// The session's 1-based number in the patient's history, shown in the
    /// title when editing an existing session.
    var sessionNumber: Int? = nil
    
    @Environment(AuthManager.self) private var auth
    @Environment(PatientStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isSaving = false
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
    @State private var isLoadingQuestionnaire = false
    @State private var voiceRecorder = VoiceNoteRecorder()
    @State private var isTranscribing = false
    /// True while a fresh transcript is being anonymized, before it may
    /// appear in the notes field.
    @State private var isAnonymizingTranscription = false
    @State private var isAnalyzing = false
    @State private var analysisResult: SessionAnalysisResult?
    @State private var isShowingAllFollowUps = false
    @State private var isEditingDate = false

    /// Whether anything would be lost by dismissing without saving: an edited
    /// date or notes, or a voice note that hasn't been transcribed into the
    /// notes yet.
    private var hasUnsavedChanges: Bool {
        if let initialDate, let initialNotes,
           initialDate != session.date || initialNotes != session.notes
            || initialType != session.type {
            return true
        }
        if voiceRecorder.recordingURL != nil { return true }
        return false
    }

    /// This session's saved questionnaire, read live from the store's cache
    /// so the section updates right after one is filled in and saved.
    private var questionnaire: CompletedQuestionnaire? {
        guard let sessionID = session.databaseID else { return nil }
        return store.cachedQuestionnaires(for: patient)?.first { $0.sessionID == sessionID }
    }

    /// The store's current instance of this patient. Reloads replace the
    /// store's patient objects, so a view that was navigated to before a
    /// reload may hold a stale instance whose sessions miss recent data
    /// (e.g. structured notes); previous-session lookups must use the fresh one.
    private var storePatient: Patient {
        store.patients.first { $0.id == patient.id } ?? patient
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
        CBTipul.groupBorderedRow(position, accent: PatientAvatarColor.background(for: patient.id))
    }

    /// The patient's session immediately before this one, by date.
    private var previousSession: Session? {
        storePatient.sessions
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
                Section {
                    if isNew {
                        VStack(spacing: 6) {
                            Text(L10n.addSessionAction)
                                .font(.title2.bold())
                            Text(patient.displayName)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                    } else {
                        VStack(spacing: 6) {
                            Text(patient.displayName)
                                .font(.title2.bold())
                            if let sessionNumber {
                                Text(L10n.session(sessionNumber))
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 6) {
                                Text(session.type.map(L10n.label(for:)) ?? L10n.sessionTypeNone)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(session.type == nil ? Theme.textFaint : Theme.gold)
                                Menu {
                                    typePicker
                                } label: {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.subheadline)
                                }
                                .accessibilityLabel(L10n.sessionTypeLabel)
                            }
                            HStack(spacing: 6) {
                                Text(L10n.hebrewDate(session.date))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Button {
                                    isEditingDate = true
                                } label: {
                                    Image(systemName: "calendar")
                                        .font(.subheadline)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel(L10n.editDateAccessibilityLabel)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                    }
                }

                // New sessions get explicit pickers instead of the compact
                // header lines: pick a type, pick a date (defaults to today).
                if isNew {
                    Section {
                        typePicker
                            .listRowBackground(groupBorderedRow(.first))
                        DatePicker(L10n.dateLabel, selection: $session.date, displayedComponents: [.date])
                            .environment(\.locale, Locale(identifier: "he_IL"))
                            .listRowBackground(groupBorderedRow(.last))
                    }
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
                    HStack(alignment: .bottom) {
                        NotesField(text: $session.notes, placeholder: L10n.optionalNotesPlaceholder,
                                   minLines: 3, maxLines: 8)
                        recordControl
                    }
                    // The AI-summary row below always closes this group, so
                    // every other row is a first/middle slice of the outline.
                    .listRowBackground(groupBorderedRow(.first))
                    // Transcription starts automatically when recording
                    // stops, so this row only ever appears after a failed
                    // transcription — the recording survives for a retry.
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
                                  || isAnonymizingTranscription)
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
                        .listRowBackground(groupBorderedRow(.last))
                    }
                }

                if !isNew {
                    questionnaireSection
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
            .patientAtmosphere(PatientAvatarColor.background(for: patient.id))
            .themedScreen()
            .dismissesKeyboardOnTap()
//            .navigationTitle(isNew
//                             ? L10n.newSessionTitle
//                             : L10n.sessionEditorTitle(sessionNumber))
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
                    .disabled(isSaving)
                }
                if !isNew {
                    // Save sits next to the menu (first in the group, so it
                    // lands on the menu's reading-direction side), enabled
                    // only once something actually changed.
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button(L10n.save) { save() }
                            .fontWeight(.semibold)
                            .disabled(isSaving || !hasUnsavedChanges)
                        Menu {
                            Button(L10n.deleteSessionAction, role: .destructive) {
                                isShowingDeleteConfirmation = true
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .rotationEffect(.degrees(90))
                        }
                        .disabled(isSaving)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isNew {
                    Button(action: { save() }) {
                        Group {
                            if isSaving {
                                ProgressView()
                                    .tint(Theme.textOnAccent)
                            } else {
                                Text(L10n.addSessionAction)
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(.pressableProminent)
                    .disabled(isSaving)
                    .padding(24)
                }
            }
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
                Button(L10n.saveChangesAction) { save(thenDismiss: true) }
                Button(L10n.discardChangesAction, role: .destructive) {
                    // The session object is shared, so revert the edits
                    // instead of leaving them in memory unsaved.
                    if let initialDate { session.date = initialDate }
                    if let initialNotes { session.notes = initialNotes }
                    session.type = initialType
                    dismiss()
                }
                Button(L10n.keepEditingAction, role: .cancel) {}
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
            .busyOverlay(isSaving, label: busyLabel)
            .animation(.easeInOut(duration: 0.2), value: errorMessage)
            .animation(.easeInOut(duration: 0.2), value: isTranscribing)
            .animation(.easeInOut(duration: 0.2), value: isAnonymizingTranscription)
            .onAppear {
                if initialDate == nil {
                    initialDate = session.date
                    initialNotes = session.notes
                    initialType = session.type
                }
            }
            .task { await loadQuestionnaire() }
            .sheet(isPresented: $isEditingDate) {
                NavigationStack {
                    DatePicker(L10n.dateLabel, selection: $session.date, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .environment(\.locale, Locale(identifier: "he_IL"))
                        .padding()
                        .navigationTitle(L10n.sessionDateTitle)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L10n.done) { isEditingDate = false }
                            }
                        }
                }
                .presentationDetents([.medium])
                .appTextSize()
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
                                    accent: PatientAvatarColor.background(for: patient.id))
            }
        }
        .appTextSize()
    }

    /// The session-type options, shared by the new-session picker row and
    /// the edit-mode pencil menu.
    private var typePicker: some View {
        Picker(L10n.sessionTypeLabel, selection: $session.type) {
            Text(L10n.sessionTypeNone).tag(SessionType?.none)
            ForEach(SessionType.allCases, id: \.self) { type in
                Text(L10n.label(for: type)).tag(SessionType?.some(type))
            }
        }
    }

    /// Mic button living at the edge of the notes text box. While recording it
    /// turns into a stop button with the elapsed time; stopping asks whether
    /// to transcribe into the notes or discard.
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
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.error)
                }
                .buttonStyle(.plain)
            }
        } else {
            Button {
                Task { await voiceRecorder.startRecording() }
            } label: {
                Image(systemName: "mic.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
            .disabled(isTranscribing || isAnonymizingTranscription)
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
                let existing = session.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                let combined = existing.isEmpty ? text : session.notes + "\n\n" + text
                let anonymized = try await store.anonymizedText(combined)
                session.notes = anonymized
                voiceRecorder.discard()
                isAnonymizingTranscription = false
                await autosaveSession()
            } catch {
                voiceRecorder.errorMessage = error.localizedDescription
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
                // Saved silently the moment it arrives; the sheet opens for
                // review without asking to keep it.
                saveStructuredNotes(analysis)
                analysisResult = SessionAnalysisResult(analysis: analysis,
                                                       requiresSaveDecision: false)
            } catch {
                errorMessage = error.localizedDescription
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
        guard session.databaseID != nil else { return }
        do {
            try await store.updateSession(session)
            // The silent save is the new baseline, so backing out without
            // further edits no longer warns about unsaved changes.
            initialDate = session.date
            initialNotes = session.notes
            initialType = session.type
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes the session (after the confirmation alert) and closes the editor.
    private func deleteSession() {
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
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Keeps a generated summary on the session and persists it. For a new
    /// session the summary is inserted together with the session on Save.
    private func saveStructuredNotes(_ analysis: WhisperService.CBTSessionAnalysis) {
        session.structuredNotes = analysis
        guard session.databaseID != nil else { return }
        Task {
            do {
                try await store.updateSession(session)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
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
        guard let current = questionnaire,
              let records = store.cachedQuestionnaires(for: patient) else { return nil }
        return records
            .filter { $0.id != current.id && $0.answeredDate <= current.answeredDate }
            .max { $0.answeredDate < $1.answeredDate }
    }

    private var questionnaireSection: some View {
        Section(L10n.questionnaireSectionTitle) {
            if let questionnaire {
                // Opens the questionnaire pre-filled with the saved answers,
                // read-only until Edit is chosen; saving upserts the same row.
                NavigationLink {
                    CombinedMoodQuestionnaireView(patient: patient, session: session,
                                                  isExisting: true)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
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
            } else if isLoadingQuestionnaire {
                ProgressView()
            } else {
                NavigationLink {
                    CombinedMoodQuestionnaireView(patient: patient, session: session)
                } label: {
                    Label(L10n.addQuestionnaireAction, systemImage: "plus")
                }
            }
        }
        // Only one of the section's rows is ever visible at a time.
        .listRowBackground(groupBorderedRow(.only))
    }

    /// Refreshes the patient's questionnaire cache from the server; the
    /// cached value is already shown while this runs.
    private func loadQuestionnaire() async {
        guard !isNew, session.databaseID != nil else { return }

        syncSessionQuestionnaire()
        if store.cachedQuestionnaires(for: patient) == nil {
            isLoadingQuestionnaire = true
        }
        do {
            _ = try await store.loadQuestionnaires(for: patient)
        } catch {
            // Keep whatever the cache had; the section shows the add button
            // rather than blocking the editor on a failed refresh.
        }
        isLoadingQuestionnaire = false
        syncSessionQuestionnaire()
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
        errorMessage = nil
        busyLabel = L10n.anonymizingStatusLabel
        isSaving = true
        Task {
            do {
                if isNew {
                    try await store.addSession(session, for: patient)
                    dismiss()
                } else {
                    try await store.updateSession(session)
                    // The save is the new baseline, so backing out without
                    // further edits no longer warns about unsaved changes.
                    initialDate = session.date
                    initialNotes = session.notes
                    initialType = session.type
                    if thenDismiss { dismiss() }
                }
            } catch {
                errorMessage = error.localizedDescription
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
        .appTextSize()
}
