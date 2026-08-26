import SwiftUI

/// The therapist's own clinical formulation workspace for a patient.
///
/// Entirely therapist-owned: nothing here is AI-generated, the screen never
/// calls the AI, and AI output is never copied in automatically. Edits are
/// saved explicitly; leaving with unsaved changes asks whether to save.
struct MyFormulationView: View {
    let patient: Patient

    @Environment(AuthManager.self) private var auth
    @Environment(PatientStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var formulation: PatientFormulation
    /// The last saved state, for detecting unsaved changes.
    @State private var initialFormulation: PatientFormulation
    @State private var isSaving = false
    @State private var isShowingBackWarning = false
    @State private var errorMessage: String?
    @State private var isChallenging = false
    @State private var supervisionResult: FormulationSupervisionResult?
    @State private var isLookingForMissing = false
    @State private var missingResult: WhatAmIMissingResult?
    @State private var isReviewingCase = false
    @State private var caseReviewResult: LongitudinalCaseReviewResult?

    /// One AI supervision request at a time, across all features.
    private var isRunningSupervision: Bool {
        isChallenging || isLookingForMissing || isReviewingCase
    }

    init(patient: Patient) {
        self.patient = patient
        let current = patient.formulation ?? .empty
        _formulation = State(initialValue: current)
        _initialFormulation = State(initialValue: current)
    }

    private var hasUnsavedChanges: Bool {
        formulation != initialFormulation
    }

    var body: some View {
        Form {
            Section {
                TextField(L10n.noTreatmentGoalPlaceholder,
                          text: optionalBinding($formulation.treatmentGoal),
                          axis: .vertical)
                if !isGoalFormatValid {
                    Text(L10n.goalFormatWarning)
                        .font(.footnote)
                        .foregroundStyle(Theme.warning)
                }
            } header: {
                Text(L10n.treatmentGoalSection)
            }
            .listRowBackground(Theme.surface)

            Section(L10n.coreBeliefSection) {
                TextField(L10n.noCoreBeliefPlaceholder,
                          text: optionalBinding($formulation.coreBelief),
                          axis: .vertical)
            }
            .listRowBackground(Theme.surface)

            Section(L10n.keyAutomaticThoughtsSection) {
                ForEach(formulation.keyAutomaticThoughts.indices, id: \.self) { index in
                    TextField(L10n.automaticThoughtLabel,
                              text: $formulation.keyAutomaticThoughts[index],
                              axis: .vertical)
                }
                .onDelete { offsets in
                    formulation.keyAutomaticThoughts.remove(atOffsets: offsets)
                }
                Button {
                    formulation.keyAutomaticThoughts.append("")
                } label: {
                    Label(L10n.addThoughtAction, systemImage: "plus")
                }
            }
            .listRowBackground(Theme.surface)

            Section(L10n.maintainingBehaviorsSection) {
                ForEach(formulation.maintainingBehaviors.indices, id: \.self) { index in
                    TextField(L10n.behaviorLabel,
                              text: $formulation.maintainingBehaviors[index],
                              axis: .vertical)
                }
                .onDelete { offsets in
                    formulation.maintainingBehaviors.remove(atOffsets: offsets)
                }
                Button {
                    formulation.maintainingBehaviors.append("")
                } label: {
                    Label(L10n.addBehaviorAction, systemImage: "plus")
                }
            }
            .listRowBackground(Theme.surface)

            Section(L10n.keyCBTCycleSection) {
                if formulation.keyCBTCycle != nil {
                    cycleEditor
                    Button(L10n.removeCycleAction, role: .destructive) {
                        formulation.keyCBTCycle = nil
                    }
                } else {
                    Text(L10n.noKeyCBTCycleLabel)
                        .foregroundStyle(.secondary)
                    Button {
                        formulation.keyCBTCycle = CBTCycle(
                            triggerSituation: nil,
                            automaticThought: nil,
                            emotion: nil,
                            behavior: nil,
                            shortTermConsequence: nil,
                            longTermConsequence: nil,
                            evidence: "",
                            confidence: ""
                        )
                    } label: {
                        Label(L10n.addCBTCycleAction, systemImage: "plus")
                    }
                }
            }
            .listRowBackground(Theme.surface)

            Section(L10n.therapistHypothesisSection) {
                NotesField(text: optionalBinding($formulation.therapistHypothesis),
                           placeholder: L10n.therapistHypothesisPlaceholder,
                           minLines: 4, maxLines: 12)
            }
            .listRowBackground(Theme.surface)

            Section {
                Button {
                    challengeFormulation()
                } label: {
                    HStack {
                        Label(L10n.challengeFormulationAction, systemImage: "wand.and.stars")
                        if isChallenging {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isRunningSupervision || !formulationHasContent)
                if isChallenging {
                    Text(L10n.analyzingFormulationLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if !formulationHasContent {
                    Text(L10n.addFormulationContentHint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    whatAmIMissing()
                } label: {
                    HStack {
                        Label(L10n.whatAmIMissingAction, systemImage: "text.magnifyingglass")
                        if isLookingForMissing {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isRunningSupervision)
                if isLookingForMissing {
                    Text(L10n.lookingAcrossHistoryLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(L10n.aiSupervisionSection)
            } footer: {
                Text(L10n.aiSupervisionFooter)
            }
            .listRowBackground(Theme.surface)

            Section {
                Button {
                    longitudinalCaseReview()
                } label: {
                    HStack {
                        Label(L10n.longitudinalReviewAction, systemImage: "chart.line.uptrend.xyaxis")
                        if isReviewingCase {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isRunningSupervision)
                if isReviewingCase {
                    Text(L10n.analyzingOverTimeLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(L10n.longitudinalCaseReviewTitle)
            } footer: {
                Text(L10n.longitudinalReviewFooter)
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
        .dismissesKeyboardOnTap()
        .navigationTitle(L10n.myFormulationTitle)
        .navigationSubtitle(patient.displayName)
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
        }
        // An alert, not a confirmation dialog: iPad popover dialogs hide
        // cancel-role buttons, and Keep Editing must always be offered.
        .alert(L10n.discardChangesTitle,
               isPresented: $isShowingBackWarning) {
            Button(L10n.saveChangesAction) { save(thenDismiss: true) }
            Button(L10n.discardChangesAction, role: .destructive) {
                dismiss()
            }
            Button(L10n.keepEditingAction, role: .cancel) {}
        }
        .sheet(item: $supervisionResult) { result in
            FormulationSupervisionView(supervision: result.supervision)
        }
        .sheet(item: $missingResult) { result in
            WhatAmIMissingView(response: result.response)
        }
        .sheet(item: $caseReviewResult) { result in
            LongitudinalCaseReviewView(response: result.response)
        }
        .busyOverlay(isSaving)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .appTextSize()
    }

    /// True once any formulation field contains real content — the minimum
    /// needed to make an AI challenge worthwhile.
    private var formulationHasContent: Bool {
        func filled(_ text: String?) -> Bool {
            !(text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if filled(formulation.treatmentGoal)
            || filled(formulation.coreBelief)
            || filled(formulation.therapistHypothesis) { return true }
        if formulation.keyAutomaticThoughts.contains(where: { filled($0) }) { return true }
        if formulation.maintainingBehaviors.contains(where: { filled($0) }) { return true }
        if let cycle = formulation.keyCBTCycle {
            return filled(cycle.triggerSituation) || filled(cycle.automaticThought)
                || filled(cycle.emotion) || filled(cycle.behavior)
                || filled(cycle.shortTermConsequence) || filled(cycle.longTermConsequence)
        }
        return false
    }

    /// Builds the patient context from locally available data and asks the
    /// AI to challenge the formulation as shown on screen. Read-only: the
    /// result is presented for reflection and never saved into the
    /// formulation.
    private func challengeFormulation() {
        guard !isRunningSupervision else { return }
        errorMessage = nil
        isChallenging = true
        Task {
            do {
                let context = try await makePatientContext()
                let supervision = try await WhisperService(client: auth.client)
                    .challengeFormulation(patientContext: context, formulation: formulation)
                supervisionResult = FormulationSupervisionResult(supervision: supervision)
            } catch {
                errorMessage = error.localizedDescription
            }
            isChallenging = false
        }
    }

    /// Asks the AI to look independently across the patient's history for
    /// patterns the therapist might be overlooking. Unlike the challenge,
    /// the formulation is not the analytical target. Read-only: findings
    /// are presented for reflection and never saved into the formulation.
    private func whatAmIMissing() {
        guard !isRunningSupervision else { return }
        errorMessage = nil
        isLookingForMissing = true
        Task {
            do {
                let context = try await makePatientContext()
                let response = try await WhisperService(client: auth.client)
                    .whatAmIMissing(patientContext: context)
                missingResult = WhatAmIMissingResult(response: response)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLookingForMissing = false
        }
    }

    /// Asks the AI what has changed in this case over time, what has not,
    /// and what deserves attention now. Read-only: the review is presented
    /// live and never persisted or written into the patient's data.
    private func longitudinalCaseReview() {
        guard !isRunningSupervision else { return }
        errorMessage = nil
        isReviewingCase = true
        Task {
            do {
                let context = try await makePatientContext()
                let response = try await WhisperService(client: auth.client)
                    .longitudinalCaseReview(patientContext: context)
                caseReviewResult = LongitudinalCaseReviewResult(response: response)
            } catch {
                errorMessage = error.localizedDescription
            }
            isReviewingCase = false
        }
    }

    /// The compact patient context from locally available data, loading the
    /// questionnaire history only when it isn't cached yet.
    private func makePatientContext() async throws -> PatientContext {
        let questionnaires: [CompletedQuestionnaire]
        if let cached = store.cachedQuestionnaires(for: patient) {
            questionnaires = cached
        } else {
            questionnaires = try await store.loadQuestionnaires(for: patient)
        }
        return PatientContext.make(for: patient, questionnaires: questionnaires)
    }

    private func save(thenDismiss: Bool = false) {
        errorMessage = nil
        isSaving = true
        Task {
            do {
                try await store.saveFormulation(formulation, for: patient)
                initialFormulation = formulation
                if thenDismiss { dismiss() }
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }

    /// The same vertical chain the preparation screen renders, editable.
    private var cycleEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            cycleStage(L10n.situationLabel, \.triggerSituation)
            cycleArrow
            cycleStage(L10n.automaticThoughtTitle, \.automaticThought)
            cycleArrow
            cycleStage(L10n.emotionLabel, \.emotion)
            cycleArrow
            cycleStage(L10n.behaviorLabel, \.behavior)
            cycleArrow
            cycleStage(L10n.shortTermConsequenceLabel, \.shortTermConsequence)
            cycleArrow
            cycleStage(L10n.longTermConsequenceLabel, \.longTermConsequence)
        }
        .padding(.vertical, 4)
    }

    private func cycleStage(_ title: String,
                            _ keyPath: WritableKeyPath<CBTCycle, String?>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(title, text: Binding(
                get: { formulation.keyCBTCycle?[keyPath: keyPath] ?? "" },
                set: { formulation.keyCBTCycle?[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
            ), axis: .vertical)
            .font(.subheadline)
        }
    }

    private var cycleArrow: some View {
        Image(systemName: "arrow.down")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
            .padding(.leading, 12)
    }

    /// Edits an optional string in place; clearing the field stores nil.
    private func optionalBinding(_ source: Binding<String?>) -> Binding<String> {
        Binding(get: { source.wrappedValue ?? "" },
                set: { source.wrappedValue = $0.isEmpty ? nil : $0 })
    }

    /// The app's treatment-goal convention:
    /// "Reduce X emotion from Y% to Z% in situations of …" (or
    /// "… in Anxiety disorder of type …"). Empty goals don't warn.
    private var isGoalFormatValid: Bool {
        let goal = (formulation.treatmentGoal ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !goal.isEmpty else { return true }
        let pattern = #"(?i)reduce\s+.+\s+from\s+\d{1,3}\s*%\s+to\s+\d{1,3}\s*%\s+in\s+.+"#
        return goal.range(of: pattern, options: .regularExpression) != nil
    }
}
