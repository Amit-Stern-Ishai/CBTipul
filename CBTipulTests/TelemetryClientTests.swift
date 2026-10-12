import Foundation
import Testing
import Supabase
@testable import CBTipul

nonisolated private func safeMetadata() -> TelemetryMetadata {
    TelemetryMetadata(platform: "ios", deviceModel: "unknown", manufacturer: nil, osVersion: "unknown", apiLevel: nil,
        appVersion: "unknown", build: "unknown", buildChannel: "release", distribution: "unknown",
        role: .unknown, network: .unknown, lifecycle: .unknown, locale: "unknown", timezone: "unknown")
}
nonisolated final class RecordingCapture: TelemetryCapture, @unchecked Sendable {
    private let lock = NSLock()
    private var captured: [TelemetryEvent] = []
    private var resets = 0
    var events: [TelemetryEvent] { lock.lock(); defer { lock.unlock() }; return captured }
    var resetCount: Int { lock.lock(); defer { lock.unlock() }; return resets }
    func capture(_ event: TelemetryEvent) { lock.lock(); defer { lock.unlock() }; captured.append(event) }
    func reset() { lock.lock(); defer { lock.unlock() }; resets += 1 }
}
struct TelemetryClientTests {
    @Test func typedPrivacyAndInvalidFields() {
        let recorder=RecordingCapture();let c=TelemetryClient(metadata:safeMetadata,capture:recorder)
        c.operation(.access,form:.diaryOne).event(.succeeded,access:.readOnly)
        c.operation(.submission).event(.succeeded)
        #expect(recorder.events.isEmpty)
        c.operation(.access).event(.failed,error:.unresolved)
        #expect(recorder.events.count==1);#expect(recorder.events[0].access==nil)
    }
    @Test func timestampCorrelationAndMonotonicDuration() {
        final class Clock: @unchecked Sendable {var time:TimeInterval=0}
        let clock=Clock();let recorder=RecordingCapture()
        let c=TelemetryClient(metadata:safeMetadata,capture:recorder,wall:{Date(timeIntervalSince1970:10)},monotonic:{clock.time})
        let op=c.begin(.access);clock.time=0.075;op.event(.succeeded,access:.full)
        #expect(recorder.events.last?.durationMs==75)
        #expect(recorder.events.allSatisfy {$0.timestamp==Date(timeIntervalSince1970:10) && $0.correlationID==op.correlation})
    }
    @Test func restorationResetAndAlreadyCapturedMetadata() {
        let recorder=RecordingCapture();let c=TelemetryClient(metadata:safeMetadata,capture:recorder)
        c.setOwner("private-a",role:.therapist);#expect(recorder.resetCount==0)
        let old=c.begin(.access);let captured=recorder.events[0]
        c.setOwner("private-a",role:.therapist);#expect(recorder.resetCount==0)
        c.setOwner(nil,role:.unknown);c.setOwner("private-b",role:.patient)
        #expect(recorder.resetCount==2)
        old.event(.succeeded,access:.full);#expect(recorder.events.count==1)
        old.rebound().event(.succeeded,access:.full);#expect(recorder.events.last?.metadata.role == .patient)
        #expect(recorder.events[0].timestamp==captured.timestamp);#expect(recorder.events[0].metadata.role == .therapist)
        c.setOwner("private-b",role:.therapist);#expect(recorder.resetCount==3)
        let encoded=(try? JSONEncoder().encode(recorder.events)).flatMap {String(data:$0,encoding:.utf8)} ?? ""
        #expect(!encoded.contains("private-a"));#expect(!encoded.contains("private-b"))
    }
    @MainActor @Test func businessResultsErrorsAndCancellationAreIndependentOfTelemetry() async throws {
        let recorder=RecordingCapture(); let c=TelemetryClient(metadata:safeMetadata,capture:recorder)
        
        let value = try await TelemetryMeasure.run(.submission,form:.diaryOne,client:c) { 42 }
        #expect(value==42)
        final class BusinessFailure: Error {}
        let failure=BusinessFailure()
        do { _ = try await TelemetryMeasure.run(.submission,form:.questionnaire,client:c) { () -> Int in throw failure };Issue.record("expected failure") }
        catch { #expect((error as? BusinessFailure) === failure) }
        do { _ = try await TelemetryMeasure.run(.authentication,method:.google,client:c) { () -> Int in throw CancellationError() };Issue.record("expected cancellation") }
        catch { #expect(error is CancellationError) }
        #expect(recorder.events.contains {$0.stage == .cancelled})
    }
    @MainActor @Test func invitationPreviewConfirmedSwitchFailureRetryAndCancellation() async {
        let recorder=RecordingCapture(); let c=TelemetryClient(metadata:safeMetadata,capture:recorder);c.setOwner("therapist-local-only",role:.therapist)
        let flow=PatientInvitationFlow(telemetry:c)
        flow.receive(token:"secret-invitation-token",start:.cold)
        await flow.loadPreview(using:{_ in PatientInvitationPreview(status:.valid,therapistDisplayName:"private therapist name",expiresAt:nil)})
        #expect(recorder.events.contains {$0.stage == .previewShown})
        let correlation=recorder.events.first!.correlationID
        flow.continueToConsent()
        var session: InvitationSession? = InvitationSession(userID:"therapist-local-only",isAnonymous:false)
        let patientID=UUID();var failures=1;var claims=0
        let d=InvitationActivationDependencies(awaitInitialization:{},session:{session},signOutLocally:{_ in session=nil;c.setOwner(nil,role:.unknown)},signInAnonymously:{session=InvitationSession(userID:"private-patient",isAnonymous:true);c.setOwner("private-patient",role:.patient)},clearContext:{},context:{AppContext(version:1,role:.patient,activation:.active,patientId:patientID)},claim:{_ in claims+=1;if failures>0 {failures-=1;throw PatientInvitationClaimError.failed};return patientID})
        await flow.activate(using:d);#expect(flow.phase == .confirmTherapistSwitch)
        await flow.confirmTherapistSwitch(using:d);#expect(recorder.events.contains {$0.stage == .failed})
        #expect(recorder.events.contains {$0.stage == .roleSwitchConfirmed && $0.previousRole == .therapist})
        // Backend mocked active context cannot be silently rebound on retry; preserve identity.
        await flow.activate(using:d);#expect(claims==1)
        flow.dismiss();#expect(recorder.events.contains {$0.stage == .cancelled})
        #expect(recorder.events.allSatisfy {$0.correlationID == correlation})
        let encoded=(try? JSONEncoder().encode(recorder.events)).flatMap {String(data:$0,encoding:.utf8)} ?? ""
        for secret in ["secret-invitation-token","private therapist name","private-patient",patientID.uuidString] { #expect(!encoded.contains(secret)) }
        let warm=PatientInvitationFlow(telemetry:c);warm.receive(token:"another-secret",start:.warm)
        #expect(recorder.events.contains { $0.flow == .invitation && $0.start == .warm })
    }
    @MainActor @Test func accessResolutionMissingFullAndReadOnlyOutcomes() async throws {
        // Service uses the no-op shared client; fixture identity never reaches an endpoint.
        let recorder=RecordingCapture(); let c=TelemetryClient(metadata:safeMetadata,capture:recorder)
        let service=AppContextService(identity:{"fixture-only"},request:{AppContext(version:1,role:.therapist,activation:nil,patientId:nil,entitlement:AppEntitlement(access:.readOnly))},telemetry:c)
        _ = try await service.getCurrentAppContext()
        #expect(recorder.events.contains {$0.flow == .access && $0.access == .readOnly})
        let missing=AppContextService(identity:{"fixture-only"},request:{AppContext(version:1,role:.therapist,activation:nil,patientId:nil)},telemetry:c)
        _ = try await missing.getCurrentAppContext()
        #expect(recorder.events.contains {$0.flow == .access && $0.error == .unresolved && $0.access == nil})
    }
    @MainActor @Test func requestStatusIsSafeAndCorrelationMatchesSubmission() async {
        let recorder=RecordingCapture(); let c=TelemetryClient(metadata:safeMetadata,capture:recorder)
        let parent=c.begin(.submission,form:.questionnaire)
        let failure=FunctionsError.httpError(code:403,data:Data("private clinical server response".utf8))
        do {
            _ = try await TelemetryScope.$operation.withValue(parent) {
                try await TelemetryRequests.run(.questionnaireSubmit) { () -> Int in throw failure }
            }
            Issue.record("expected failure")
        } catch {}
        #expect(recorder.events.contains {$0.request == .questionnaireSubmit && $0.httpStatus == 403 && $0.error == .forbidden})
        #expect(recorder.events.allSatisfy {$0.correlationID == parent.correlation})
        let data=try? JSONEncoder().encode(recorder.events)
        #expect(!(String(data:data ?? Data(),encoding:.utf8) ?? "").contains("private clinical server response"))
    }
}
