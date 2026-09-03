import SwiftUI

/// Shows a patient's status, links to their sessions, questionnaires, and
/// AI assistant, and the patient's own notes (with voice transcription,
/// same behavior as session notes).
struct PatientDetailView: View {
    @Bindable var patient: Patient

    @Environment(AuthManager.self) private var auth
    @Environment(PatientStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isSaving = false
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
    @State private var voiceRecorder = VoiceNoteRecorder()
    @State private var isTranscribing = false
    /// True while a fresh transcript is being anonymized, before it may
    /// appear in the notes field.
    @State private var isAnonymizingTranscription = false
    @State private var isPreparing = false
    @State private var preparationResult: NextSessionPreparationResult?
    @State private var savedPreparation: SavedPreparation?

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
    /// notes or a voice note that hasn't been transcribed yet. The treatment
    /// goal is not included — its edit sheet saves immediately.
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

    /// True until the questionnaire cache has been filled for this patient,
    /// while the current-state chips show reserved placeholders.
    private var isLoadingQuestionnaires: Bool {
        store.cachedQuestionnaires(for: patient) == nil
    }

    /// The most recently answered questionnaire, from the store's cache.
    private var lastQuestionnaire: CompletedQuestionnaire? {
        store.cachedQuestionnaires(for: patient)?.max { $0.answeredDate < $1.answeredDate }
    }

    /// The questionnaire answered before the most recent one, for the
    /// score chips' trend arrows.
    private var previousQuestionnaire: CompletedQuestionnaire? {
        guard let records = store.cachedQuestionnaires(for: patient),
              let last = lastQuestionnaire else { return nil }
        return records
            .filter { $0.id != last.id && $0.answeredDate <= last.answeredDate }
            .max { $0.answeredDate < $1.answeredDate }
    }

    /// The patient's most recent session by date.
    private var lastSession: Session? {
        patient.sessions.max { $0.date < $1.date }
    }

    /// The patient's identity color — the exact color of their list avatar.
    /// Used only for patient-specific accents; gold remains the color of
    /// app actions and navigation, navy the primary surfaces.
    private var patientColor: Color {
        PatientAvatarColor.background(for: patient.id)
    }

    /// Black or white, matching the contrast rule of the avatar initials.
    private var onPatientColor: Color {
        PatientAvatarColor.foreground(for: patient.id)
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
                VStack(spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(patient.displayName)
                            .font(.title2.bold())
                        Button {
                            startEditingName()
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(onPatientColor, patientColor)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(L10n.editPatientNameAction)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(treatmentGoal.wrappedValue.isEmpty
                             ? L10n.noTreatmentGoalPlaceholder
                             : treatmentGoal.wrappedValue)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(treatmentGoal.wrappedValue.isEmpty ? .secondary : .primary)
                            .multilineTextAlignment(.center)
                        Button {
                            goalDraft = treatmentGoal.wrappedValue
                            isEditingGoal = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(onPatientColor, patientColor)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(L10n.editTreatmentGoalAction)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    // The goal pill carries the patient's identity color —
                    // same ghost strength the gold version used.
                    .background(patientColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    StatusBadge(status: patient.status)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section {
                HStack {
                    Spacer()
                    if let questionnaire = lastQuestionnaire?.questionnaire {
                        VStack(spacing: 4) {
                            ScoreCapsule.gad7(questionnaire, previous: previousQuestionnaire?.questionnaire)
                            ScoreCapsule.phq9(questionnaire, previous: previousQuestionnaire?.questionnaire)
                        }
                        .transition(.opacity)
                        Spacer()
                    } else if isLoadingQuestionnaires {
                        // Reserve the chips' space while the cache fills, so
                        // the row doesn't jump when the scores arrive.
                        VStack(spacing: 4) {
                            ScoreCapsule(text: L10n.scoreBadge(name: L10n.gad7ShortName, score: 10),
                                         color: Theme.textFaint)
                            ScoreCapsule(text: L10n.scoreBadge(name: L10n.phq9ShortName, score: 10),
                                         color: Theme.textFaint)
                        }
                        .redacted(reason: .placeholder)
                        .opacity(0.4)
                        .transition(.opacity)
                        Spacer()
                    }
                    if let type = lastSession?.type {
                        Text(L10n.label(for: type))
                        Spacer()
                    }
                    Text(L10n.sessionsCount(patient.sessionsUpToTodayCount))
                    Spacer()
                }
                .font(.subheadline.weight(.semibold))
                .animation(.easeInOut(duration: 0.35), value: isLoadingQuestionnaires)
                .animation(.easeInOut(duration: 0.35), value: lastQuestionnaire?.id)
            }
            .listRowBackground(groupBorderedRow(.only))

            Section {
                Picker(selection: $patient.status) {
                    ForEach(PatientStatus.allCases) { Text($0.rawValue).tag($0) }
                } label: {
                    iconChip("person.crop.circle.badge.checkmark", title: L10n.statusLabel)
                }
                .listRowBackground(groupBorderedRow(.first))

                NavigationLink {
                    PatientSessionsView(patient: patient)
                } label: {
                    iconChip("calendar", title: L10n.sessionsTitle)
                }
                .listRowBackground(groupBorderedRow(.middle))

                NavigationLink {
                    PatientQuestionnairesView(patient: patient)
                } label: {
                    iconChip("chart.xyaxis.line", title: L10n.viewQuestionnairesAction)
                }
                .listRowBackground(groupBorderedRow(.middle))

                NavigationLink {
                    PatientAIView(patient: patient)
                } label: {
                    iconChip("sparkles", title: L10n.aiAction)
                }
                .listRowBackground(groupBorderedRow(.middle))

                Button {
                    prepareNextSession()
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

            Section(L10n.notesSection) {
                HStack(alignment: .bottom) {
                    NotesField(text: $patient.notes, placeholder: L10n.optionalNotesPlaceholder,
                               minLines: 3, maxLines: 8)
                    recordControl
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
//        .navigationTitle(patient.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
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
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(L10n.save) { save() }
                        .disabled(isSaving || !hasUnsavedChanges)
                    Divider()
                    Button(L10n.deletePatientAction, role: .destructive) {
                        isShowingDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                }
                .disabled(isSaving)
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
                }
                .themedScreen()
                .navigationTitle(L10n.editPatientNameTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.cancel) { isEditingName = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.save) { saveEditedName() }
                            .disabled(firstNameDraft.trimmingCharacters(in: .whitespaces).isEmpty
                                      && lastNameDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .appTextSize()
            .presentationDetents([.medium])
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
        .busyOverlay(isSaving, label: busyLabel)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .animation(.easeInOut(duration: 0.2), value: isTranscribing)
        .animation(.easeInOut(duration: 0.2), value: isAnonymizingTranscription)
        .onAppear {
            if initialNotes == nil {
                initialNotes = patient.notes
            }
            if savedPreparation == nil {
                savedPreparation = SavedPreparation.load(for: patient.id)
            }
        }
        .task {
            // The last-questionnaire row needs the questionnaire cache filled.
            if store.cachedQuestionnaires(for: patient) == nil {
                _ = try? await store.loadQuestionnaires(for: patient)
            }
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
                let existing = patient.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                let combined = existing.isEmpty ? text : patient.notes + "\n\n" + text
                let anonymized = try await store.anonymizedText(combined)
                patient.notes = anonymized
                voiceRecorder.discard()
                isAnonymizingTranscription = false
                // Silently persist the transcription; the silent save is the
                // new baseline, so leaving afterwards doesn't warn.
                do {
                    try await store.updatePatientNotes(patient)
                    initialNotes = patient.notes
                } catch {
                    errorMessage = error.localizedDescription
                }
            } catch {
                voiceRecorder.errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
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
        firstNameDraft = parts.first ?? ""
        lastNameDraft = parts.count > 1 ? parts[1] : ""
        isEditingName = true
    }

    private func saveEditedName() {
        do {
            try store.renamePatient(patient, firstName: firstNameDraft, lastName: lastNameDraft)
            isEditingName = false
        } catch {
            errorMessage = error.localizedDescription
            isEditingName = false
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
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }

    private func save(thenDismiss: Bool = false) {
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
                if thenDismiss { dismiss() }
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
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

#Preview {
    let auth = AuthManager()
    NavigationStack {
        PatientDetailView(patient: Patient(id: .integer(1), firstName: "ישראלה", lastName: "ישראלית", sessions: [Session()]))
    }
    .environment(auth)
    .environment(PatientStore(client: auth.client))
}
