import SwiftUI
import PhotosUI

/// One image attached to the session, either freshly picked or loaded from
/// Supabase Storage.
private struct SessionImageItem: Identifiable {
    let id = UUID()
    let fileName: String
    let uiImage: UIImage
    let data: Data
    var isUploaded: Bool
}

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
    @State private var errorMessage: String?
    @State private var isShowingCancelWarning = false
    @State private var initialDate: Date?
    @State private var initialNotes: String?
    @State private var isLoadingQuestionnaire = false
    @State private var voiceRecorder = VoiceNoteRecorder()
    @State private var isTranscribing = false
    @State private var isAnalyzing = false
    @State private var analysisResult: SessionAnalysisResult?
    @State private var isShowingTranscribeDialog = false
    @State private var isReshowingTranscribeDialog = false

    @State private var images: [SessionImageItem] = []
    @State private var removedUploadedFileNames: [String] = []
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var isShowingCamera = false
    @State private var isShowingUploadOptions = false
    @State private var isShowingPhotoPicker = false
    @State private var isLoadingImages = false
    @State private var viewerItem: SessionImageItem?

    /// Whether anything would be lost by dismissing without saving: an edited
    /// date or notes, pending image additions/removals, or a voice note that
    /// hasn't been transcribed into the notes yet.
    private var hasUnsavedChanges: Bool {
        if let initialDate, let initialNotes,
           initialDate != session.date || initialNotes != session.notes {
            return true
        }
        if !removedUploadedFileNames.isEmpty { return true }
        if images.contains(where: { !$0.isUploaded }) { return true }
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
        guard let databaseID = patient.databaseID else { return patient }
        return store.patients.first { $0.databaseID == databaseID } ?? patient
    }

    /// The patient's most recent session before this one.
    private var previousSession: Session? {
        storePatient.sessions
            .filter { $0.id != session.id && $0.date <= session.date }
            .max { $0.date < $1.date }
    }

    /// Indices into the previous session's follow-up questions that the
    /// therapist marked "Follow up", surfaced at the top of this editor.
    /// Indices (not copies) so the questions can be marked discussed in place.
    private var previousFollowUpIndices: [Int] {
        guard let questions = previousSession?.structuredNotes?.followUpQuestions else { return [] }
        return questions.indices.filter { questions[$0].status == .followUp }
    }

    var body: some View {
        NavigationStack {
            Form {
                if !previousFollowUpIndices.isEmpty {
                    Section {
                        ForEach(previousFollowUpIndices, id: \.self) { questionIndex in
                            if let item = previousSession?.structuredNotes?.followUpQuestions[questionIndex] {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.question)
                                            .font(.subheadline.weight(.semibold))
                                        if !item.reason.isEmpty {
                                            Text(item.reason)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Button {
                                        appendNotesBlock(item.question)
                                    } label: {
                                        Image(systemName: "text.badge.plus")
                                            .font(.title3)
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Add to notes")
                                    Button {
                                        markPreviousFollowUpDiscussed(questionIndex)
                                    } label: {
                                        Image(systemName: "checkmark.circle")
                                            .font(.title3)
                                            .foregroundStyle(.green)
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Mark discussed")
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    } header: {
                        Label("From Last Session", systemImage: "arrow.uturn.forward")
                    }
                }

                Section {
                    DatePicker("Date", selection: $session.date, displayedComponents: [.date])
                }

                Section("Notes") {
                    HStack(alignment: .bottom) {
                        NotesField(text: $session.notes, placeholder: "Optional notes",
                                   minLines: 3, maxLines: 8)
                        recordControl
                    }
                    .confirmationDialog(QuestionnaireText.recordingFinishedTitle,
                                        isPresented: $isShowingTranscribeDialog,
                                        titleVisibility: .visible) {
                        Button(voiceRecorder.isPlaying
                               ? QuestionnaireText.stopPlaybackAction
                               : QuestionnaireText.playRecordingAction) {
                            voiceRecorder.togglePlayback()
                            isReshowingTranscribeDialog = true
                        }
                        Button(QuestionnaireText.transcribeAction) { transcribe() }
                        Button(QuestionnaireText.discardRecordingAction, role: .destructive) {
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
                            Text(QuestionnaireText.transcribingLabel)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let recorderError = voiceRecorder.errorMessage {
                        Text(recorderError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if isAnalyzing {
                        HStack {
                            ProgressView()
                            Text("Analyzing…")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            analyze()
                        } label: {
                            Label("AI Summary", systemImage: "sparkles")
                        }
                        .disabled(session.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if let structuredNotes = session.structuredNotes {
                        Button {
                            analysisResult = SessionAnalysisResult(analysis: structuredNotes,
                                                                   requiresSaveDecision: false)
                        } label: {
                            Label("Show Structured Summary", systemImage: "doc.text.magnifyingglass")
                        }
                    }
                }

                if !isNew {
                    questionnaireSection
                }

                if isLoadingImages || !images.isEmpty {
                    Section {
                        if isLoadingImages {
                            ProgressView()
                        }
                        if !images.isEmpty {
                            imagesRow
                        }
                    }
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
            .overlay(alignment: .bottomTrailing) {
                floatingUploadButton
            }
            .navigationTitle(isNew
                             ? "New Session"
                             : "Session\(sessionNumber.map { " \($0)" } ?? "")")
            .navigationSubtitle(patient.displayName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            isShowingCancelWarning = true
                        } else {
                            dismiss()
                        }
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isSaving)
                }
            }
            // An alert, not a confirmation dialog: iPad popover dialogs hide
            // cancel-role buttons, and Keep Editing must always be offered.
            .alert(QuestionnaireText.discardChangesTitle,
                   isPresented: $isShowingCancelWarning) {
                Button(QuestionnaireText.saveChangesAction) { save() }
                Button(QuestionnaireText.discardChangesAction, role: .destructive) {
                    // The session object is shared, so revert the edits
                    // instead of leaving them in memory unsaved.
                    if let initialDate { session.date = initialDate }
                    if let initialNotes { session.notes = initialNotes }
                    dismiss()
                }
                Button(QuestionnaireText.keepEditingAction, role: .cancel) {}
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
            .busyOverlay(isSaving)
            .animation(.easeInOut(duration: 0.2), value: errorMessage)
            .animation(.easeInOut(duration: 0.2), value: isTranscribing)
            .onAppear {
                if initialDate == nil {
                    initialDate = session.date
                    initialNotes = session.notes
                }
            }
            .task { await loadQuestionnaire() }
            .task { await loadImages() }
            .onChange(of: photoSelection) { _, items in
                guard !items.isEmpty else { return }
                photoSelection = []
                Task {
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            addImage(image)
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraPicker { image in
                    addImage(image)
                }
                .ignoresSafeArea()
            }
            .sheet(item: $analysisResult) { result in
                SessionAnalysisView(analysis: result.analysis,
                                    requiresSaveDecision: result.requiresSaveDecision,
                                    onSave: { saveStructuredNotes($0) })
            }
            .fullScreenCover(item: $viewerItem) { item in
                SessionImageViewer(image: item.uiImage) { edited in
                    replaceImage(item, with: edited)
                } onTranscribed: { text in
                    appendImageTranscription(text)
                }
                .appTextSize()
            }
        }
        .appTextSize()
    }

    /// Picked and stored images for this session, shown under the notes.
    /// Changes are pushed to Supabase Storage when the session is saved.
    private var imagesRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(images) { item in
                    Button {
                        viewerItem = item
                    } label: {
                        Image(uiImage: item.uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(QuestionnaireText.deleteImageAction, role: .destructive) {
                            removeImage(item)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    /// Small floating button that offers the image upload options.
    private var floatingUploadButton: some View {
        Button {
            isShowingUploadOptions = true
        } label: {
            Image(systemName: "doc.badge.plus")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Circle().fill(.tint))
                .shadow(radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(QuestionnaireText.uploadDocumentAction)
        .padding()
        .confirmationDialog(QuestionnaireText.uploadDocumentAction,
                            isPresented: $isShowingUploadOptions,
                            titleVisibility: .hidden) {
            Button(QuestionnaireText.addImageFromLibraryAction) {
                isShowingPhotoPicker = true
            }
            if CameraPicker.isCameraAvailable {
                Button(QuestionnaireText.takePhotoAction) {
                    isShowingCamera = true
                }
            }
        }
        .photosPicker(isPresented: $isShowingPhotoPicker,
                      selection: $photoSelection,
                      maxSelectionCount: 10,
                      matching: .images)
    }

    /// Compresses and stores a newly picked image locally until Save.
    private func addImage(_ image: UIImage) {
        guard let jpeg = image.resizedJPEGData(maxDimension: 1600, quality: 0.7),
              let compressed = UIImage(data: jpeg) else { return }
        images.append(SessionImageItem(
            fileName: "\(UUID().uuidString).jpg",
            uiImage: compressed,
            data: jpeg,
            isUploaded: false
        ))
    }

    private func removeImage(_ item: SessionImageItem) {
        images.removeAll { $0.id == item.id }
        if item.isUploaded {
            removedUploadedFileNames.append(item.fileName)
        }
    }

    /// Swaps an image for its edited version. The old stored file is queued
    /// for deletion and the new one uploads on the next session save.
    private func replaceImage(_ item: SessionImageItem, with newImage: UIImage) {
        guard let index = images.firstIndex(where: { $0.id == item.id }),
              let jpeg = newImage.resizedJPEGData(maxDimension: 1600, quality: 0.7),
              let compressed = UIImage(data: jpeg) else { return }
        if item.isUploaded {
            removedUploadedFileNames.append(item.fileName)
        }
        images[index] = SessionImageItem(
            fileName: "\(UUID().uuidString).jpg",
            uiImage: compressed,
            data: jpeg,
            isUploaded: false
        )
    }

    /// Shows this session's stored images, from the cache when available.
    private func loadImages() async {
        guard !isNew, session.databaseID != nil else { return }

        if let cached = store.cachedSessionImages(for: session) {
            setImages(from: cached)
            return
        }
        isLoadingImages = true
        if let loaded = try? await store.loadSessionImages(for: session) {
            setImages(from: loaded)
        }
        isLoadingImages = false
    }

    private func setImages(from pairs: [(fileName: String, data: Data)]) {
        images = pairs.compactMap { pair in
            UIImage(data: pair.data).map {
                SessionImageItem(fileName: pair.fileName, uiImage: $0, data: pair.data, isUploaded: true)
            }
        }
    }

    /// Applies pending image changes to Supabase Storage: removals first,
    /// then uploads of newly added images.
    private func syncImages() async throws {
        for fileName in removedUploadedFileNames {
            try await store.deleteSessionImage(fileName: fileName, for: session)
        }
        removedUploadedFileNames = []

        for index in images.indices where !images[index].isUploaded {
            try await store.uploadSessionImage(images[index].data, fileName: images[index].fileName, for: session)
            images[index].isUploaded = true
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

    /// Sends the notes text to the AI analysis Edge Function and presents
    /// the full response in a sheet.
    private func analyze() {
        let whisperService = WhisperService(client: auth.client)
        errorMessage = nil
        isAnalyzing = true
        Task {
            do {
                let analysis = try await whisperService.analyzeSession(sessionNotes: session.notes)
                analysisResult = SessionAnalysisResult(analysis: analysis,
                                                       requiresSaveDecision: true)
            } catch {
                errorMessage = error.localizedDescription
            }
            isAnalyzing = false
        }
    }

    /// Marks a follow-up question of the previous session as discussed and
    /// persists the previous session's review; the row leaves this editor's
    /// From Last Session list immediately.
    private func markPreviousFollowUpDiscussed(_ questionIndex: Int) {
        guard let previous = previousSession else { return }
        previous.structuredNotes?.followUpQuestions[questionIndex].status = .discussed
        guard previous.databaseID != nil else { return }
        Task {
            do {
                try await store.updateSession(previous)
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

    private func appendTranscription(_ text: String) {
        let timeText = Date.now.formatted(date: .numeric, time: .shortened)
        appendNotesBlock("\(QuestionnaireText.transcriptionHeader(timeText: timeText))\n\(text)")
    }

    /// Adds text extracted from an image to the notes, under a dated header.
    private func appendImageTranscription(_ text: String) {
        let dateText = Date.now.formatted(date: .numeric, time: .omitted)
        appendNotesBlock("\(QuestionnaireText.imageTranscriptionHeader(dateText: dateText))\n\(text)")
    }

    private func appendNotesBlock(_ block: String) {
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
                // The session now has a database ID, so image changes can sync.
                try await syncImages()
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
