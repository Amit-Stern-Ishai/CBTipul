import SwiftUI

/// Patient-level access, also available beside the separate session questionnaire.
struct QuestionnaireAccessControl: View {
    let patient: Patient
    var compact = false
    var body: some View { PatientToolAccessControl(patient: patient, type: .questionnaire, compact: compact) }
}

struct PatientToolAccessControl: View {
    let patient: Patient
    let type: PatientAssignmentType
    var compact = false
    var listRow = false
    var parentBusy = false
    var onBusyChanged: (Bool) -> Void = { _ in }
    #if DEBUG
    var reviewEnabled: Bool? = nil
    #endif
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
    private var available: Bool {
        #if DEBUG
        if reviewEnabled != nil { return true }
        #endif
        return !store.isDemoMode && !DemoData.isDemoID(patient.id) && patient.id.uuidValue != nil
    }

    var body: some View {
        Group {
        if listRow { activityRow } else {
        VStack(alignment: .leading, spacing: 10) {
            if !compact {
                Label(title, systemImage: type == .questionnaire ? "list.clipboard" : "book.closed")
                    .font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            if loaded && (!compact || assignmentID != nil) {
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
                .accessibilityIdentifier("activity.stop.\(type.rawValue)")
            } else if connected {
                Button { Task { await changeAccess() } } label: {
                    Label(L10n.accessActivate, systemImage: "plus.circle")
                }.buttonStyle(.pressableProminent).disabled(busy || parentBusy)
                .entitlementCreateControl()
                .accessibilityIdentifier("activity.enable.\(type.rawValue)")
            } else {
                Text(compact ? "המטופל/ת עדיין לא מחובר/ת" : L10n.patientSendingRequiresConnection).font(.footnote).foregroundStyle(.secondary)
            }
            if busy { ProgressView() }
            if let error {
                Text(error).font(.footnote).foregroundStyle(Theme.error)
                Button(L10n.questionnaireAssignmentRetryAction) { Task { await refresh() } }.disabled(busy || parentBusy)
            }
        }
        }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: patient.id) { await refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await refresh() } } }
        .confirmationDialog((listRow ? rowTitle : title) + " — " + L10n.accessStop, isPresented: $confirmingStop, titleVisibility: .visible) {
            Button(L10n.accessStop, role: .destructive) { Task { await changeAccess() } }
            Button(L10n.cancel, role: .cancel) {}
        } message: { Text(L10n.accessStopExplanation) }
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var rowTitle: String { L10n.activityName(type) }
    private var activityRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(spacing: 12))
            layout {
                VStack(alignment: .leading, spacing: 3) {
                    Text(rowTitle).font(.body.weight(.medium)).foregroundStyle(Theme.textBright)
                    if loaded {
                        Label(assignmentID == nil ? L10n.activityInactive(type) : L10n.activityActive(type),
                              systemImage: assignmentID == nil ? "minus.circle" : "checkmark.circle.fill")
                            .font(.caption).foregroundStyle(assignmentID == nil ? Theme.textBody : Theme.success)
                    }
                }
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 12) }
                activityAction
            }
            if let error { Text(error).font(.footnote).foregroundStyle(Theme.error).fixedSize(horizontal: false, vertical: true) }
        }.frame(minHeight: 48).accessibilityElement(children: .contain)
    }
    @ViewBuilder private var activityAction: some View {
        if !available {
            Text(L10n.questionnaireDemoSendingUnavailable).font(.footnote).foregroundStyle(Theme.textBody)
        } else if busy || (!loaded && error == nil) {
            ProgressView().controlSize(.small).frame(minWidth: 44, minHeight: 44).accessibilityLabel(L10n.activityLoading)
        } else if error != nil {
            Button(L10n.retry) { Task { await refresh() } }.frame(minHeight: 44).disabled(parentBusy)
        } else if assignmentID != nil {
            Button(L10n.accessStop) { confirmingStop = true }
                .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                .foregroundStyle(Theme.error).disabled(parentBusy).entitlementCreateControl()
                .accessibilityLabel(L10n.accessStop + " — " + rowTitle)
                .accessibilityIdentifier("activity.stop.\(type.rawValue)")
        } else if connected {
            Button(L10n.activityEnable) { Task { await changeAccess() } }
                .font(.subheadline.weight(.semibold)).buttonStyle(.bordered).tint(Theme.gold)
                .frame(minHeight: 44).disabled(parentBusy).entitlementCreateControl()
                .accessibilityLabel(L10n.activityEnable + " — " + rowTitle)
                .accessibilityIdentifier("activity.enable.\(type.rawValue)")
        } else {
            Text(L10n.patientSendingRequiresConnection).font(.footnote).foregroundStyle(Theme.textBody)
        }
    }

    private func refresh() async {
        #if DEBUG
        if let reviewEnabled { assignmentID = reviewEnabled ? UUID() : nil; loaded = true; connected = true; return }
        #endif
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
        #if DEBUG
        if reviewEnabled != nil { assignmentID = assignmentID == nil ? UUID() : nil; return }
        #endif
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
