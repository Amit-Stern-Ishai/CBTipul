import Foundation
import SwiftData
import os

/// Local, on-device mapping of a patient to their name, so names can later
/// be removed from the backend and kept only on this device.
@Model
final class LocalPatientIdentity {
    /// The patient's local `Patient.id`. Never generated here — always taken
    /// from the existing patient object.
    @Attribute(.unique) var patientID: UUID
    /// The row's primary key in the Supabase `Patients` table. `Patient.id`
    /// is regenerated on every launch, so this is the stable key used to
    /// upsert across launches without duplicating rows.
    @Attribute(.unique) var databaseID: String
    var name: String

    init(patientID: UUID, databaseID: String, name: String) {
        self.patientID = patientID
        self.databaseID = databaseID
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

    private func context() throws -> ModelContext {
        if let container {
            return container.mainContext
        }
        let container = try ModelContainer(for: LocalPatientIdentity.self)
        self.container = container
        return container.mainContext
    }

    /// Upserts a patientID → name mapping for every saved patient. Safe to
    /// run repeatedly: existing mappings only get their name refreshed.
    /// Persistence failures are logged and never thrown, so they cannot
    /// prevent the patient list from loading.
    func upsertIdentities(for patients: [Patient]) {
        do {
            let context = try context()
            for patient in patients {
                guard let databaseID = patient.databaseID?.queryValue else { continue }
                let descriptor = FetchDescriptor<LocalPatientIdentity>(
                    predicate: #Predicate { $0.databaseID == databaseID }
                )
                let name = patient.displayName
                if let existing = try context.fetch(descriptor).first {
                    if existing.name != name {
                        existing.name = name
                    }
                } else {
                    context.insert(LocalPatientIdentity(
                        patientID: patient.id,
                        databaseID: databaseID,
                        name: name
                    ))
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
