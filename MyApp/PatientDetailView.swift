import SwiftUI

/// Shows a patient's status and their list of sessions.
struct PatientDetailView: View {
    @Bindable var patient: Patient

    /// Which session editor sheet, if any, is presented.
    private enum SheetRoute: Identifiable {
        case new(Session)
        case edit(Session)

        var id: UUID { session.id }

        var session: Session {
            switch self {
            case .new(let session), .edit(let session): return session
            }
        }

        var isNew: Bool {
            if case .new = self { return true }
            return false
        }
    }

    @State private var route: SheetRoute?

    /// The session the questionnaire sheet is presented for.
    @State private var questionnaireSession: Session?

    /// Sessions sorted by date, most recent first.
    private var sortedSessions: [Session] {
        patient.sessions.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section {
                Picker("Status", selection: $patient.status) {
                    ForEach(PatientStatus.allCases) { Text($0.rawValue).tag($0) }
                }

                NavigationLink {
                    PatientQuestionnairesView(patient: patient)
                } label: {
                    Label(QuestionnaireText.viewQuestionnairesAction, systemImage: "chart.xyaxis.line")
                }
            }

            Section("Sessions") {
                if patient.sessions.isEmpty {
                    Text("No sessions yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(sortedSessions.enumerated()), id: \.element.id) { index, session in
                        HStack {
                            Button {
                                route = .edit(session)
                            } label: {
                                SessionRow(number: sortedSessions.count - index, session: session)
                            }
                            .buttonStyle(.plain)

                            Menu {
                                Button {
                                    questionnaireSession = session
                                } label: {
                                    Label(QuestionnaireText.addQuestionnaireAction, systemImage: "list.clipboard")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(patient.displayName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    route = .new(Session())
                } label: {
                    Label("Add Session", systemImage: "plus")
                }
            }
        }
        .sheet(item: $route) { route in
            SessionEditorView(session: route.session, patient: patient, isNew: route.isNew)
        }
        .sheet(item: $questionnaireSession) { session in
            NavigationStack {
                CombinedMoodQuestionnaireView(patient: patient, session: session)
            }
        }
    }
}

/// A single row in the sessions list.
private struct SessionRow: View {
    let number: Int
    let session: Session

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Session \(number)")
                    .font(.headline)
                Text(session.date, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    let auth = AuthManager()
    NavigationStack {
        PatientDetailView(patient: Patient(firstName: "Alex", lastName: "Rivera", sessions: [Session()]))
    }
    .environment(PatientStore(client: auth.client))
}
