import SwiftUI

/// The app's uniform GAD-7/PHQ-9 score chip: a severity-tinted capsule with
/// an optional trend arrow showing the change since the previous
/// questionnaire (up = worse = error red, down = better = success green).
struct ScoreCapsule: View {
    let text: String
    let color: Color
    var delta: Int? = nil

    var body: some View {
        HStack(spacing: 3) {
            Text(text)
                .foregroundStyle(color)
            if let delta, delta != 0 {
                Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(delta > 0 ? Theme.error : Theme.success)
            }
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
    }

    /// The GAD-7 chip of a questionnaire, with the trend vs `previous`.
    static func gad7(_ questionnaire: CombinedMoodQuestionnaire,
                     previous: CombinedMoodQuestionnaire? = nil) -> ScoreCapsule {
        ScoreCapsule(
            text: L10n.scoreBadge(name: L10n.gad7ShortName, score: questionnaire.gad7Score),
            color: questionnaire.gad7Severity.color,
            delta: previous.map { questionnaire.gad7Score - $0.gad7Score }
        )
    }

    /// The PHQ-9 chip of a questionnaire, with the trend vs `previous`.
    static func phq9(_ questionnaire: CombinedMoodQuestionnaire,
                     previous: CombinedMoodQuestionnaire? = nil) -> ScoreCapsule {
        ScoreCapsule(
            text: L10n.scoreBadge(name: L10n.phq9ShortName, score: questionnaire.phq9Score),
            color: questionnaire.phq9Severity.color,
            delta: previous.map { questionnaire.phq9Score - $0.phq9Score }
        )
    }
}
