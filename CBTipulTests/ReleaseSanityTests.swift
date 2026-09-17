import Foundation
import Testing
@testable import CBTipul

/// Offline release sanity: demo clinic CRUD + showcase load without Edge Functions.
@MainActor
struct ReleaseSanityTests {

    private func makeStore() -> PatientStore {
        PatientStore(client: AuthManager().client) { $0 }
    }

    private func clearDemoDisk() {
        DemoClinicStore.clearAll()
    }

    @Test func demoClinicCRUDAndShowcaseLoadOffline() async throws {
        clearDemoDisk()
        defer { clearDemoDisk() }

        let store = makeStore()
        store.enterDemoMode()

        #expect(store.isDemoMode)
        #expect(store.patients.isEmpty)

        try await store.addPatient(firstName: "Dana", lastName: "Demo")
        #expect(store.patients.count == 1)

        let patient = try #require(store.patients.first)
        #expect(DemoData.isTutorialPatientID(patient.id))
        if case .text(let value) = patient.id {
            #expect(value.hasPrefix("demo-user-"))
        } else {
            Issue.record("Expected text demo patient id")
        }

        let session = Session(notes: "first session notes", type: .intake)
        try await store.addSession(session, for: patient)
        #expect(patient.sessions.count == 1)
        #expect(session.databaseID != nil)

        session.notes = "updated session notes"
        try await store.updateSession(session)
        #expect(patient.sessions.first?.notes == "updated session notes")

        var questionnaire = CombinedMoodQuestionnaire()
        questionnaire.gad7Answers = Array(repeating: 1, count: L10n.gad7Questions.count)
        questionnaire.phq9Answers = Array(repeating: 1, count: L10n.phq9Questions.count)
        questionnaire.interferenceLevel = 1
        try await store.saveQuestionnaire(questionnaire, for: patient, session: session)

        let saved = store.cachedQuestionnaires(for: patient) ?? []
        #expect(saved.count == 1)
        #expect(session.questionnaire.gad7Score == L10n.gad7Questions.count)

        store.loadShowcaseDemoData()
        #expect(store.showcaseDataLoaded)

        let showcase = store.patients.filter { DemoData.isShowcaseID($0.id) }
        #expect(!showcase.isEmpty)
        #expect(store.patients.contains { patient in
            if case .text(let value) = patient.id { return value == "demo-1" }
            return false
        })
        #expect(store.patients.contains { DemoData.isTutorialPatientID($0.id) })
        #expect(store.isDemoMode)
    }
}
