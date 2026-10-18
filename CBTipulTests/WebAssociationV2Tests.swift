import Foundation
import Testing
import Supabase
@testable import CBTipul

@MainActor @Suite(.serialized) struct WebAssociationV2Tests {
    let workspace = "11111111-1111-1111-1111-111111111111"
    let patient = "33333333-3333-3333-3333-333333333333"
    let session = "44444444-4444-4444-4444-444444444444"
    let item = "22222222-2222-2222-2222-222222222222"
    let bigID = "9223372036854775806"
    func base(link: Bool = true, sessionTarget: Bool = true) -> WebAssociationRequest {
        .init(p_workspace_id: workspace,p_patient_id: patient,p_existing_session_id: sessionTarget ? session : nil,p_create_session: false,p_link_questionnaire: link,p_session_date:nil,p_session_type:nil)
    }
    func candidate(incoming: Bool = false, disabled: Bool = false, current: Bool = false, id: String? = nil) -> [String:Any] {
        ["source":incoming ? "incoming":"existing","id":incoming ? NSNull(): (id ?? bigID) as Any,"item_id":incoming ? item as Any:NSNull(),"measurement_date":current ? "2026-09-20":"2026-10-10","recorded_at":"2026-10-13T13:30:00Z","time_kind":incoming ? "completed_at":"created_at","session_id":disabled ? "55555555-5555-5555-5555-555555555555" as Any:current ? session as Any:NSNull(),"selectable": !disabled,"is_current_session_questionnaire":current,"gad7_answers":Array(repeating:1,count:7),"phq9_answers":Array(repeating:1,count:9),"interference_level":2,"gad7_score":7,"phq9_score":9]
    }
    func previewData(_ candidates: [[String:Any]], append: Bool = false, token: String = "token-one", sessionTarget: Bool = true) throws -> Data {
        try JSONSerialization.data(withJSONObject:["workspace_id":workspace,"patient_id":patient,"session_id":sessionTarget ? session as Any:NSNull(),"preview_token":token,"has_notes":append,"session_has_notes":append,"notes_will_append":append,"candidate_measurement_date":"2026-10-10","questionnaires":candidates,"selectable_questionnaire_count":candidates.filter { $0["selectable"] as? Bool == true }.count,"requires_questionnaire_choice":candidates.filter { $0["selectable"] as? Bool == true }.count>1,"current_session_questionnaire_id":candidates.contains { $0["is_current_session_questionnaire"] as? Bool == true } ? bigID as Any:NSNull()])
    }
    func decode(_ data: Data) throws -> WebAssociationPreview { try JSONDecoder().decode(WebAssociationPreview.self,from:data) }
    var receipt: Data { Data("{\"workspace_id\":\"\(workspace)\",\"patient_id\":\"\(patient)\",\"session_id\":\"\(session)\",\"resources\":[],\"linked_questionnaire_id\":\"\(bigID)\",\"notes_appended\":true}".utf8) }
    func defaults() -> UserDefaults { UserDefaults(suiteName:"WebAssociationV2Tests.\(UUID())")! }

