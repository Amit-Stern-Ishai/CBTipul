import Foundation
import Observation
import OSLog

struct AppVersionPolicy: Decodable, Equatable, Sendable {
    let platform: String
    let latestBuild: Int
    let minimumBuild: Int
    let latestVersion: String
    let storeUrl: String

    var validatedStoreURL: URL? {
        guard let url = URL(string: storeUrl), url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { return nil }
        return url
    }

    func isValid(for platform: String) -> Bool {
        self.platform == platform && latestBuild > 0 && minimumBuild > 0 && minimumBuild <= latestBuild
            && validatedStoreURL != nil
    }
}

enum AppVersionDecision: Equatable {
    case current, optional, required
    static func evaluate(installed: Int?, policy: AppVersionPolicy, platform: String) -> Self {
        guard let installed, installed > 0, policy.isValid(for: platform) else { return .current }
        if installed < policy.minimumBuild { return .required }
        return installed < policy.latestBuild ? .optional : .current
    }
}

enum AppVersionService {
    static let timeout: TimeInterval = 4
    static func request(platform: String) -> URLRequest {
        var request = URLRequest(url: SupabaseConfig.url.appendingPathComponent("functions/v1/get-app-version-policy"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONEncoder().encode(["platform": platform])
        request.timeoutInterval = timeout
        return request
    }
    static func fetch(platform: String) async throws -> AppVersionPolicy {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request(platform: platform))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(AppVersionPolicy.self, from: data)
    }
}

@MainActor @Observable
final class AppVersionManager {
    static let dismissalKey = "cbtipul.dismissedOptionalUpdateBuild"
    static let refreshInterval: TimeInterval = 6 * 60 * 60
    private(set) var checkingInitially = true
    private(set) var decision: AppVersionDecision = .current
    private(set) var policy: AppVersionPolicy?
    private(set) var optionalVisible = false
    private(set) var lastSuccess: Date?
    private var lastAttempt: Date?
    private var checking = false
    private let installed: Int?
    private let defaults: UserDefaults
    private let now: () -> Date
    private let fetch: (String) async throws -> AppVersionPolicy

    init(installed: Int? = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""),
         defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init,
         fetch: @escaping (String) async throws -> AppVersionPolicy = AppVersionService.fetch) {
        self.installed = installed; self.defaults = defaults; self.now = now; self.fetch = fetch
    }

    func check(coldLaunch: Bool = false) async {
        guard !checking else { return }
        let date = now()
        if !coldLaunch && decision != .required {
            if let lastSuccess, date.timeIntervalSince(lastSuccess) < Self.refreshInterval { return }
            // Failed checks do not trigger a network request on every brief foreground transition.
            if let lastAttempt, date.timeIntervalSince(lastAttempt) < 60 { return }
        }
        checking = true; lastAttempt = date
        defer { checking = false; checkingInitially = false }
        guard let installed, installed > 0 else { failOpen(); return }
        do {
            let result = try await fetch("ios")
            guard result.isValid(for: "ios") else { failOpen(); return }
            policy = result
            decision = AppVersionDecision.evaluate(installed: installed, policy: result, platform: "ios")
            optionalVisible = decision == .optional && defaults.integer(forKey: Self.dismissalKey) != result.latestBuild
            lastSuccess = now()
        } catch {
            failOpen()
        }
    }

    func dismissOptional() {
        guard decision == .optional, let policy else { return }
        defaults.set(policy.latestBuild, forKey: Self.dismissalKey)
        optionalVisible = false
    }

    private func failOpen() {
        decision = .current; policy = nil; optionalVisible = false
        AppLog.store.notice("App version policy unavailable or invalid; continuing normally")
    }
}
