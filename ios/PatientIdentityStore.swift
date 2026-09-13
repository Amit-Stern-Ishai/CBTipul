import Foundation
import Security
import os

/// Errors from the Keychain-backed patient identity store.
enum PatientIdentityStoreError: Error {
    case keychainFailure(OSStatus)
}

/// Local mapping of a patient to their name, so names can later be removed
/// from the backend and kept only on the therapist's own devices.
///
/// Each patient is one Keychain generic-password item: service
/// `CBTipul.patient-names`, account = the server-assigned patient ID,
/// value = the name as UTF-8. Items are marked synchronizable, so they ride
/// iCloud Keychain across the therapist's devices and survive uninstalls.
final class PatientIdentityStore {
    private let logger = Logger(subsystem: "CBTipul", category: "PatientIdentityStore")

    private static let service = "CBTipul.patient-names"

    /// Attributes identifying a patient's Keychain item. Synchronizable must
    /// be part of the query, or lookups won't match synchronizable items.
    private static func query(for account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: true,
        ]
    }

    /// Saves or updates the name stored for a patient.
    func save(patientID: DatabaseID, name: String) throws {
        let data = Data(name.utf8)
        let query = Self.query(for: patientID.queryValue)
        let update: [String: Any] = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var attributes = query
            attributes[kSecValueData as String] = data
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            status = SecItemAdd(attributes as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw PatientIdentityStoreError.keychainFailure(status)
        }
    }

    /// The name stored for a patient, or nil when there is no mapping or the
    /// stored value is unreadable.
    func name(for patientID: DatabaseID) -> String? {
        var query = Self.query(for: patientID.queryValue)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                logger.error("Reading patient name failed: \(status)")
            }
            return nil
        }
        guard let data = result as? Data, let name = String(data: data, encoding: .utf8) else {
            logger.error("Stored patient name is unreadable; ignoring it")
            return nil
        }
        return name
    }

    /// Removes the mapping of a patient. Only for an actual patient-delete
    /// operation — never for pruning after a load, since the Keychain will
    /// eventually hold the only copy of each name.
    func delete(patientID: DatabaseID) throws {
        let status = SecItemDelete(Self.query(for: patientID.queryValue) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PatientIdentityStoreError.keychainFailure(status)
        }
    }

    /// Upserts a patientID → name mapping for every patient. Safe to run
    /// repeatedly: unchanged names are left untouched (sparing iCloud
    /// Keychain sync churn). Failures are logged and never thrown, so they
    /// cannot prevent the patient list from loading.
    ///
    /// Saves the backend name, never the resolved display name — and never
    /// an empty one, so a backend without names can't erase stored ones.
    func upsertIdentities(for patients: [Patient]) {
        for patient in patients {
            let name = patient.backendName
            guard !name.isEmpty else { continue }
            guard self.name(for: patient.id) != name else { continue }
            do {
                try save(patientID: patient.id, name: name)
            } catch {
                logger.error("Saving patient name failed: \(error)")
            }
        }
    }
}
