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
            questionnairesForPatient: { _ in nil },
            hasPreparation: { _ in false },
            hasCompletedDemoTour: false
        )
        #expect(progress.completedCount == 0)
        #expect(!progress.isComplete)
        #expect(!progress.hasPatient)
    }

    @Test func realPatientsDoNotCountTowardTutorialSteps() {
        let patient = Patient(id: .integer(1), firstName: "A", lastName: "B")
        let progress = GettingStartedProgress.evaluate(
            patients: [patient],
            questionnairesForPatient: { _ in [] },
            hasPreparation: { _ in false },
            hasCompletedDemoTour: false
        )
        #expect(!progress.hasPatient)
        #expect(progress.completedCount == 0)
    }

    @Test func showcaseDemoPatientsDoNotCompleteAddPatientStep() {
        let demo = Patient(id: .text("demo-1"), firstName: "Demo", lastName: "One")
        demo.formulation = PatientFormulation(
            treatmentGoal: "goal",
            coreBelief: nil,
            keyAutomaticThoughts: [],
            maintainingBehaviors: [],
            keyCBTCycle: nil,
            therapistHypothesis: nil
        )
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
            },
            hasPreparation: { _ in true },
            hasCompletedDemoTour: true
        )
        #expect(progress.hasCompletedDemoTour)
        #expect(!progress.hasPatient)
        #expect(progress.completedCount == 1)
    }

    @Test func userAddedDemoPatientCountsForTutorial() {
        let patient = Patient(id: .text("demo-user-1"), firstName: "A", lastName: "B")
        patient.formulation = PatientFormulation(
            treatmentGoal: "הפחתת חרדה",
            coreBelief: nil,
            keyAutomaticThoughts: [],
            maintainingBehaviors: [],
            keyCBTCycle: nil,
            therapistHypothesis: nil
        )
        let session = Session(notes: "")
        patient.sessions = [session]

        let progress = GettingStartedProgress.evaluate(
            patients: [patient],
            questionnairesForPatient: { _ in [] },
            hasPreparation: { _ in false },
            hasCompletedDemoTour: true
        )
        #expect(progress.hasCompletedDemoTour)
        #expect(progress.hasPatient)
        #expect(progress.hasTreatmentGoal)
        #expect(progress.hasSession)
        #expect(!progress.hasSessionSummary)
        #expect(progress.completedCount == 4)
    }

    @Test func completedChecklistRequiresAllTutorialSignals() {
        let patient = Patient(id: .text("demo-user-99"), firstName: "A", lastName: "B")
        patient.formulation = PatientFormulation(
            treatmentGoal: "מטרה",
            coreBelief: nil,
            keyAutomaticThoughts: [],
            maintainingBehaviors: [],
            keyCBTCycle: nil,
            therapistHypothesis: nil
        )
        let session = Session(notes: "סיכום מפגש")
        session.databaseID = .text("demo-user-99-s1")
        patient.sessions = [session]

        let questionnaire = CompletedQuestionnaire(
            databaseID: .text("demo-user-99-q1"),
            sessionID: session.databaseID,
            answeredDate: .now,
            questionnaire: CombinedMoodQuestionnaire()
        )

        let progress = GettingStartedProgress.evaluate(
            patients: [patient],
            questionnairesForPatient: { _ in [questionnaire] },
            hasPreparation: { $0 == patient.id },
            hasCompletedDemoTour: true
        )
        #expect(progress.isComplete)
        #expect(progress.completedCount == 7)
    }

    @Test func summaryAcceptsStructuredNotesWithoutFreeText() {
        let patient = Patient(id: .integer(1))
        let session = Session(notes: "   ")
        // structuredNotes nil → no summary; nonempty notes → summary
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
