import Foundation
import Testing
@testable import CBTipul

struct PatientDiaryOneActivationTests {
    private let assignmentID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let patientID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let therapistID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

    @Test func newActivationDecodesAssignment() throws {
        let assignment = try PatientDiaryOneActivation.assignment(fromResponseData: responseJSON(createdNew: true))
        #expect(assignment.id == assignmentID)
        #expect(assignment.patientId == patientID)
        #expect(assignment.therapistId == therapistID)
        #expect(assignment.sessionId == nil)
        #expect(assignment.type == .diaryOne)
        #expect(assignment.completedAt == nil)
        #expect(assignment.cancelledAt == nil)
        #expect(assignment.isOpen)
    }

    @Test func existingActiveCreatedNewFalseStillSucceeds() throws {
        let assignment = try PatientDiaryOneActivation.assignment(fromResponseData: responseJSON(createdNew: false))
        #expect(assignment.id == assignmentID)
        #expect(assignment.type == .diaryOne)
        #expect(assignment.isOpen)
    }

    @Test func patientNotConnectedMapsToDomainError() {
        let data = Data(#"{"error":"patient_not_connected","message":"not connected"}"#.utf8)
        #expect(PatientDiaryOneActivation.mapError(from: data, statusCode: 400) == .patientNotConnected)
    }

    @Test func diaryOneUsesEdgeFunctionNotDirectInsert() {
        #expect(PatientDiaryOneActivation.functionName == "request-patient-diary-one")
        #expect(PatientDiaryOneActivation.usesEdgeFunction(.diaryOne))
        #expect(!PatientDiaryOneActivation.usesDirectInsert(.diaryOne))
    }

    @Test func otherOngoingTypesKeepDirectInsert() {
        #expect(!PatientDiaryOneActivation.usesEdgeFunction(.diaryTwo))
        #expect(PatientDiaryOneActivation.usesDirectInsert(.diaryTwo))
        #expect(!PatientDiaryOneActivation.usesEdgeFunction(.questionnaire))
        #expect(!PatientDiaryOneActivation.usesDirectInsert(.questionnaire))
    }

    @Test func requestBodyContainsOnlyPatientId() throws {
        let data = try PatientDiaryOneActivation.requestJSON(patientId: patientID)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(object?.keys.sorted() == ["patientId"])
        #expect(object?["patientId"] as? String == patientID.uuidString)
    }

    @Test func postgrestAssignmentStillDecodesSnakeCase() throws {
        let json = Data("""
        {
          "id": "\(assignmentID.uuidString)",
          "patient_id": "\(patientID.uuidString)",
          "therapist_id": "\(therapistID.uuidString)",
          "session_id": null,
          "type": "diary_one",
          "created_at": "2026-09-22T12:34:56Z",
          "completed_at": null,
          "cancelled_at": null
        }
        """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let row = try decoder.decode(PatientAssignment.self, from: json)
        #expect(row.id == assignmentID)
        #expect(row.patientId == patientID)
        #expect(row.type == .diaryOne)
    }

    @Test func otherEdgeFailuresMapToExistingErrors() {
        #expect(
            PatientDiaryOneActivation.mapError(
                from: Data(#"{"error":"unauthorized"}"#.utf8),
                statusCode: 401
            ) == .notSignedIn
        )
        #expect(
            PatientDiaryOneActivation.mapError(
                from: Data(#"{"error":"therapist_mode_required"}"#.utf8),
                statusCode: 403
            ) == .notSignedIn
        )
        #expect(
            PatientDiaryOneActivation.mapError(
                from: Data(#"{"error":"patient_not_found"}"#.utf8),
                statusCode: 404
            ) == .invalidIdentifier
        )
        #expect(
            PatientDiaryOneActivation.mapError(
                from: Data(#"{"error":"invalid_request"}"#.utf8),
                statusCode: 400
            ) == .invalidIdentifier
        )
    }

    private func responseJSON(createdNew: Bool) -> Data {
        Data("""
        {
          "success": true,
          "assignment": {
            "id": "\(assignmentID.uuidString)",
            "patientId": "\(patientID.uuidString)",
            "therapistId": "\(therapistID.uuidString)",
            "sessionId": null,
            "type": "diary_one",
            "createdAt": "2026-09-22T12:34:56.789Z",
            "completedAt": null,
            "cancelledAt": null
          },
          "createdNew": \(createdNew)
        }
        """.utf8)
    }
}
