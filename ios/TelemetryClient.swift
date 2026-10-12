import Foundation

// Deliberately independent of SDK errors, credentials, and clinical models.
nonisolated enum TelemetryFlow: String, Codable, Sendable { case authentication, restoration, access, invitation, submission, push, request, onboarding, sharing, assignment, message, ai }
nonisolated enum TelemetryStage: String, Codable, Sendable { case started, succeeded, failed, cancelled, retry, received, previewShown, roleSwitchConfirmed, authorization, opened, shareSheetOpened, sharingReported, completed }
nonisolated enum TelemetryFeature: String, Codable, Sendable { case introduction, welcome, demoTour, displayName, invitationCreation, invitationShare, questionnaireAssignment, diaryAssignment, sendMessage, readMessage, messages, chat, transcription, sessionAnalysis, sessionPreparation, supervision, whatAmIMissing, caseReview }
nonisolated enum TelemetryOutcome: String, Codable, Sendable { case started, succeeded, failed, cancelled, retrying, observed }
nonisolated extension TelemetryStage {
    var outcome: TelemetryOutcome { switch self { case .started: .started; case .succeeded, .completed: .succeeded; case .failed: .failed; case .cancelled: .cancelled; case .retry: .retrying; default: .observed } }
}
nonisolated enum TelemetryMethod: String, Codable, Sendable { case email, google, apple, anonymous }
nonisolated enum TelemetryForm: String, Codable, Sendable { case questionnaire, diaryOne, diaryTwo, diaryThree }
nonisolated enum TelemetryRole: String, Codable, Sendable { case therapist, patient, unknown }
nonisolated enum TelemetryAccess: String, Codable, Sendable { case full; case readOnly = "read_only" }
nonisolated enum TelemetryNetwork: String, Codable, Sendable { case wifi, cellular, ethernet, other, offline, unknown }
nonisolated enum TelemetryLifecycle: String, Codable, Sendable { case foreground, background, unknown }
nonisolated enum TelemetryStart: String, Codable, Sendable { case cold, warm, unknown }
nonisolated enum TelemetryError: String, Codable, Sendable { case none, generic, cancelled, timeout, network, unauthorized, forbidden, unavailable, unresolved }
nonisolated enum TelemetryPushOperation: String, Codable, Sendable { case permission, apnsRegistration, fcmRegistration, deviceRegistration, received, opened }
nonisolated enum TelemetryAuthorization: String, Codable, Sendable { case allowed, denied, notDetermined, unknown }
nonisolated enum TelemetryEnvironment: String, Codable, Sendable { case development, production, unknown }
nonisolated enum TelemetryNotification: String, Codable, Sendable { case questionnaire, diary, patientMessage, other, unknown }
nonisolated enum TelemetryRequest: String, Codable, Sendable { case appContext, invitationPreview, invitationClaim, questionnaireSubmit, diaryOneSubmit, diaryTwoSubmit, diaryThreeSubmit, pushDeviceRegister }

nonisolated struct TelemetryMetadata: Codable, Sendable {
    let platform: String
    let deviceModel: String
    let manufacturer: String?
    let osVersion: String
    let apiLevel: Int?
    let appVersion: String
    let build: String
    let buildChannel: String
    let distribution: String
    var demo: Bool = false
    var role: TelemetryRole
    var network: TelemetryNetwork
    var lifecycle: TelemetryLifecycle
    let locale: String
    let timezone: String
    var valid: Bool {
        platform == "ios" && manufacturer == nil && apiLevel == nil &&
        [deviceModel, osVersion, appVersion, build, locale, timezone].allSatisfy {
            !$0.isEmpty && $0.count <= 128 && !$0.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        } && ["debug", "release"].contains(buildChannel) && distribution == "unknown"
    }
}

