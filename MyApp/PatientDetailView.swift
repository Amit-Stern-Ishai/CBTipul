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
    @State private var errorMessage: String?
    @State private var isShowingBackWarning = false
    @State private var isShowingDeleteConfirmation = false
    @State private var initialNotes: String?
    @State private var isEditingGoal = false
    @State private var goalDraft = ""
    @State private var voiceRecorder = VoiceNoteRecorder()
    @State private var isTranscribing = false
    @State private var isShowingTranscribeDialog = false
    @State private var isReshowingTranscribeDialog = false
    @State private var isPreparing = false
    @State private var preparationResult: NextSessionPreparationResult?
    @State private var savedPreparation: SavedPreparation?

    /// A saved preparation goes stale once a session dated after its
    /// generation exists — it prepared for a session that already happened.
    private var isSavedPreparationOutdated: Bool {
        guard let savedPreparation else { return false }
        return patient.sessions.contains { $0.date > savedPreparation.generatedAt }
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

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    Text(patient.displayName)
                        .font(.title2.bold())
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
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(L10n.editTreatmentGoalAction)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    // The goal is the screen's single prestige-gold mark.
                    .background(Theme.prestigeGhost, in: RoundedRectangle(cornerRadius: 12))
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
                        Spacer()
                    }
                    if let type = lastSession?.type {
                        Text(L10n.label(for: type))
                        Spacer()
                    }
                    Text(L10n.sessionsCount(patient.sessions.count))
                    Spacer()
                }
                .font(.subheadline.weight(.semibold))
            }
            .listRowBackground(Theme.surface)

            Section {
                Picker(selection: $patient.status) {
                    ForEach(PatientStatus.allCases) { Text($0.rawValue).tag($0) }
                } label: {
                    iconChip("person.crop.circle.badge.checkmark", color: .green, title: L10n.statusLabel)
                }

                NavigationLink {
                    PatientSessionsView(patient: patient)
                } label: {
                    iconChip("calendar", color: .blue, title: L10n.sessionsTitle)
                }

                NavigationLink {
                    PatientQuestionnairesView(patient: patient)
                } label: {
                    iconChip("chart.xyaxis.line", color: Theme.warning, title: L10n.viewQuestionnairesAction)
                }

//                NavigationLink {
//                    MyFormulationView(patient: patient)
//                } label: {
//                    iconChip("brain.head.profile", color: .pink, title: L10n.myFormulationTitle)
//                }

                NavigationLink {
                    PatientAIView(patient: patient)
                } label: {
                    iconChip("sparkles", color: .purple, title: L10n.aiAction)
                }

                Button {
                    prepareNextSession()
                } label: {
                    HStack {
                        iconChip("wand.and.stars", color: .indigo, title: L10n.prepareNextSessionAction)
                        if isPreparing {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isPreparing)

                if let savedPreparation {
                    Button {
                        preparationResult = NextSessionPreparationResult(
                            response: savedPreparation.response,
                            isOutdated: isSavedPreparationOutdated
                        )
                    } label: {
                        HStack {
                            iconChip("doc.text.magnifyingglass", color: .teal, title: L10n.lastPreparationAction)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(savedPreparation.generatedAt,
                                     format: .dateTime.day().month().year())
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
                }
            }
            .listRowBackground(Theme.surface)

            Section(L10n.notesSection) {
                HStack(alignment: .bottom) {
                    NotesField(text: $patient.notes, placeholder: L10n.optionalNotesPlaceholder,
                               minLines: 3, maxLines: 8)
                    recordControl
                }
                .confirmationDialog(L10n.recordingFinishedTitle,
                                    isPresented: $isShowingTranscribeDialog,
                                    titleVisibility: .visible) {
                    Button(voiceRecorder.isPlaying
                           ? L10n.stopPlaybackAction
                           : L10n.playRecordingAction) {
                        voiceRecorder.togglePlayback()
                        isReshowingTranscribeDialog = true
                    }
                    Button(L10n.transcribeAction) { transcribe() }
                    Button(L10n.discardRecordingAction, role: .destructive) {
                        voiceRecorder.discard()
                    }
                }
                .onChange(of: isShowingTranscribeDialog) { _, isShowing in
                    guard !isShowing else { return }
                    if isReshowingTranscribeDialog {
                        // Play/Stop keeps the choice open: re-present.
                        isReshowingTranscribeDialog = false
                        Task { isShowingTranscribeDialog = true }
                    } else if !isTranscribing, voiceRecorder.recordingURL != nil {
                        // Dismissing without choosing (tap outside) counts
                        // as discard; nothing else can reach the file.
                        voiceRecorder.discard()
                    }
                }

                if isTranscribing {
                    HStack {
                        ProgressView()
                        Text(L10n.transcribingLabel)
                            .foregroundStyle(.secondary)
                    }
                }

                if let recorderError = voiceRecorder.errorMessage {
                    Text(recorderError)
                        .font(.footnote)
                        .foregroundStyle(Theme.error)
                }
            }
            .listRowBackground(Theme.surface)

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Theme.error)
                }
                .listRowBackground(Theme.surface)
            }
        }
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
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.save) { save() }
                    .disabled(isSaving || !hasUnsavedChanges)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(L10n.deletePatientAction, role: .destructive) {
                        isShowingDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(isSaving)
            }
        }
        .alert(L10n.deletePatientConfirmTitle,
               isPresented: $isShowingDeleteConfirmation) {
            Button(L10n.deletePatientAction, role: .destructive) { deletePatient() }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.deletePatientConfirmMessage)
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
            NextSessionPreparationView(response: result.response)
        }
        .sheet(isPresented: $isEditingGoal) {
            NavigationStack {
                Form {
                    TextField(L10n.noTreatmentGoalPlaceholder, text: $goalDraft, axis: .vertical)
                }
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
        .busyOverlay(isSaving)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .animation(.easeInOut(duration: 0.2), value: isTranscribing)
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
                    .foregroundStyle(.red)
                Button {
                    voiceRecorder.stopRecording()
                    isShowingTranscribeDialog = true
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
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
            .disabled(isTranscribing)
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
                appendTranscription(text)
                voiceRecorder.discard()
                isTranscribing = false
            } catch {
                voiceRecorder.errorMessage = error.localizedDescription
                isTranscribing = false
                // Re-ask so the recording can be retried or discarded.
                isShowingTranscribeDialog = true
            }
        }
    }

    private func appendTranscription(_ text: String) {
        let timeText = Date.now.formatted(date: .numeric, time: .shortened)
        appendNotesBlock("\(L10n.transcriptionHeader(timeText: timeText))\n\(text)")
    }

    private func appendNotesBlock(_ block: String) {
        if patient.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            patient.notes = block
        } else {
            patient.notes += "\n\n" + block
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
                let response = try await WhisperService(client: auth.client)
                    .prepareNextSession(patientContext: context)
                savedPreparation = SavedPreparation.save(response, for: patient.id)
                preparationResult = NextSessionPreparationResult(response: response)
            } catch {
                errorMessage = error.localizedDescription
            }
            isPreparing = false
        }
    }

    /// Deletes the patient (after the confirmation alert) and leaves the screen.
    private func deletePatient() {
        errorMessage = nil
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
    private func iconChip(_ systemImage: String, color: Color, title: String) -> some View {
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
        PatientDetailView(patient: Patient(id: .integer(1), firstName: "Alex", lastName: "Rivera", sessions: [Session()]))
    }
    .environment(auth)
    .environment(PatientStore(client: auth.client))
}
