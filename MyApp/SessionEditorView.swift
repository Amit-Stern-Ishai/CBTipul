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

    @Environment(PatientStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var isLoadingQuestionnaire = false
    @State private var voiceRecorder = VoiceNoteRecorder()
    @State private var isTranscribing = false

    /// This session's saved questionnaire, read live from the store's cache
    /// so the section updates right after one is filled in and saved.
    private var questionnaire: CompletedQuestionnaire? {
        guard let sessionID = session.databaseID else { return nil }
        return store.cachedQuestionnaires(for: patient)?.first { $0.sessionID == sessionID }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(patient.displayName, systemImage: "person")
                        .foregroundStyle(.secondary)
                }

                Section("Session") {
                    DatePicker("Date", selection: $session.date, displayedComponents: [.date])
                }

                Section("Notes") {
                    TextField("Optional notes", text: $session.notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                voiceNoteSection

                if !isNew {
                    questionnaireSection
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .dismissesKeyboardOnTap()
            .navigationTitle(isNew ? "New Session" : "Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isSaving)
                }
            }
            .overlay {
                if isSaving { ProgressView() }
            }
            .task { await loadQuestionnaire() }
        }
    }

    /// Records, plays back, and discards a voice note for the session.
    /// Transcription (Whisper) will be attached to the recorded file next.
    private var voiceNoteSection: some View {
        Section(QuestionnaireText.voiceNoteSectionTitle) {
            if voiceRecorder.isRecording {
                HStack {
                    Label(QuestionnaireText.recordingLabel, systemImage: "waveform")
                        .foregroundStyle(.red)
                    Spacer()
                    Text(formattedDuration)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Button {
                        voiceRecorder.stopRecording()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            } else if voiceRecorder.recordingURL != nil {
                HStack {
                    Button {
                        voiceRecorder.togglePlayback()
                    } label: {
                        Image(systemName: voiceRecorder.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)

                    Text("\(QuestionnaireText.voiceNoteLabel) (\(formattedDuration))")

                    Spacer()

                    Button {
                        voiceRecorder.discard()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }

                if isTranscribing {
                    HStack {
                        ProgressView()
                        Text(QuestionnaireText.transcribingLabel)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        transcribe()
                    } label: {
                        Label(QuestionnaireText.transcribeAction, systemImage: "text.bubble")
                    }
                }
            } else {
                Button {
                    Task { await voiceRecorder.startRecording() }
                } label: {
                    Label(QuestionnaireText.recordVoiceNoteAction, systemImage: "mic.fill")
                }
            }

            if let recorderError = voiceRecorder.errorMessage {
                Text(recorderError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
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
        voiceRecorder.errorMessage = nil
        isTranscribing = true
        Task {
            do {
                let text = try await WhisperService.transcribe(fileURL: fileURL)
                appendTranscription(text)
            } catch {
                voiceRecorder.errorMessage = error.localizedDescription
            }
            isTranscribing = false
        }
    }

    private func appendTranscription(_ text: String) {
        let timeText = Date.now.formatted(date: .numeric, time: .shortened)
        let block = "\(QuestionnaireText.transcriptionHeader(timeText: timeText))\n\(text)"
        if session.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            session.notes = block
        } else {
            session.notes += "\n\n" + block
        }
    }

    private var questionnaireSection: some View {
        Section(QuestionnaireText.questionnaireSectionTitle) {
            if let questionnaire {
                // Opens the editable questionnaire pre-filled with the saved
                // answers; saving upserts the same row.
                NavigationLink {
                    CombinedMoodQuestionnaireView(patient: patient, session: session)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(questionnaire.answeredDate, style: .date)
                            .font(.headline)
                        Text("\(QuestionnaireText.gad7ShortName): \(questionnaire.questionnaire.gad7Score) · \(QuestionnaireText.phq9ShortName): \(questionnaire.questionnaire.phq9Score)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if isLoadingQuestionnaire {
                ProgressView()
            } else {
                NavigationLink {
                    CombinedMoodQuestionnaireView(patient: patient, session: session)
                } label: {
                    Label(QuestionnaireText.addQuestionnaireAction, systemImage: "plus")
                }
            }
        }
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

    private func save() {
        errorMessage = nil
        isSaving = true
        Task {
            do {
                if isNew {
                    try await store.addSession(session, for: patient)
                } else {
                    try await store.updateSession(session)
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

#Preview {
    SessionEditorView(session: Session(), patient: Patient(firstName: "Alex"), isNew: true)
        .environment(PatientStore(client: AuthManager().client))
}
