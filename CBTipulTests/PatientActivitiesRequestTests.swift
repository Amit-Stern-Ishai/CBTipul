import Foundation
import Testing
@testable import CBTipul

@MainActor struct PatientActivitiesRequestTests {
    @Test func readsBeforeSendingAndRestoresPending() async {
        let request = PatientActivitiesRequest()
        var calls: [Bool] = []
        await request.run(send: false, current: { true }) { calls.append($0); return "no_request" }
        #expect(request.state == .ready)
        await request.run(send: true, current: { true }) { calls.append($0); return "pending" }
        #expect(request.state == .pending)
        await request.run(send: true, current: { true }) { calls.append($0); return "pending" }
        #expect(calls == [false, true])
        let reopened = PatientActivitiesRequest()
        await reopened.run(send: false, current: { true }) { _ in "pending" }
        #expect(reopened.state == .pending)
    }
    @Test func lostResponseReadsStatusNeverResends() async {
        let request = PatientActivitiesRequest()
        await request.run(send: false, current: { true }) { _ in "no_request" }
        var calls: [Bool] = []
        await request.run(send: true, current: { true }) { send in
            calls.append(send)
            if send { throw URLError(.timedOut) }
            return "pending"
        }
        #expect(calls == [true, false])
        #expect(request.state == .pending)
        #expect(!request.uncertain)
    }
    @Test func failedReadCannotSendAndRetryCanFindActivities() async {
        let request = PatientActivitiesRequest()
        await request.run(send: false, current: { true }) { _ in throw URLError(.notConnectedToInternet) }
        #expect(request.state == .failed)
        var sent = false
        await request.run(send: true, current: { true }) { _ in sent = true; return "pending" }
        #expect(!sent)
        await request.run(send: false, current: { true }) { _ in "activities_available" }
        #expect(request.state == .available)
    }
    @Test func staleAccountAndUnknownStatusAreNotSuccess() async {
        let request = PatientActivitiesRequest()
        var current = true
        await request.run(send: false, current: { current }) { _ in current = false; return "pending" }
        #expect(request.state != .pending)
        await request.run(send: false, current: { true }) { _ in "unexpected" }
        #expect(request.state == .failed)
    }
    @Test func uncertainAndFailedRecheckRequiresReadRetry() async {
        let request = PatientActivitiesRequest()
        await request.run(send: false, current: { true }) { _ in "no_request" }
        var calls: [Bool] = []
        await request.run(send: true, current: { true }) { send in calls.append(send); throw URLError(.timedOut) }
        #expect(calls == [true, false])
        #expect(request.state == .failed && request.uncertain)
        await request.run(send: false, current: { true }) { _ in "no_request" }
        #expect(request.state == .ready)
    }
    @Test func duplicateTapWhileInFlightDoesNotSendAgain() async {
        let request = PatientActivitiesRequest()
        await request.run(send: false, current: { true }) { _ in "no_request" }
        var duplicate = false
        await request.run(send: true, current: { true }) { _ in
            await request.run(send: true, current: { true }) { _ in duplicate = true; return "pending" }
            return "pending"
        }
        #expect(!duplicate)
    }
    @Test func pushWaitsForColdStartPatientLoadAndOpensActionsOnce() {
        let coordinator = TherapistNotificationCoordinator.shared
        coordinator.resetOnLogout()
        defer { coordinator.resetOnLogout() }
        let patient = Patient(id: .text("synthetic-patient"))
        coordinator.handlePushTap(userInfo: ["type": "patient_activities_requested", "patient_id": "synthetic-patient"])
        coordinator.processPending(patients: [])
        #expect(coordinator.consumePatientNavigation() == nil)
        coordinator.markTherapistRootReady()
        coordinator.processPending(patients: [])
        #expect(coordinator.consumePatientNavigation() == nil)
        coordinator.markPatientsLoadSettled()
        coordinator.processPending(patients: [patient])
        let destination = coordinator.consumePatientNavigation()
        #expect(destination?.patientID == patient.id)
        #expect(destination?.activitySettings == true)
        coordinator.processPending(patients: [patient])
        #expect(coordinator.consumePatientNavigation() == nil)
    }
    @Test func routesToExactPatientsActions() {
        let payload = AppNotificationPayload.from(userInfo: ["type": "patient_activities_requested", "patient_id": "synthetic-patient"])!
        #expect(NotificationRouter.destination(from: payload) == .patientDetail(patientId: "synthetic-patient"))
        #expect(NotificationInboxCopy.message(for: payload.type) == "המטופל/ת ביקשו להפעיל פעילויות")
    }
}
