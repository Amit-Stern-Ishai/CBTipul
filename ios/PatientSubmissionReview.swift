import SwiftUI

struct SubmissionReviewSection {
    let title: String
    let lines: [String]
}

struct PatientSubmissionReview: View {
    let sections: [SubmissionReviewSection]
    var onEdit: (Int) -> Void
    var onSend: () -> Void
    private func editButton(_ index: Int) -> some View {
        Button(L10n.reviewEdit) { onEdit(index) }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel(L10n.reviewEditSection(sections[index].title))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(L10n.reviewSharingExplanation).foregroundStyle(Theme.textBody)
                    ForEach(sections.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 10) {
                            ViewThatFits(in: .horizontal) {
                                HStack {
                                    Text(sections[index].title).font(.headline).fixedSize()
                                    Spacer()
                                    editButton(index).fixedSize()
                                }
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(sections[index].title).font(.headline)
                                        .fixedSize(horizontal: false, vertical: true)
                                    editButton(index)
                                }
                            }
                            ForEach(Array(sections[index].lines.enumerated()), id: \.offset) { _, text in
                                Text(text.isEmpty ? L10n.reviewNotProvided : text).frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }.padding(16).background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                    }
                }.padding(20)
            }
            .themedScreen()
            .navigationTitle(L10n.reviewBeforeSending)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.back) { onEdit(0) } } }
            .safeAreaInset(edge: .bottom) {
                Button(L10n.patientDiaryOneSaveAction, action: onSend)
                    .buttonStyle(.pressableProminent).padding(16).background(Theme.base)
            }
        }.environment(\.layoutDirection, .rightToLeft).appTextSize()
            .accessibilityIdentifier("patient.submission.review")
    }
}

extension DiaryOneEntryDraft {
    var reviewSections: [SubmissionReviewSection] { [
        .init(title: L10n.diaryOneEventTitle, lines: [event]),
        .init(title: L10n.diaryOneThoughtTitle, lines: persistedAutomaticThoughts),
        .init(title: L10n.diaryFeelingsTitle, lines: feelings.map { "\($0.trimmedName) — \($0.intensity ?? 0)%" }),
        .init(title: L10n.diaryOneBehaviourTitle, lines: [behaviour]),
        .init(title: L10n.diaryOnePhysicalSymptomsTitle, lines: [physicalSymptoms])
    ] }
}
extension DiaryTwoEntryDraft {
    var reviewSections: [SubmissionReviewSection] { [
        .init(title: L10n.diaryOneEventTitle, lines: [event]),
        .init(title: L10n.diaryOneThoughtTitle, lines: persistedAutomaticThoughts),
        .init(title: L10n.diaryFeelingsTitle, lines: feelings.map { "\($0.trimmedName) — \($0.intensity ?? 0)%" }),
        .init(title: L10n.diaryThinkingErrorsTitle, lines: thinkingErrors.map(\.title)),
        .init(title: L10n.diaryAlternativeThoughtsTitle, lines: persistedAlternativeThoughts)
    ] }
}
extension PatientDiaryThreeDraft {
    var reviewSections: [SubmissionReviewSection] { [
        .init(title: L10n.diaryThreeSituationTitle, lines: [entry.situation]),
        .init(title: L10n.diaryOneThoughtTitle, lines: entry.automaticThoughts.map { "\($0.text)\n\(L10n.diaryThreeBeliefBefore): \($0.beliefBefore ?? 0)%" }),
        .init(title: L10n.diaryThreeFeelingsBefore, lines: entry.feelings.map { "\($0.name) — \($0.intensityBefore ?? 0)%" }),
        .init(title: L10n.diaryThinkingErrorsTitle, lines: entry.thinkingErrors.map(\.title)),
        .init(title: L10n.diaryAlternativeThoughtsTitle, lines: entry.alternativeThoughts.map { "\($0.text) — \($0.belief ?? 0)%" }),
        .init(title: L10n.diaryThreeThoughtsAfter, lines: entry.automaticThoughts.map { "\($0.text) — \($0.beliefAfter ?? 0)%" }),
        .init(title: L10n.diaryThreeFeelingsAfter, lines: entry.feelings.map { "\($0.name) — \($0.intensityAfter ?? 0)%" })
    ] }
}
extension CombinedMoodQuestionnaire {
    var reviewSections: [SubmissionReviewSection] {
        let gad = L10n.gad7Questions.enumerated().map { index, question in
            SubmissionReviewSection(title: question, lines: [gad7Answers[index].map { L10n.answerDescriptions[$0] } ?? L10n.reviewNotProvided])
        }
        let phq = L10n.phq9Questions.enumerated().map { index, question in
            SubmissionReviewSection(title: question, lines: [phq9Answers[index].map { L10n.answerDescriptions[$0] } ?? L10n.reviewNotProvided])
        }
        return gad + phq + [.init(title: L10n.phq9InterferenceQuestion, lines: [interferenceLevel.map { L10n.phq9InterferenceOptions[$0] } ?? L10n.reviewNotProvided])]
    }
}
