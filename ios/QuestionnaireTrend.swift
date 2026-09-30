import Foundation

/// Input is chronological. Missing or invalid answers are not zero scores.
enum QuestionnaireTrend: CaseIterable, Hashable {
    case improving, betterThanBeginning, unchanged, worseThanBeginning, worsening, insufficient

    static func classify(_ answers: [Int?]) -> Self {
        let values = answers.compactMap { $0 }.filter { (0...3).contains($0) }
        guard values.count >= 2 else { return .insufficient }
        let pairs = zip(values, values.dropFirst())
        if values.allSatisfy({ $0 == values[0] }) { return .unchanged }
        if pairs.allSatisfy({ $0.0 >= $0.1 }) { return .improving }
        if pairs.allSatisfy({ $0.0 <= $0.1 }) { return .worsening }
        if values.last! < values[0] { return .betterThanBeginning }
        if values.last! > values[0] { return .worseThanBeginning }
        return .unchanged
    }
}
