import SwiftUI

/// A patient's sessions: numbered list (most recent first), adding and
/// editing sessions, and attaching a questionnaire to a session.
struct PatientSessionsView: View {
    let patient: Patient

    @Environment(PatientStore.self) private var store

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
            if patient.sessions.isEmpty {
                Text(L10n.noSessionsYetLabel)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(sortedSessions.enumerated()), id: \.element.id) { index, session in
                    HStack {
                        Button {
                            route = .edit(session)
                        } label: {
                            SessionRow(
                                number: sortedSessions.count - index,
                                session: session,
                                subtitle: subtitle(for: session)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle(L10n.sessionsTitle)
        .navigationSubtitle(patient.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    route = .new(Session())
                } label: {
                    Label(L10n.addSessionAction, systemImage: "plus")
                }
            }
        }
        .sheet(item: $route) { route in
            SessionEditorView(
                session: route.session,
                patient: patient,
                isNew: route.isNew,
                sessionNumber: route.isNew ? nil : sessionNumber(for: route.session)
            )
        }
        .sheet(item: $questionnaireSession) { session in
            NavigationStack {
                CombinedMoodQuestionnaireView(patient: patient, session: session)
            }
            .appTextSize()
        }
        .task {
            // The score previews need the questionnaire cache filled.
            if store.cachedQuestionnaires(for: patient) == nil {
                _ = try? await store.loadQuestionnaires(for: patient)
            }
        }
    }

    /// The session's 1-based number in the patient's history (oldest = 1),
    /// matching the numbers shown in the list rows.
    private func sessionNumber(for session: Session) -> Int? {
        sortedSessions.firstIndex { $0.id == session.id }
            .map { sortedSessions.count - $0 }
    }

    /// The row's preview line: the session's questionnaire scores when one
    /// was filled in, otherwise the first line of the notes.
    private func subtitle(for session: Session) -> String? {
        if let record = store.cachedQuestionnaires(for: patient)?
            .first(where: { $0.sessionID == session.databaseID }) {
            return L10n.gadPhqScores(gad7: record.questionnaire.gad7Score, phq9: record.questionnaire.phq9Score)
        }
        return nil
    }
}

/// A single row in the sessions list.
private struct SessionRow: View {
    let number: Int
    let session: Session
    let subtitle: String?

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.session(number))
                    .font(.headline)
                // Always present so the row height doesn't jump when the
                // questionnaire scores finish loading.
                Text(session.date, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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
        PatientSessionsView(patient: Patient(firstName: "ישראלה", lastName: "ישראלית", sessions: [Session()]))
    }
    .environment(PatientStore(client: auth.client))
}
