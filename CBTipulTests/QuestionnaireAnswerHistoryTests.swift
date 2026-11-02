import Testing
@testable import CBTipul

@MainActor struct QuestionnaireAnswerHistoryTests {
    @Test func weightedRecencyIsIndependentOfFrequency() {
        let answers: [Int?] = [2, 1, 1]
        let newest = QuestionnaireAnswerHistory(answers: answers, value: 2)
        #expect(abs(newest.weight - 4.0/7.0) < 0.000001)
        #expect(newest.frequency == 1.0/3.0)
        #expect(newest.band == 2)
        #expect(abs((0...3).map { QuestionnaireAnswerHistory(answers: answers, value: $0).weight }.reduce(0, +) - 1) < 0.000001)
    }
    @Test func missingAnswersDoNotBecomeZeroOrLoseTheirAge() {
        let item = QuestionnaireAnswerHistory(answers: [2, nil, 1, 9], value: 2)
        #expect(item.total == 2)
        #expect(item.weight == 0.8)
        #expect(QuestionnaireAnswerHistory(answers: [], value: 0).frequency == 0)
        #expect(QuestionnaireAnswerHistory(answers: [nil, 9], value: 0).weight == 0)
    }
    @Test func bandsAndRepeatedAnswers() {
        #expect(QuestionnaireAnswerHistory(answers: [1, 1, 1], value: 1).weight == 1)
        #expect(QuestionnaireAnswerHistory(answers: [1, 1, 1], value: 0).count == 0)
        #expect(QuestionnaireAnswerHistory(answers: [2, 1, 0, 3], value: 1).band == 1)
        #expect(QuestionnaireAnswerHistory(answers: [2, 1, 0, 3], value: 3).band == 0)
    }
}
