import Foundation

enum PatientNameAppGroup { static let identifier = "group.com.CBTipul.app" }
/// Notifications never persist or recover patient names. The extension has no signed-in memory.
enum PatientNameResolver: Sendable {
    nonisolated static func clear() { UserDefaults(suiteName: PatientNameAppGroup.identifier)?.removeObject(forKey: "patientDisplayNames") }
    nonisolated static func displayName(forPatientId: String) -> String? { clear(); return nil }
    nonisolated static func setDisplayName(_ name: String, forPatientId: String) { clear() }
    nonisolated static func removeDisplayName(forPatientId: String) { clear() }
}
