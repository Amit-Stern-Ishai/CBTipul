import SwiftUI

/// A patient's Diary 1 entries, newest first. Therapist-only for this step.
struct PatientDiaryOneView: View {
    let patient: Patient

    @Environment(DiaryOneStore.self) private var diary

    private enum LoadState {
        case loading
        case loaded
        case failed
    }

    @State private var loadState: LoadState = .loading

    private var entries: [DiaryOneEntry] {
        diary.entries(for: patient.id)
    }

    private var patientColor: Color {
        PatientAvatarColor.background(for: patient.id)
    }

    var body: some View {
        Group {
            switch loadState {
            case .loading where entries.isEmpty:
                ProgressView()
                    .tint(Theme.gold)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed where entries.isEmpty:
                fetchError
            case .loading, .loaded, .failed:
                entryList
            }
        }
        .patientAtmosphere(patientColor)
        .themedScreen()
        .demoModeChrome()
        .navigationTitleWithSubtitle(L10n.diaryOneTitle, subtitle: patient.displayName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    DiaryOneEntryFormView(patient: patient, mode: .create)
                        .id("diary-one-create-\(patient.id.queryValue)")
                } label: {
                    Label(L10n.diaryOneAddEntryAction, systemImage: "plus")
                }
            }
        }
        .onAppear {
            Task { await loadEntries() }
        }
    }

    private var entryList: some View {
        List {
            if case .failed = loadState {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.diaryOneLoadFailed)
                        .font(.footnote)
                        .foregroundStyle(Theme.error)
                    Button(L10n.retryAction) {
                        Task { await loadEntries() }
                    }
                }
                .listRowBackground(groupBorderedRow(.only))
            }

            if entries.isEmpty {
                VStack(spacing: 12) {
                    Text(L10n.diaryOneEmptyTitle)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text(L10n.diaryOneEmptyBody)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .listRowBackground(groupBorderedRow(.only))
            } else {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    NavigationLink {
                        DiaryOneEntryFormView(patient: patient, mode: .edit(entry))
                            .id(entry.id)
                    } label: {
                        diarySummary(entry)
                    }
                    .listRowBackground(groupBorderedRow(
                        .at(index, of: entries.count)
                    ))
                }
            }
        }
        .refreshable {
            await loadEntries()
        }
    }

    private var fetchError: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.diaryOneLoadFailed)
                .font(.body)
                .foregroundStyle(Theme.textBody)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { await loadEntries() }
            } label: {
                Text(L10n.retryAction)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.pressableProminent)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func diarySummary(_ entry: DiaryOneEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.hebrewNumericDate(entry.createdAt))
                .font(.headline)
            labeledLine(L10n.diaryOneEventTitle, entry.event)
            labeledLine(L10n.diaryOneThoughtTitle, entry.thought)
            labeledLine(
                L10n.diaryFeelingsTitle,
                L10n.diaryFeelingsPreview(entry.feelings)
            )
        }
        .padding(.vertical, 4)
    }

    private func labeledLine(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .lineLimit(2)
        }
    }

    private func groupBorderedRow(_ position: GroupRowPosition) -> some View {
        CBTipul.groupBorderedRow(position, accent: patientColor)
    }

    private func loadEntries() async {
        if entries.isEmpty {
            loadState = .loading
        }
        do {
            _ = try await diary.loadEntries(for: patient.id)
            loadState = .loaded
        } catch {
            loadState = .failed
        }
    }
}

/// Add or edit a Diary 1 entry. Physical symptoms are optional.
struct DiaryOneEntryFormView: View {
    let patient: Patient
    let mode: DiaryOneEditorMode

    @Environment(DiaryOneStore.self) private var diary
    @Environment(\.dismiss) private var dismiss

    @State private var draft: DiaryOneEntryDraft
    @State private var initialSnapshot: DiaryOneEntryDraft.Snapshot
    @State private var didAttemptSave = false
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var isShowingValidationAlert = false
    @State private var isShowingBackWarning = false
    @State private var isShowingDeleteConfirmation = false
    @State private var errorMessage: String?
    @State private var validationMessage: String?

    private var patientColor: Color {
        PatientAvatarColor.background(for: patient.id)
    }

    private var isBusy: Bool { isSaving || isDeleting }
    private var existing: DiaryOneEntry? { mode.existing }

    private var hasUnsavedChanges: Bool {
        draft.comparableSnapshot != initialSnapshot
    }

