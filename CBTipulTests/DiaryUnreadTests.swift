import Foundation
import XCTest
import Supabase
@testable import CBTipul

@MainActor final class DiaryUnreadTests: XCTestCase {
    let patient = "11111111-1111-4111-8111-111111111111"
    let other = "22222222-2222-4222-8222-222222222222"
    let entries = ["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1", "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2", "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3"]
    func key(_ index: Int) -> DiaryNotificationKey { DiaryNotificationKey(patientID: patient, resourceType: "diary_one_entry", entryID: entries[index])! }
    func fixture() async throws -> (SupabaseClient, NotificationStore) {
        DiaryUnreadHTTP.reset(patient: patient, other: other, entries: entries)
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [DiaryUnreadHTTP.self]
        let client = SupabaseClient(supabaseURL: URL(string: "https://diary-unread.invalid")!, supabaseKey: "synthetic",
            options: .init(auth: .init(storage: ClinicalTestAuthStorage(), autoRefreshToken: false), global: .init(session: URLSession(configuration: config))))
        _ = try await client.auth.signIn(email: "synthetic@example.invalid", password: "unused")
        let store = NotificationStore(client: client); await store.refresh()
        return (client,store)
    }
    func count(_ store: NotificationStore) -> Int { DiaryNotificationReadState.unreadKeys(store.notifications).filter {$0.patientID==patient}.count }
    func testThreeEntriesPushThenHistoryThenFinalAndRelaunch() async throws {
        let (client,store) = try await fixture()
        XCTAssertEqual(count(store),3);XCTAssertEqual(store.notifications.count,6)
        let originalEntries = Set(store.notifications.compactMap(DiaryNotificationKey.init).filter {$0.patientID==patient})
        let first = store.notifications.first {DiaryNotificationKey($0)==key(0)}!
        guard case .diaryOneEntry(let p,let resource,let id) = NotificationRouter.destination(from:first) else {return XCTFail("exact route required")}
        XCTAssertEqual(DiaryNotificationKey(patientID:p,resourceType:resource!,entryID:id!),key(0))
        // The view calls this only after the selected exact content has loaded and appeared.
        await store.markDiaryEntryRead(key(0));XCTAssertEqual(count(store),2)
        XCTAssertEqual(DiaryUnreadHTTP.writeCount(),2) // Duplicate notification rows, one entry.
        await store.markDiaryEntryRead(key(1));XCTAssertEqual(count(store),1)
        await store.markDiaryEntryRead(key(2));XCTAssertEqual(count(store),0)
        XCTAssertEqual(store.notifications.count,6) // Read notifications remain in history.
        XCTAssertEqual(Set(store.notifications.compactMap(DiaryNotificationKey.init).filter {$0.patientID==patient}),originalEntries)
        XCTAssertTrue(store.notifications.first {$0.type == .questionnaireCompleted}!.isUnread)
        XCTAssertTrue(store.notifications.first {$0.patientId==other}!.isUnread)
        let relaunched = NotificationStore(client:client);await relaunched.refresh()
        XCTAssertEqual(count(relaunched),0);XCTAssertEqual(relaunched.notifications.count,6)
    }
    func testNoReceiptForRefreshExpansionMissingOrFailedReceipt() async throws {
        let (_,store)=try await fixture()
        await store.refresh();XCTAssertEqual(DiaryUnreadHTTP.writeCount(),0)
        await store.markDiaryEntryRead(DiaryNotificationKey(patientID:patient,resourceType:"diary_one_entry",entryID:UUID().uuidString)!)
        XCTAssertEqual(DiaryUnreadHTTP.writeCount(),0);XCTAssertEqual(count(store),3)
        DiaryUnreadHTTP.failWrites(true);await store.markDiaryEntryRead(key(0))
        XCTAssertEqual(count(store),3);XCTAssertTrue(store.notifications.allSatisfy(\.isUnread))
    }
    func testColdEntryLoadAndDuplicateDeliveredAfterReading() async throws {
        let (client,store)=try await fixture();store.clear()
        await store.markDiaryEntryRead(key(0));XCTAssertEqual(count(store),2)
        DiaryUnreadHTTP.appendDuplicate()
        let relaunched=NotificationStore(client:client);await relaunched.refresh()
        XCTAssertEqual(count(relaunched),2)
        XCTAssertTrue(relaunched.notifications.filter {DiaryNotificationKey($0)==key(0)}.allSatisfy {!$0.isUnread})
    }
    func testAccountSwitchDiscardsAnInFlightReadResponse() async throws {
        let (_,store) = try await fixture()
        DiaryUnreadHTTP.holdNextWrite()
        let task = Task { await store.markDiaryEntryRead(key(0)) }
        for _ in 0..<200 {
            if DiaryUnreadHTTP.hasPendingWrite() { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertTrue(DiaryUnreadHTTP.hasPendingWrite())
        store.clear()
        DiaryUnreadHTTP.finishWrite()
        await task.value
        XCTAssertTrue(store.notifications.isEmpty)
    }
    func testMissingAndMismatchedIdentityNeverGuessLatest() async throws {
        let (_,store)=try await fixture();let item=store.notifications[0]
        let malformed=AppNotification(id:UUID(),type:.diaryTwoEntryAdded,patientId:patient,sessionId:nil,assignmentId:nil,resourceType:"diary_one_entry",resourceId:entries[0],createdAt:Date(),seenAt:nil,readAt:nil)
        XCTAssertNil(DiaryNotificationKey(malformed))
        XCTAssertNil(DiaryNotificationKey(patientID:patient,resourceType:"diary_one_entry",entryID:"latest"))
        XCTAssertNotEqual(DiaryNotificationKey(item),DiaryNotificationKey(patientID:other,resourceType:"diary_one_entry",entryID:entries[0]))
        XCTAssertNotEqual(key(0),DiaryNotificationKey(patientID:patient,resourceType:"diary_two_entry",entryID:entries[0]))
        XCTAssertEqual(DiaryUnreadHTTP.writeCount(),0)
    }
}

private final class DiaryUnreadHTTP: URLProtocol, @unchecked Sendable {
    static let lock=NSLock()
    static var rows:[[String:Any]]=[];static var writes=0;static var fail=false
    static var hold=false;static var pending:(() -> Void)?
    static func holdNextWrite(){lock.lock();defer{lock.unlock()};hold=true}
    static func hasPendingWrite()->Bool{lock.lock();defer{lock.unlock()};return pending != nil}
    static func finishWrite(){lock.lock();let action=pending;pending=nil;lock.unlock();action?()}
    static func reset(patient:String,other:String,entries:[String]) {
        lock.lock();defer{lock.unlock()};writes=0;fail=false;hold=false;pending=nil
        rows=(0..<6).map { i -> [String: Any] in
            let index = i == 3 ? 0 : min(i, 2)
            let type = i == 5 ? "questionnaire_completed" : "diary_1_entry_added"
            let resource = i == 5 ? "questionnaire" : "diary_one_entry"
            return ["id":String(format:"00000000-0000-4000-8000-%012d",i+1),"type":type,"patient_id":i==4 ? other:patient,"resource_type":resource,"resource_id":entries[index],"created_at":"2026-11-11T10:00:00Z","read_at":NSNull(),"seen_at":NSNull()]
        }
    }
    static func writeCount()->Int {lock.lock();defer{lock.unlock()};return writes}
    static func failWrites(_ value:Bool){lock.lock();defer{lock.unlock()};fail=value}
    static func appendDuplicate(){lock.lock();defer{lock.unlock()};var row=rows[0];row["id"]="00000000-0000-4000-8000-000000000099";row["read_at"]=NSNull();row["seen_at"]=NSNull();rows.append(row)}
    override class func canInit(with request:URLRequest)->Bool {true}
    override class func canonicalRequest(for request:URLRequest)->URLRequest {request}
    override func startLoading() {
        var data=request.httpBody ?? Data()
        if let stream=request.httpBodyStream {stream.open();defer{stream.close()};var bytes=[UInt8](repeating:0,count:2048);while stream.hasBytesAvailable {let n=stream.read(&bytes,maxLength:bytes.count);if n<=0{break};data.append(bytes,count:n)}}
        let body=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] ?? [:]
        let path=request.url!.path;var status=200;var response:Data
        Self.lock.lock()
        if path.hasSuffix("/token") {
            response=Data(#"{"access_token":"synthetic","refresh_token":"synthetic","token_type":"bearer","expires_in":3600,"expires_at":4102444800,"user":{"id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","aud":"authenticated","app_metadata":{},"user_metadata":{},"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}}"#.utf8)
        } else if path.hasSuffix("mark_notification_read") {
            if Self.fail {status=503;response=Data(#"{"code":"XX000","message":"synthetic failure"}"#.utf8)}
            else {Self.writes+=1;for i in Self.rows.indices where (Self.rows[i]["id"] as? String)?.lowercased()==(body["p_notification_id"] as? String)?.lowercased(){Self.rows[i]["read_at"]="2026-11-11T11:00:00Z"};response=Data("null".utf8)}
        } else if path.hasSuffix("notifications") {response=try! JSONSerialization.data(withJSONObject:Self.rows)}
        else {response=Data("0".utf8)}
        let shouldHold = Self.hold && path.hasSuffix("mark_notification_read")
        if shouldHold { Self.hold=false }
        Self.lock.unlock()
        let finish = {
        self.client?.urlProtocol(self,didReceive:HTTPURLResponse(url:self.request.url!,statusCode:status,httpVersion:nil,headerFields:["Content-Type":"application/json"])!,cacheStoragePolicy:.notAllowed)
        self.client?.urlProtocol(self,didLoad:response);self.client?.urlProtocolDidFinishLoading(self)
        }
        if shouldHold {Self.lock.lock();Self.pending=finish;Self.lock.unlock()} else {finish()}
    }
    override func stopLoading(){}
}
