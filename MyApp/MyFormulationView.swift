import SwiftUI

/// The therapist's own clinical formulation workspace for a patient.
///
/// Entirely therapist-owned: nothing here is AI-generated, the screen never
/// calls the AI, and AI output is never copied in automatically. Edits are
/// saved explicitly; leaving with unsaved changes asks whether to save.
struct MyFormulationView: View {
    let patient: Patient

    @Environment(PatientStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var formulation: PatientFormulation
    /// The last saved state, for detecting unsaved changes.
    @State private var initialFormulation: PatientFormulation
    @State private var isSaving = false
    @State private var isShowingBackWarning = false
    @State private var errorMessage: String?

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
                TextField("No treatment goal defined — add one",
                          text: optionalBinding($formulation.treatmentGoal),
                          axis: .vertical)
                if !isGoalFormatValid {
                    Text("Expected format: “Reduce X emotion from Y% to Z% in situations of …”")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("🎯 Treatment Goal")
            }

            Section("🧠 Core Belief") {
                TextField("No core belief defined",
                          text: optionalBinding($formulation.coreBelief),
                          axis: .vertical)
            }

            Section("💭 Key Automatic Thoughts") {
                ForEach(formulation.keyAutomaticThoughts.indices, id: \.self) { index in
                    TextField("Automatic thought",
                              text: $formulation.keyAutomaticThoughts[index],
                              axis: .vertical)
                }
                .onDelete { offsets in
                    formulation.keyAutomaticThoughts.remove(atOffsets: offsets)
                }
                Button {
                    formulation.keyAutomaticThoughts.append("")
                } label: {
                    Label("Add Thought", systemImage: "plus")
                }
            }

            Section("🔄 Maintaining Behaviors") {
                ForEach(formulation.maintainingBehaviors.indices, id: \.self) { index in
                    TextField("Behavior",
                              text: $formulation.maintainingBehaviors[index],
                              axis: .vertical)
                }
                .onDelete { offsets in
                    formulation.maintainingBehaviors.remove(atOffsets: offsets)
                }
                Button {
                    formulation.maintainingBehaviors.append("")
                } label: {
                    Label("Add Behavior", systemImage: "plus")
                }
            }

            Section("🔁 Key CBT Cycle") {
                if formulation.keyCBTCycle != nil {
                    cycleEditor
                    Button("Remove Cycle", role: .destructive) {
                        formulation.keyCBTCycle = nil
                    }
                } else {
                    Text("No key CBT cycle defined")
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
                        Label("Add CBT Cycle", systemImage: "plus")
                    }
                }
            }

            Section("🧩 Therapist Hypothesis") {
                NotesField(text: optionalBinding($formulation.therapistHypothesis),
                           placeholder: "Your working hypothesis about what maintains the problem",
                           minLines: 4, maxLines: 12)
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
        .navigationTitle("My Formulation")
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
                    Label("Back", systemImage: "chevron.backward")
                }
                .disabled(isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(isSaving || !hasUnsavedChanges)
            }
        }
        // An alert, not a confirmation dialog: iPad popover dialogs hide
        // cancel-role buttons, and Keep Editing must always be offered.
        .alert(QuestionnaireText.discardChangesTitle,
               isPresented: $isShowingBackWarning) {
            Button(QuestionnaireText.saveChangesAction) { save(thenDismiss: true) }
            Button(QuestionnaireText.discardChangesAction, role: .destructive) {
                dismiss()
            }
            Button(QuestionnaireText.keepEditingAction, role: .cancel) {}
        }
        .busyOverlay(isSaving)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .appTextSize()
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
            cycleStage("Situation", \.triggerSituation)
            cycleArrow
            cycleStage("Automatic Thought", \.automaticThought)
            cycleArrow
            cycleStage("Emotion", \.emotion)
            cycleArrow
            cycleStage("Behavior", \.behavior)
            cycleArrow
            cycleStage("Short-term consequence", \.shortTermConsequence)
            cycleArrow
            cycleStage("Long-term consequence", \.longTermConsequence)
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