/// No free-form property bag. Every field and enum is listed here.
nonisolated struct TelemetryEvent: Encodable, Sendable {
    let schemaVersion: Int
    let timestamp: Date
    let correlationID: UUID
    let metadata: TelemetryMetadata
    let flow: TelemetryFlow
    let stage: TelemetryStage
    let outcome: TelemetryOutcome
    let error: TelemetryError
    let durationMs: Int
    let attempt: Int
    let retryCount: Int
    let feature: TelemetryFeature?
    let method: TelemetryMethod?
    let form: TelemetryForm?
    let access: TelemetryAccess?
    let start: TelemetryStart?
    let previousRole: TelemetryRole?
    let pushOperation: TelemetryPushOperation?
    let authorization: TelemetryAuthorization?
    let preferenceEnabled: Bool?
    let apnsEnvironment: TelemetryEnvironment?
    let notificationType: TelemetryNotification?
    let request: TelemetryRequest?
    let httpStatus: Int?
    var valid: Bool {
        guard retryCount == attempt - 1, outcome == stage.outcome, schemaVersion == 1, metadata.valid, durationMs >= 0, durationMs <= 86_400_000,
              (1...100).contains(attempt), httpStatus.map({ (100...599).contains($0) }) ?? true else { return false }
        let stages: [TelemetryFlow: Set<TelemetryStage>] = [
            .authentication: [.started,.succeeded,.failed,.cancelled], .restoration: [.succeeded,.failed],
            .access: [.started,.succeeded,.failed,.cancelled,.retry],
            .invitation: [.received,.previewShown,.started,.succeeded,.failed,.cancelled,.roleSwitchConfirmed],
            .submission: [.started,.succeeded,.failed,.cancelled],
            .push: [.started,.succeeded,.failed,.authorization,.received,.opened],
            .request: [.started,.succeeded,.failed,.cancelled,.retry],
            .onboarding: [.started,.succeeded,.failed,.cancelled], .sharing: [.started,.succeeded,.failed,.cancelled,.shareSheetOpened,.sharingReported],
            .assignment: [.started,.succeeded,.failed,.cancelled,.completed], .message: [.started,.succeeded,.failed,.cancelled,.opened], .ai: [.started,.succeeded,.failed,.cancelled]]
        guard stages[flow]?.contains(stage) == true else { return false }
        let features: [TelemetryFlow:Set<TelemetryFeature>] = [.onboarding:[.introduction,.welcome,.demoTour,.displayName],.sharing:[.invitationCreation,.invitationShare],.assignment:[.questionnaireAssignment,.diaryAssignment],.message:[.sendMessage,.readMessage,.messages],.ai:[.chat,.transcription,.sessionAnalysis,.sessionPreparation,.supervision,.whatAmIMissing,.caseReview]]
        if let allowed=features[flow] { guard let feature,allowed.contains(feature) else {return false} }
        else if feature != nil {return false}
        if method != nil && flow != .authentication { return false }
        if form != nil && flow != .submission { return false }
        if access != nil && !(flow == .access && stage == .succeeded) { return false }
        if (start != nil || previousRole != nil) && flow != .invitation { return false }
        if (pushOperation != nil || authorization != nil || preferenceEnabled != nil || apnsEnvironment != nil || notificationType != nil) && flow != .push { return false }
        if (request != nil || httpStatus != nil) && flow != .request { return false }
        if flow == .authentication && method == nil { return false }
        if flow == .submission && form == nil { return false }
        if flow == .push && pushOperation == nil { return false }
        if flow == .request && request == nil { return false }
        if stage == .failed { if error == .none || error == .cancelled { return false } }
        else if stage == .cancelled { if error != .cancelled { return false } }
        else if error != .none { return false }
        return true
    }
}

