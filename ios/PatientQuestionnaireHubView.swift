import SwiftUI

struct PatientQuestionnaireHubView: View {
    let patientId: UUID
    var cachedHistory: [CompletedQuestionnaire] = []
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
                if activeAssignment != nil || (!loading && !accessFailed) {
                    PatientToolStatusView(active: activeAssignment != nil)
                }
                if activeAssignment == nil {
                    if loading {
                        ProgressView()
                    } else if accessFailed {
                        Text(L10n.patientTasksLoadError).foregroundStyle(Theme.error)
                    } else {
                        Text(L10n.patientQuestionnaireCancelledError).foregroundStyle(.secondary)
                    }
                }
                if submitted { Label(L10n.patientQuestionnaireSubmittedTitle, systemImage: "checkmark.circle") }
            }
            .listRowBackground(Theme.surface)
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
                        HStack(spacing: 12) {
                            Label(record.answeredDate.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: Locale(identifier: "he_IL"))), systemImage: "list.clipboard")
                                .font(.headline)
                                .foregroundStyle(Theme.textBright)
                            Spacer(minLength: 8)
                            VStack(alignment: .trailing, spacing: 6) {
                                ScoreCapsule.gad7(record.questionnaire)
                                ScoreCapsule.phq9(record.questionnaire)
                            }
                        }.padding(.vertical, 4)
                    }
                }
            }
            .listRowBackground(Theme.surface)
        }
        .listStyle(.insetGrouped)
        .listRowSeparatorTint(Theme.borderFaint)
        .themedScreen()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let assignment = activeAssignment {
                Button { if EntitlementState.shared.allowMutation() { formAssignmentID = assignment.id } } label: {
                    Label(L10n.patientQuestionnaireStartAction, systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }.entitlementCreateControl()
                .buttonStyle(.pressableProminent)
                .controlSize(.large)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Theme.base)
            }
        }
        .navigationTitle(L10n.patientQuestionnaireCardTitle)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await refresh() }
        .task(id: patientId) { history = cachedHistory; applyFormRequest(); await refresh() }
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