    init(patient: Patient, mode: DiaryOneEditorMode) {
        self.patient = patient
        self.mode = mode
        let hydrated: DiaryOneEntryDraft
        switch mode {
        case .create:
            hydrated = .empty
        case .edit(let entry):
            hydrated = .from(entry)
        }
        _draft = State(initialValue: hydrated)
        _initialSnapshot = State(initialValue: hydrated.comparableSnapshot)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stepCard(
                    title: L10n.diaryOneEventTitle,
                    question: L10n.diaryOneEventQuestion,
                    text: $draft.event,
                    incompleteMessage: didAttemptSave && draft.event.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? L10n.diaryOneValidationEvent : nil
                )
                stepCard(
                    title: L10n.diaryOneThoughtTitle,
                    question: L10n.diaryOneThoughtQuestion,
                    text: $draft.thought,
                    incompleteMessage: didAttemptSave && draft.thought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? L10n.diaryOneValidationThought : nil
                )
                feelingsCard
                stepCard(
                    title: L10n.diaryOneBehaviourTitle,
                    question: L10n.diaryOneBehaviourQuestion,
                    text: $draft.behaviour,
                    incompleteMessage: didAttemptSave && draft.behaviour.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? L10n.diaryOneValidationBehaviour : nil
                )
                stepCard(
                    title: L10n.diaryOnePhysicalSymptomsTitle,
                    question: L10n.diaryOnePhysicalSymptomsQuestion,
                    text: $draft.physicalSymptoms,
                    optionalHint: L10n.diaryOneOptionalHint
                )
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Theme.error)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .patientAtmosphere(patientColor)
        .themedScreen()
        .demoModeChrome()
        .dismissesKeyboardOnTap()
        .navigationTitle(L10n.diaryOneTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .busyOverlay(isBusy)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await save() }
            } label: {
                Text(L10n.diaryOneSaveEntryAction)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.pressableProminent)
            .disabled(isBusy)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Theme.base.opacity(0.95))
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    if hasUnsavedChanges {
                        isShowingBackWarning = true
                    } else {
                        dismiss()
                    }
                } label: {
                    Label(L10n.back, systemImage: "chevron.backward")
                        .labelStyle(.titleAndIcon)
                }
                .disabled(isBusy)
            }
            if existing != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        isShowingDeleteConfirmation = true
                    } label: {
                        Label(L10n.diaryOneDeleteAction, systemImage: "trash")
                    }
                    .disabled(isBusy)
                }
            }
        }
        .alert(L10n.diaryOneValidationTitle, isPresented: $isShowingValidationAlert) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(validationMessage ?? L10n.diaryOneValidationMessage)
        }
        .alert(L10n.discardChangesTitle, isPresented: $isShowingBackWarning) {
            Button(L10n.discardChangesAction, role: .destructive) { dismiss() }
            Button(L10n.keepEditingAction, role: .cancel) {}
        }
        .alert(L10n.diaryOneDeleteConfirmTitle, isPresented: $isShowingDeleteConfirmation) {
            Button(L10n.diaryOneDeleteAction, role: .destructive) {
                Task { await deleteEntry() }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.diaryOneDeleteConfirmMessage)
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
    }

    private var feelingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.diaryFeelingsTitle)
                .font(.headline)
            DiaryFeelingsEditor(
                drafts: $draft.feelings,
                highlightIncomplete: didAttemptSave
            )
            if didAttemptSave, draft.feelings.isEmpty {
                Text(L10n.diaryOneValidationFeelingsRequired)
                    .font(.footnote)
                    .foregroundStyle(Theme.error)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private func stepCard(
        title: String,
        question: String,
        text: Binding<String>,
        optionalHint: String? = nil,
        incompleteMessage: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                if let optionalHint {
                    Text(optionalHint)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textFaint)
                }
            }
            Text(question)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            NotesField(text: text, placeholder: question, minLines: 3, maxLines: 8)
            if let incompleteMessage {
                Text(incompleteMessage)
                    .font(.footnote)
                    .foregroundStyle(Theme.error)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private func save() async {
        guard !isBusy else { return }
        didAttemptSave = true
        if let message = draft.validationMessage() {
            validationMessage = message
            isShowingValidationAlert = true
            return
        }
        guard let feelings = draft.persistedFeelings() else {
            validationMessage = L10n.diaryOneValidationMessage
            isShowingValidationAlert = true
            return
        }
        isSaving = true
        errorMessage = nil
        let symptoms = draft.physicalSymptoms.trimmingCharacters(in: .whitespacesAndNewlines)
        let event = draft.event.trimmingCharacters(in: .whitespacesAndNewlines)
        let thought = draft.thought.trimmingCharacters(in: .whitespacesAndNewlines)
        let behaviour = draft.behaviour.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            switch mode {
            case .edit(let existing):
                _ = try await diary.updateEntry(
                    id: existing.id,
                    patientId: patient.id,
                    event: event,
                    thought: thought,
                    feelings: feelings,
                    behaviour: behaviour,
                    physicalSymptoms: symptoms
                )
            case .create:
                _ = try await diary.createEntry(
                    patientId: patient.id,
                    event: event,
                    thought: thought,
                    feelings: feelings,
                    behaviour: behaviour,
                    physicalSymptoms: symptoms
                )
            }
            initialSnapshot = draft.comparableSnapshot
            dismiss()
        } catch {
            errorMessage = L10n.diaryOneSaveFailed
            isSaving = false
        }
    }

    private func deleteEntry() async {
        guard !isBusy, let existing else { return }
        isDeleting = true
        errorMessage = nil
        do {
            try await diary.deleteEntry(id: existing.id, patientId: patient.id)
            initialSnapshot = draft.comparableSnapshot
            dismiss()
        } catch {
            errorMessage = L10n.diaryOneDeleteFailed
            isDeleting = false
        }
    }
}
