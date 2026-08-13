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

    @Environment(PatientStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var isLoadingQuestionnaire = false
    @State private var voiceRecorder = VoiceNoteRecorder()
    @State private var isTranscribing = false

    @State private var images: [SessionImageItem] = []
    @State private var removedUploadedFileNames: [String] = []
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var isShowingCamera = false
    @State private var isShowingUploadOptions = false
    @State private var isShowingPhotoPicker = false
    @State private var isLoadingImages = false
    @State private var viewerItem: SessionImageItem?

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

                imagesSection

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
            .fullScreenCover(item: $viewerItem) { item in
                SessionImageViewer(image: item.uiImage) { edited in
                    replaceImage(item, with: edited)
                } onTranscribed: { text in
                    appendImageTranscription(text)
                }
            }
        }
    }

    /// Picked and stored images for this session, with add/delete controls.
    /// Changes are pushed to Supabase Storage when the session is saved.
    private var imagesSection: some View {
        Section(QuestionnaireText.imagesSectionTitle) {
            if isLoadingImages {
                ProgressView()
            }

            if !images.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(images) { item in
                            ZStack(alignment: .topTrailing) {
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
                                Button {
                                    removeImage(item)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white, .black.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                                .padding(4)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Button {
                isShowingUploadOptions = true
            } label: {
                Label(QuestionnaireText.uploadDocumentAction, systemImage: "doc.badge.plus")
            }
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
