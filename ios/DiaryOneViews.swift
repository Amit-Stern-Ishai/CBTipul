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
                    DiaryOneEntryFormView(patient: patient, existing: nil)
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
                        DiaryOneEntryFormView(patient: patient, existing: entry)
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
                L10n.diaryOneFeelingTitle,
                L10n.diaryOneFeelingSummary(feeling: entry.feeling, intensity: entry.feelingIntensity)
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
                .lineLimit(3)
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
    var existing: DiaryOneEntry?

    @Environment(DiaryOneStore.self) private var diary
    @Environment(\.dismiss) private var dismiss

    @State private var event: String
    @State private var thought: String
    @State private var feeling: String
    @State private var feelingIntensity: Int?
    @State private var behaviour: String
    @State private var physicalSymptoms: String
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var isShowingValidationAlert = false
    @State private var isShowingDeleteConfirmation = false
    @State private var errorMessage: String?

    private var patientColor: Color {
        PatientAvatarColor.background(for: patient.id)
    }

    private var isBusy: Bool { isSaving || isDeleting }

    init(patient: Patient, existing: DiaryOneEntry?) {
        self.patient = patient
        self.existing = existing
        _event = State(initialValue: existing?.event ?? "")
        _thought = State(initialValue: existing?.thought ?? "")
        _feeling = State(initialValue: existing?.feeling ?? "")
        _feelingIntensity = State(initialValue: existing?.feelingIntensity)
        _behaviour = State(initialValue: existing?.behaviour ?? "")
        _physicalSymptoms = State(initialValue: existing?.physicalSymptoms ?? "")
    }

    private var isValid: Bool {
        let required = [event, thought, feeling, behaviour]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard required.allSatisfy({ !$0.isEmpty }) else { return false }
        guard let feelingIntensity, (0...100).contains(feelingIntensity) else { return false }
        return true
    }

    var body: some View {
        Form {
            fieldSection(
                title: L10n.diaryOneEventTitle,
                question: L10n.diaryOneEventQuestion,
                text: $event
            )
            fieldSection(
                title: L10n.diaryOneThoughtTitle,
                question: L10n.diaryOneThoughtQuestion,
                text: $thought
            )
            Section(L10n.diaryOneFeelingTitle) {
                Text(L10n.diaryOneFeelingQuestion)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(groupBorderedRow(.first))
                NotesField(text: $feeling, placeholder: L10n.diaryOneFeelingQuestion, minLines: 3, maxLines: 8)
                    .listRowBackground(groupBorderedRow(.middle))
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L10n.diaryOneFeelingIntensityTitle)
                        Spacer()
                        Text(intensityLabel)
                            .fontWeight(.semibold)
                            .foregroundStyle(feelingIntensity == nil ? Theme.textFaint : Theme.textBright)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(feelingIntensity ?? 50) },
                            set: { feelingIntensity = Int($0.rounded()) }
                        ),
                        in: 0...100,
                        step: 1
                    )
                    .tint(Theme.gold)
                }
                .listRowBackground(groupBorderedRow(.last))
            }
            fieldSection(
                title: L10n.diaryOneBehaviourTitle,
                question: L10n.diaryOneBehaviourQuestion,
                text: $behaviour
            )
            fieldSection(
                title: L10n.diaryOnePhysicalSymptomsTitle,
                question: L10n.diaryOnePhysicalSymptomsQuestion,
                text: $physicalSymptoms
            )

            Section {
                Button {
                    Task { await save() }
                } label: {
                    Text(L10n.diaryOneSaveEntryAction)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .disabled(isBusy)
                .listRowBackground(groupBorderedRow(.only))
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
        .demoModeChrome()
        .dismissesKeyboardOnTap()
        .navigationTitle(L10n.diaryOneTitle)
        .navigationBarTitleDisplayMode(.inline)
        .busyOverlay(isBusy)
        .toolbar {
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
            Text(L10n.diaryOneValidationMessage)
        }
        .alert(L10n.diaryOneDeleteConfirmTitle, isPresented: $isShowingDeleteConfirmation) {
            Button(L10n.diaryOneDeleteAction, role: .destructive) {
                Task { await deleteEntry() }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.diaryOneDeleteConfirmMessage)
        }
    }

    private var intensityLabel: String {
        if let feelingIntensity {
            return L10n.diaryOneIntensityValue(feelingIntensity)
        }
        return L10n.diaryOneIntensityUnset
    }

    private func fieldSection(title: String, question: String, text: Binding<String>) -> some View {
        Section(title) {
            Text(question)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .listRowBackground(groupBorderedRow(.first))
            NotesField(text: text, placeholder: question, minLines: 3, maxLines: 8)
                .listRowBackground(groupBorderedRow(.last))
        }
    }

    private func groupBorderedRow(_ position: GroupRowPosition) -> some View {
        CBTipul.groupBorderedRow(position, accent: patientColor)
    }

    private func save() async {
        guard !isBusy else { return }
        guard isValid, let feelingIntensity else {
            isShowingValidationAlert = true
            return
        }
        isSaving = true
        errorMessage = nil
        let symptoms = physicalSymptoms.trimmingCharacters(in: .whitespacesAndNewlines)
        let event = event.trimmingCharacters(in: .whitespacesAndNewlines)
        let thought = thought.trimmingCharacters(in: .whitespacesAndNewlines)
        let feeling = feeling.trimmingCharacters(in: .whitespacesAndNewlines)
        let behaviour = behaviour.trimmingCharacters(in: .whitespacesAndNewlines)
        let intensity = min(100, max(0, feelingIntensity))
        do {
            if let existing {
                _ = try await diary.updateEntry(
                    id: existing.id,
                    patientId: patient.id,
                    event: event,
                    thought: thought,
                    feeling: feeling,
                    feelingIntensity: intensity,
                    behaviour: behaviour,
                    physicalSymptoms: symptoms
                )
            } else {
                _ = try await diary.createEntry(
                    patientId: patient.id,
                    event: event,
                    thought: thought,
                    feeling: feeling,
                    feelingIntensity: intensity,
                    behaviour: behaviour,
                    physicalSymptoms: symptoms
                )
            }
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
            dismiss()
        } catch {
            errorMessage = L10n.diaryOneDeleteFailed
            isDeleting = false
        }
    }
}
