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
                    .listRowBackground(Theme.surface)
            } else {
                ForEach(Array(sortedSessions.enumerated()), id: \.element.id) { index, session in
                    HStack {
                        Button {
                            route = .edit(session)
                        } label: {
                            SessionRow(
                                number: sortedSessions.count - index,
                                session: session,
                                scores: scorePreview(for: session, at: index)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowBackground(Theme.surface)
                    .listRowSeparatorTint(Theme.borderFaint)
                }
            }
        }
        .themedScreen()
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

    /// The row's score preview: the session's questionnaire scores plus how
    /// each changed since the previous session with a filled questionnaire.
    /// `index` is the session's position in `sortedSessions`.
    private func scorePreview(for session: Session, at index: Int) -> ScorePreview? {
        guard let records = store.cachedQuestionnaires(for: patient),
              let sessionID = session.databaseID,
              let record = records.first(where: { $0.sessionID == sessionID })
        else { return nil }
        // The most recent earlier session that has a filled questionnaire.
        let previous = sortedSessions[(index + 1)...].lazy
            .compactMap { earlier in
                earlier.databaseID.flatMap { id in records.first { $0.sessionID == id } }
            }
            .first
        return ScorePreview(
            questionnaire: record.questionnaire,
            previous: previous?.questionnaire
        )
    }
}

/// A session row's questionnaire plus the previous filled one, for the
/// score chips and their trend arrows.
private struct ScorePreview {
    let questionnaire: CombinedMoodQuestionnaire
    let previous: CombinedMoodQuestionnaire?
}

/// A single row in the sessions list.
private struct SessionRow: View {
    let number: Int
    let session: Session
    let scores: ScorePreview?

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.gold)
                .frame(width: 34, height: 34)
                .background(Theme.goldGhost, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(session.date, style: .date)
                        .font(.headline)
                    if session.structuredNotes != nil {
                        Image(systemName: "doc.text")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(L10n.hasStructuredSummaryLabel)
                    }
                }
                if let type = session.type {
                    Text(L10n.label(for: type))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let scores {
                VStack(alignment: .trailing, spacing: 4) {
                    ScoreCapsule.gad7(scores.questionnaire, previous: scores.previous)
                    ScoreCapsule.phq9(scores.questionnaire, previous: scores.previous)
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

#Preview {
    let auth = AuthManager()
    NavigationStack {
        PatientSessionsView(patient: Patient(id: .integer(1), firstName: "ישראלה", lastName: "ישראלית", sessions: [Session()]))
    }
    .environment(PatientStore(client: auth.client))
}
