import Foundation
import Observation

nonisolated struct AppleTokenRegistrationResponse: Decodable { let success: Bool }
nonisolated struct AccountDeletionResponse: Decodable {
    let success: Bool
    let appleManualRevocationRequired: Bool
}
nonisolated struct AppleTokenRegistrationRequest: Encodable { let authorizationCode: String }

enum AccountActionError: LocalizedError {
    case failed, identityChanged
    var errorDescription: String? { L10n.accountActionFailed }
}

/// UI-independent lifecycle state. All network operations are injected so tests
/// never invoke live functions. Credentials live only in each async call's memory.
@Observable @MainActor
final class AccountActions {
    typealias Register = (String, String) async throws -> AppleTokenRegistrationResponse
    typealias Delete = (String) async throws -> AccountDeletionResponse
    private let registerToken: Register
    private let deleteConfirmedAccount: Delete
    private var identity: String?
    private var generation = UUID()
    var identityGeneration: UUID { generation }
    private(set) var isRegistering = false
    private(set) var isDeleting = false
    private(set) var registrationWarningUserID: String?
    var deletionNotice: String?

    init(register: @escaping Register, delete: @escaping Delete) {
        registerToken = register
        deleteConfirmedAccount = delete
    }

    func setIdentity(_ userID: String?) {
        guard identity != userID else { return }
        identity = userID
        invalidatePending()
    }

    func invalidatePending() {
        generation = UUID()
        isRegistering = false
        registrationWarningUserID = nil
    }

    func register(code: String?, userID: String, accessToken: String) async {
        guard identity == userID, !isRegistering, !isDeleting else { return }
        let operation = generation
        isRegistering = true
        defer { if generation == operation { isRegistering = false } }
        do {
            guard let code, !code.isEmpty else { throw AccountActionError.failed }
            let response = try await registerToken(code, accessToken)
            guard generation == operation, identity == userID else { return }
            guard response.success else { throw AccountActionError.failed }
            registrationWarningUserID = nil
        } catch {
            guard generation == operation, identity == userID else { return }
            registrationWarningUserID = userID
        }
    }

    /// Called exclusively from the explicit account-deletion confirmation flow.
    func delete(userID: String, accessToken: String, cleanup: () -> Void) async throws -> AccountDeletionResponse {
        guard identity == userID, !isDeleting, !isRegistering else { throw AccountActionError.failed }
        let operation = generation
        isDeleting = true
        defer { isDeleting = false }
        let response = try await deleteConfirmedAccount(accessToken)
        guard response.success else { throw AccountActionError.failed }
        guard generation == operation, identity == userID else { throw AccountActionError.identityChanged }
        cleanup()
        deletionNotice = response.appleManualRevocationRequired
            ? L10n.accountDeletedAppleRevocation : L10n.accountDeletedMessage
        return response
    }
}
