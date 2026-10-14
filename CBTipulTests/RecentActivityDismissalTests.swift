import Foundation
import Testing
@testable import CBTipul

@MainActor
struct RecentActivityDismissalTests {
    @Test func dismissedEntriesSurviveRecreationAndNewEntriesRemainVisible() throws {
        let suite = "CBTipul.tests.recent-dismissal.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let patient = DatabaseID.text("patient-a")
        let first = RecentActivityDismissals(defaults: defaults)
        first.dismiss(["diary-one-ABC", "questionnaire-17"], owner: "therapist-a", patientID: patient)
        let recreated = RecentActivityDismissals(defaults: defaults)
        #expect(recreated.contains("diary-one-abc", owner: "therapist-a", patientID: patient))
        #expect(recreated.contains("questionnaire-17", owner: "therapist-a", patientID: patient))
        #expect(!recreated.contains("diary-one-new", owner: "therapist-a", patientID: patient))
        #expect(!recreated.contains("questionnaire-18", owner: "therapist-a", patientID: patient))
    }

    @Test func accountPatientAndDemoDismissalsStaySeparate() throws {
        let suite = "CBTipul.tests.recent-scope.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let dismissal = RecentActivityDismissals(defaults: defaults)
        dismissal.dismiss(["entry"], owner: "therapist-a", patientID: .text("patient-a"))
        #expect(!dismissal.contains("entry", owner: "therapist-b", patientID: .text("patient-a")))
        #expect(!dismissal.contains("entry", owner: "therapist-a", patientID: .text("patient-b")))
        #expect(!dismissal.contains("entry", owner: "local-demo", patientID: .text("patient-a")))
        dismissal.dismiss(["entry"], owner: "owner:patient", patientID: .text("a"))
        #expect(!dismissal.contains("entry", owner: "owner", patientID: .text("patient:a")))
    }

    @Test func missingIdentityCannotDismissAnotherAccountsActivity() throws {
        let suite = "CBTipul.tests.recent-identity.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let dismissal = RecentActivityDismissals(defaults: defaults)
        dismissal.dismiss(["entry"], owner: nil, patientID: .text("patient"))
        dismissal.dismiss(["entry"], owner: "", patientID: .text("patient"))
        #expect(!dismissal.contains("entry", owner: "therapist", patientID: .text("patient")))
        #expect(!dismissal.contains("entry", owner: nil, patientID: .text("patient")))
    }
}
