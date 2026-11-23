import Foundation
import Testing
@testable import CBTipul

@MainActor struct FeatureDiscoveryTests {
    private func fixture() -> (FeatureDiscovery, URL, UserDefaults) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("discovery-tests-" + UUID().uuidString).appendingPathComponent("state.json")
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        return (FeatureDiscovery(defaults: defaults, storageURL: url, therapist: { true }), url, defaults)
    }
    @Test func allSixTypesAreOncePerAccountNotPatient() throws {
        let (state, url, prefs) = fixture()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        for feature in ["invite", "voice", "web", "secondSession", "diaryOne", "diaryTwo"] {
            state.enqueue(feature, account: "A", patient: .text("p"), demo: false)
            state.enqueue(feature, account: "A", patient: .text("q"), demo: false)
            #expect(!state.seen(feature, account: "A"))
            state.mark(feature, account: "A") // Actual prompt presentation, including Connect/dismiss.
            state.enqueue(feature, account: "a", patient: .text("third"), demo: false)
            #expect(state.pending(account: "a").allSatisfy { $0.feature != feature })
            #expect(!state.seen(feature, account: "B"))
        }
        state.clear() // Sign out: presentation clears, flags survive.
        let relaunched = FeatureDiscovery(defaults: prefs, storageURL: url, therapist: { true })
        #expect(relaunched.seen("invite", account: "a"))
        #expect(!relaunched.seen("invite", account: "b"))
        let otherDevice = FeatureDiscovery(defaults: UserDefaults(suiteName: UUID().uuidString)!, therapist: { true })
        #expect(!otherDevice.seen("invite", account: "a"))
        #expect(try url.deletingLastPathComponent().resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }
    @Test func legacyPatientFlagsCarryForwardOnlyForTheirTherapist() {
        let (state, _, prefs) = fixture()
        for kind in ["diaryOne", "diaryTwo", "secondSession"] {
            prefs.set(true, forKey: "discovery.patient.previous-patient.\(kind).a")
            #expect(state.seen(kind, account: "A"))
            #expect(state.seen(state.patientFeature(kind, patient: .text("new-patient")), account: "a"))
            #expect(!state.seen(kind, account: "b"))
        }
        prefs.set(true, forKey: "discovery.voice.a")
        #expect(state.seen("voice", account: "a"))
        #expect(!state.seen("web", account: "a"))
    }
    @Test func failedMigrationWriteKeepsLegacyFlag() throws {
        let (_, url, prefs) = fixture()
        try Data().write(to: url.deletingLastPathComponent()) // A file blocks creation of the directory.
        let legacy = "discovery.patient.p.diaryOne.a"
        prefs.set(true, forKey: legacy)
        let state = FeatureDiscovery(defaults: prefs, storageURL: url, therapist: { true })
        #expect(state.seen("diaryOne", account: "a"))
        #expect(prefs.bool(forKey: legacy))
    }
    @Test func failedSaveAndFailedLookupRemainQueuedAcrossRelaunch() {
        let (state, url, prefs) = fixture()
        state.requestWeb(account: "a", patient: .text("p"), session: UUID(), demo: false)
        state.requestMilestone(.diaryOne, account: "a", patient: .text("p"), entry: UUID(), demo: false)
        // No server save or eligibility success; neither enqueue nor mounting a host marks shown.
        state.clear()
        let relaunched = FeatureDiscovery(defaults: prefs, storageURL: url, therapist: { true })
        #expect(relaunched.pending(account: "a").map(\.feature) == ["web", "diaryOne"])
        #expect(relaunched.pending(account: "b").isEmpty)
        #expect(!relaunched.seen("diaryOne", account: "a"))
        relaunched.mark("web", account: "a")
        #expect(relaunched.pending(account: "a").map(\.feature) == ["diaryOne"])
        relaunched.mark("diaryOne", account: "a")
        #expect(relaunched.pending(account: "a").isEmpty)
    }
    @Test func twoSessionMilestonesAreIndependentAndAlreadyEnabledDiaryDoesNotDropSecondSession() {
        let (state, _, _) = fixture()
        let patient = Patient(id: .text(UUID().uuidString))
        let session = Session(type: .diaryOne)
        patient.sessions = [Session(type: .intake), session]
        state.requestWeb(account: "a", patient: patient.id, session: session.id, demo: false)
        state.sessionCreated(session, patient: patient, account: "a", demo: false)
        state.sessionCreated(session, patient: patient, account: "a", demo: false) // Resave/callback repeat.
        #expect(state.pending(account: "a").map(\.feature) == ["web", "diaryOne", "secondSession"])
        let diary = state.pending(account: "a").first { $0.feature == "diaryOne" }!
        #expect(DiscoveryRules.suggestion(connected: true, enabled: true) == nil)
        state.remove(diary) // Revalidated as already enabled.
        #expect(state.pending(account: "a").map(\.feature) == ["web", "secondSession"])
        #expect(!state.seen("diaryOne", account: "a"))
    }
    @Test func bothDiaryTriggerPathsShareAFlagAndConnectConsumesEnableVariant() {
        for kind in [FeatureDiscovery.Milestone.diaryOne, .diaryTwo] {
            let (state, _, _) = fixture()
            state.requestMilestone(kind, account: "a", patient: .text("p"), entry: UUID(), demo: false)
            state.requestMilestone(kind, account: "a", patient: .text("q"), demo: false)
            #expect(DiscoveryRules.suggestion(connected: false, enabled: nil) == true)
            state.mark(kind.rawValue, account: "a") // Connect was displayed; dismissal also consumes.
            state.requestMilestone(kind, account: "a", patient: .text("third"), demo: false)
            #expect(state.pending(account: "a").isEmpty)
        }
    }
    @Test func eligibilityAndPresentationDoNotGuessOrConsume() {
        #expect(DiscoveryRules.suggestion(connected: nil, enabled: false) == nil)
        #expect(DiscoveryRules.suggestion(connected: true, enabled: nil) == nil)
        #expect(DiscoveryRules.suggestion(connected: true, enabled: false) == false)
        for busy in [false,true] { for feedback in [false,true] { for modal in [false,true] { for valid in [false,true] {
            #expect(DiscoveryRules.present(pending: true, busy: busy, feedback: feedback, obstructed: modal, valid: valid) == (!busy && !feedback && !modal && valid))
        } } } }
        #expect(DiscoveryCopy.url == "https://cbtipul.com/app")
    }
    @Test func actualTypingOnlyAndDemoPatientModeBypass() {
        #expect(DiscoveryRules.voice(userEdit: true, nonempty: true, therapist: true, demo: false, seen: false))
        #expect(!DiscoveryRules.voice(userEdit: false, nonempty: true, therapist: true, demo: false, seen: false))
        #expect(!DiscoveryRules.voice(userEdit: true, nonempty: true, therapist: false, demo: false, seen: false))
        #expect(!DiscoveryRules.voice(userEdit: true, nonempty: true, therapist: true, demo: true, seen: false))
        let (state, _, _) = fixture()
        state.enqueue("invite", account: "a", patient: .text("p"), demo: true)
        #expect(state.pending(account: "a").isEmpty)
        let patientMode = FeatureDiscovery(defaults: UserDefaults(suiteName: UUID().uuidString)!, therapist: { false })
        patientMode.requestWeb(account: "a", patient: .text("p"), session: UUID(), demo: false)
        #expect(patientMode.pending(account: "a").isEmpty)
    }
    @Test func failedEligibilityRetriesSameIntentWithoutConsumingIt() async throws {
        let (state, _, _) = fixture()
        state.requestMilestone(.diaryOne, account: "a", patient: .text("p"), entry: UUID(), demo: false)
        let intent = state.pending(account: "a")[0]
        var attempts = 0
        func connection() throws -> Bool {
            attempts += 1
            if attempts == 1 { throw URLError(.notConnectedToInternet) }
            return true
        }
        do {
            _ = try await DiscoveryRules.resolve(intent, firstEntry: { true }, sessionExists: { true }, connected: { try connection() }, enabled: { _ in false })
            Issue.record("Expected lookup failure")
        } catch { }
        #expect(state.pending(account: "a")[0].id == intent.id)
        #expect(!state.seen("diaryOne", account: "a"))
        let result = try await DiscoveryRules.resolve(intent, firstEntry: { true }, sessionExists: { true }, connected: { try connection() }, enabled: { kind in
            #expect(kind == .diaryOne); return false
        })
        #expect(result == false)
        #expect(attempts == 2)
        state.mark(intent.feature, account: intent.account)
        #expect(state.pending(account: "a").isEmpty)
    }
    @Test func failedSaveWebEligibilityDoesNotRequireSavedSessionOrConnection() async throws {
        let intent = FeatureDiscovery.Intent(account: "a", feature: "web", patient: .text("p"), session: UUID())
        let result = try await DiscoveryRules.resolve(intent, firstEntry: { false }, sessionExists: { false },
            connected: { throw URLError(.notConnectedToInternet) }, enabled: { _ in false })
        #expect(result == false)
    }
    @Test func visitsRemainPerPatientAndDoNotConsumeMilestones() {
        let (state, _, _) = fixture()
        #expect(!state.beginPatientVisit(account: "a", patient: .text("p")))
        #expect(state.beginPatientVisit(account: "A", patient: .text("p")))
        #expect(!state.beginPatientVisit(account: "a", patient: .text("q")))
        #expect(!state.beginPatientVisit(account: "b", patient: .text("p")))
        #expect(!state.seen("diaryOne", account: "a"))
    }
}

