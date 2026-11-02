#if DEBUG
import SwiftUI
import Supabase
import AVFoundation

/// Opt-in synthetic UI harness. All requests use an invalid domain intercepted
/// by URLProtocol; it never reads or writes real patients or sessions.
struct SummaryRecoveryFixture: View {
    static var enabled: Bool {
        AuthManager.isUITesting && ProcessInfo.processInfo.arguments.contains("-SummaryRecoveryFixture")
    }
    private static var didReset = false
    @State private var auth: AuthManager
    @State private var store: PatientStore
    @State private var presented = true
    private let patient: Patient
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SummaryFixtureProtocol.self]
        let client = SupabaseClient(supabaseURL: URL(string: "https://summary-fixture.invalid")!,
            supabaseKey: "synthetic-test-key", options: .init(global: .init(session: URLSession(configuration: config))))
        let auth = AuthManager(clientOverride: client)
        auth.enterUITestingSession()
        EntitlementState.shared.setIdentity(AuthManager.uiTestingUserId)
        EntitlementState.shared.apply(.init(version: 1, role: .therapist, activation: nil, patientId: nil,
                                            entitlement: .init(access: .full)))
        AIDataSharingConsentStore.shared.setDemoBypass(true)
        let patient = Patient(id: .integer(987654321))
        patient.localName = "בדיקה סינתטית"
        let store = PatientStore(client: client, persistPatientCache: false)
        store.patients = [patient]
        self.patient = patient
        _auth = State(initialValue: auth)
        _store = State(initialValue: store)
        if ProcessInfo.processInfo.arguments.contains("-ResetSummaryFixture") && !Self.didReset {
            Self.didReset = true
            let storage = DeviceDraftStorage()
            if let key = try? DeviceDraftStorage.key(userID: AuthManager.uiTestingUserId,
                    kind: "therapist-session", target: "new:987654321") {
                if let saved = try? storage.load(SessionRecovery.self, key: key), let name = saved.audioFileName,
                   let file = try? SessionAudioRecovery.resolve(name: name, account: AuthManager.uiTestingUserId) {
                    try? FileManager.default.removeItem(at: file)
                }
                try? storage.remove(key: key)
            }
            if ProcessInfo.processInfo.arguments.contains("-SummaryVoiceFixture") {
                do {
                    let url = try SessionAudioRecovery.create(account: AuthManager.uiTestingUserId)
                    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
                    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!
                    buffer.frameLength = 44100
                    for index in 0..<44100 { buffer.floatChannelData![0][index] = 0 }
                    let audio = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC,
                        AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1])
                    try audio.write(from: buffer)
                    let key = try DeviceDraftStorage.key(userID: AuthManager.uiTestingUserId,
                        kind: "therapist-session", target: "new:987654321")
                    let value = SessionRecovery(date: .now, notes: " ", type: nil, structuredNotes: nil,
                        selectedPatientID: nil, audioFileName: url.lastPathComponent, transcriptReady: false)
                    try storage.save(value, key: key)
                } catch { assertionFailure("Synthetic audio setup failed") }
            }
            for key in ["allowance", "transcribe", "anonymize", "insert", "committed"] { UserDefaults.standard.removeObject(forKey: "summary-fixture." + key) }
        }
    }
    var body: some View {
        VStack {
            Text("בדיקת שחזור בלבד")
            Button("פתיחת סיכום בדיקה") { presented = true }.accessibilityIdentifier("fixture.open")
            metrics
        }
        .sheet(isPresented: $presented) {
            VStack(spacing: 0) {
                SessionEditorView(session: Session(notes: " "), patient: patient, isNew: true)
                metrics
            }
            .environment(auth).environment(store).environment(GettingStartedRouter()).environment(OnboardingStore())
        }
    }
    private var metrics: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            Text(["allowance", "transcribe", "anonymize", "insert", "committed"].map { "\($0)=\(UserDefaults.standard.integer(forKey: "summary-fixture." + $0))" }.joined(separator: ";"))
                .font(.caption2).accessibilityIdentifier("fixture.counts")
        }
    }
}

nonisolated final class SummaryFixtureProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "summary-fixture.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        let path = request.url!.path
        let failure = ProcessInfo.processInfo.arguments.contains("-SummaryProcessingFailure")
        var status = 200
        var body = "[]"
        func count(_ step: String) {
            let key = "summary-fixture." + step
            UserDefaults.standard.set(UserDefaults.standard.integer(forKey: key) + 1, forKey: key)
        }
        if path.hasSuffix("get_my_ai_allowance") {
            count("allowance")
            body = #"{"checked_at":"2026-10-22T09:00:00Z","usage_month":"2026-10","resets_at":"2026-11-01T00:00:00Z","chat_tokens":{"limit":1000000,"used":0,"remaining":1000000,"exhausted":false,"code":null},"transcription_seconds":{"limit":10000,"used":0,"remaining":10000,"exhausted":false,"code":null}}"#
            if ProcessInfo.processInfo.arguments.contains("-SummaryAllowanceLow") {
                body = body.replacingOccurrences(of: "\"used\":0,\"remaining\":1000000", with: "\"used\":900000,\"remaining\":100000")
            }
            if ProcessInfo.processInfo.arguments.contains("-SummaryAllowanceDenied") {
                body = body.replacingOccurrences(of: "\"used\":0,\"remaining\":1000000,\"exhausted\":false", with: "\"used\":1000000,\"remaining\":0,\"exhausted\":true")
            }
            if ProcessInfo.processInfo.arguments.contains("-SummaryAllowanceUnavailable") {
                client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)); return
            }
        } else if path.contains("transcribe") {
            count("transcribe"); body = #"{"text":"תמלול סינתטי לבדיקת שחזור"}"#
        } else if path.hasSuffix("anonymize-clinical-text") {
            count("anonymize")
            if failure {
                status = 429
                body = #"{"monthlyLimit":1000000,"usedTokens":1004700,"remainingTokens":0}"#
            } else { body = #"{"anonymizedText":"סיכום מוגן לבדיקה"}"# }
        } else if path.hasSuffix("Sessions") && request.httpMethod == "POST" {
            count("insert")
            if ProcessInfo.processInfo.arguments.contains("-SummaryNeverReached") {
                // A transport failure before simulated server execution.
                client?.urlProtocol(self, didFailWithError: URLError(.timedOut)); return
            }
            count("committed")
            if ProcessInfo.processInfo.arguments.contains("-SummaryUncertainSave") && UserDefaults.standard.integer(forKey: "summary-fixture.insert") == 1 {
                client?.urlProtocol(self, didFailWithError: URLError(.timedOut)); return
            }
            body = #"{"id":987654322}"#
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
            headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
#endif