    @Test func candidatesPreserveDaysTimesStringIDsAndQuestionNine() throws {
        let p = try decode(previewData([candidate(incoming:true),candidate(),candidate(current:true,id:"9007199254740993"),candidate(disabled:true,id:"12")]))
        #expect(p.questionnaires.count==4 && p.selectable_questionnaire_count==3)
        #expect(p.questionnaires[0].time_kind=="completed_at" && p.questionnaires[1].time_kind=="created_at")
        #expect(p.questionnaires[0].measurement_date=="2026-10-10")
        #expect(p.questionnaires[2].measurement_date=="2026-09-20" && p.questionnaires[2].is_current_session_questionnaire)
        #expect(p.questionnaires[1].recordID==bigID && p.questionnaires[2].recordID=="9007199254740993")
        #expect(p.questionnaires[0].flagsQuestionNine && !p.questionnaires[3].selectable)
    }
    @Test func choicesEncodeExactlyAndNeverMoveDisabledCandidates() throws {
        let p=try decode(previewData([candidate(incoming:true),candidate(),candidate(disabled:true,id:"12")]))
        #expect(throws:WebWorkspaceFailure.self) { try p.prepare(base(),choice:nil) }
        let incoming=try p.prepare(base(),choice:.incoming(item))
        let json=try JSONSerialization.jsonObject(with:JSONEncoder().encode(incoming)) as! [String:Any]
        #expect((json["p_questionnaire_choice"] as? [String:String]) == ["source":"incoming","item_id":item])
        let existing=try p.prepare(base(),choice:.existing(bigID))
        let choice=try JSONSerialization.jsonObject(with:JSONEncoder().encode(existing.p_questionnaire_choice)) as! [String:String]
        #expect(choice == ["source":"existing","id":bigID])
        #expect(throws:WebWorkspaceFailure.self) { try p.prepare(base(),choice:.existing("12")) }
    }
    @Test func notesOnlyAndPatientOnlyPreserveResultsAndLinks() throws {
        let p=try decode(previewData([candidate(),candidate(current:true,id:"2")],append:true))
        let r=try p.prepare(base(),choice:.existing(bigID))
        try r.validate(hasNotes:true,hasQuestionnaire:false)
        #expect(!r.p_acknowledge_existing_notes)
        #expect(try p.confirmed(r).p_acknowledge_existing_notes)
        let preserve=try p.prepare(base(link:false),choice:.existing(bigID))
        let json=try JSONSerialization.jsonObject(with:JSONEncoder().encode(preserve)) as! [String:Any]
        #expect(json["p_questionnaire_choice"] is NSNull)
        let patientOnly=try decode(previewData([candidate(incoming:true),candidate()],sessionTarget:false))
        let standalone=try patientOnly.prepare(base(link:false,sessionTarget:false),choice:nil)
        try standalone.validate(hasNotes:false,hasQuestionnaire:true)
        #expect(standalone.p_existing_session_id==nil && !standalone.p_link_questionnaire)
    }
    @Test func missingMetadataAndIncompleteAnswersDoNotInventScores() throws {
        let c:[String:Any] = ["source":"existing","id":bigID,"selectable":true,"is_current_session_questionnaire":false,"phq9_answers":[NSNull(),NSNull(),NSNull(),NSNull(),NSNull(),NSNull(),NSNull(),NSNull(),1]]
        let p=try decode(previewData([c]))
        #expect(p.questionnaires[0].measurement_date==nil && p.questionnaires[0].gad7_score==nil)
        #expect(p.questionnaires[0].recorded_at==nil && !p.questionnaires[0].hasCompleteAnswers && p.questionnaires[0].flagsQuestionNine)
    }
    @Test func changedTargetsAndOldTokensCannotBeConfirmed() throws {
        let p=try decode(previewData([candidate()],append:true))
        var r=try p.prepare(base(),choice:.existing(bigID)); r.p_preview_token="old-token"
        #expect(throws:WebWorkspaceFailure.self) { try p.confirmed(r) }
        let other=WebAssociationRequest(p_workspace_id:workspace,p_patient_id:"99999999-9999-9999-9999-999999999999",p_existing_session_id:session,p_create_session:false,p_link_questionnaire:true,p_session_date:nil,p_session_type:nil)
        #expect(throws:WebWorkspaceFailure.self) { try p.prepare(other,choice:.existing(bigID)) }
    }
    @Test func previewTransportUsesOnlyExactTargetAndSupportsReadOnly() async throws {
        var calls:[String]=[]; var body:[String:Any]=[:]
        let target=WebAssociationTarget(p_workspace_id:workspace,p_patient_id:patient,p_existing_session_id:nil,p_create_session:true,p_session_date:"2026-10-15",p_session_type:"intake")
        let store=WebWorkspaceStore(defaults:defaults(),currentUser:{"owner"},canWrite:{false},rpc:{name,data in calls.append(name);body=try JSONSerialization.jsonObject(with:data) as! [String:Any];return try previewData([candidate()],sessionTarget:false)})
        _ = try await store.preview(target)
        #expect(body["p_session_date"] as? String=="2026-10-15" && body["p_create_session"] as? Bool==true)
        #expect(body["p_link_questionnaire"]==nil && body["p_questionnaire_choice"]==nil)
        do { try await store.associate(base()); Issue.record("read-only mutation") } catch { #expect(error as? WebWorkspaceFailure == .readOnly) }
        #expect(calls==["preview_web_workspace_association"])
    }
    @Test func stalePreviewIsClearedAndNeedsFreshExplicitConfirmation() async throws {
        let rejection=try JSONDecoder().decode(PostgrestError.self,from:Data(#"{"message":"association_preview_changed","code":"P0001","details":null,"hint":null}"#.utf8))
        var writes=0;var previews=0
        let store=WebWorkspaceStore(defaults:defaults(),currentUser:{"owner"},canWrite:{true},rpc:{name,_ in
            if name=="preview_web_workspace_association" { previews+=1;return try previewData([candidate(),candidate(incoming:true)],append:true,token:previews==1 ? "one":"two") }
            if name=="list_pending_web_workspaces" { return Data("[]".utf8) }
            #expect(name=="associate_web_workspace_v2");writes+=1
            if writes==1 { throw rejection };return receipt
        })
        let first=try await store.preview(base().target)
        do { try await store.associate(first.confirmed(first.prepare(base(),choice:.existing(bigID))));Issue.record("must reject stale") } catch { #expect(error as? WebWorkspaceFailure == .previewChanged) }
        #expect(store.requests.isEmpty && store.busyIDs.isEmpty && writes==1)
        let fresh=try await store.preview(base().target)
        #expect(throws:WebWorkspaceFailure.self) {try fresh.prepare(base(),choice:nil)}
        try await store.associate(fresh.confirmed(fresh.prepare(base(),choice:.incoming(item))))
        #expect(writes==2 && previews==2 && store.linkedQuestionnaireID==bigID)
    }
    @Test func uncertainRetryKeepsTokenChoiceAndAcknowledgementWithoutDoubleAppend() async throws {
        let persistence=defaults();var bodies:[WebAssociationRequest]=[];var appends=0;var refreshed=0
        let rpc:(String,Data)async throws->Data={name,data in
            if name=="list_pending_web_workspaces" { return Data("[]".utf8) }
            #expect(name=="associate_web_workspace_v2")
            let r=try JSONDecoder().decode(WebAssociationRequest.self,from:data);bodies.append(r)
            if bodies.count==1 {appends+=1;throw URLError(.networkConnectionLost)}
            #expect(r==bodies[0]);return receipt
        }
        let p=try decode(previewData([candidate(),candidate(incoming:true)],append:true))
        let submitted=try p.confirmed(p.prepare(base(),choice:.existing(bigID)))
        let first=WebWorkspaceStore(defaults:persistence,currentUser:{"owner"},canWrite:{true},rpc:rpc)
        do {try await first.associate(submitted)}catch{}
        let second=WebWorkspaceStore(defaults:persistence,currentUser:{"owner"},canWrite:{true},rpc:rpc)
        second.refreshRecords={_ in refreshed+=1;return true}
        try await second.associate(base(link:false))
        #expect(bodies.count==2 && bodies[0]==bodies[1] && appends==1 && refreshed==1)
        #expect(bodies[1].p_acknowledge_existing_notes && bodies[1].p_preview_token==p.preview_token)
        #expect(second.requests.isEmpty && second.linkedQuestionnaireID==bigID)
    }
    @Test func singleEligibleIsAutomaticButMultipleAlwaysNeedExplicitChoice() throws {
        let only = try decode(previewData([candidate(incoming:true),candidate(disabled:true,id:"12")]))
        #expect(only.resolvedChoice(nil) == .incoming(item))
        let multiple = try decode(previewData([candidate(incoming:true),candidate()]))
        #expect(multiple.resolvedChoice(nil) == nil)
        #expect(multiple.resolvedChoice(.existing(bigID)) == .existing(bigID))
        #expect(multiple.resolvedChoice(.existing("12")) == nil)
        #expect(only.resolvedChoice(.existing("12")) == .incoming(item))
    }
    @Test func finalSaveAcknowledgesInlineAppendWithoutAnotherInteraction() throws {
        let p = try decode(previewData([candidate()],append:true))
        let selected = p.resolvedChoice(nil)
        let submitted = try p.confirmed(p.prepare(base(),choice:selected))
        #expect(submitted.p_acknowledge_existing_notes && submitted.p_questionnaire_choice == .existing(bigID))
        let notesOnly = try p.confirmed(p.prepare(base(link:false),choice:nil))
        #expect(notesOnly.p_acknowledge_existing_notes && notesOnly.p_questionnaire_choice == nil)
    }
    @Test func staleRefreshKeepsValidChoiceButNeverAcknowledgesNewAppendWarningSilently() throws {
        let previous = try decode(previewData([candidate(),candidate(incoming:true)],append:true))
        let submitted = try previous.confirmed(previous.prepare(base(),choice:.existing(bigID)))
        let fresh = try decode(previewData([candidate(),candidate(incoming:true)],append:true,token:"fresh"))
        #expect(fresh.canContinueSaving(submitted,choice:fresh.resolvedChoice(.existing(bigID)),appendWasVisible:true))
        #expect(!fresh.canContinueSaving(submitted,choice:nil,appendWasVisible:true))
        let notesRequest = try previous.confirmed(previous.prepare(base(link:false),choice:nil))
        let noNotes = try decode(previewData([],append:false,token:"no-notes"))
        #expect(!noNotes.canContinueSaving(notesRequest,choice:nil,appendWasVisible:true))
        #expect(!fresh.canContinueSaving(submitted,choice:.existing(bigID),appendWasVisible:false))
        let replacement = try decode(previewData([candidate(incoming:true)],token:"changed"))
        #expect(!replacement.canContinueSaving(submitted,choice:replacement.resolvedChoice(.existing(bigID)),appendWasVisible:true))
    }
    @Test func knownServerRejectionIsNotAnUncertainSaveAndDoesNotLockRetry() async throws {
        for code in ["PGRST202","42883","23514"] {
            let failure = try JSONDecoder().decode(PostgrestError.self,from:Data("{\"message\":\"rejected\",\"code\":\"\(code)\",\"details\":null,\"hint\":null}".utf8))
            let expected: WebWorkspaceFailure = code == "23514" ? .rejected : .serviceUnavailable
            #expect(WebWorkspaceFailure.classify(failure) == expected)
            let store = WebWorkspaceStore(defaults:defaults(),currentUser:{"owner"},canWrite:{true},rpc:{_,_ in throw failure})
            let p=try decode(previewData([candidate()]))
            do {try await store.associate(p.confirmed(p.prepare(base(),choice:p.resolvedChoice(nil))))}catch{#expect(error as? WebWorkspaceFailure == expected)}
            #expect(store.requests.isEmpty && store.busyIDs.isEmpty)
        }
        #expect(WebWorkspaceFailure.classify(URLError(.networkConnectionLost)) == .uncertain)
    }

}
