import Foundation
import Supabase

/// Typed logical operation only; no raw URL, body, headers, or SDK error serialization.
@MainActor enum TelemetryRequests {
    static func run<T: Sendable>(_ request: TelemetryRequest, body: @MainActor () async throws -> T) async throws -> T {
        let op = TelemetryScope.operation?.requestOperation(request) ?? TelemetryClient.shared.begin(.request, request: request)
        if TelemetryScope.operation != nil { op.event(.started) }
        do { let result = try await body(); op.event(.succeeded); return result }
        catch {
            if case let FunctionsError.httpError(code, _) = error {
            op.event(.failed, error: code == 401 ? .unauthorized : code == 403 ? .forbidden : .generic, status: code)
            } else { op.event(error is CancellationError ? .cancelled : .failed, error: error is CancellationError ? .cancelled : .generic) }
            throw error
        }
    }
}
