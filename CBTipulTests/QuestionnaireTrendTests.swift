import Testing
@testable import CBTipul

struct QuestionnaireTrendTests {
    @Test func allowsPlateausButKeepsConstantAnswersSeparate() {
        #expect(QuestionnaireTrend.classify([3, 3, 2, 2, 0]) == .improving)
        #expect(QuestionnaireTrend.classify([0, 0, 1, 1, 3]) == .worsening)
        #expect(QuestionnaireTrend.classify([2, 2, 2]) == .unchanged)
        #expect(QuestionnaireTrend.classify([0, 0]) == .unchanged)
    }
    @Test func checksEveryStepRatherThanOnlyEndpoints() {
        #expect(QuestionnaireTrend.classify([3, 1, 2]) == .mixed)
        #expect(QuestionnaireTrend.classify([0, 2, 1]) == .mixed)
        #expect(QuestionnaireTrend.classify([2, 1, 2]) == .mixed)
    }
    @Test func missingAndInvalidAnswersNeverBecomeZeros() {
        #expect(QuestionnaireTrend.classify([3, nil, 2, -1, 4, 1]) == .improving)
        #expect(QuestionnaireTrend.classify([1, nil, 1]) == .unchanged)
        #expect(QuestionnaireTrend.classify([nil, 2, nil]) == .insufficient)
        #expect(QuestionnaireTrend.classify([]) == .insufficient)
        #expect(QuestionnaireTrend.classify([nil, -1, 4]) == .insufficient)
    }
}
