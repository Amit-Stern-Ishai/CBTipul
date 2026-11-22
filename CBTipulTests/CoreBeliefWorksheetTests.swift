import Foundation
import Testing
@testable import CBTipul

struct CoreBeliefWorksheetTests {
    @Test func blankRoundTripIncludesEveryNull() throws {
        let value = CoreBeliefWorksheet()
        let data = try CoreBeliefWorksheetCodec.encodeDocument(value)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json.count == 16)
        for key in ["old_now", "old_most", "old_least", "balanced_now", "balanced_most", "balanced_least", "old_final", "balanced_final"] { #expect(json[key] is NSNull) }
        #expect(try CoreBeliefWorksheetCodec.decodeDocument(data) == value)
    }
    @Test func zeroAndMixedValuesKeepTheirMeaning() throws {
        var value = CoreBeliefWorksheet()
        value.oldBelief = .init(text: "ישן", feelings: "חשש", now: 0, most: 91, least: nil)
        value.balancedBelief = .init(text: "מאוזן", feelings: "תקווה", now: 12, most: nil, least: 0)
        value.oldEvidence = "ראיות"; value.alternativeInterpretations = "חלופה"; value.balancedEvidence = "עבר"; value.experiments = "ניסוי"
        value.finalOldRating = 0; value.finalBalancedRating = 100
        let data = try CoreBeliefWorksheetCodec.encodeDocument(value)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["old_now"] as? Int == 0); #expect(json["old_most"] as? Int == 91)
        #expect(json["balanced_now"] as? Int == 12); #expect(json["old_final"] as? Int == 0)
        #expect(json["balanced_final"] as? Int == 100); #expect(json["alternative_interpretations"] as? String == "חלופה")
        #expect(try CoreBeliefWorksheetCodec.decodeDocument(data) == value)
    }
    @Test func publishedAndAbsentDocumentsAreDistinctFromBlankDrafts() throws {
        let none = try CoreBeliefWorksheetCodec.decodeRecord(Data(#"{"patient_id":"p","document":null,"revision":null,"published_at":null}"#.utf8))
        #expect(none.document == nil); #expect(none.updatedAt == nil)
        let document = String(data: try CoreBeliefWorksheetCodec.encodeDocument(CoreBeliefWorksheet()), encoding: .utf8)!
        let payload = "{\"patient_id\":\"p\",\"document\":\(document),\"revision\":\"opaque-A\",\"published_at\":\"sent\",\"updated_at\":\"updated\",\"published_revision\":\"opaque-A\"}"
        let record = try CoreBeliefWorksheetCodec.decodeRecord(Data(payload.utf8))
        #expect(record.document == CoreBeliefWorksheet()); #expect(record.revision == "opaque-A")
        #expect(record.publishedRevision == "opaque-A"); #expect(record.updatedAt == "updated"); #expect(record.publishedAt == "sent")
        var edit = record.document!; edit.oldBelief.text = "B"
        #expect(record.document?.oldBelief.text == "")
    }
    @Test func malformedRatingsAndMissingKeysAreRejected() throws {
        let data = try CoreBeliefWorksheetCodec.encodeDocument(CoreBeliefWorksheet())
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        for invalid: Any in [-1, 101, 0.5, "0", true] {
            json["old_now"] = invalid
            let malformed = try JSONSerialization.data(withJSONObject: json)
            #expect(throws: (any Error).self) { try CoreBeliefWorksheetCodec.decodeDocument(malformed) }
        }
        json.removeValue(forKey: "old_now")
        #expect(throws: (any Error).self) { try CoreBeliefWorksheetCodec.decodeDocument(JSONSerialization.data(withJSONObject: json)) }
        var invalid = CoreBeliefWorksheet(); invalid.finalOldRating = 101
        #expect(throws: (any Error).self) { try CoreBeliefWorksheetCodec.encodeDocument(invalid) }
    }

    @Test func testRequestContractSeparatesSaveAndPublish() throws {
        var draft = CoreBeliefWorksheet(); draft.oldBelief.now = 0
        let save = try CoreBeliefRequest.body(action: "save", patientID: "patient", revision: nil, document: draft)
        let data = try JSONEncoder().encode(save)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let document = try #require(json["document"] as? [String: Any])
        #expect(document.count == 16)
        #expect(document["old_now"] as? Int == 0)
        #expect(document["old_most"] is NSNull)
        #expect(json["expected_revision"] is NSNull)
        let published = try CoreBeliefRequest.body(action: "publish", patientID: "patient", revision: "opaque", document: draft)
        #expect(published["document"] == nil)
        #expect(throws: (any Error).self) { try CoreBeliefRequest.body(action: "publish", patientID: "patient", revision: nil, document: draft) }
        let read = try CoreBeliefRequest.body(action: "load_published", patientID: "must-not-send", revision: "must-not-send", document: draft)
        #expect(read.count == 1)
    }
}
