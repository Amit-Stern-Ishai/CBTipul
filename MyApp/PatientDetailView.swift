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
                VStack(spacing: 10) {
                    InitialsAvatar(name: patient.displayName, size: 72)
                    Text(patient.displayName)
                        .font(.title2.bold())
                    StatusBadge(status: patient.status)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section {
                Picker(selection: $patient.status) {
                    ForEach(PatientStatus.allCases) { Text($0.rawValue).tag($0) }
                } label: {
                    iconChip("person.crop.circle.badge.checkmark", color: .green, title: "Status")
                }

                NavigationLink {
                    PatientQuestionnairesView(patient: patient)
                } label: {
                    iconChip("chart.xyaxis.line", color: .orange, title: QuestionnaireText.viewQuestionnairesAction)
                }

                NavigationLink {
                    PatientAIView(patient: patient)
                } label: {
                    iconChip("sparkles", color: .purple, title: QuestionnaireText.aiAction)
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
        .navigationBarTitleDisplayMode(.inline)
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

    /// A Settings-style row label: a small tinted icon square next to the title.
    private func iconChip(_ systemImage: String, color: Color, title: String) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 7))
        }
    }
}

/// A single row in the sessions list.
private struct SessionRow: View {
    let number: Int
    let session: Session

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(session.date, style: .date)
                    .font(.headline)
                if !session.notes.isEmpty {
                    Text(session.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
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
