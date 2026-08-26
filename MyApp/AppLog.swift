import OSLog

/// Central loggers, one per area of the app, all under the app's subsystem
/// so Console.app can filter them together.
///
/// Patient data is sensitive: log only events, database identifiers, counts,
/// durations and error descriptions — never clinical content (names, notes,
/// questionnaire answers, AI text).
enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "CBTipul"

    /// Sign in/up/out and session state.
    static let auth = Logger(subsystem: subsystem, category: "auth")
    /// Supabase reads/writes and the local caches.
    static let store = Logger(subsystem: subsystem, category: "store")
    /// AI features: chat, transcription, analysis, preparation, supervision.
    static let ai = Logger(subsystem: subsystem, category: "ai")
}
