import Foundation

/// Shared App Group used only for the patient UUID → local display-name map
/// so a Notification Service Extension can resolve names. Clinical data stays
/// in the main app. The Keychain remains the source of truth.
enum PatientNameAppGroup {
    static let identifier = "group.com.CBTipul.app"
}

/// Resolves a locally stored patient display name. Does not talk to the
/// network and must never log names or id/name pairs.
enum PatientNameResolver: Sendable {
    private static let namesKey = "patientDisplayNames"

    /// Local display name for `patientId`, or nil when none is stored.
    nonisolated static func displayName(forPatientId patientId: String) -> String? {
        let id = patientId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return nil }
        guard let defaults = UserDefaults(suiteName: PatientNameAppGroup.identifier) else {
            return nil
        }
        let map = defaults.dictionary(forKey: namesKey) as? [String: String] ?? [:]
        let name = map[id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? nil : name
    }

    /// Mirrors one mapping into App Group storage. Empty names remove the entry.
    nonisolated static func setDisplayName(_ name: String, forPatientId patientId: String) {
        let id = patientId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        mutateMap { map in
            if trimmed.isEmpty {
                map.removeValue(forKey: id)
            } else {
                map[id] = trimmed
            }
        }
    }

    nonisolated static func removeDisplayName(forPatientId patientId: String) {
        setDisplayName("", forPatientId: patientId)
    }

    private nonisolated static func mutateMap(_ mutate: (inout [String: String]) -> Void) {
        guard let defaults = UserDefaults(suiteName: PatientNameAppGroup.identifier) else { return }
        var map = defaults.dictionary(forKey: namesKey) as? [String: String] ?? [:]
        mutate(&map)
        defaults.set(map, forKey: namesKey)
    }
}
