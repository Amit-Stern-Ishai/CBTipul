import SwiftUI

/// The app's uniform GAD-7/PHQ-9 score chip: a severity-tinted capsule with
/// an optional trend arrow showing the change since the previous
/// questionnaire (up = worse = error red, down = better = success green).
struct ScoreCapsule: View {
    let text: String
    let color: Color
    var delta: Int? = nil
    var fill: Color? = nil

    var body: some View {
        HStack(spacing: 3) {
            Text(text)
                .foregroundStyle(fill == nil ? color : Theme.turquoiseInk)
            if let delta, delta != 0 {
                Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                    .font(BrandTypography.caption2.weight(.bold))
                    .foregroundStyle(fill == nil ? (delta > 0 ? Theme.error : Theme.success) : Theme.turquoiseInk)
            }
        }
        .font(BrandTypography.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(fill ?? color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    /// The GAD-7 chip of a questionnaire, with the trend vs `previous`.
    static func gad7(_ questionnaire: CombinedMoodQuestionnaire,
                     previous: CombinedMoodQuestionnaire? = nil) -> ScoreCapsule {
        ScoreCapsule(
            text: L10n.scoreBadge(name: L10n.gad7ShortName, score: questionnaire.gad7Score),
            color: questionnaire.gad7Severity.color,
            delta: previous.map { questionnaire.gad7Score - $0.gad7Score },
            fill: gadFill(questionnaire.gad7Severity)
        )
    }

    /// The PHQ-9 chip of a questionnaire, with the trend vs `previous`.
    static func phq9(_ questionnaire: CombinedMoodQuestionnaire,
                     previous: CombinedMoodQuestionnaire? = nil) -> ScoreCapsule {
        ScoreCapsule(
            text: L10n.scoreBadge(name: L10n.phq9ShortName, score: questionnaire.phq9Score),
            color: questionnaire.phq9Severity.color,
            delta: previous.map { questionnaire.phq9Score - $0.phq9Score },
            fill: phqFill(questionnaire.phq9Severity)
        )
    }

    private static func gadFill(_ severity: GAD7Severity) -> Color {
        switch severity {
        case .minimal: Theme.severityMinimal
        case .mild: Theme.severityMild
        case .substantial: Theme.severityModerate
        case .extreme: Theme.severitySevere
        }
    }
    private static func phqFill(_ severity: PHQ9Severity) -> Color {
        switch severity {
        case .minimal: Theme.severityMinimal
        case .mild: Theme.severityMild
        case .moderate: Theme.severityModerate
        case .moderatelySevere, .severe: Theme.severitySevere
        }
    }
}
