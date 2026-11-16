import Foundation
import OSLog
import Supabase

/// Curated, content-free messages; no raw backend text reaches the UI or diagnostics.
nonisolated enum AIActionFailure: String, Error, LocalizedError {
    case cancelled, timeout, invalidResponse, backend
    static func from(_ error: Error) -> AIActionFailure? {
        if error is CancellationError { return .cancelled }
        if let url = error as? URLError {
            if url.code == .cancelled { return .cancelled }
            if url.code == .timedOut { return .timeout }
        }
        if error is DecodingError { return .invalidResponse }
        if let own = error as? AIActionFailure { return own }
        if case let FunctionsError.httpError(status, _) = error {
            let classified = ClientFailure.from(error)
            guard [.service, .connection, .unknown].contains(classified) else { return nil }
            if status == 408 || status == 504 { return .timeout }
            if status >= 500 && ClientFailure.from(error) == .service { return .backend }
        }
        return nil
    }
    static func message(_ error: Error) -> String {
        if error is AIDataSharingConsentDeclinedError {
            return L10n.aiActionConsentNotGranted
        }
        return from(error)?.localizedDescription ?? error.userFacingMessage ?? ClientFailure.unknown.localizedDescription
    }
    var errorDescription: String? {
        switch self {
        case .cancelled: return L10n.aiActionCancelled
        case .timeout: return L10n.aiActionTimedOut
        case .invalidResponse: return L10n.aiActionInvalidResponse
        case .backend: return L10n.aiActionBackendFailure
        }
    }
}

/// Local, DEBUG-only allowlisted metadata. Never contains bodies, identifiers, URLs,
/// exception descriptions, coding paths, model output, allowance balances or tokens.
nonisolated struct AIActionDiagnostics: Sendable {
    @TaskLocal static var current: AIActionDiagnostics?
    enum Stage: String { case action, questionnaires, context, allowance, anonymization, consent, authentication, preparationHTTP, analysisHTTP, gatewayHTTP, anonymizerHTTP, response, decode, presentation, cache }
    enum Outcome: String { case started, succeeded, failed, cancelled, discarded }
    let correlation = UUID().uuidString
    private let started = ProcessInfo.processInfo.systemUptime

    func event(_ stage: Stage, _ outcome: Outcome, since: TimeInterval? = nil,
               status: Int? = nil, bytes: Int? = nil, records: Int? = nil, error: Error? = nil) {
        #if DEBUG
        let elapsed = Int((ProcessInfo.processInfo.systemUptime - (since ?? started)) * 1_000)
        let code: String
        if let error {
            if let failure = AIActionFailure.from(error) { code = failure.rawValue }
            else if error is AIDataSharingConsentDeclinedError { code = "consent_declined" }
            else { code = ClientFailure.from(error).rawValue }
        } else { code = "none" }
        let logger = Logger(subsystem: "com.CBTipul.app", category: "AIActionDebug")
        logger.info("request=\(correlation, privacy: .public) stage=\(stage.rawValue, privacy: .public) elapsed_ms=\(elapsed) outcome=\(outcome.rawValue, privacy: .public) http_status=\(status ?? -1) payload_bytes=\(bytes ?? -1) records=\(records ?? -1) code=\(code, privacy: .public)")
        #endif
    }
    /// Temporary on-device diagnostic dialog; never includes response bodies or error descriptions.
    func failureDetails(_ error: Error, stage: AIActionLifecycle.Stage?) -> String {
        #if DEBUG
        let status: String
        if case let FunctionsError.httpError(value, _) = error { status = String(value) }
        else { status = "n/a" }
        let code: String
        if let url = error as? URLError { code = "URLError(\(url.code.rawValue))" }
        else if case FunctionsError.relayError = error { code = "relay_error" }
        else { code = AIActionFailure.from(error)?.rawValue ?? ClientFailure.from(error).rawValue }
        let elapsed = Int((ProcessInfo.processInfo.systemUptime - started) * 1_000)
        return String(format: L10n.aiPreparationTemporaryDetails,
                      stage?.rawValue ?? "action", status, code, elapsed, correlation)
        #else
        return ""
        #endif
    }
    func measure<T>(_ stage: Stage, bytes: Int? = nil, records: Int? = nil,
                    operation: () async throws -> T) async throws -> T {
        let start = ProcessInfo.processInfo.systemUptime
        event(stage, .started, bytes: bytes, records: records)
        do {
            let value = try await operation()
            event(stage, .succeeded, since: start, bytes: bytes, records: records)
            return value
        } catch {
            var status: Int?
            if case let FunctionsError.httpError(value, data) = error {
                status = value
                event(.response, .failed, status: value, bytes: data.count, error: error)
            }
            event(stage, AIActionFailure.from(error) == .cancelled ? .cancelled : .failed,
                  since: start, status: status, bytes: bytes, records: records, error: error)
            throw error
        }
    }
    func payloadBytes<T: Encodable>(_ value: T) -> Int? {
        #if DEBUG
        return (try? JSONEncoder().encode(value))?.count
        #else
        return nil
        #endif
    }
    func decode<T: Decodable>(_ type: T.Type, data: Data, status: Int,
                              decoder: JSONDecoder = JSONDecoder()) throws -> T {
        event(.response, .succeeded, status: status, bytes: data.count)
        let start = ProcessInfo.processInfo.systemUptime
        do {
            let value = try decoder.decode(type, from: data)
            event(.decode, .succeeded, since: start, status: status, bytes: data.count)
            return value
        } catch {
            event(.decode, .failed, since: start, status: status, bytes: data.count, error: error)
            throw error
        }
    }
}
