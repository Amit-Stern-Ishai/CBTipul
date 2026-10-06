import SwiftUI

/// Patient-level access, also available beside the separate session questionnaire.
struct QuestionnaireAccessControl: View {
    let patient: Patient
    var body: some View { PatientToolAccessControl(patient: patient, type: .questionnaire) }
}

struct PatientToolAccessControl: View {
    let patient: Patient
    let type: PatientAssignmentType
    var parentBusy = false
    var onBusyChanged: (Bool) -> Void = { _ in }
    @State private var generation = 0
    private var title: String {
        switch type {
        case .questionnaire: L10n.accessQuestionnairesTitle
        case .diaryOne: L10n.diaryOneTitle
        case .diaryTwo: L10n.diaryTwoTitle
        case .diaryThree: L10n.diaryThreeTitle
        }
    }
    private var detail: String {
        switch type {
        case .questionnaire: L10n.accessQuestionnairesDescription
        case .diaryOne: L10n.patientDiaryDescription
        case .diaryTwo: L10n.patientDiaryTwoDescription
        case .diaryThree: L10n.patientDiaryThreeDescription
        }
    }
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
            Label(title, systemImage: type == .questionnaire ? "list.clipboard" : "book.closed")
                .font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
            if loaded {
                Label(assignmentID == nil ? L10n.accessInactive : L10n.accessActive,
                      systemImage: assignmentID == nil ? "minus.circle" : "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(assignmentID == nil ? Color.secondary : Theme.success)
            }
            if !available {
                Text(L10n.questionnaireDemoSendingUnavailable).font(.footnote)
            } else if !loaded {
                if error == nil { ProgressView() }
            } else if assignmentID != nil {
                Button(L10n.accessStop, role: .destructive) { confirmingStop = true }
                    .disabled(busy || parentBusy)
                .entitlementCreateControl()
            } else if connected {
                Button { Task { await changeAccess() } } label: {
                    Label(L10n.accessActivate, systemImage: "plus.circle")
                }.buttonStyle(.pressableProminent).disabled(busy || parentBusy)
                .entitlementCreateControl()
            } else {
                Text(L10n.patientSendingRequiresConnection).font(.footnote).foregroundStyle(.secondary)
            }
            if busy { ProgressView() }
            if let error {
                Text(error).font(.footnote).foregroundStyle(Theme.error)
                Button(L10n.questionnaireAssignmentRetryAction) { Task { await refresh() } }.disabled(busy || parentBusy)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: patient.id) { await refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await refresh() } } }
        .confirmationDialog(title + " — " + L10n.accessStop, isPresented: $confirmingStop, titleVisibility: .visible) {
            Button(L10n.accessStop, role: .destructive) { Task { await changeAccess() } }
            Button(L10n.cancel, role: .cancel) {}
        } message: { Text(L10n.accessStopExplanation) }
    }

    private func refresh() async {
        guard available, !busy, let id = patient.id.uuidValue else { return }
        let requestGeneration = generation
        if let cached = service.cachedOngoingAssignment(patientId: id, type: type),
           let connection = service.cachedPatientConnection(patientId: id) {
            assignmentID = cached.assignmentId
            connected = connection
            loaded = true
        }
        do {
            let connection = try await service.isPatientConnected(patientId: id)
            let assignment = try await service.activeOngoingAssignment(patientId: id, type: type)
            guard !busy, generation == requestGeneration else { return }
            connected = connection
            assignmentID = assignment?.id
            loaded = true
            error = nil
        } catch is CancellationError {} catch {
            if generation == requestGeneration { self.error = L10n.accessError }
        }
    }

    private func changeAccess() async {
        guard !busy, !parentBusy, available, let id = patient.id.uuidValue else { return }
        generation += 1
        busy = true
        onBusyChanged(true)
        defer { busy = false; onBusyChanged(false) }
        error = nil
        do {
            if let assignmentID {
                try await service.cancelOngoingAssignment(id: assignmentID)
                self.assignmentID = nil
            } else {
                assignmentID = try await service.activateOngoingAssignment(patientId: id, type: type).id
            }
        } catch { self.error = L10n.accessError }
    }
}
