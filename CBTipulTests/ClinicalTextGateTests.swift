import Testing
@testable import CBTipul

/// Records every text a mocked anonymizer was asked to process. The tests
/// run on the main actor, so unsynchronized access is safe.
private final class MockAnonymizer: @unchecked Sendable {
    var receivedTexts: [String] = []
    var failsOn: Set<String> = []

    /// The mocked replacement is clearly distinguishable from the input.
    func anonymize(_ text: String) async throws -> String {
        receivedTexts.append(text)
        if failsOn.contains(text) { throw ClinicalTextAnonymizerError.anonymizationFailed }
        return "ANON<\(text)>"
    }

    @MainActor
    func makeGate() -> ClinicalTextGate {
        ClinicalTextGate { try await self.anonymize($0) }
    }
}

/// The gate is the single choke point every patient-related free text passes
/// before `PatientStore` uploads it, so these tests cover the saving rules.
@MainActor
struct ClinicalTextGateTests {

    @Test func successfulAnonymizationReturnsOnlyTheAnonymizedText() async throws {
        let mock = MockAnonymizer()
        let gate = mock.makeGate()

        let prepared = try await gate.prepare("note naming the patient")

        // What the store persists is the function's output, never the input.
        #expect(prepared == "ANON<note naming the patient>")
        #expect(mock.receivedTexts == ["note naming the patient"])
    }

    @Test func inputIsTrimmedBeforeAnonymization() async throws {
        let mock = MockAnonymizer()
        let gate = mock.makeGate()

        let prepared = try await gate.prepare("  note  \n")

        #expect(prepared == "ANON<note>")
        #expect(mock.receivedTexts == ["note"])
    }

    @Test func failurePreventsProducingAValueToSave() async throws {
        let mock = MockAnonymizer()
        mock.failsOn = ["sensitive"]
        let gate = mock.makeGate()

        // The store only builds its insert/update records from the gate's
        // return value, so a throw here means nothing can be uploaded.
        await #expect(throws: ClinicalTextAnonymizerError.self) {
            try await gate.prepare("sensitive")
        }
    }

    @Test func multipleNotesKeepTheirQuestionIndices() async throws {
        let mock = MockAnonymizer()
        let gate = mock.makeGate()

        let prepared = try await gate.prepare(notes: ["first", "", "third"])

        // Each note is anonymized separately and stays at its own index.
        #expect(prepared == ["ANON<first>", "", "ANON<third>"])
        #expect(mock.receivedTexts == ["first", "third"])
    }

    @Test func emptyFieldsDoNotInvokeTheFunction() async throws {
        let mock = MockAnonymizer()
        let gate = mock.makeGate()

        let prepared = try await gate.prepare("   \n ")

        #expect(prepared == nil)
        #expect(mock.receivedTexts.isEmpty)
    }

    @Test func unchangedTextLoadedFromSupabaseIsNotReprocessed() async throws {
        let mock = MockAnonymizer()
        let gate = mock.makeGate()
        gate.markSafe("already stored note")

        let prepared = try await gate.prepare("already stored note")

        #expect(prepared == "already stored note")
        #expect(mock.receivedTexts.isEmpty)
    }

    @Test func repeatedSavesOfASavedValueDoNotRepeatRequests() async throws {
        let mock = MockAnonymizer()
        let gate = mock.makeGate()

        // First save anonymizes; the store then keeps the returned value as
        // the field's new content, exactly like a successful upload does.
        let first = try await gate.prepare("fresh note")
        #expect(first == "ANON<fresh note>")

        // Saving again with the stored value must not call the function.
        let second = try await gate.prepare(first ?? "")
        #expect(second == first)
        #expect(mock.receivedTexts == ["fresh note"])
    }

    @Test func oneFailingFieldAbortsBeforeRemainingFieldsAreSent() async throws {
        let mock = MockAnonymizer()
        mock.failsOn = ["second"]
        let gate = mock.makeGate()

        await #expect(throws: ClinicalTextAnonymizerError.self) {
            _ = try await gate.prepare(notes: ["first", "second", "third"])
        }
        // The failure propagates immediately: no value is produced for the
        // record, so the store's single upsert never happens — no partial
        // save — and later fields were never sent anywhere.
        #expect(mock.receivedTexts == ["first", "second"])
    }
}
