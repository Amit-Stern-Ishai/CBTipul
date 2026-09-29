import Foundation

/// The staged patient exercise owns one clinical draft; later stages re-rate its same rows.
struct PatientDiaryThreeDraft: Codable, Equatable {
    var entry = DiaryThreeEntryDraft.empty
    var currentStep = 1
    var hasMeaningfulContent: Bool {
        !entry.situation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        entry.automaticThoughts.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || $0.beliefBefore != nil || $0.beliefAfter != nil } ||
        !entry.feelings.isEmpty || !entry.thinkingErrors.isEmpty ||
        entry.alternativeThoughts.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || $0.belief != nil }
    }
    private func valid(_ value: Int?) -> Bool { value.map { (0...100).contains($0) } ?? false }
    func validationMessage(for step: Int? = nil) -> String? {
        switch step ?? currentStep {
        case 1:
            return entry.situation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? L10n.diaryThreeValidationSituation : nil
        case 2:
            if entry.automaticThoughts.isEmpty || entry.automaticThoughts.contains(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { return L10n.diaryOneValidationThought }
            return entry.automaticThoughts.contains { !valid($0.beliefBefore) } ? L10n.patientDiaryThreeRateEveryItem : nil
        case 3:
            if entry.feelings.isEmpty { return L10n.diaryOneValidationFeelingsRequired }
            if Set(entry.feelings.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }).count != entry.feelings.count { return L10n.diaryFeelingAlreadySelected }
            return entry.feelings.contains { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !valid($0.intensityBefore) } ? L10n.patientDiaryThreeRateEveryItem : nil
        case 4:
            if entry.thinkingErrors.isEmpty { return L10n.diaryTwoValidationErrors }
            return Set(entry.thinkingErrors).count != entry.thinkingErrors.count ? L10n.diaryTwoDuplicateThinkingError : nil
        case 5:
            if entry.alternativeThoughts.isEmpty || entry.alternativeThoughts.contains(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { return L10n.diaryTwoValidationAlternatives }
            return entry.alternativeThoughts.contains { !valid($0.belief) } ? L10n.patientDiaryThreeRateEveryItem : nil
        case 6:
            return entry.automaticThoughts.isEmpty || entry.automaticThoughts.contains { !valid($0.beliefAfter) } ? L10n.patientDiaryThreeRateEveryItem : nil
        case 7:
            return entry.feelings.isEmpty || entry.feelings.contains { !valid($0.intensityAfter) } ? L10n.patientDiaryThreeRateEveryItem : nil
        default: return L10n.diaryOneValidationMessage
        }
    }
    var firstInvalidStep: Int? { (1...7).first { validationMessage(for: $0) != nil } }
    mutating func advance() -> Bool {
        guard currentStep < 7, validationMessage() == nil else { return false }
        currentStep += 1
        return true
    }
    mutating func back() { currentStep = max(1, currentStep - 1) }
}