@MainActor struct DiscoveryReminderTests {
    @Test func clockRequiresNewActionAndOnlyOneReminderAcrossPatients() {
        var clock = Date(timeIntervalSince1970: 1000)
        let state = FeatureDiscovery(defaults: UserDefaults(suiteName: UUID().uuidString)!, now: { clock }, therapist: { true })
        state.enterContext("screen")
        for feature in ["invite", "voice", "web", "secondSession", "diaryOne", "diaryTwo"] {
            state.enqueue(feature, account: "a", patient: .text("p"), demo: false)
            state.presented(state.pending(account: "a").first { $0.feature == feature }!)
        }
        clock.addTimeInterval(3 * 86400 - 1)
        state.enqueue("invite", account: "a", patient: .text("q"), demo: false)
        #expect(state.pending(account: "a").isEmpty)
        clock.addTimeInterval(1)
        #expect(state.pending(account: "a").isEmpty) // Clock alone never creates an intent.
        #expect(state.eligible("invite", account: "a"))
        #expect(!state.eligible("web", account: "a"))
        clock.addTimeInterval(4 * 86400)
        for feature in ["invite", "voice", "web", "secondSession", "diaryOne", "diaryTwo"] {
            state.enqueue(feature, account: "a", patient: .text("q"), demo: false)
            let reminder = state.pending(account: "a").first { $0.feature == feature }!
            #expect(reminder.reminder == true)
            state.presented(reminder); state.presented(reminder) // Presentation callback can repeat.
            clock.addTimeInterval(8 * 86400)
            state.enqueue(feature, account: "a", patient: .text("third"), demo: false)
            #expect(!state.pending(account: "a").contains { $0.feature == feature })
        }
        #expect(state.eligible("web", account: "b"))
    }
    @Test func suppressionVoiceCompletionContextAndRelaunch() {
        var clock = Date(timeIntervalSince1970: 1000)
        let prefs = UserDefaults(suiteName: UUID().uuidString)!
        let state = FeatureDiscovery(defaults: prefs, now: { clock }, therapist: { true })
        state.enterContext("p")
        for feature in ["web", "voice", "diaryOne", "diaryTwo"] { state.mark(feature, account: "a") }
        state.suppress("web", account: "a"); state.usedVoice(account: "a")
        clock.addTimeInterval(8 * 86400)
        #expect(!state.eligible("web", account: "a")); #expect(!state.eligible("voice", account: "a"))
        state.requestMilestone(.diaryOne, account: "a", patient: .text("p"), demo: false)
        state.requestMilestone(.diaryTwo, account: "a", patient: .text("p"), demo: false)
        #expect(state.pending(account: "a").count == 2)
        state.enterContext("q")
        #expect(state.pending(account: "a").isEmpty)
        #expect(state.eligible("diaryOne", account: "a")) // No failed presentation consumed it.
        state.requestMilestone(.diaryOne, account: "a", patient: .text("q"), demo: false)
        let relaunched = FeatureDiscovery(defaults: prefs, now: { clock }, therapist: { true })
        #expect(relaunched.pending(account: "a").isEmpty)
        #expect(relaunched.eligible("diaryOne", account: "a"))
        #expect(!relaunched.eligible("voice", account: "a")); #expect(!relaunched.eligible("web", account: "a"))
    }
    @Test func legacyMigrationStartsCooldownNow() {
        var clock = Date(timeIntervalSince1970: 1000)
        let prefs = UserDefaults(suiteName: UUID().uuidString)!
        prefs.set(true, forKey: "discovery.patient.p.diaryOne.a")
        let state = FeatureDiscovery(defaults: prefs, now: { clock }, therapist: { true })
        #expect(state.seen("diaryOne", account: "a")); #expect(!state.eligible("diaryOne", account: "a"))
        clock.addTimeInterval(7 * 86400)
        #expect(state.eligible("diaryOne", account: "a"))
    }
}

