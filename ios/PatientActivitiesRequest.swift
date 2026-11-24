import Foundation
import Observation

/// A failed send is reconciled with a read, never automatically resent.
@MainActor @Observable final class PatientActivitiesRequest {
    enum State: Equatable { case loading, ready, sending, pending, available, failed }
    private(set) var state: State = .loading
    private(set) var uncertain = false
    private var busy = false
    func run(send: Bool, current: () -> Bool, rpc: (Bool) async throws -> String) async {
        guard !busy, current(), !send || state == .ready else { return }
        busy = true
        defer { busy = false }
        state = send ? .sending : .loading
        do {
            let result = try await rpc(send)
            guard current(), !Task.isCancelled else { return }
            try apply(result)
            uncertain = false
        } catch {
            guard current(), !Task.isCancelled else { return }
            uncertain = send || uncertain
            if send {
                do {
                    let result = try await rpc(false)
                    guard current(), !Task.isCancelled else { return }
                    try apply(result)
                    if state == .pending || state == .available { uncertain = false }
                } catch { if current() { state = .failed } }
            } else { state = .failed }
        }
    }
    private func apply(_ value: String) throws {
        switch value {
        case "no_request": state = .ready
        case "pending": state = .pending
        case "activities_available": state = .available
        default: throw URLError(.cannotParseResponse)
        }
    }
}
