import Foundation
import Testing
@testable import CBTipul
struct ConceptSuggestionsTests {
 @Test func allSectionsIncludeUnsavedDraft() throws {
  var draft=ConceptDocument();draft.core_beliefs=["unsaved"]
  for section in ConceptSection.allCases {
   let request=ConceptSuggestionRequest(patient_id:"selected",section:section.rawValue,document:draft,patient_context:"full context")
   let json=try JSONSerialization.jsonObject(with:JSONEncoder().encode(request)) as! [String:Any]
   #expect(json["patient_id"] as? String == "selected");#expect(json["section"] as? String == section.rawValue)
   let doc=json["document"] as! [String:[String]];#expect(doc.count==5);#expect(doc["core_beliefs"]==["unsaved"])
  }
 }
 @Test func responses() throws {
  #expect(try ConceptSuggestionsResponse(suggestions:[]).validated().isEmpty)
  #expect(try ConceptSuggestionsResponse(suggestions:["a","a"]).validated()==["a"])
  #expect(throws:(any Error).self){try ConceptSuggestionsResponse(suggestions:Array(repeating:"a",count:5)).validated()}
 }
}
