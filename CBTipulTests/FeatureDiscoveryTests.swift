import Foundation
import Testing
@testable import CBTipul

@MainActor struct FeatureDiscoveryTests {
    @Test func accountFlagsAreIndependentAndPersist() {
        let name = "discovery-test-" + UUID().uuidString
        let prefs = UserDefaults(suiteName: name)!
        defer { prefs.removePersistentDomain(forName: name) }
        let state = FeatureDiscovery(defaults: prefs)
        state.mark("voice", account: "ACCOUNT-A")
        #expect(state.seen("voice", account: "account-a"))
        #expect(!state.seen("web", account: "account-a"))
        #expect(!state.seen("voice", account: "account-b"))
        #expect(FeatureDiscovery(defaults: prefs).seen("voice", account: "account-a"))
    }
    @Test func queueDoesNotConsumeBeforeDisplayOrStack() {
        let prefs = UserDefaults(suiteName: UUID().uuidString)!
        let state = FeatureDiscovery(defaults: prefs)
        let first = UUID()
        state.requestWeb(account: "a", patient: .text("p"), session: first, demo: true)
        #expect(state.web == nil)
        state.requestWeb(account: nil, patient: .text("p"), session: first, demo: false)
        #expect(state.web == nil)
        state.requestWeb(account: "a", patient: .text("p"), session: first, demo: false)
        state.requestWeb(account: "a", patient: .text("other"), session: UUID(), demo: false)
        #expect(state.web?.session == first)
        #expect(!state.seen("web", account: "a"))
        state.clear()
        #expect(state.web == nil)
        state.mark("web", account: "a")
        state.requestWeb(account: "a", patient: .text("p"), session: first, demo: false)
        #expect(state.web == nil)
    }
    @Test func actualTypingOnly() {
        #expect(DiscoveryRules.voice(userEdit: true, nonempty: true, therapist: true, demo: false, seen: false))
        #expect(!DiscoveryRules.voice(userEdit: false, nonempty: true, therapist: true, demo: false, seen: false))
        #expect(!DiscoveryRules.voice(userEdit: true, nonempty: true, therapist: false, demo: false, seen: false))
        #expect(!DiscoveryRules.voice(userEdit: true, nonempty: true, therapist: true, demo: true, seen: false))
        #expect(!DiscoveryRules.voice(userEdit: true, nonempty: true, therapist: true, demo: false, seen: true))
    }
    @Test func feedbackAndModalPriority() {
        for busy in [false,true] { for feedback in [false,true] { for modal in [false,true] { for valid in [false,true] {
            #expect(DiscoveryRules.present(pending: true, busy: busy, feedback: feedback, obstructed: modal, valid: valid) == (!busy && !feedback && !modal && valid))
        } } } }
        #expect(DiscoveryCopy.url == "https://cbtipul.com/app")
    }
    @Test func diaryMilestonesTakePriorityAndUseActualSessionTypes() {
        #expect(DiscoveryRules.sessionMilestone(type: .diaryOne, matchingCount: 1, total: 2) == .diaryOne)
        #expect(DiscoveryRules.sessionMilestone(type: .diaryTwo, matchingCount: 1, total: 2) == .diaryTwo)
        #expect(DiscoveryRules.sessionMilestone(type: .intake, matchingCount: 1, total: 2) == .secondSession)
        #expect(DiscoveryRules.sessionMilestone(type: .diaryOne, matchingCount: 2, total: 2) == .secondSession)
        #expect(DiscoveryRules.sessionMilestone(type: .diaryTwo, matchingCount: 2, total: 3) == nil)
        #expect(DiscoveryRules.sessionMilestone(type: nil, matchingCount: 1, total: 1) == nil)
    }
    @Test func connectionAndActivityMustBeKnown() {
        #expect(DiscoveryRules.suggestion(connected: false, enabled: nil) == true)
        #expect(DiscoveryRules.suggestion(connected: true, enabled: false) == false)
        #expect(DiscoveryRules.suggestion(connected: true, enabled: true) == nil)
        #expect(DiscoveryRules.suggestion(connected: true, enabled: nil) == nil)
        #expect(DiscoveryRules.suggestion(connected: nil, enabled: false) == nil)
    }
    @Test func diaryPathsShareOneFlagButPatientsAccountsAndDiariesDoNot() {
        let name = "milestone-test-" + UUID().uuidString
        let prefs = UserDefaults(suiteName: name)!
        defer { prefs.removePersistentDomain(forName: name) }
        let state = FeatureDiscovery(defaults: prefs)
        let patient = DatabaseID.text("patient-a")
        let key = state.patientFeature(FeatureDiscovery.Milestone.diaryOne.rawValue, patient: patient)
        #expect(!state.seen(key, account: "a"))
        state.mark(key, account: "a") // Called at presentation, independent of creation path.
        #expect(FeatureDiscovery(defaults: prefs).seen(key, account: "A"))
        #expect(!state.seen(key, account: "b"))
        #expect(!state.seen(state.patientFeature("diaryOne", patient: .text("patient-b")), account: "a"))
        #expect(!state.seen(state.patientFeature("diaryTwo", patient: patient), account: "a"))
        #expect(!state.seen(state.patientFeature("recentVisit", patient: patient), account: "a"))
    }

