import SwiftUI

/// Stable scroll targets shared by the form and its completion guide.
enum QuestionnaireItem: Hashable {
    case gad7(Int)
    case phq9(Int)
    case interference
}

struct QuestionnaireCompletion {
    let answered: Int
    let total: Int
    let firstUnanswered: QuestionnaireItem?

    init(_ questionnaire: CombinedMoodQuestionnaire, includesInterference: Bool = true) {
        let items: [(QuestionnaireItem, Int?)] =
            L10n.gad7Questions.indices.map { (.gad7($0), questionnaire.gad7Answers.indices.contains($0) ? questionnaire.gad7Answers[$0] : nil) }
            + L10n.phq9Questions.indices.map { (.phq9($0), questionnaire.phq9Answers.indices.contains($0) ? questionnaire.phq9Answers[$0] : nil) }
            + (includesInterference ? [(.interference, questionnaire.interferenceLevel)] : [])
        let missing = items.filter { !CombinedMoodQuestionnaire.answerValues.contains($0.1 ?? -1) }
        total = items.count
        answered = total - missing.count
        firstUnanswered = missing.first?.0
    }
}

extension CombinedMoodQuestionnaire {
    /// Restored data must have current array lengths before the form binds by index.
    /// Patient drafts never restore therapist notes or out-of-range answers.
    var normalizedPatientDraft: CombinedMoodQuestionnaire {
        var value = CombinedMoodQuestionnaire()
        for index in value.gad7Answers.indices where gad7Answers.indices.contains(index) {
            value.gad7Answers[index] = Self.answerValues.contains(gad7Answers[index] ?? -1) ? gad7Answers[index] : nil
        }
        for index in value.phq9Answers.indices where phq9Answers.indices.contains(index) {
            value.phq9Answers[index] = Self.answerValues.contains(phq9Answers[index] ?? -1) ? phq9Answers[index] : nil
        }
        value.interferenceLevel = Self.answerValues.contains(interferenceLevel ?? -1) ? interferenceLevel : nil
        return value
    }
}

/// Therapist questionnaires retain their existing rule: the 16 scored items
/// are required, while interference remains optional.
struct TherapistQuestionnaireCompletionGuide: ViewModifier {
    let questionnaire: CombinedMoodQuestionnaire
    let isEditing: Bool
    @Binding var revealMissing: Bool
    @Binding var marksUnanswered: Bool

    private var completion: QuestionnaireCompletion {
        QuestionnaireCompletion(questionnaire, includesInterference: false)
    }

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .safeAreaInset(edge: .top, spacing: 0) {
                    if isEditing {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.questionnaireCompletion(completion.answered, total: completion.total))
                                .font(.subheadline.weight(.semibold))
                            ProgressView(value: Double(completion.answered), total: Double(completion.total))
                                .accessibilityLabel(L10n.questionnaireCompletion(completion.answered, total: completion.total))
                            if completion.firstUnanswered != nil {
                                Button(L10n.nextUnansweredAction) {
                                    marksUnanswered = true
                                    scrollToMissing(proxy)
                                }
                                .font(.subheadline)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.base)
                    }
                }
                .onChange(of: revealMissing) { _, reveal in
                    guard reveal else { return }
                    marksUnanswered = true
                    scrollToMissing(proxy)
                    revealMissing = false
                }
        }
    }

    private func scrollToMissing(_ proxy: ScrollViewProxy) {
        guard let item = completion.firstUnanswered else { return }
        withAnimation { proxy.scrollTo(item, anchor: .top) }
    }
}
