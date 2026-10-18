import SwiftUI

struct WebAssociationCandidateSummary: View {
    let candidate: WebAssociationCandidate
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(candidate.source == "incoming" ? L10n.wwIncomingResult : L10n.wwExistingResult).font(.caption).foregroundStyle(Theme.textBody)
            Text(L10n.wwMeasurementDate + (candidate.measurement_date ?? L10n.wwDateUnavailable)).font(.subheadline)
            Text((candidate.time_kind == "completed_at" ? L10n.wwCompletedTime : L10n.wwRecordedTime) + (candidate.recorded_at.map(WebWorkspaceDate.display) ?? L10n.wwDateUnavailable)).font(.caption)
            ViewThatFits(in: .horizontal) {
            HStack {
                if let score = candidate.gad7_score {
                    ScoreCapsule(text: L10n.scoreBadge(name: L10n.gad7ShortName, score: score), color: GAD7Severity(score: score).color)
                } else { Text(L10n.gad7ShortName + ": " + L10n.wwScoreUnavailable).font(.caption) }
                if let score = candidate.phq9_score {
                    ScoreCapsule(text: L10n.scoreBadge(name: L10n.phq9ShortName, score: score), color: PHQ9Severity(score: score).color)
                } else { Text(L10n.phq9ShortName + ": " + L10n.wwScoreUnavailable).font(.caption) }
            }
                VStack(alignment: .leading, spacing: 5) { scoreLabels }
            }
            if candidate.is_current_session_questionnaire { Label(L10n.wwCurrentResult, systemImage: "link").font(.subheadline) }
            if !candidate.selectable { Text(L10n.wwOtherSessionResult).font(.footnote).foregroundStyle(Theme.textBody) }
            if candidate.flagsQuestionNine { Label(L10n.wwQuestionNineFlag, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(Theme.error) }
        }
    }
    @ViewBuilder private var scoreLabels: some View {
                if let score = candidate.gad7_score {
                    ScoreCapsule(text: L10n.scoreBadge(name: L10n.gad7ShortName, score: score), color: GAD7Severity(score: score).color)
                } else { Text(L10n.gad7ShortName + ": " + L10n.wwScoreUnavailable).font(.caption) }
                if let score = candidate.phq9_score {
                    ScoreCapsule(text: L10n.scoreBadge(name: L10n.phq9ShortName, score: score), color: PHQ9Severity(score: score).color)
                } else { Text(L10n.phq9ShortName + ": " + L10n.wwScoreUnavailable).font(.caption) }
    }

}
struct WebAssociationCandidateRow: View {
    let candidate: WebAssociationCandidate
    let selected: Bool
    let choose: (() -> Void)?
    let inspect: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let choose, candidate.selectable, candidate.choice != nil {
                Button(action: choose) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(Theme.gold)
                        WebAssociationCandidateSummary(candidate: candidate).frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(.vertical, 8).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel(candidate.selectionDescription).accessibilityAddTraits(selected ? .isSelected : [])
            } else { WebAssociationCandidateSummary(candidate: candidate) }
            Button(L10n.wwInspectAnswers, action: inspect).font(.subheadline)
        }
    }
}

struct WebAssociationCandidateAnswers: View {
    let candidate: WebAssociationCandidate
    var body: some View {
        List {
            Group {
            Section { WebAssociationCandidateSummary(candidate: candidate) }
            if candidate.hasCompleteAnswers {
                QuestionnaireSections(questionnaire: .constant(candidate.questionnaire), isEditable: false)
            } else {
                // Do not let the existing complete-result renderer present a partial sum as a total.
                Section(L10n.gad7ShortName) { answers(L10n.gad7Questions, candidate.gad7_answers) }
                Section(L10n.phq9ShortName) { answers(L10n.phq9Questions, candidate.phq9_answers) }
            }
            }.listRowBackground(Theme.surface).listRowSeparatorTint(Theme.borderFaint)
        }.navigationTitle(L10n.wwInspectAnswers).navigationBarTitleDisplayMode(.inline).webWorkspaceStyle()
    }
    @ViewBuilder private func answers(_ questions: [String], _ values: [Int?]?) -> some View {
        ForEach(questions.indices, id: \.self) { index in
            VStack(alignment: .leading, spacing: 6) {
                Text(questions[index])
                let value = values?.indices.contains(index) == true ? values![index] : nil
                Text(value.flatMap { L10n.answerDescriptions.indices.contains($0) ? L10n.answerDescriptions[$0] : nil } ?? L10n.wwDateUnavailable).foregroundStyle(Theme.textBody)
            }
        }
    }
}

extension WebAssociationCandidate {
    var selectionDescription: String {
        let sourceLabel = source == "incoming" ? L10n.wwIncomingResult : L10n.wwExistingResult
        let dateLabel = L10n.wwMeasurementDate + (measurement_date ?? L10n.wwDateUnavailable)
        let timeTitle = time_kind == "completed_at" ? L10n.wwCompletedTime : L10n.wwRecordedTime
        let timeValue = recorded_at.map(WebWorkspaceDate.display) ?? L10n.wwDateUnavailable
        let gadValue = gad7_score.map { String($0) } ?? L10n.wwScoreUnavailable
        let phqValue = phq9_score.map { String($0) } ?? L10n.wwScoreUnavailable
        let labels: [String] = [sourceLabel, dateLabel, timeTitle + timeValue,
                                L10n.gad7ShortName + ": " + gadValue,
                                L10n.phq9ShortName + ": " + phqValue,
                                is_current_session_questionnaire ? L10n.wwCurrentResult : ""]
        return labels.filter { !$0.isEmpty }.joined(separator: ". ")
    }
}