/// The SDK owns buffering, delivery, retries and anonymous identity.
nonisolated protocol TelemetryCapture: Sendable {
    func capture(_ event: TelemetryEvent)
    func reset()
}
nonisolated struct DisabledTelemetryCapture: TelemetryCapture {
    func capture(_ event: TelemetryEvent) {}
    func reset() {}
}
nonisolated final class TelemetryClient: @unchecked Sendable {
    static let shared = TelemetryClient(metadata: { TelemetryPlatform.snapshot() })
    private let lock = NSRecursiveLock()
    private let metadata: @Sendable () -> TelemetryMetadata
    private let wall: () -> Date
    private let monotonic: () -> TimeInterval
    private var owner: String?
    private var observedOwner = false
    private var role: TelemetryRole = .unknown
    private var demo = false
    private var capture: any TelemetryCapture
    init(metadata: @escaping @Sendable () -> TelemetryMetadata, capture: any TelemetryCapture = DisabledTelemetryCapture(),
         wall: @escaping () -> Date = Date.init, monotonic: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.metadata = metadata; self.capture = capture; self.wall = wall; self.monotonic = monotonic
    }
    private func locked<T>(_ action: () -> T) -> T { lock.lock(); defer { lock.unlock() }; return action() }
    func configure(capture: any TelemetryCapture) { locked { self.capture = capture } }
    /// Auth identity is compared locally only. It is never passed to PostHog.
    /// Initial restoration keeps the SDK identity; subsequent logout/account/role changes reset it.
    func setOwner(_ identity: String?, role: TelemetryRole) {
        locked {
            let changed = owner != identity || self.role != role
            if observedOwner && changed { capture.reset() }
            if changed { demo = false }
            owner = identity; self.role = role; observedOwner = true
        }
    }
    func setDemo(_ enabled: Bool) { locked { demo = enabled } }
    func begin(_ flow: TelemetryFlow, feature: TelemetryFeature? = nil, method: TelemetryMethod? = nil, form: TelemetryForm? = nil,
               push: TelemetryPushOperation? = nil, request: TelemetryRequest? = nil) -> TelemetryOperation {
        let op = locked { TelemetryOperation(client: self, flow: flow, feature: feature, method: method, form: form, push: push, request: request,
                                    owner: owner, role: role, demo: demo, started: monotonic()) }
        op.event(.started)
        return op
    }
    func operation(_ flow: TelemetryFlow, feature: TelemetryFeature? = nil, method: TelemetryMethod? = nil, form: TelemetryForm? = nil, push: TelemetryPushOperation? = nil, request: TelemetryRequest? = nil, correlation: UUID = UUID()) -> TelemetryOperation {
        locked { TelemetryOperation(client: self, flow: flow, feature: feature, method: method, form: form, push: push, request: request, owner: owner, role: role, demo: demo, started: monotonic(), correlation: correlation) }
    }
    fileprivate func rebind(_ op: TelemetryOperation) -> TelemetryOperation {
        locked { TelemetryOperation(client: self, flow: op.flow, feature: op.feature, method: op.method, form: op.form, push: op.push, request: op.request,
                           owner: owner, role: role, demo: demo, started: op.started, correlation: op.correlation) }
    }
    fileprivate func child(_ op: TelemetryOperation, request: TelemetryRequest) -> TelemetryOperation {
        TelemetryOperation(client: self, flow: .request, request: request, owner: op.owner, role: op.role, demo: op.demo, started: monotonic(), correlation: op.correlation)
    }
    fileprivate func record(_ op: TelemetryOperation, stage: TelemetryStage, error: TelemetryError,
                            access: TelemetryAccess?, attempt: Int, start: TelemetryStart?, previous: TelemetryRole?,
                            authorization: TelemetryAuthorization?, preference: Bool?, environment: TelemetryEnvironment?,
                            notification: TelemetryNotification?, status: Int?) {
        var m = metadata()
        locked {
            // Only prevent NEW stale captures across accounts; SDK queues are untouched.
            guard op.owner == owner, op.role == role else { return }
            m.role = op.role; m.demo = op.demo
            let e = TelemetryEvent(schemaVersion: 1, timestamp: wall(), correlationID: op.correlation,
                metadata: m, flow: op.flow, stage: stage, outcome: stage.outcome, error: error,
                durationMs: min(86_400_000, max(0, Int((monotonic()-op.started)*1000))), attempt: attempt, retryCount: attempt - 1,
                feature: op.feature, method: op.method, form: op.form, access: access, start: start, previousRole: previous,
                pushOperation: op.push, authorization: authorization, preferenceEnabled: preference,
                apnsEnvironment: environment, notificationType: notification, request: op.request, httpStatus: status)
            guard e.valid else { return }
            capture.capture(e)
        }
    }
}

