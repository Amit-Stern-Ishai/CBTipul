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
                                scores: scorePreview(for: session, at: index)
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
            gad7: record.questionnaire.gad7Score,
            phq9: record.questionnaire.phq9Score,
            gad7Delta: previous.map { record.questionnaire.gad7Score - $0.questionnaire.gad7Score },
            phq9Delta: previous.map { record.questionnaire.phq9Score - $0.questionnaire.phq9Score }
        )
    }
}

/// A session row's questionnaire scores and their change since the previous
/// filled questionnaire (`nil` delta when there is no previous one).
private struct ScorePreview {
    let gad7: Int
    let phq9: Int
    let gad7Delta: Int?
    let phq9Delta: Int?
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
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.12), in: Circle())
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
                    ScoreBadge(name: L10n.gad7ShortName, score: scores.gad7, delta: scores.gad7Delta)
                    ScoreBadge(name: L10n.phq9ShortName, score: scores.phq9, delta: scores.phq9Delta)
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

/// One compact questionnaire score with a trend arrow: red when the score
/// went up (worse) and green when it went down (better) since the previous
/// filled questionnaire; neutral when unchanged or there is no previous one.
private struct ScoreBadge: View {
    let name: String
    let score: Int
    let delta: Int?

    private var trendColor: Color {
        guard let delta, delta != 0 else { return .secondary }
        return delta > 0 ? .red : .green
    }

    var body: some View {
        HStack(spacing: 2) {
            Text(L10n.scoreBadge(name: name, score: score))
                .font(.caption.weight(.semibold))
            if let delta, delta != 0 {
                Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                    .font(.caption2.weight(.bold))
            }
        }
        .foregroundStyle(trendColor)
    }
}

#Preview {
    let auth = AuthManager()
    NavigationStack {
        PatientSessionsView(patient: Patient(id: .integer(1), firstName: "ישראלה", lastName: "ישראלית", sessions: [Session()]))
    }
    .environment(PatientStore(client: auth.client))
}
