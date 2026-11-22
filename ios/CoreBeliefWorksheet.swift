import Foundation

/// UI/domain content shared by draft editing, reading, and the published patient copy.
/// API field names and response metadata deliberately do not live in this model.
struct CoreBeliefWorksheet: Equatable, Sendable {
    struct Belief: Equatable, Sendable {
        var text = ""
        var feelings = ""
        var now: Int? = nil
        var most: Int? = nil
        var least: Int? = nil
    }
    var oldBelief = Belief()
    var balancedBelief = Belief()
    var oldEvidence = ""
    var alternativeInterpretations = ""
    var balancedEvidence = ""
    var experiments = ""
    var finalOldRating: Int? = nil
    var finalBalancedRating: Int? = nil
}

struct CoreBeliefWorksheetRecord: Equatable, Sendable {
    let patientId: String
    let document: CoreBeliefWorksheet?
    let revision: String?
    let updatedAt: String?
    let publishedRevision: String?
    let publishedAt: String?
}

enum CoreBeliefWorksheetCodec {
    enum Failure: Error { case invalidDocument }
    static func encodeDocument(_ value: CoreBeliefWorksheet) throws -> Data {
        let dto = CoreBeliefWorksheetDTO(value)
        try dto.validate()
        return try JSONEncoder().encode(dto)
    }
    static func decodeDocument(_ data: Data) throws -> CoreBeliefWorksheet {
        let dto = try JSONDecoder().decode(CoreBeliefWorksheetDTO.self, from: data)
        try dto.validate()
        return dto.model
    }
    static func decodeRecord(_ data: Data) throws -> CoreBeliefWorksheetRecord {
        let dto = try JSONDecoder().decode(CoreBeliefWorksheetRecordDTO.self, from: data)
        try dto.document?.validate()
        return CoreBeliefWorksheetRecord(patientId: dto.patient_id, document: dto.document?.model,
            revision: dto.revision, updatedAt: dto.updated_at,
            publishedRevision: dto.published_revision, publishedAt: dto.published_at)
    }
}