    @Test func visitsArePerPatientAndAccountAndPersistAcrossNewViews() {
        let name = "visits-" + UUID().uuidString
        let prefs = UserDefaults(suiteName: name)!
        defer { prefs.removePersistentDomain(forName: name) }
        let state = FeatureDiscovery(defaults: prefs)
        #expect(!state.beginPatientVisit(account: "a", patient: .text("p")))
        #expect(!state.beginPatientVisit(account: "a", patient: .text("q")))
        #expect(!state.beginPatientVisit(account: "b", patient: .text("p")))
        #expect(FeatureDiscovery(defaults: prefs).beginPatientVisit(account: "A", patient: .text("p")))
    }

    @Test func creationPathsShareMilestonesOnlyPresentationConsumesAndNoStacking() {
        let name = "creation-paths-" + UUID().uuidString
        let prefs = UserDefaults(suiteName: name)!
        defer { prefs.removePersistentDomain(forName: name) }
        for kind in [FeatureDiscovery.Milestone.diaryOne, .diaryTwo] {
            for entryFirst in [true, false] {
                let state = FeatureDiscovery(defaults: prefs, therapist: { true })
                let patient = Patient(id: .text(UUID().uuidString))
                let session = Session(type: kind == .diaryOne ? .diaryOne : .diaryTwo)
                patient.sessions = [Session(type: .intake), session]
                if entryFirst {
                    state.requestMilestone(kind, account: "a", patient: patient.id, entry: UUID(), demo: false)
                } else { state.sessionCreated(session, patient: patient, account: "a", demo: false) }
                #expect(state.milestone?.milestone == kind)
                let feature = state.patientFeature(kind.rawValue, patient: patient.id)
                #expect(!state.seen(feature, account: "a"))
                state.requestMilestone(.secondSession, account: "a", patient: patient.id, demo: false)
                #expect(state.milestone?.milestone == kind)
                state.mark(feature, account: "a") // Simulate the real sheet's onAppear.
                state.milestone = nil
                if entryFirst { state.sessionCreated(session, patient: patient, account: "a", demo: false) }
                else { state.requestMilestone(kind, account: "a", patient: patient.id, entry: UUID(), demo: false) }
                #expect(state.milestone == nil)
            }
        }
    }
    @Test func demoPatientModeAndRepeatedCompletedCreatesCannotPrompt() {
        let name = "creation-gates-" + UUID().uuidString
        let prefs = UserDefaults(suiteName: name)!
        defer { prefs.removePersistentDomain(forName: name) }
        let patient = Patient(id: .text(UUID().uuidString))
        let session = Session(type: .intake)
        patient.sessions = [Session(), session]
        let state = FeatureDiscovery(defaults: prefs, therapist: { true })
        state.sessionCreated(session, patient: patient, account: "a", demo: true)
        #expect(state.milestone == nil)
        let patientMode = FeatureDiscovery(defaults: prefs, therapist: { false })
        patientMode.sessionCreated(session, patient: patient, account: "a", demo: false)
        #expect(patientMode.milestone == nil)
        state.sessionCreated(session, patient: patient, account: "a", demo: false)
        #expect(state.milestone?.milestone == .secondSession)
        state.milestone = nil // State was unavailable: skip without consuming the preference.
        state.sessionCreated(session, patient: patient, account: "a", demo: false)
        #expect(state.milestone == nil)
        #expect(!state.seen(state.patientFeature("secondSession", patient: patient.id), account: "a"))
    }

}
