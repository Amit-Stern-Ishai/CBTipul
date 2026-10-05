import Foundation

struct PatientHomeSnapshot {
    var assignments: [PatientAssignment]?
    var questionnaires: [CompletedQuestionnaire]?
    var diaryOne: [DiaryOneEntry]?
    var diaryTwo: [DiaryTwoEntry]?
    var diaryThree: [DiaryThreeEntry]?

    func hasHistory(_ type: PatientAssignmentType) -> Bool {
        switch type {
        case .questionnaire: !(questionnaires ?? []).isEmpty
        case .diaryOne: !(diaryOne ?? []).isEmpty
        case .diaryTwo: !(diaryTwo ?? []).isEmpty
        case .diaryThree: !(diaryThree ?? []).isEmpty
        }
    }
    func isVisible(_ type: PatientAssignmentType, active: Bool) -> Bool { active || hasHistory(type) }
}

/// Session-only cache, scoped to both the authenticated user and patient.
@MainActor enum PatientHomeCache {
    private static var owner: String?
    private static var snapshot = PatientHomeSnapshot()
    static func read(key: String) -> PatientHomeSnapshot {
        if owner != key { owner = key; snapshot = PatientHomeSnapshot() }
        return snapshot
    }
    static func save(_ value: PatientHomeSnapshot, key: String) {
        guard owner == key else { return }
        snapshot = value
    }
    static func clear() { owner = nil; snapshot = PatientHomeSnapshot() }
}
