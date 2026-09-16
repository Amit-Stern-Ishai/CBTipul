import Foundation
import Testing
@testable import CBTipul

@MainActor
struct OnboardingStoreTests {

    private func makeStore() -> (OnboardingStore, UserDefaults) {
        let suite = "OnboardingStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (OnboardingStore(defaults: defaults), defaults)
    }

    @Test func newUserWithNoDataShowsWelcomeAndChecklist() {
        let (store, _) = makeStore()
        store.setActiveUser(id: "user-a")

        #expect(!store.welcomeDismissed)
        #expect(!store.checklistDismissed)
    }

    @Test func dismissingWelcomePersistsPerUser() {
        let (store, _) = makeStore()
        store.setActiveUser(id: "user-a")
        store.dismissWelcome()

        #expect(store.welcomeDismissed)

        store.setActiveUser(id: "user-b")
        #expect(!store.welcomeDismissed)

        store.setActiveUser(id: "user-a")
        #expect(store.welcomeDismissed)
    }

    @Test func dismissingChecklistCanBeRestored() {
        let (store, _) = makeStore()
        store.setActiveUser(id: "user-a")
        store.dismissChecklist()
        #expect(store.checklistDismissed)

        store.showChecklistAgain()
        #expect(!store.checklistDismissed)
    }

    @Test func switchingUsersDoesNotLeakOnboardingState() {
        let (store, _) = makeStore()
        store.setActiveUser(id: "user-a")
        store.dismissWelcome()
        store.dismissChecklist()
        store.markFirstPreparationTipSeen()

        store.setActiveUser(id: "user-b")
        #expect(!store.welcomeDismissed)
        #expect(!store.checklistDismissed)
        #expect(!store.hasSeenFirstPreparationTip)
    }

    @Test func clearPersistedStateRemovesActiveUserKeys() {
        let (store, defaults) = makeStore()
        store.setActiveUser(id: "user-a")
        store.dismissWelcome()
        store.dismissChecklist()
        store.markFirstQuestionnaireTipSeen()

        store.clearPersistedState(for: "user-a")

        #expect(!store.welcomeDismissed)
        #expect(!store.checklistDismissed)
        #expect(!store.hasSeenFirstQuestionnaireTip)
        #expect(defaults.object(forKey: OnboardingStore.welcomeKey(for: "user-a")) == nil)
    }

    @Test func clearPersistedStateWorksAfterSignOut() {
        let (store, defaults) = makeStore()
        store.setActiveUser(id: "user-a")
        store.dismissWelcome()
        store.setActiveUser(id: nil)

        store.clearPersistedState(for: "user-a")

        #expect(defaults.object(forKey: OnboardingStore.welcomeKey(for: "user-a")) == nil)
        store.setActiveUser(id: "user-a")
        #expect(!store.welcomeDismissed)
    }

    @Test func signOutClearsInMemoryFlagsWithoutWritingOtherUsers() {
        let (store, _) = makeStore()
        store.setActiveUser(id: "user-a")
        store.dismissWelcome()

        store.setActiveUser(id: nil)
        #expect(!store.welcomeDismissed)

        store.setActiveUser(id: "user-a")
        #expect(store.welcomeDismissed)
    }
}

@MainActor
struct GettingStartedProgressTests {

    @Test func newUserWithNoDataHasEmptyProgress() {
        let progress = GettingStartedProgress.evaluate(
            patients: [],
            questionnairesForPatient: { _ in nil }
        )
        #expect(progress.completedCount == 0)
        #expect(!progress.isComplete)
        #expect(!progress.hasPatient)
        #expect(progress.currentStep == .createPatient)
    }

    @Test func realPatientsDoNotCountTowardTutorialSteps() {
        let patient = Patient(id: .integer(1), firstName: "A", lastName: "B")
        let progress = GettingStartedProgress.evaluate(
            patients: [patient],
            questionnairesForPatient: { _ in [] }
        )
        #expect(!progress.hasPatient)
        #expect(progress.completedCount == 0)
    }

