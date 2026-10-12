import Foundation

nonisolated enum PostHogTelemetryConfiguration {
    static let projectToken = "phc_zizZLMjDQtJRcuLR6TQPdohGFhDFQXGvmLBqPeYY3KiE"
    static let host = "https://eu.i.posthog.com"
    // Collection enabled. Local build checks must not launch the app.
    static let enabled = true
    static var valid: Bool { valid(token: projectToken, host: host) }
    static func valid(token: String, host: String) -> Bool {
        host == "https://eu.i.posthog.com" && token.hasPrefix("phc_") && token.count > 8 &&
        token.count < 200 && token.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }
    }
}
