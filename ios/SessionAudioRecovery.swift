import Foundation
import CryptoKit

/// No names or identifiers in filenames. Audio is device-only and excluded from backup.
/// completeUnlessOpen permits an already-open recording to continue while locked.
nonisolated enum SessionAudioRecovery {
    static func directory(account: String) throws -> URL {
        guard !account.isEmpty else { throw ClientFailure.localDraft }
        let digest = SHA256.hash(data: Data(account.utf8)).map { String(format: "%02x", $0) }.joined()
        return try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                          appropriateFor: nil, create: true)
            .appendingPathComponent("SessionAudioRecovery", isDirectory: true)
            .appendingPathComponent(digest, isDirectory: true)
    }
    static func create(account: String) throws -> URL {
        var folder = try directory(account: account)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUnlessOpen])
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try folder.setResourceValues(values)
        var file = folder.appendingPathComponent(UUID().uuidString + ".m4a")
        try Data().write(to: file, options: [.atomic, .completeFileProtectionUnlessOpen])
        try file.setResourceValues(values)
        return file
    }
    static func resolve(name: String, account: String) throws -> URL {
        guard name == URL(fileURLWithPath: name).lastPathComponent,
              UUID(uuidString: String(name.dropLast(4))) != nil, name.hasSuffix(".m4a") else {
            throw ClientFailure.localDraft
        }
        return try directory(account: account).appendingPathComponent(name)
    }
}