    @Test func showcaseDemoPatientsDoNotCompleteCreatePatientStep() {
        let demo = Patient(id: .text("demo-1"), firstName: "Demo", lastName: "One")
        demo.sessions = [Session(notes: "notes")]
        let progress = GettingStartedProgress.evaluate(
            patients: [demo],
            questionnairesForPatient: { _ in
                [CompletedQuestionnaire(
                    databaseID: .text("q"),
                    sessionID: nil,
                    answeredDate: .now,
                    questionnaire: CombinedMoodQuestionnaire()
                )]
            }
        )
        #expect(!progress.hasPatient)
        #expect(progress.completedCount == 0)
    }

    @Test func userAddedDemoPatientCountsForTutorial() {
        let patient = Patient(id: .text("demo-user-1"), firstName: "A", lastName: "B")
        let session = Session(notes: "")
        patient.sessions = [session]

        let progress = GettingStartedProgress.evaluate(
            patients: [patient],
            questionnairesForPatient: { _ in [] }
        )
        #expect(progress.hasPatient)
        #expect(progress.hasSession)
        #expect(!progress.hasSessionNotes)
        #expect(progress.completedCount == 2)
        #expect(progress.currentStep == .fillQuestionnaire)
        #expect(progress.focusPatientID == patient.id)
        #expect(!progress.isUnlocked(.recordSessionSummary))
    }

    @Test func progressFollowsFurthestTutorialPatientNotNewestEmptyOne() {
        let withSession = Patient(id: .text("demo-user-old"), firstName: "Old", lastName: "One")
        withSession.sessions = [Session(notes: "")]
        let emptyNewer = Patient(id: .text("demo-user-new"), firstName: "New", lastName: "Two")

        let progress = GettingStartedProgress.evaluate(
            patients: [withSession, emptyNewer],
            questionnairesForPatient: { _ in [] }
        )
        #expect(progress.focusPatientID == withSession.id)
        #expect(progress.hasSession)
        #expect(progress.currentStep == .fillQuestionnaire)
    }

    @Test func completedChecklistRequiresAllTutorialSignals() throws {
        let patient = Patient(id: .text("demo-user-99"), firstName: "A", lastName: "B")
        let session = Session(notes: "סיכום פגישה")
        session.databaseID = .text("demo-user-99-s1")
        let analysisJSON = Data("""
        {
          "session_summary": "סיכום",
          "key_situations": [],
          "possible_nats": [],
          "cbt_cycles": [],
          "therapist_hypotheses": [],
          "follow_up_questions": [],
          "assignments_for_next_week": []
        }
        """.utf8)
        session.structuredNotes = try JSONDecoder().decode(
            WhisperService.CBTSessionAnalysis.self,
            from: analysisJSON
        )
        patient.sessions = [session]

        let questionnaire = CompletedQuestionnaire(
            databaseID: .text("demo-user-99-q1"),
            sessionID: session.databaseID,
            answeredDate: .now,
            questionnaire: CombinedMoodQuestionnaire()
        )

        let progress = GettingStartedProgress.evaluate(
            patients: [patient],
            questionnairesForPatient: { _ in [questionnaire] }
        )
        #expect(progress.hasPatient)
        #expect(progress.hasSession)
        #expect(progress.hasQuestionnaire)
        #expect(progress.hasSessionNotes)
        #expect(progress.hasAISummary)
        #expect(progress.isComplete)
        #expect(progress.completedCount == 5)
    }

    @Test func summaryAcceptsStructuredNotesWithoutFreeText() {
        let session = Session(notes: "   ")
        #expect(!GettingStartedProgress.sessionHasSummary(session))

        session.notes = "הערות"
        #expect(GettingStartedProgress.sessionHasSummary(session))
    }

    @Test func missingPreparationActionPrefersSessionThenSummary() {
        let patient = Patient(id: .integer(1))
        #expect(GettingStartedProgress.missingPreparationAction(for: patient) == .addSession)

        patient.sessions = [Session(notes: "")]
        #expect(GettingStartedProgress.missingPreparationAction(for: patient) == .addSessionSummary)

        patient.sessions = [Session(notes: "סיכום")]
        #expect(GettingStartedProgress.missingPreparationAction(for: patient) == .addQuestionnaire)
    }
}
