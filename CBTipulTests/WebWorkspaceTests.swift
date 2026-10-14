import Foundation
import Testing
import Supabase
@testable import CBTipul

@MainActor @Suite(.serialized) struct WebWorkspaceTests {
    static let fixture = #"{"id": "11111111-1111-1111-1111-111111111111", "status": "pending", "started_at": "2026-10-13T13:00:00.123+03:00", "finished_at": "2026-10-13T13:45:00+03:00", "reference_label": "בדיקה מקומית", "payload": {"version": 1, "notes": "הערות לבדיקה בלבד", "items": [{"id": "22222222-2222-2222-2222-000000000001", "type": "questionnaire", "completed_at": "2026-10-13T13:30:00.123+03:00", "data": {"gad7_answers": [0, 1, 2, 3, 0, 1, 2], "phq9_answers": [0, 1, 2, 3, 0, 1, 2, 3, 1], "interference_level": 2, "notes": "הערת שאלון"}, "measurement_date": "2026-10-10"}, {"id": "22222222-2222-2222-2222-000000000002", "type": "diary_one", "completed_at": "2026-10-13T13:30:00.123+03:00", "data": {"event": "אירוע לבדיקה", "automatic_thoughts": ["מחשבה אחת", "מחשבה נוספת"], "feelings": [{"name": "עצב", "intensity": 0}], "behaviour": "התנהגות", "physical_symptoms": null}}, {"id": "22222222-2222-2222-2222-000000000003", "type": "diary_two", "completed_at": "2026-10-13T13:30:00.123+03:00", "data": {"event": "אירוע נוסף", "automatic_thoughts": ["מחשבה"], "feelings": [{"name": "דאגה", "intensity": 100}], "thinking_errors": ["mind_reading"], "alternative_thoughts": ["מחשבה חלופית"]}}, {"id": "22222222-2222-2222-2222-000000000004", "type": "diary_three", "completed_at": "2026-10-13T13:30:00.123+03:00", "data": {"situation": "מצב לבדיקה", "automatic_thoughts": [{"text": "מחשבה", "beliefBefore": 100, "beliefAfter": 0}], "feelings": [{"name": "דאגה", "intensityBefore": 100, "intensityAfter": 0}], "thinking_errors": ["fortune_telling"], "alternative_thoughts": [{"text": "מחשבה חלופית", "belief": 85}]}}]}}"#
    let id = "11111111-1111-1111-1111-111111111111"
    let patient = "33333333-3333-3333-3333-333333333333"
    let session = "44444444-4444-4444-4444-444444444444"
    func request(notes: Bool = false, linked: Bool = false, create: Bool = false) -> WebAssociationRequest {
        WebAssociationRequest(p_workspace_id: id, p_patient_id: patient, p_existing_session_id: (notes || linked) && !create ? session : nil, p_create_session: create, p_link_questionnaire: linked, p_session_date: create ? "2026-10-14" : nil, p_session_type: create ? "intake" : nil)
    }
    @Test func allWorksheetFormatsPreserveTimestampsAndRatings() throws {
        let workspace = try JSONDecoder().decode(WebWorkspace.self, from: Data(Self.fixture.utf8))
        #expect(workspace.payload.items.count == 4 && workspace.payload.hasNotes)
        #expect(workspace.started_at == "2026-10-13T13:00:00.123+03:00")
        let item = workspace.payload.items[0]
        #expect(item.measurement_date == "2026-10-10")
        #expect(item.completed_at == "2026-10-13T13:30:00.123+03:00")
        guard case .questionnaire(let q) = item.content, case .diaryOne(let one) = workspace.payload.items[1].content,
              case .diaryTwo(let two) = workspace.payload.items[2].content, case .diaryThree(let three) = workspace.payload.items[3].content else { Issue.record("Wrong worksheet types"); return }
        #expect(q.questionnaire.gad7Score == 9 && q.questionnaire.phq9Score == 13 && q.flagsQuestionNine)
        #expect(one.automatic_thoughts.count == 2 && one.feelings[0].intensity == 0 && one.physical_symptoms == nil)
        #expect(two.alternative_thoughts?.count == 1 && two.feelings[0].intensity == 100)
        #expect(three.automatic_thoughts[0].beliefBefore == 100 && three.automatic_thoughts[0].beliefAfter == 0)
        #expect(three.feelings[0].intensityAfter == 0 && three.alternative_thoughts[0].belief == 85)
    }
    @Test func parameterMatrixAndIdentifierOnlyEncoding() throws {
        for hasNotes in [false, true] { for linked in [false, true] { for create in [false, true] {
            let r = request(notes: hasNotes, linked: linked, create: create)
            if create && !hasNotes && !linked { #expect(throws: WebWorkspaceFailure.self) { try r.validate(hasNotes: hasNotes, hasQuestionnaire: true) } }
            else { try r.validate(hasNotes: hasNotes, hasQuestionnaire: true) }
        } } }
        #expect(throws: WebWorkspaceFailure.self) { try request(linked: true).validate(hasNotes: false, hasQuestionnaire: false) }
        #expect(throws: WebWorkspaceFailure.self) { try request().validate(hasNotes: true, hasQuestionnaire: true) }
        let r = request(notes: true)
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(r)) as! [String: Any]
        #expect(json["p_patient_id"] as? String == patient)
        #expect(json["p_link_questionnaire"] as? Bool == false)
        #expect(json["p_session_date"] == nil && json["p_session_type"] == nil)
        #expect(!json.keys.contains { $0.contains("name") })
    }
    @Test func bigintResourceIdentifiersRemainStrings() throws {
        let result = try JSONDecoder().decode(WebAssociationResult.self, from: Data(receipt.utf8))
        #expect(result.resources[0].id == "9223372036854775806")
    }
    var receipt: String { """
    {"workspace_id":"\(id)","patient_id":"\(patient)","session_id":null,"resources":[{"item_id":"\(id)","type":"questionnaire","id":"9223372036854775806"}]}
    """ }
    @Test func lostResponsePersistsExactRequestAcrossStoreRecreation() async throws {
        let suite = "WebWorkspaceTests.\(UUID())"; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var bodies: [Data] = []; var refreshed = 0
        let rpc: (String, Data) async throws -> Data = { name, body in
            if name == "list_pending_web_workspaces" { return Data("[]".utf8) }
            bodies.append(body)
            if bodies.count == 1 { throw URLError(.networkConnectionLost) }
            return Data(receipt.utf8)
        }
        let first = WebWorkspaceStore(defaults: defaults, currentUser: { "therapist-a" }, canWrite: { true }, rpc: rpc)
        #expect(first.associationCount == 0)
        do { try await first.associate(request(notes: true)); Issue.record("Must report lost response") } catch {}
        #expect(first.requests[id] == request(notes: true))
        #expect(first.associationCount == 1)
        let second = WebWorkspaceStore(defaults: defaults, currentUser: { "therapist-a" }, canWrite: { true }, rpc: rpc)
        second.refreshRecords = { _ in refreshed += 1; return true }
        try await second.associate(request(linked: true, create: true))
        #expect(bodies.count == 2)
        #expect(try JSONDecoder().decode(WebAssociationRequest.self, from: bodies[0]) == JSONDecoder().decode(WebAssociationRequest.self, from: bodies[1]))
        #expect(second.requests.isEmpty && refreshed == 1)
        #expect(second.associationCount == 0)
        let other = WebWorkspaceStore(defaults: defaults, currentUser: { "therapist-b" }, canWrite: { true }, rpc: rpc)
        await other.refresh(); #expect(other.requests.isEmpty)
    }
    @Test func conflictUnlocksChoicesAndReadOnlyNeverMutates() async throws {
        let suite = "WebWorkspaceTests.\(UUID())"; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let conflict = try JSONDecoder().decode(PostgrestError.self, from: Data(#"{"message":"session_already_has_questionnaire","code":"P0001","details":null,"hint":null}"#.utf8))
        let store = WebWorkspaceStore(defaults: defaults, currentUser: { "therapist" }, canWrite: { true }, rpc: { _,_ in throw conflict })
        do { try await store.associate(request(linked: true)); Issue.record("Expected conflict") }
        catch { #expect(error as? WebWorkspaceFailure == .conflict) }
        #expect(store.requests.isEmpty)
        var calls = 0
        let readOnly = WebWorkspaceStore(defaults: defaults, currentUser: { "therapist" }, canWrite: { false }, rpc: { _,_ in calls += 1; return Data("[]".utf8) })
        do { try await readOnly.associate(request()); Issue.record("Expected denial") } catch {}
        do { try await readOnly.discard(id); Issue.record("Expected denial") } catch {}
        #expect(calls == 0)
        await readOnly.refresh(); #expect(calls == 1)
    }
    @Test func closedWorkspaceCannotOfferAnotherTransfer() async throws {
        let suite = "WebWorkspaceTests.\(UUID())"; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let rejection = try JSONDecoder().decode(PostgrestError.self, from: Data(#"{"message":"already_associated","code":"P0001","details":null,"hint":null}"#.utf8))
        var transfers = 0
        let store = WebWorkspaceStore(defaults: defaults, currentUser: { "therapist" }, canWrite: { true }, rpc: { name,_ in
            if name == "list_pending_web_workspaces" { return Data("[]".utf8) }
            transfers += 1; throw rejection
        })
        do { try await store.discard(id); Issue.record("Expected closed workspace") } catch {}
        #expect(store.closedIDs.contains(id))
        do { try await store.associate(request()); Issue.record("Expected closed workspace") } catch {}
        #expect(transfers == 1)
    }
    @Test func notificationsRouteWithoutPatientOrSession() {
        let payload = AppNotificationPayload(typeRaw: "web_workspace_ready", notificationId: nil, patientId: nil, sessionId: nil, assignmentId: nil, resourceType: "web_workspace", resourceId: id)
        #expect(NotificationRouter.destination(from: payload) == .webWorkspace(id: id))
        #expect(!payload.type.routesInPatientMode)
        let coordinator = TherapistNotificationCoordinator.shared
        coordinator.resetOnLogout(); coordinator.markTherapistRootReady()
        coordinator.handlePushTap(userInfo: ["type": "web_workspace_ready", "resource_type": "web_workspace", "resource_id": id])
        coordinator.processPending(patients: [])
        #expect(coordinator.pendingWorkspace?.id == id && coordinator.selectedTab == .notifications)
        coordinator.pendingWorkspace = nil
        coordinator.handlePushTap(userInfo: ["type": "web_workspace_ready", "resource_type": "web_workspace", "resource_id": id])
        coordinator.processPending(patients: [])
        #expect(coordinator.pendingWorkspace == nil)
        coordinator.resetOnLogout()
    }
}