/// Flat deployed 16-key document. Optional ratings are explicitly encoded as null.
private struct CoreBeliefWorksheetDTO: Codable {
    let old_belief: String
    let old_feelings: String
    let old_now: Int?
    let old_most: Int?
    let old_least: Int?
    let balanced_belief: String
    let balanced_feelings: String
    let balanced_now: Int?
    let balanced_most: Int?
    let balanced_least: Int?
    let old_evidence: String
    let alternative_interpretations: String
    let balanced_evidence: String
    let experiments: String
    let old_final: Int?
    let balanced_final: Int?
    enum CodingKeys: String, CodingKey, CaseIterable {
        case old_belief
        case old_feelings
        case old_now
        case old_most
        case old_least
        case balanced_belief
        case balanced_feelings
        case balanced_now
        case balanced_most
        case balanced_least
        case old_evidence
        case alternative_interpretations
        case balanced_evidence
        case experiments
        case old_final
        case balanced_final
    }
    init(_ value: CoreBeliefWorksheet) {
        old_belief = value.oldBelief.text
        old_feelings = value.oldBelief.feelings
        old_now = value.oldBelief.now
        old_most = value.oldBelief.most
        old_least = value.oldBelief.least
        balanced_belief = value.balancedBelief.text
        balanced_feelings = value.balancedBelief.feelings
        balanced_now = value.balancedBelief.now
        balanced_most = value.balancedBelief.most
        balanced_least = value.balancedBelief.least
        old_evidence = value.oldEvidence
        alternative_interpretations = value.alternativeInterpretations
        balanced_evidence = value.balancedEvidence
        experiments = value.experiments
        old_final = value.finalOldRating
        balanced_final = value.finalBalancedRating
    }
    init(from decoder: Decoder) throws {
        let all = try decoder.container(keyedBy: AnyKey.self)
        guard Set(all.allKeys.map(\.stringValue)) == Set(CodingKeys.allCases.map(\.rawValue)) else { throw CoreBeliefWorksheetCodec.Failure.invalidDocument }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        old_belief = try c.decode(String.self, forKey: .old_belief)
        old_feelings = try c.decode(String.self, forKey: .old_feelings)
        old_now = try c.decode(Int?.self, forKey: .old_now)
        old_most = try c.decode(Int?.self, forKey: .old_most)
        old_least = try c.decode(Int?.self, forKey: .old_least)
        balanced_belief = try c.decode(String.self, forKey: .balanced_belief)
        balanced_feelings = try c.decode(String.self, forKey: .balanced_feelings)
        balanced_now = try c.decode(Int?.self, forKey: .balanced_now)
        balanced_most = try c.decode(Int?.self, forKey: .balanced_most)
        balanced_least = try c.decode(Int?.self, forKey: .balanced_least)
        old_evidence = try c.decode(String.self, forKey: .old_evidence)
        alternative_interpretations = try c.decode(String.self, forKey: .alternative_interpretations)
        balanced_evidence = try c.decode(String.self, forKey: .balanced_evidence)
        experiments = try c.decode(String.self, forKey: .experiments)
        old_final = try c.decode(Int?.self, forKey: .old_final)
        balanced_final = try c.decode(Int?.self, forKey: .balanced_final)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(old_belief, forKey: .old_belief)
        try c.encode(old_feelings, forKey: .old_feelings)
        try c.encode(old_now, forKey: .old_now)
        try c.encode(old_most, forKey: .old_most)
        try c.encode(old_least, forKey: .old_least)
        try c.encode(balanced_belief, forKey: .balanced_belief)
        try c.encode(balanced_feelings, forKey: .balanced_feelings)
        try c.encode(balanced_now, forKey: .balanced_now)
        try c.encode(balanced_most, forKey: .balanced_most)
        try c.encode(balanced_least, forKey: .balanced_least)
        try c.encode(old_evidence, forKey: .old_evidence)
        try c.encode(alternative_interpretations, forKey: .alternative_interpretations)
        try c.encode(balanced_evidence, forKey: .balanced_evidence)
        try c.encode(experiments, forKey: .experiments)
        try c.encode(old_final, forKey: .old_final)
        try c.encode(balanced_final, forKey: .balanced_final)
    }
    var model: CoreBeliefWorksheet {
        var value = CoreBeliefWorksheet()
        value.oldBelief.text = old_belief
        value.oldBelief.feelings = old_feelings
        value.oldBelief.now = old_now
        value.oldBelief.most = old_most
        value.oldBelief.least = old_least
        value.balancedBelief.text = balanced_belief
        value.balancedBelief.feelings = balanced_feelings
        value.balancedBelief.now = balanced_now
        value.balancedBelief.most = balanced_most
        value.balancedBelief.least = balanced_least
        value.oldEvidence = old_evidence
        value.alternativeInterpretations = alternative_interpretations
        value.balancedEvidence = balanced_evidence
        value.experiments = experiments
        value.finalOldRating = old_final
        value.finalBalancedRating = balanced_final
        return value
    }
    func validate() throws {
        let texts = [old_belief, old_feelings, balanced_belief, balanced_feelings, old_evidence, alternative_interpretations, balanced_evidence, experiments]
        let ratings: [Int?] = [old_now, old_most, old_least, balanced_now, balanced_most, balanced_least, old_final, balanced_final]
        guard texts.allSatisfy({ $0.utf16.count <= 10000 }), ratings.allSatisfy({ $0 == nil || (0...100).contains($0!) }) else { throw CoreBeliefWorksheetCodec.Failure.invalidDocument }
    }
    private struct AnyKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }
}
private struct CoreBeliefWorksheetRecordDTO: Decodable {
    let patient_id: String
    let document: CoreBeliefWorksheetDTO?
    let revision: String?
    let updated_at: String?
    let published_revision: String?
    let published_at: String?
    enum CodingKeys: String, CodingKey { case patient_id, document, revision, updated_at, published_revision, published_at }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        patient_id = try c.decode(String.self, forKey: .patient_id)
        // Missing document is malformed; explicit null means no worksheet in this view.
        document = try c.decode(CoreBeliefWorksheetDTO?.self, forKey: .document)
        revision = try c.decode(String?.self, forKey: .revision)
        published_at = try c.decode(String?.self, forKey: .published_at)
        updated_at = try c.decodeIfPresent(String.self, forKey: .updated_at)
        published_revision = try c.decodeIfPresent(String.self, forKey: .published_revision)
    }
}
