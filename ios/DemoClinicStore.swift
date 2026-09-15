import Foundation
import OSLog

/// Local-only persistence for the demo clinic.
///
/// Kept completely separate from the real Keychain identity store, the real
/// patients disk cache, and real preparation files — so demo edits never
/// touch production data, and re-entering demo restores what the therapist
/// last left there.
enum DemoClinicStore {
    private static let logger = Logger(subsystem: "CBTipul", category: "DemoClinicStore")

    private static var clinicURL: URL {
        URL.applicationSupportDirectory.appending(path: "demo-clinic.json")
    }

    private static var namesURL: URL {
        URL.applicationSupportDirectory.appending(path: "demo-patient-names.json")
    }

    private static func preparationURL(for patientID: DatabaseID) -> URL {
        URL.cachesDirectory.appending(path: "demo-preparation-\(patientID.queryValue).json")
    }

    // MARK: - Clinic snapshot (patients + questionnaires)

    struct Snapshot: Codable {
        var patients: [PatientRecord]
        var questionnairesByPatient: [String: [CompletedQuestionnaire]]
    }

    struct PatientRecord: Codable {
        let id: DatabaseID
        let firstName: String
        let lastName: String
        let active: Bool
        let notes: String
        let sessions: [SessionRecord]
        let formulation: PatientFormulation?
    }

    struct SessionRecord: Codable {
        let databaseID: DatabaseID?
        let date: Date
        let notes: String
        let type: SessionType?
        let structuredNotes: WhisperService.CBTSessionAnalysis?
    }

    static func loadClinic() -> Snapshot? {
        guard let data = try? Data(contentsOf: clinicURL) else { return nil }
        do {
            return try JSONDecoder().decode(Snapshot.self, from: data)
        } catch {
            logger.error("Demo clinic decode failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    static func saveClinic(_ snapshot: Snapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? FileManager.default.createDirectory(
            at: clinicURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: clinicURL, options: [.atomic, .completeFileProtection])
    }

    // MARK: - Names (demo-only; never Keychain)

    static func loadNames() -> [String: String] {
        guard let data = try? Data(contentsOf: namesURL),
              let names = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return names
    }

    static func saveNames(_ names: [String: String]) {
        guard let data = try? JSONEncoder().encode(names) else { return }
        try? FileManager.default.createDirectory(
            at: namesURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: namesURL, options: [.atomic, .completeFileProtection])
    }

    static func name(for patientID: DatabaseID) -> String? {
        let value = loadNames()[patientID.queryValue]
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    static func saveName(_ name: String, for patientID: DatabaseID) {
        var names = loadNames()
        names[patientID.queryValue] = name
        saveNames(names)
    }

    static func deleteName(for patientID: DatabaseID) {
        var names = loadNames()
        names.removeValue(forKey: patientID.queryValue)
        saveNames(names)
    }

    // MARK: - Preparations (demo-only files)

    static func loadPreparation(for patientID: DatabaseID) -> SavedPreparation? {
        guard let data = try? Data(contentsOf: preparationURL(for: patientID)) else { return nil }
        return try? JSONDecoder().decode(SavedPreparation.self, from: data)
    }

    @discardableResult
    static func savePreparation(_ response: WhisperService.PrepareSessionResponse,
                                for patientID: DatabaseID) -> SavedPreparation {
        let saved = SavedPreparation(generatedAt: .now, response: response)
        if let data = try? JSONEncoder().encode(saved) {
            try? data.write(
                to: preparationURL(for: patientID),
                options: [.atomic, .completeFileProtection]
            )
        }
        return saved
    }

    static func deletePreparation(for patientID: DatabaseID) {
        try? FileManager.default.removeItem(at: preparationURL(for: patientID))
    }

    // MARK: - Wipe

    /// Removes every demo-local artifact (clinic, names, preparations).
    static func clearAll() {
        try? FileManager.default.removeItem(at: clinicURL)
        try? FileManager.default.removeItem(at: namesURL)
        let caches = URL.cachesDirectory
        if let files = try? FileManager.default.contentsOfDirectory(
            at: caches, includingPropertiesForKeys: nil
        ) {
            for file in files where file.lastPathComponent.hasPrefix("demo-preparation-") {
                try? FileManager.default.removeItem(at: file)
            }
        }
        logger.notice("Cleared all demo clinic stores")
    }
}
