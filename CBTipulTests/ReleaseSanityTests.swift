import Foundation
import Testing
@testable import CBTipul

/// Offline release sanity: populated sample mode, edits, and restoration.
@MainActor
struct ReleaseSanityTests {

    private func makeStore() -> PatientStore {
        PatientStore(client: AuthManager().client) { $0 }
    }

    private func clearDemoDisk() {
        DemoClinicStore.clearAll()
    }

    @Test func demoClinicCRUDAndShowcaseLoadOffline() async throws {
        await EntitlementTestIsolation.acquire()
        defer { EntitlementTestIsolation.release() }
        clearDemoDisk()
        defer { clearDemoDisk() }

        let store = makeStore()
        store.enterDemoMode()

        #expect(store.isDemoMode)
        #expect(store.showcaseDataLoaded)
        let sampleCount = store.patients.count
        #expect(sampleCount == DemoData.showcaseIDValues.count)
        #expect(store.patients.allSatisfy { !$0.sessions.isEmpty })

        try await store.addPatient(firstName: "Dana", lastName: "Demo")
        #expect(store.patients.count == sampleCount + 1)

        let patient = try #require(store.patients.first { DemoData.isTutorialPatientID($0.id) })
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

        let sample = try #require(showcase.first)
        sample.notes = "Saved sample edit"
        try await store.updatePatientNotes(sample)
        let removedSample = try #require(showcase.last)
        try await store.deletePatient(removedSample)

        // A fresh store restores both sample edits and user-created demo records.
        let restored = makeStore()
        restored.enterDemoMode()
        #expect(restored.patients.first { $0.id == sample.id }?.notes == "Saved sample edit")
        #expect(!restored.patients.contains { $0.id == removedSample.id })
        let restoredPatient = try #require(restored.patients.first { $0.id == patient.id })
        #expect(restoredPatient.sessions.first?.notes == "updated session notes")
        #expect(restored.cachedQuestionnaires(for: restoredPatient)?.count == 1)
        let restoredCount = restored.patients.count
        restored.enterDemoMode()
        restored.loadShowcaseDemoData()
        #expect(restored.patients.count == restoredCount)

        // Leaving sample mode must preserve its disk snapshot for the next visit.
        await restored.exitDemoMode()
        #expect(!restored.isDemoMode)
        #expect(!restored.patients.contains { DemoData.isDemoID($0.id) })
        #expect(DemoClinicStore.loadClinic()?.includesSampleData == true)
        restored.enterDemoMode()
        #expect(restored.patients.count == restoredCount)
        #expect(restored.patients.first { $0.id == sample.id }?.notes == "Saved sample edit")

        // Old tutorial snapshots gain samples without losing the therapist's work.
        var legacy = try #require(DemoClinicStore.loadClinic())
        legacy.includesSampleData = nil
        legacy.patients.removeAll { DemoData.isShowcaseID($0.id) }
        legacy.questionnairesByPatient = legacy.questionnairesByPatient.filter {
            !DemoData.isShowcaseID(.text($0.key))
        }
        DemoClinicStore.saveClinic(legacy)
        let migrated = makeStore()
        migrated.enterDemoMode()
        #expect(migrated.patients.count == sampleCount + 1)
        #expect(migrated.patients.first { $0.id == patient.id }?.sessions.first?.notes == "updated session notes")
        #expect(migrated.showcaseDataLoaded)
    }
}
