import Foundation
import SwiftData
import os

/// Local, on-device mapping of a patient to their name, so names can later
/// be removed from the backend and kept only on this device.
@Model
final class LocalPatientIdentity {
    /// The patient's server-assigned ID (`Patient.id`), stored as its
    /// string query value.
    @Attribute(.unique) var patientID: String
    var name: String

    init(patientID: String, name: String) {
        self.patientID = patientID
        self.name = name
    }
}

/// SwiftData-backed store of `LocalPatientIdentity` rows.
///
/// Phase 1 migration: fed by `PatientStore.loadPatients()` so the local
/// patientID → name mapping is populated for every loaded patient.
@MainActor
final class PatientIdentityStore {
    private let logger = Logger(subsystem: "CBTipul", category: "PatientIdentityStore")
    private var container: ModelContainer?

    private static var storeURL: URL {
        URL.applicationSupportDirectory.appending(path: "LocalPatientIdentity.store")
    }

    private func context() throws -> ModelContext {
        if let container {
            return container.mainContext
        }
        try FileManager.default.createDirectory(
            at: .applicationSupportDirectory, withIntermediateDirectories: true)
        let configuration = ModelConfiguration(url: Self.storeURL)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: LocalPatientIdentity.self,
                                           configurations: configuration)
        } catch {
            // The store is a rebuildable mirror of server data, so a schema
            // mismatch is resolved by starting over instead of migrating;
            // the next load repopulates it fully.
            logger.error("Recreating patient identity store: \(error)")
            try FileManager.default.removeItem(at: Self.storeURL)
            container = try ModelContainer(for: LocalPatientIdentity.self,
                                           configurations: configuration)
        }
        self.container = container
        return container.mainContext
    }

    /// Upserts a patientID → name mapping for every patient. Safe to run
    /// repeatedly: existing mappings only get their name refreshed.
    /// Persistence failures are logged and never thrown, so they cannot
    /// prevent the patient list from loading.
    func upsertIdentities(for patients: [Patient]) {
        do {
            let context = try context()
            for patient in patients {
                let patientID = patient.id.queryValue
                let descriptor = FetchDescriptor<LocalPatientIdentity>(
                    predicate: #Predicate { $0.patientID == patientID }
                )
                let name = patient.displayName
                if let existing = try context.fetch(descriptor).first {
                    if existing.name != name {
                        existing.name = name
                    }
                } else {
                    context.insert(LocalPatientIdentity(patientID: patientID, name: name))
                }
            }
            if context.hasChanges {
                try context.save()
            }
        } catch {
            logger.error("Failed to persist local patient identities: \(error)")
        }
    }
}
