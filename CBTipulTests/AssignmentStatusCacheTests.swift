import Foundation
import Testing
@testable import CBTipul

@MainActor
struct AssignmentStatusCacheTests {
    @Test func inactiveIsKnownAndSeparateFromNeverLoaded() {
        let cache = AssignmentStatusCache(), account = UUID()
        #expect(cache.value(account: account, resource: "diary") == nil)
        cache.store(nil, account: account, resource: "diary")
        #expect(cache.value(account: account, resource: "diary") != nil)
        #expect(cache.value(account: account, resource: "diary")?.assignmentId == nil)
    }
    @Test func isolatesAccountsPatientsAndAssignmentKinds() {
        let cache = AssignmentStatusCache(), account = UUID(), assignment = UUID()
        cache.store(assignment, account: account, resource: "patient/a/diary_one")
        #expect(cache.value(account: UUID(), resource: "patient/a/diary_one") == nil)
        #expect(cache.value(account: nil, resource: "patient/a/diary_one") == nil)
        #expect(cache.value(account: account, resource: "patient/b/diary_one") == nil)
        #expect(cache.value(account: account, resource: "patient/a/diary_two") == nil)
        cache.store(UUID(), account: nil, resource: "patient/a/diary_one")
        #expect(cache.value(account: account, resource: "patient/a/diary_one")?.assignmentId == assignment)
    }
    @Test func olderRefreshCannotUndoActivationOrCancellation() {
        let cache = AssignmentStatusCache(), account = UUID(), assignment = UUID()
        let beforeActivation = cache.revision(account: account, resource: "diary")
        cache.store(assignment, account: account, resource: "diary")
        cache.store(nil, account: account, resource: "diary", ifRevision: beforeActivation)
        #expect(cache.value(account: account, resource: "diary")?.assignmentId == assignment)
        let beforeCancellation = cache.revision(account: account, resource: "diary")
        cache.store(nil, account: account, resource: "diary")
        cache.store(assignment, account: account, resource: "diary", ifRevision: beforeCancellation)
        #expect(cache.value(account: account, resource: "diary") != nil)
        #expect(cache.value(account: account, resource: "diary")?.assignmentId == nil)
    }
    @Test func freshRefreshReplacesLastKnownState() {
        let cache = AssignmentStatusCache(), account = UUID()
        cache.store(UUID(), account: account, resource: "diary")
        let revision = cache.revision(account: account, resource: "diary")
        cache.store(nil, account: account, resource: "diary", ifRevision: revision)
        #expect(cache.value(account: account, resource: "diary")?.assignmentId == nil)
    }
}
