import Foundation
import Security
import SwiftUI

/// Drafts stay in this device's Keychain, separate from clinical server records.
/// The account, form kind and target all participate in the key.
struct DeviceDraftStorage {
    var service = "CBTipul.device-form-drafts.v1"

    private func query(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key,
         kSecAttrSynchronizable as String: false]
    }

    static func key(userID: String, kind: String, target: String) throws -> String {
        try JSONEncoder().encode([userID, kind, target]).base64EncodedString()
    }

    func contains(key: String) -> Bool {
        var attributes = query(key)
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(attributes as CFDictionary, nil) == errSecSuccess
    }

    func load<Value: Decodable>(_ type: Value.Type, key: String) throws -> Value? {
        var attributes = query(key)
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(attributes as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw DraftError.storage(status)
        }
        return try JSONDecoder().decode(type, from: data)
    }

    func save<Value: Encodable>(_ value: Value, key: String) throws {
        let data = try JSONEncoder().encode(value)
        let attributes = query(key)
        var status = SecItemUpdate(attributes as CFDictionary,
                                   [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var insertion = attributes
            insertion[kSecValueData as String] = data
            insertion[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(insertion as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw DraftError.storage(status) }
    }

    func remove(key: String) throws {
        let status = SecItemDelete(query(key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw DraftError.storage(status)
        }
    }

    enum DraftError: Error { case storage(OSStatus) }
}

/// Shared feedback and lifecycle for the three forms. Never sends content.
@Observable
@MainActor
final class DeviceFormDraft<Value: Codable> {
    private let storage: DeviceDraftStorage
    private var key: String?
    private(set) var hasLoaded = false
    private(set) var feedback: String?
    private(set) var hasError = false

    init(storage: DeviceDraftStorage = DeviceDraftStorage()) { self.storage = storage }

    func restore(userID: String?, kind: String, target: String) -> Value? {
        guard !hasLoaded else { return nil }
        hasLoaded = true
        guard let userID, !userID.isEmpty else {
            fail(L10n.deviceDraftSaveFailed)
            return nil
        }
        do {
            let resolvedKey = try DeviceDraftStorage.key(userID: userID, kind: kind, target: target)
            key = resolvedKey
            let value = try storage.load(Value.self, key: resolvedKey)
            if value != nil { feedback = L10n.deviceDraftRestored }
            return value
        } catch {
            fail(L10n.deviceDraftRestoreFailed)
            return nil
        }
    }

    @discardableResult
    func save(_ value: Value, isEmpty: Bool) -> Bool {
        guard let key else { fail(L10n.deviceDraftSaveFailed); return false }
        do {
            if isEmpty { try storage.remove(key: key) }
            else { try storage.save(value, key: key) }
            hasError = false
            feedback = isEmpty ? nil : L10n.deviceDraftSaved
            return true
        } catch {
            fail(L10n.deviceDraftSaveFailed)
            return false
        }
    }

    @discardableResult
    func discard() -> Bool {
        guard let key else { fail(L10n.deviceDraftRemoveFailed); return false }
        do {
            try storage.remove(key: key)
            hasError = false
            feedback = nil
            return true
        } catch {
            fail(L10n.deviceDraftRemoveFailed)
            return false
        }
    }

    private func fail(_ message: String) { hasError = true; feedback = message }
}

struct DeviceDraftFeedback: View {
    let message: String?
    var isError = false

    var body: some View {
        if let message {
            Label(message, systemImage: isError ? "exclamationmark.triangle" : "iphone")
                .font(.footnote)
                .foregroundStyle(isError ? Theme.error : Theme.textBody)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("form.draftStatus")
        }
    }
}