@MainActor struct DiscoveryReminderHandoffTests {
    @Test func successfulSaveReturnsOnlyToKnownParent() {
        var clock = Date(timeIntervalSince1970: 1000)
        let state = FeatureDiscovery(defaults: UserDefaults(suiteName: UUID().uuidString)!, now: { clock }, therapist: { true })
        state.mark("web", account: "a"); clock.addTimeInterval(7 * 86400)
        state.enterEditor("editor", parent: "patient")
        state.requestWeb(account: "a", patient: .text("p"), session: UUID(), demo: false)
        state.returnAfterSave(); state.leaveContext("editor"); state.enterContext("patient")
        #expect(state.pending(account: "a").count == 1)
        state.enterContext("another-patient")
        #expect(state.pending(account: "a").isEmpty)
        #expect(state.eligible("web", account: "a"))
    }
    @Test func reminderRechecksConnectionAndActivityAfterLookupFailure() async throws {
        var clock = Date(timeIntervalSince1970: 1000)
        let state = FeatureDiscovery(defaults: UserDefaults(suiteName: UUID().uuidString)!, now: { clock }, therapist: { true })
        state.mark("diaryOne", account: "a"); clock.addTimeInterval(7 * 86400); state.enterContext("p")
        state.requestMilestone(.diaryOne, account: "a", patient: .text("p"), entry: UUID(), demo: false)
        let intent = state.pending(account: "a")[0]
        do { _ = try await DiscoveryRules.resolve(intent, firstEntry: { false }, sessionExists: { true }, connected: { throw CocoaError(.fileReadUnknown) }, enabled: { _ in false }); Issue.record("Expected lookup failure") } catch { }
        #expect(state.pending(account: "a").count == 1)
        let enabled = try await DiscoveryRules.resolve(intent, firstEntry: { false }, sessionExists: { true }, connected: { true }, enabled: { _ in false })
        #expect(enabled == false) // A later entry qualifies; current connection changes Connect to Enable.
        let done = try await DiscoveryRules.resolve(intent, firstEntry: { false }, sessionExists: { true }, connected: { true }, enabled: { _ in true })
        #expect(done == nil)
    }
}