nonisolated final class TelemetryOperation: @unchecked Sendable {
    fileprivate let feature: TelemetryFeature?
    fileprivate let client: TelemetryClient, flow: TelemetryFlow, method: TelemetryMethod?, form: TelemetryForm?
    fileprivate let push: TelemetryPushOperation?, request: TelemetryRequest?, started: TimeInterval
    fileprivate let owner: String?, role: TelemetryRole, demo: Bool
    let correlation: UUID
    init(client: TelemetryClient, flow: TelemetryFlow, feature: TelemetryFeature? = nil, method: TelemetryMethod? = nil, form: TelemetryForm? = nil,
         push: TelemetryPushOperation? = nil, request: TelemetryRequest? = nil, owner: String?, role: TelemetryRole, demo: Bool, started: TimeInterval, correlation: UUID = UUID()) {
        self.client=client; self.flow=flow; self.feature=feature; self.method=method; self.form=form; self.push=push; self.request=request
        self.owner=owner; self.role=role; self.demo=demo; self.started=started; self.correlation=correlation
    }
    func rebound() -> TelemetryOperation { client.rebind(self) }
    func requestOperation(_ request: TelemetryRequest) -> TelemetryOperation {
        client.child(self, request: request)
    }
    func event(_ stage: TelemetryStage, error: TelemetryError = .none, access: TelemetryAccess? = nil, attempt: Int = 1,
               start: TelemetryStart? = nil, previous: TelemetryRole? = nil, authorization: TelemetryAuthorization? = nil,
               preference: Bool? = nil, environment: TelemetryEnvironment? = nil, notification: TelemetryNotification? = nil,
               status: Int? = nil) {
        client.record(self, stage: stage, error: error, access: access, attempt: attempt, start: start, previous: previous,
                      authorization: authorization, preference: preference, environment: environment, notification: notification, status: status)
    }
}

nonisolated enum TelemetryScope {
    @TaskLocal static var operation: TelemetryOperation?
}
@MainActor enum TelemetryMeasure {
    static func run<T: Sendable>(_ flow: TelemetryFlow, method: TelemetryMethod? = nil, form: TelemetryForm? = nil, client: TelemetryClient = .shared,
                       body: @MainActor () async throws -> T) async throws -> T {
        let operation = client.begin(flow, method: method, form: form)
        do { let value = try await TelemetryScope.$operation.withValue(operation) { try await body() }; (flow == .authentication ? operation.rebound() : operation).event(.succeeded); return value }
        catch { operation.event(error is CancellationError ? .cancelled : .failed, error: error is CancellationError ? .cancelled : .generic); throw error }
    }
}

nonisolated enum TelemetryPushObservation {
    static func type(_ raw: String?) -> TelemetryNotification {
        switch raw {
        case "questionnaire_assigned", "questionnaire_completed": .questionnaire
        case "diary_1_assigned", "diary_2_assigned", "diary_3_assigned", "diary_one_entry_added", "diary_two_entry_added", "diary_three_entry_added": .diary
        case "message_received": .patientMessage
        case nil: .unknown
        default: .other
        }
    }
    static func record(_ stage: TelemetryStage, type: TelemetryNotification, correlation: UUID?) {
        let op = TelemetryClient.shared.operation(.push, push: stage == .opened ? .opened : .received, correlation: correlation ?? UUID())
        op.event(stage, notification: type)
    }
}

/// Inline observer for existing async services: no actor hops, no clinical values passed to events.
nonisolated final class TelemetryFlowObservation {
    let operation: TelemetryOperation
    private var stage: TelemetryStage = .failed
    private var error: TelemetryError = .generic
    init(_ flow:TelemetryFlow,feature:TelemetryFeature,client:TelemetryClient = .shared) {
        operation=client.begin(flow,feature:feature)
    }
    func succeeded() {stage = .succeeded;error = .none}
    func cancelled() {stage = .cancelled;error = .cancelled}
    func finish() {operation.event(stage,error:error)}
}
