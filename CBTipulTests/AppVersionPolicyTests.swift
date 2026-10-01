import Foundation
import Testing
@testable import CBTipul

@MainActor @Suite(.serialized)
struct AppVersionPolicyTests {
    private func policy(latest: Int = 5, minimum: Int = 3, platform: String = "ios", url: String = "https://apps.apple.com/test-policy") -> AppVersionPolicy {
        AppVersionPolicy(platform: platform, latestBuild: latest, minimumBuild: minimum,
                         latestVersion: "1.0.10", storeUrl: url)
    }
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "version-tests-\(UUID().uuidString)")!
    }
    @Test func buildDecisions() {
        #expect(AppVersionDecision.evaluate(installed: 5, policy: policy(minimum: 5), platform: "ios") == .current)
        #expect(AppVersionDecision.evaluate(installed: 4, policy: policy(), platform: "ios") == .optional)
        #expect(AppVersionDecision.evaluate(installed: 2, policy: policy(), platform: "ios") == .required)
        #expect(AppVersionDecision.evaluate(installed: 6, policy: policy(), platform: "ios") == .current)
        #expect(AppVersionDecision.evaluate(installed: nil, policy: policy(), platform: "ios") == .current)
        #expect(AppVersionDecision.evaluate(installed: 0, policy: policy(), platform: "ios") == .current)
    }
    @Test func malformedPoliciesFailOpen() async {
        for bad in [policy(latest: 0), policy(minimum: 0), policy(minimum: 6), policy(platform: "android"),
                    policy(url: "http://apps.apple.com/test"), policy(url: "https:///"), policy(url: "garbage")] {
            let manager = AppVersionManager(installed: 1, defaults: defaults(), fetch: { _ in bad })
            await manager.check(coldLaunch: true)
            #expect(manager.decision == .current)
            #expect(!manager.checkingInitially)
            #expect(manager.lastSuccess == nil)
        }
    }
    @Test func networkAndTimeoutFailOpenIncludingAfterRequired() async {
        for code in [URLError.notConnectedToInternet, .timedOut, .badServerResponse, .cannotDecodeContentData] {
            var failed = false
            let manager = AppVersionManager(installed: 1, defaults: defaults(), fetch: { _ in
                if failed { throw URLError(code) }
                return policy()
            })
            await manager.check(coldLaunch: true)
            #expect(manager.decision == .required)
            failed = true
            await manager.check()
            #expect(manager.decision == .current)
            #expect(!manager.checkingInitially)
            #expect(manager.policy == nil)
        }
    }
    @Test func dismissalPersistsNewBuildRepromptsAndRequiredOverrides() async {
        let storage = defaults()
        var remote = policy()
        let first = AppVersionManager(installed: 4, defaults: storage, fetch: { _ in remote })
        await first.check(coldLaunch: true)
        #expect(first.optionalVisible)
        first.dismissOptional()
        #expect(storage.integer(forKey: AppVersionManager.dismissalKey) == 5)
        let nextLaunch = AppVersionManager(installed: 4, defaults: storage, fetch: { _ in remote })
        await nextLaunch.check(coldLaunch: true)
        #expect(!nextLaunch.optionalVisible)
        remote = policy(latest: 6)
        await nextLaunch.check(coldLaunch: true)
        #expect(nextLaunch.optionalVisible)
        nextLaunch.dismissOptional()
        remote = policy(latest: 6, minimum: 5)
        await nextLaunch.check(coldLaunch: true)
        #expect(nextLaunch.decision == .required)
        #expect(!nextLaunch.optionalVisible)
    }
    @Test func foregroundTimingAndRequiredBypass() async {
        var now = Date(timeIntervalSince1970: 100_000)
        var calls = 0
        var remote = policy()
        let manager = AppVersionManager(installed: 5, defaults: defaults(), now: { now }, fetch: { platform in
            #expect(platform == "ios")
            calls += 1
            return remote
        })
        await manager.check(coldLaunch: true)
        now += 60
        await manager.check()
        #expect(calls == 1)
        now += AppVersionManager.refreshInterval
        await manager.check()
        #expect(calls == 2)
        remote = policy(latest: 8, minimum: 7)
        await manager.check(coldLaunch: true)
        await manager.check()
        #expect(calls == 4)
        remote = policy(latest: 5)
        await manager.check()
        #expect(manager.decision == .current)
    }
    @Test func publicRequestAndBackendStoreURL() async throws {
        let request = AppVersionService.request(platform: "ios")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.url?.lastPathComponent == "get-app-version-policy")
        #expect(try JSONDecoder().decode([String: String].self, from: #require(request.httpBody)) == ["platform": "ios"])
        #expect(request.timeoutInterval == 4)
        let supplied = "https://apps.apple.com/custom-backend-listing"
        let manager = AppVersionManager(installed: 1, defaults: defaults(), fetch: { _ in policy(url: supplied) })
        await manager.check(coldLaunch: true)
        #expect(manager.policy?.validatedStoreURL?.absoluteString == supplied)
    }
    @Test func invalidJSONCannotBecomePolicy() {
        #expect(throws: (any Error).self) { try JSONDecoder().decode(AppVersionPolicy.self, from: Data("{}".utf8)) }
    }
}
