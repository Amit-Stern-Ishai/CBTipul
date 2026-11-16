import Foundation

/// Request ownership only; never stores clinical values or changes processing policy.
nonisolated struct AIActionLifecycle {
    enum Stage: String { case questionnaires, context, allowance, anonymization, server, presentation }
    private(set) var request: UUID?
    private var owner: String?
    private(set) var stage: Stage?
    var isRunning: Bool { request != nil }

    mutating func begin(owner: String?) -> UUID? {
        guard !isRunning, let owner else { return nil }
        let id = UUID(); self.owner = owner; request = id
        return id
    }
    func accepts(_ id: UUID, owner: String?) -> Bool {
        request == id && self.owner != nil && self.owner == owner
    }
    mutating func advance(_ next: Stage, request id: UUID, owner: String?) throws {
        try Task.checkCancellation()
        guard accepts(id, owner: owner) else { throw CancellationError() }
        stage = next
    }
    mutating func finish(_ id: UUID) {
        guard request == id else { return }
        invalidate()
    }
    mutating func invalidate() { request = nil; owner = nil; stage = nil }
}
