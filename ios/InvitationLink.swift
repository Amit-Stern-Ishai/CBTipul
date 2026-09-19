import Foundation

/// Parses canonical patient-invitation Universal Links:
/// `https://cbtipul.com/invite/<TOKEN>`.
///
/// Does not claim the invitation or talk to the backend.
enum InvitationLink {
    static let host = "cbtipul.com"
    static let pathPrefix = "/invite/"

    static func token(from url: URL) -> String? {
        token(scheme: url.scheme, host: url.host(), path: url.path)
    }

    static func token(scheme: String?, host: String?, path: String?) -> String? {
        guard scheme?.lowercased() == "https" else { return nil }
        guard host?.lowercased() == Self.host else { return nil }
        let path = path ?? ""
        guard path.hasPrefix(pathPrefix) else { return nil }
        let token = String(path.dropFirst(pathPrefix.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if token.isEmpty || token.contains("/") { return nil }
        return token
    }
}
