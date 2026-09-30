import SwiftUI

struct PatientQuestionnaireHubView: View {
    let patientId: UUID
    @Binding var openFormRequest: UUID?
    var onAssignmentsChanged: () async -> Void
    @Environment(AuthManager.self) private var auth
    @Environment(\.scenePhase) private var scenePhase
    @State private var activeAssignment: PatientAssignment?
    @State private var formAssignmentID: UUID?
    @State private var history: [CompletedQuestionnaire] = []
    @State private var loading = true
    @State private var historyFailed = false
    @State private var accessFailed = false
    @State private var submitted = false

    var body: some View {
        List {
            Section {
                Text(L10n.patientQuestionnaireCardBody).foregroundStyle(.secondary)
                if let assignment = activeAssignment {
                    Button { formAssignmentID = assignment.id } label: {
                        Label(L10n.patientQuestionnaireStartAction, systemImage: "plus.circle.fill")
                    }
                } else if loading {
                    ProgressView()
                } else if accessFailed {
                    Text(L10n.patientTasksLoadError).foregroundStyle(Theme.error)
                } else {
                    Text(L10n.patientQuestionnaireCancelledError).foregroundStyle(.secondary)
                }
                if submitted { Label(L10n.patientQuestionnaireSubmittedTitle, systemImage: "checkmark.circle") }
            }
            Section(L10n.patientQuestionnaireHistory) {
                if historyFailed {
                    Text(L10n.patientQuestionnaireHistoryError).foregroundStyle(Theme.error)
                    Button(L10n.questionnaireAssignmentRetryAction) { Task { await refresh() } }
                } else if loading && history.isEmpty { ProgressView() }
                else if history.isEmpty { Text(L10n.patientQuestionnaireHistoryEmpty).foregroundStyle(.secondary) }
                ForEach(history) { record in
                    NavigationLink {
                        Form {
                            QuestionnaireSections(questionnaire: .constant(record.questionnaire), isEditable: false,
                                previous: nil, accent: Theme.gold, showsTherapistNotes: false, showsClinicalGuidance: false)
                        }
                        .themedScreen()
                        .navigationTitle(L10n.hebrewDate(record.answeredDate))
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(record.answeredDate.formatted(date: .abbreviated, time: .shortened))
                            HStack { ScoreCapsule.gad7(record.questionnaire); ScoreCapsule.phq9(record.questionnaire) }
                        }.padding(.vertical, 4)
                    }
                }
            }
        }
        .themedScreen()
        .navigationTitle(L10n.patientQuestionnaireCardTitle)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await refresh() }
        .task(id: patientId) { applyFormRequest(); await refresh() }
        .onChange(of: openFormRequest) { _, _ in applyFormRequest() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await refresh() } } }
        .navigationDestination(item: $formAssignmentID) { id in
            PatientQuestionnaireView(assignmentId: id, onSubmitted: {
                submitted = true
                await refresh()
                await onAssignmentsChanged()
            }, onInactive: {
                activeAssignment = nil
                await refresh()
                await onAssignmentsChanged()
            })
        }
    }

    private func applyFormRequest() {
        guard let id = openFormRequest else { return }
        // Parent resolved this ID from the authenticated, authoritative assignment list.
        if formAssignmentID != id { formAssignmentID = id }
        openFormRequest = nil
    }

    private func refresh() async {
        defer { loading = false }
        do {
            activeAssignment = try await PatientAssignmentService(client: auth.client)
                .activeOngoingAssignment(patientId: patientId, type: .questionnaire)
            accessFailed = false
        } catch { accessFailed = true }
        do {
            history = try await PatientQuestionnaireHistoryService(client: auth.client).history(patientId: patientId)
            historyFailed = false
        } catch { historyFailed = true }
    }
}
