import Foundation
import Observation

/// Locally dismissed clinical submission IDs, scoped to the therapist and patient.
/// Notification read/seen receipts and clinical records remain independent.
@MainActor @Observable
final class RecentActivityDismissals {
    static let shared = RecentActivityDismissals()
    private static let storageKey = "recentActivityDismissals.v1"
    private let defaults: UserDefaults
    private var dismissedIDs: [String: [String]]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        dismissedIDs = defaults.dictionary(forKey: Self.storageKey) as? [String: [String]] ?? [:]
    }

    func contains(_ submissionID: String, owner: String?, patientID: DatabaseID) -> Bool {
        guard let key = scope(owner: owner, patientID: patientID) else { return false }
        return dismissedIDs[key]?.contains(submissionID.lowercased()) == true
    }

    func dismiss(_ submissionIDs: [String], owner: String?, patientID: DatabaseID) {
        guard let key = scope(owner: owner, patientID: patientID), !submissionIDs.isEmpty else { return }
        let existing = Set(dismissedIDs[key] ?? [])
        dismissedIDs[key] = existing.union(submissionIDs.map { $0.lowercased() }).sorted()
        defaults.set(dismissedIDs, forKey: Self.storageKey)
    }

    private func scope(owner: String?, patientID: DatabaseID) -> String? {
        guard let owner, !owner.isEmpty else { return nil }
        // JSON array encoding avoids ambiguous delimiters in account or patient IDs.
        guard let data = try? JSONEncoder().encode([owner.lowercased(), patientID.queryValue.lowercased()]) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
