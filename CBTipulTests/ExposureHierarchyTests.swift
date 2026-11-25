import Supabase
import Foundation
import Testing
@testable import CBTipul
struct ExposureHierarchyTests {
 @Test func roundTripAndOrder() throws {
  let a=ExposureItem(situation:"א",difficulty:nil), b=ExposureItem(situation:"ב",difficulty:0), c=ExposureItem(situation:"ג",difficulty:90)
  let baseline=ExposureDocument(items:[c,b,a]);var draft=baseline;draft.move(a.id,to:0)
  #expect(draft.items == [a,c,b]);#expect(baseline.items == [c,b,a])
  let data=try JSONEncoder().encode(draft);#expect(try JSONDecoder().decode(ExposureDocument.self,from:data)==draft)
  let items=(try JSONSerialization.jsonObject(with:data) as! [String:Any])["items"] as! [[String:Any]]
  #expect(items[0]["difficulty"] is NSNull);#expect(items[2]["difficulty"] as? Int == 0)
 }
 @Test func validationAndRequestIdentity() throws {
  let a=ExposureItem(situation:"א");#expect(ExposureDocument().isValid);#expect(!ExposureDocument(items:[a,a]).isValid)
  for item in [ExposureItem(situation:" "),ExposureItem(situation:String(repeating:"א",count:1001)),ExposureItem(situation:"א",difficulty:101),ExposureItem(situation:"א",difficulty:-1)] {#expect(!ExposureDocument(items:[item]).isValid)}
  let body=try ExposureRequest.body(action:"save",patientID:nil,revision:nil,document:ExposureDocument(items:[a]))
  #expect(body["patient_id"] == nil);#expect(body["expected_revision"] == .null)
  #expect(try ExposureRequest.body(action:"load",patientID:"p",revision:nil,document:ExposureDocument())["patient_id"] == .string("p"))
 }
 @Test func ongoingAssignmentRecognized() {
  let row=PatientAssignment(id:UUID(),patientId:UUID(),therapistId:nil,sessionId:nil,typeValue:"exposure_hierarchy",createdAt:Date(),completedAt:Date(),cancelledAt:nil)
  #expect(row.isExposureHierarchy);#expect(row.isOpen)
 }
 @Test func nullDocumentIsNotEmptyList() throws {
  let record=try JSONDecoder().decode(ExposureRecord.self,from:Data(#"{"patient_id":"11111111-1111-4111-8111-111111111111","document":null,"revision":null,"updated_at":null}"#.utf8));#expect(record.document == nil)
 }
}
