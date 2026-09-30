import SwiftUI

/// Patient-level access, also available beside the separate session questionnaire.
struct QuestionnaireAccessControl: View {
    let patient: Patient
    @Environment(AuthManager.self) private var auth
    @Environment(PatientStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var assignmentID: UUID?
    @State private var loaded = false
    @State private var connected = false
    @State private var busy = false
    @State private var error: String?
    @State private var confirmingStop = false

    private var service: PatientAssignmentService { PatientAssignmentService(client: auth.client) }
    private var available: Bool { !store.isDemoMode && !DemoData.isDemoID(patient.id) && patient.id.uuidValue != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(assignmentID == nil ? L10n.sendQuestionnaireToPatientAction : L10n.questionnairesActive,
                  systemImage: assignmentID == nil ? "list.clipboard" : "checkmark.circle.fill")
                .font(.headline)
            Text(L10n.patientQuestionnaireRequestDescription).font(.subheadline).foregroundStyle(.secondary)
            if !available {
                Text(L10n.questionnaireDemoSendingUnavailable).font(.footnote)
            } else if !loaded {
                if error == nil { ProgressView() }
            } else if assignmentID != nil {
                Button(L10n.questionnairesStop, role: .destructive) { confirmingStop = true }
                    .disabled(busy)
            } else if connected {
                Button { Task { await changeAccess() } } label: {
                    Label(L10n.sendQuestionnaireToPatientAction, systemImage: "plus.circle")
                }.buttonStyle(.borderedProminent).disabled(busy)
            } else {
                Text(L10n.patientSendingRequiresConnection).font(.footnote).foregroundStyle(.secondary)
            }
            if busy { ProgressView() }
            if let error {
                Text(error).font(.footnote).foregroundStyle(Theme.error)
                Button(L10n.questionnaireAssignmentRetryAction) { Task { await refresh() } }.disabled(busy)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: patient.id) { await refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await refresh() } } }
        .confirmationDialog(L10n.questionnairesStop, isPresented: $confirmingStop, titleVisibility: .visible) {
            Button(L10n.questionnairesStop, role: .destructive) { Task { await changeAccess() } }
            Button(L10n.cancel, role: .cancel) {}
        } message: { Text(L10n.questionnairesStopExplanation) }
    }

    private func refresh() async {
        guard available, !busy, let id = patient.id.uuidValue else { return }
        if let cached = service.cachedOngoingAssignment(patientId: id, type: .questionnaire),
           let connection = service.cachedPatientConnection(patientId: id) {
            assignmentID = cached.assignmentId
            connected = connection
            loaded = true
        }
        do {
            let connection = try await service.isPatientConnected(patientId: id)
            let assignment = try await service.activeOngoingAssignment(patientId: id, type: .questionnaire)
            guard !busy else { return }
            connected = connection
            assignmentID = assignment?.id
            loaded = true
            error = nil
        } catch is CancellationError {} catch { self.error = L10n.questionnaireAssignmentSendError }
    }

    private func changeAccess() async {
        guard !busy, let id = patient.id.uuidValue else { return }
        busy = true
        error = nil
        do {
            if let assignmentID {
                try await service.cancelOngoingAssignment(id: assignmentID)
                self.assignmentID = nil
            } else {
                assignmentID = try await service.activateOngoingAssignment(patientId: id, type: .questionnaire).id
            }
        } catch { self.error = L10n.questionnaireAssignmentSendError }
        busy = false
    }
}
